#!/usr/bin/env python3
"""Exercise banner creation and request configuration in both slices of an editable IPA.

Requires Unicorn 2.1.4. The tested SDK methods run as linked machine code.
The harness supplies Objective-C dispatch, object allocation, and off-device
stand-ins for UIKit, Foundation and the slot's web view and service objects.
"""
import argparse
from pathlib import Path
import struct

from check_gameplay import ARG_REGS, GAME, RETURN, STACK, Machine, arm, float_bits, word
from check_editable_admob import RuntimeMetadata, candidate_images
from linkmatch import word as file_word
from unicorn import UC_HOOK_CODE
from verify import ROOT


class AdMachine:
    # Select the classes under test. Unexpected calls fail rather than silently
    # succeeding against an unrelated service.
    tested = {"GADBannerView", "GADSlot", "GADAdType", "GADRequest", "GADRequestPrivate"}
    standins = {"GADDelegateManager", "GADWebView", "GADBannerWebViewDelegate",
                "GADSlotStatistics", "GADMToGADGlue", "GADTiming"}

    def __init__(self, image):
        self.meta = RuntimeMetadata(image.data)
        self.layout = self.meta.layout
        self.cpu = Machine(image.data, {}).cpu
        self.next_object = GAME
        self.objects = {}
        self.classes = {info.address: name for name, info in self.meta.classes.items()}
        self.class_addresses = {name: addr for addr, name in self.classes.items()}
        self.selectors = {self.layout.string(addr): addr for ref in self.layout.pointers("__objc_selrefs")
                          if (addr := self.layout.read(ref))}
        self.frames = {}
        self.events = []
        self.executed = set()
        self.ivar_offsets = {}
        self.realize_request_subclass()
        for addr, symbol in self.meta.bindings.items():
            if symbol.startswith("_OBJC_CLASS_$_"):
                name = symbol.split("$_", 1)[1]
                if name not in self.class_addresses:
                    cls = self.allocate("Class")
                    self.classes[cls] = name
                    self.class_addresses[name] = cls
                self.cpu.mem_write(addr, word(self.class_addresses[name]))
            elif (symbol in {"_CGRectZero", "_CGSizeZero"} or
                  symbol.startswith("_UIApplication") and symbol.endswith("Notification")):
                self.cpu.mem_write(addr, word(self.allocate(symbol)))

        indirect = file_word(image.data, self.layout.commands[11] + 56)
        self.stubs = {}
        for section in self.layout.sections:
            if not section.stride or "stub" not in section.name:
                continue
            for i in range(section.size // section.stride):
                ordinal = file_word(image.data, indirect + 4 * (section.indirect + i))
                if ordinal < len(self.layout.names):
                    addr = section.addr + i * section.stride
                    self.stubs[addr] = self.layout.names[ordinal]
            self.cpu.hook_add(UC_HOOK_CODE, self.import_call, begin=section.addr,
                              end=section.addr + section.size - 1)

    def allocate(self, kind):
        addr = self.next_object
        self.next_object += 256
        if self.next_object > GAME + 0x10000:
            raise ValueError("emulated allocation area exhausted")
        self.objects[addr] = kind
        if kind in self.class_addresses:
            self.cpu.mem_write(addr, word(self.class_addresses[kind]))
        return addr

    def read_word(self, addr):
        return int.from_bytes(self.cpu.mem_read(addr, 4), "little")

    def realize_request_subclass(self):
        # The original SDK declared this subclass against a smaller version of
        # GADRequest. objc4 slides its four-byte pointer ivars at realization.
        name = "GADRequestPrivate"
        info = self.meta.classes[name]
        layout = self.layout
        ro = layout.read(info.address + 16) & ~3
        slide = (max(0, self.meta.classes["GADRequest"].instance_size - info.instance_start) + 3) & ~3
        table = layout.read(ro + 28)
        for i in range(layout.read(table + 4)):
            item = table + 8 + i * layout.read(table)
            field = layout.string(layout.read(item + 4))
            cell = layout.read(item)
            self.ivar_offsets[name, field] = layout.read(cell) + slide
            self.cpu.mem_write(cell, word(layout.read(cell) + slide))

    def field(self, receiver, owner, name, length=4):
        offset = self.ivar_offsets.get((owner, name), self.meta.classes[owner].ivars[name].offset)
        return int.from_bytes(self.cpu.mem_read(receiver + offset, length), "little")

    def lookup(self, owner, sign, selector):
        while owner in self.tested:
            info = self.meta.classes[owner]
            method = info.methods.get((sign, selector))
            if method:
                self.executed.add((owner, selector))
                return method.imp
            owner = info.superclass
        return None

    def dispatch(self, receiver, selector, args, *, superclass=None, stret=0):
        cls = self.classes.get(receiver)
        owner = superclass or cls or self.objects.get(receiver)
        if not receiver:
            return self.complete(0)
        imp = self.lookup(owner, "+" if cls else "-", selector)
        if imp:
            # objc_msgSendSuper2 receives an objc_super*, but its implementation
            # invokes the resolved IMP with the instance as its first argument.
            self.cpu.reg_write(ARG_REGS[int(bool(stret))], receiver)
            self.cpu.reg_write(arm.UC_ARM_REG_PC, imp)
            return
        if selector == "class":
            value = receiver if cls else self.class_addresses[owner]
        elif cls and selector in {"alloc", "allocWithZone:"}:
            value = self.allocate(cls)
        elif selector in {"retain", "autorelease", "copy", "init"}:
            value = receiver
        elif selector == "isKindOfClass:":
            value = int(self.class_addresses.get(owner) == args[0])
        elif selector == "respondsToSelector:":
            value = 0  # Exercise banner layout on pre-Auto-Layout UIKit.
        elif selector in {"initWithFrame:", "setFrame:"} and owner in {"UIView", "GADBannerView", "GADWebView"}:
            self.frames[receiver] = tuple(args[:4])
            value = receiver
        elif selector in {"frame", "bounds"} and stret:
            self.cpu.mem_write(stret, struct.pack("<4I", *self.frames[receiver]))
            value = stret
        elif cls == "UIColor" and selector == "clearColor":
            value = self.allocate("UIColor")
        elif cls == "NSNotificationCenter" and selector == "defaultCenter":
            value = self.allocate(cls)
        elif cls == "NSMutableDictionary" and selector == "dictionary":
            value = self.allocate(cls)
        elif cls == "NSNumber" and selector == "numberWithBool:":
            value = self.allocate(cls)
            self.events.append((selector, args[0], value))
        elif cls == "NSString" and selector == "stringWithFormat:":
            value = self.allocate(cls)
        elif cls == "GADDevice" and selector == "isOSAtLeastMajor:minor:bug:":
            value = 1
        elif owner in self.standins and selector in {"initWithSlot:", "initWithCategory:"}:
            value = receiver
        elif selector in {"setBackgroundColor:", "setClipsToBounds:", "addSubview:",
                          "addObserver:selector:name:object:", "setScalesPageToFit:", "setHidden:",
                          "setMediaPlaybackRequiresUserAction:", "setDelegate:", "setSlot:",
                          "setIdentifier:", "setViewController:", "release"}:
            self.events.append((selector, receiver, args[0]))
            value = 0
        else:
            raise ValueError(f"unhandled Objective-C message {owner} {selector}")
        self.complete(value)

    def complete(self, value):
        self.cpu.reg_write(ARG_REGS[0], value)
        self.cpu.reg_write(arm.UC_ARM_REG_PC, self.cpu.reg_read(arm.UC_ARM_REG_LR))

    def import_call(self, cpu, address, _size, _data):
        name = self.stubs[address]
        regs = [cpu.reg_read(r) for r in ARG_REGS]
        stack = cpu.reg_read(arm.UC_ARM_REG_SP)
        if name.startswith("_objc_msgSend"):
            stret = regs[0] if "stret" in name else 0
            i = int(bool(stret))
            receiver = regs[i]
            superclass = None
            if "Super" in name:
                start = self.classes[self.read_word(receiver + 4)]
                superclass = self.meta.classes[start].superclass
                receiver = self.read_word(receiver)
            args = regs[i+2:] + list(struct.unpack("<4I", cpu.mem_read(stack, 16)))
            self.dispatch(receiver, self.layout.string(regs[i+1]), args,
                          superclass=superclass, stret=stret)
        elif name == "_objc_setProperty":
            cpu.mem_write(regs[0] + regs[2], word(regs[3]))
            self.complete(0)
        elif name == "_objc_setProperty_nonatomic":
            cpu.mem_write(regs[0] + regs[3], word(regs[2]))
            self.complete(0)
        elif name == "_objc_getProperty":
            self.complete(self.read_word(regs[0] + regs[2]))
        elif name == "_NSAllocateObject":
            self.complete(self.allocate(self.classes[regs[0]]))
        elif name == "_NSStringFromClass":
            self.complete(self.allocate("NSString"))
        else:
            raise ValueError(f"unexpected imported call {name}")

    def call(self, owner, receiver, selector, *values):
        start = self.lookup(owner, "+" if receiver in self.classes else "-", selector)
        if start is None:
            raise ValueError(f"missing linked implementation {owner} {selector}")
        args = (receiver, self.selectors.get(selector, 0), *values)
        for reg, value in zip(ARG_REGS, args):
            self.cpu.reg_write(reg, value)
        self.cpu.mem_write(STACK, b"".join(word(v) for v in args[4:]) or bytes(4))
        self.cpu.reg_write(arm.UC_ARM_REG_SP, STACK)
        self.cpu.reg_write(arm.UC_ARM_REG_LR, RETURN)
        self.cpu.emu_start(start, RETURN, count=100000)
        if self.cpu.reg_read(arm.UC_ARM_REG_PC) != RETURN:
            raise ValueError(f"instruction budget exceeded in {owner} {selector}")
        return self.cpu.reg_read(ARG_REGS[0])


def require(actual, expected, operation):
    if actual != expected:
        raise ValueError(f"{operation} produced {actual!r}, expected {expected!r}")


def check(image):
    vm = AdMachine(image)
    banner = vm.allocate("GADBannerView")
    size = (float_bits(320), float_bits(50), 0)
    require(vm.call("GADBannerView", banner, "initWithAdSize:", *size), banner, "banner init")
    slot = vm.field(banner, "GADBannerView", "_slot")
    require(vm.objects.get(slot), "GADSlot", "banner slot")
    require(vm.field(slot, "GADSlot", "_adView"), banner, "slot view")
    require(vm.field(slot, "GADSlot", "_supportedOrientations"), 1, "initial slot orientations")
    web = vm.field(slot, "GADSlot", "_webView")
    require(vm.objects.get(web), "GADWebView", "slot web view")
    require(("addSubview:", banner, web) in vm.events, True, "installing banner web view")
    require(vm.frames[banner], (0, 0, *size[:2]), "banner frame")
    ad_type = vm.field(slot, "GADSlot", "_adType")
    require(vm.objects.get(ad_type), "GADAdType", "slot ad type")
    require(vm.field(ad_type, "GADAdType", "_adSize", 12),
            int.from_bytes(struct.pack("<3I", *size), "little"), "320 x 50 banner ad size")

    custom_size = (float_bits(311), float_bits(47), 1)
    vm.call("GADBannerView", banner, "setAdSize:", *custom_size)
    replacement = vm.field(slot, "GADSlot", "_adType")
    require(vm.objects.get(replacement), "GADAdType", "custom ad type")
    require(vm.field(replacement, "GADAdType", "_adSize", 12),
            int.from_bytes(struct.pack("<3I", *custom_size), "little"), "custom ad size")
    require(vm.frames[banner], (0, 0, *custom_size[:2]), "custom banner frame")
    vm.call("GADBannerView", banner, "setAdSize:", *custom_size)
    require(vm.field(slot, "GADSlot", "_adType"), replacement, "preserving unchanged ad size")

    unit_id = vm.allocate("NSString")
    controller = vm.allocate("UIViewController")
    vm.call("GADBannerView", banner, "setAdUnitID:", unit_id)
    vm.call("GADBannerView", banner, "setRootViewController:", controller)
    require(vm.call("GADBannerView", banner, "adUnitID"), unit_id, "public ad unit ID")
    require(vm.field(slot, "GADSlot", "_rootViewController"), controller, "slot root controller")
    stats = vm.field(slot, "GADSlot", "_slotStats")
    require(("setIdentifier:", stats, unit_id) in vm.events, True, "statistics unit ID")

    request = vm.call("GADRequest", vm.class_addresses["GADRequest"], "request")
    require(vm.objects.get(request), "GADRequestPrivate", "public request factory")
    extras = vm.field(request, "GADRequestPrivate", "_networkExtrasMap")
    require(vm.objects.get(extras), "NSMutableDictionary", "request extras map")
    vm.call("GADRequestPrivate", request, "setGender:", 2)
    vm.call("GADRequestPrivate", request, "setTesting:", 1)
    vm.call("GADRequestPrivate", request, "tagForChildDirectedTreatment:", 1)
    require(vm.call("GADRequestPrivate", request, "gender"), 2, "request gender")
    require(vm.call("GADRequestPrivate", request, "isTesting"), 1, "request testing flag")
    treatment = vm.field(request, "GADRequestPrivate", "_childDirectedTreatment")
    require(("numberWithBool:", 1, treatment) in vm.events, True, "child-directed treatment")
    require(vm.field(request, "GADRequestPrivate", "_networkExtrasMap"), extras, "preserving request extras")
    print(f"{image.arch}: banner creation and request configuration passed ({len(vm.executed)} linked methods)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-ipa", type=Path, default=ROOT / "build/Flappy Bird editable.ipa")
    args = parser.parse_args()
    for image in candidate_images(args.candidate_ipa).values():
        check(image)


if __name__ == "__main__":
    main()
