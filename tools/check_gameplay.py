#!/usr/bin/env python3
"""Differentially execute gameplay.c and the IPA in Unicorn on macOS with Xcode.

Install unicorn==2.1.4 into a Python 3 virtual environment, then run
python tools/check_gameplay.py. Both 32-bit slices run under emulation.
See --help for options. Engine callbacks are observations: the check compares
their arguments and order, game-object memory and the two pipe generator words.
"""
import argparse
import math
from pathlib import Path
import random
import struct
import subprocess
import tempfile
import zipfile

import verify

try:
    from unicorn import Uc, UC_ARCH_ARM, UC_MODE_ARM, UC_HOOK_CODE
    from unicorn import arm_const as arm
except ImportError:
    raise SystemExit("Install the emulator with python -m pip install unicorn==2.1.4")


# Function entries identified separately in the two original slices.
ENTRIES = {
    "bird_update": (0x1134c, 0x113d4), "bird_flap": (0x11194, 0x11220),
    "bird_reset": (0x108a8, 0x1092c), "bird_draw": (0x11434, 0x114c0),
    "game_frame": (0x10b18, 0x10ba0), "game_touch_begin": (0x11104, 0x11190),
    "game_touch_end": (0x11204, 0x1128c), "game_reset": (0x10918, 0x109a0),
    "game_handle_event": (0x10a18, 0x10aa0), "rand": (0xdff18, 0xdff24),
    "sprite_place": (0xf608, 0xf6a8), "sprite_select_animation": (0xf684, 0xf724),
    "sprite_update_animation": (0xf6b8, 0xf758), "engine_schedule": (0xe754, 0xe804),
    "engine_output": (0xe874, 0xe924), "screen_flash": (0xe7e0, 0xe890),
    "screen_shake": (0xe838, 0xe8e8), "start_transition": (0xd938, 0xdadc),
    "tween_start": (0xe790, 0xe840), "button_place": (0xf748, 0xf7e4),
    "draw_region": (0xceec, 0xd094), "draw_rotated": (0xe5a0, 0xe658),
    "font_place": (0xcda4, 0xcf4c), "draw_text": (0xcdc0, 0xcf68),
    "show_game_over": (0x10430, 0x104bc),
}

# Argument count in four-byte ARM procedure-call slots. font_place's double
# occupies two stack slots. All arguments to draw_text, including score, fit
# in the four argument registers.
CALL_SLOTS = {
    "rand": 0, "sprite_place": 3, "sprite_select_animation": 3,
    "sprite_update_animation": 2, "engine_schedule": 4, "engine_output": 3,
    "screen_flash": 2, "screen_shake": 3, "start_transition": 4,
    "tween_start": 5, "button_place": 3, "draw_region": 5, "draw_rotated": 6,
    "font_place": 6, "draw_text": 4, "show_game_over": 1,
    "virtual_update": 2, "virtual_draw": 2,
}
GLOBALS = {"flap_game": 0xfd614, "flap_random_z": 0xfd620,
           "flap_random_w": 0xfd61c, "flap_sine_table": 0xfd624}
ARG_REGS = [arm.UC_ARM_REG_R0, arm.UC_ARM_REG_R1, arm.UC_ARM_REG_R2, arm.UC_ARM_REG_R3]
GAME = 0x220000
BIRD = GAME + 0x1000
METHOD_TABLE = GAME + 0xf000
RETURN = 0x240000
STACK = 0x231000
SINE = GAME + 0xd000
VIRTUAL_UPDATE = RETURN + 4
VIRTUAL_DRAW = RETURN + 8


def word(value):
    return struct.pack("<I", value & 0xffffffff)


def float_bits(value):
    return struct.unpack("<I", struct.pack("<f", value))[0]


def build(arch, temp):
    hooks = temp / "hooks.c"
    # The code hooks intercept these symbols before the CPU runs a stub.
    hooks.write_text("".join(f"unsigned {name};\n" for name in GLOBALS) +
                     "".join(f"void {name}(void) {{}}\n" for name in CALL_SLOTS))
    outputs = []
    for source in [verify.ROOT / "src/gameplay.c", hooks]:
        obj = temp / (source.stem + ".o")
        subprocess.run(["xcrun", "clang", "-target", f"{arch}-apple-ios7.0", "-isysroot", "/",
                        "-mthumb", "-Os", "-fno-stack-protector", "-ffreestanding",
                        "-c", source, "-o", obj], check=True)
        outputs.append(obj)
    image = temp / "game"
    subprocess.run(["xcrun", "ld", "-arch", arch, "-static", "-segalign", "0x1000",
                    "-segaddr", "__TEXT", "0x180000", "-e", "_bird_update", "-platform_version",
                    "ios", "7.0", "7.0", *outputs, "-o", image], check=True)
    return verify.Image(image.read_bytes())


class Machine:
    def __init__(self, data, symbols):
        self.symbols = symbols
        cpu = self.cpu = Uc(UC_ARCH_ARM, UC_MODE_ARM)
        command = 28
        for _ in range(struct.unpack_from("<I", data, 16)[0]):
            kind, size = struct.unpack_from("<II", data, command)
            if kind == 1:  # LC_SEGMENT
                address, vm_size, offset, file_size = struct.unpack_from("<4I", data, command + 24)
                if address and vm_size:
                    cpu.mem_map(address, (vm_size + 4095) & ~4095)
                    if file_size:
                        cpu.mem_write(address, data[offset:offset + file_size])
            command += size
        cpu.mem_map(GAME, 0x10000)
        cpu.mem_map(STACK - 0x1000, 0x2000)
        cpu.mem_map(RETURN, 0x1000)
        cpu.reg_write(arm.UC_ARM_REG_C1_C0_2, 0x00f00000)
        cpu.reg_write(arm.UC_ARM_REG_FPEXC, 0x40000000)
        self.hooks = {symbols[n]: n for n in CALL_SLOTS if n in symbols}
        self.hooks.update({VIRTUAL_UPDATE: "virtual_update", VIRTUAL_DRAW: "virtual_draw"})
        for address in self.hooks:
            cpu.hook_add(UC_HOOK_CODE, self.observe_call, begin=address, end=address)

    def observe_call(self, cpu, address, _size, _user):
        name = self.hooks[address]
        count = CALL_SLOTS[name]
        args = [cpu.reg_read(r) for r in ARG_REGS[:count]]
        for i in range(4, count):
            addr = cpu.reg_read(arm.UC_ARM_REG_SP) + 4 * (i - 4)
            args.append(struct.unpack("<I", cpu.mem_read(addr, 4))[0])
        if name == "draw_text":
            args[2] = bytes(cpu.mem_read(args[2], 3))  # "%u", located at a different VA
        self.calls.append((name, args))
        if name == "rand":
            cpu.reg_write(ARG_REGS[0], self.random_value)
        cpu.reg_write(arm.UC_ARM_REG_PC, cpu.reg_read(arm.UC_ARM_REG_LR))

    def run(self, name, state, args, random_value):
        self.random_value = random_value
        self.calls = []
        cpu = self.cpu
        cpu.mem_write(GAME, bytes(state))
        cpu.mem_write(STACK - 0x1000, bytes(0x2000))
        for symbol, value in zip(GLOBALS, [GAME, 0xc67fe32a, 0x873456ab, SINE]):
            cpu.mem_write(self.symbols[symbol], word(value))
        for i, arg in enumerate(args):
            if i < 4:
                cpu.reg_write(ARG_REGS[i], arg)
            else:
                cpu.mem_write(STACK + (i - 4) * 4, word(arg))
        cpu.reg_write(arm.UC_ARM_REG_SP, STACK)
        cpu.reg_write(arm.UC_ARM_REG_LR, RETURN | 1)
        cpu.emu_start(self.symbols[name] | 1, RETURN, count=5000)
        if cpu.reg_read(arm.UC_ARM_REG_PC) != RETURN:
            raise ValueError(f"{name} exceeded its instruction budget")
        rng = [bytes(cpu.mem_read(self.symbols[n], 4)) for n in ("flap_random_z", "flap_random_w")]
        return bytes(cpu.mem_read(GAME, len(state))), self.calls, rng


def initial_state(rng):
    state = bytearray(0x10000)

    def put(offset, value):
        state[offset:offset + 4] = word(value)

    def put_float(offset, value):
        put(offset, float_bits(value))

    put(0x554, BIRD)
    put(0x3ac, GAME + 0x3000)
    put(0x300c, 1)
    put(0x3008, GAME + 0x3100)
    put(0x3100, GAME + 0x3200)

    # Overlay, button and image pointers, in Game's original field order.
    fields = (0x548, 0x558, 0x55c, 0x560, 0x564, 0x568, 0x56c, 0x570, 0x574,
              0x57c, 0x580, 0x584, 0x588, 0x58c, 0x590, 0x594, 0x598,
              0x59c, 0x5c4, 0x5c8, 0x5cc)
    for i, field in enumerate(fields):
        obj = 0x3400 + 0x100 * i
        put(field, GAME + obj)
        put(obj, METHOD_TABLE)
        if 0x57c <= field <= 0x59c:
            put(obj + 8, 52)
            put(obj + 12, 320)
        else:
            for flag in (4, 5, 0x1e):
                state[obj + flag] = rng.randrange(2)
            put(obj + 0x30, rng.randrange(3))
            put(obj + 0x14, rng.randrange(3))
    put(METHOD_TABLE - GAME, VIRTUAL_UPDATE | 1)
    put(METHOD_TABLE - GAME + 4, VIRTUAL_DRAW | 1)
    put(0x1000, METHOD_TABLE)
    put(0x1030, 80)
    put(0x1034, rng.choice([-10, 0, 80, 150, 243, 320, 378, 380, 381, 390]))
    put(0x103c, 20)
    put(0x1040, 20)
    put(0x1050, rng.choice([0, GAME + 0x2000]))
    state[0x1057] = rng.randrange(2)
    put(0x105c, GAME + 0x2100)
    put(0x2018, rng.randrange(3))
    state[0x201c] = rng.randrange(2)
    for frame in range(9):
        put(0x2100 + 4 * frame, GAME + 0x5000 + 32 * frame)
    put(0x1084, rng.randrange(3))
    put_float(0x1060, rng.choice([-20, 0, 5, 50, 90]))
    put_float(0x1064, rng.choice([-10, -1, 0, 10]))
    put_float(0x1068, 0.4)
    put_float(0x1070, rng.choice([-6, -4, 0, 4, 7.5, 8]))
    put_float(0x1074, 0.3)
    state[0x1078] = rng.randrange(2)
    state[0x1079] = rng.randrange(2)
    put(0x107c, rng.randrange(45) * 8)
    for degree in range(360):
        put_float(0xd000 + degree * 4, math.sin(math.radians(degree)))
    state[0x550] = rng.randrange(2)
    put(0x5d0, rng.choice([0, 2]))
    put(0x5c0, rng.randrange(2))
    put(0x5a0, rng.choice([-22, -24, 0]))
    for i, xs in enumerate([[-55, 39, 80, 81, 82, 99, 105], [25, 210, 330], [25, 210, 330]]):
        put(0x5b0 + 4 * i, rng.choice(xs))
        put(0x5a4 + 4 * i, rng.choice([100, 180, 250, 280]))
    put(0x5bc, 105)
    put(0x538, rng.randrange(100))
    return state


def linked_symbols(rebuilt):
    symbols = {name[1:]: entry.addr for name, entry in rebuilt.symbols.items()
               if name.startswith("_")}
    if "rand" not in symbols:
        # In the full app, libc's rand is an import. Intercept the call at
        # the linked ARM stub, before dyld would resolve it on a device.
        from linkmatch import Layout, word as read_word
        layout = Layout(rebuilt.data)
        table = read_word(rebuilt.data, layout.commands[11] + 56)
        for section in layout.sections:
            if not section.stride or "stub" not in section.name:
                continue
            for index in range(section.size // section.stride):
                ordinal = read_word(rebuilt.data, table + 4 * (section.indirect + index))
                if ordinal < len(layout.names) and layout.names[ordinal] == "_rand":
                    symbols["rand"] = section.addr + index * section.stride
    needed = (ENTRIES.keys() | GLOBALS.keys()) - symbols.keys()
    if needed:
        raise ValueError(f"{rebuilt.arch} missing linked game symbols: {sorted(needed)}")
    return symbols


def check_pipe_edges(reference, candidate, rng):
    """Exercise both collision rectangles, including their independent widths."""
    state = initial_state(rng)
    bird = BIRD - GAME
    state[0x550] = state[bird + 0x78] = state[bird + 0x79] = 0
    upper = struct.unpack_from("<I", state, 0x594)[0] - GAME
    lower = struct.unpack_from("<I", state, 0x590)[0] - GAME
    bird_x, bird_width, bird_height = 80, 20, 20
    lower_y, upper_height, lower_height = 250, 100, 70
    upper_bottom = lower_y - 96
    struct.pack_into("<i", state, 0x5d0, 2)
    struct.pack_into("<i", state, bird + 0x30, bird_x)
    struct.pack_into("<ii", state, bird + 0x3c, bird_width, bird_height)
    struct.pack_into("<iii", state, 0x5a4, lower_y, lower_y, lower_y)
    y_edges = (upper_bottom - upper_height - bird_height, upper_bottom,
               lower_y - bird_height, lower_y + lower_height)
    args = [GAME, float_bits(1 / 60)]
    count = 0
    for upper_width, lower_width in ((24, 52), (52, 24)):
        struct.pack_into("<ii", state, upper + 8, upper_width, upper_height)
        struct.pack_into("<ii", state, lower + 8, lower_width, lower_height)
        x_edges = (bird_x - upper_width, bird_x - lower_width, bird_x + bird_width)
        for pair in (0, 1):
            for warmup in (-1, 0, 1):
                struct.pack_into("<i", state, 0x5c0, warmup)
                for x in (edge + dx for edge in x_edges for dx in (-1, 0, 1)):
                    struct.pack_into("<iii", state, 0x5b0, 500, 500, 500)
                    # The pipe moves two pixels immediately before the test.
                    struct.pack_into("<i", state, 0x5b0 + 4 * pair, x + 2)
                    for y in (edge + dy for edge in y_edges for dy in (-1, 0, 1)):
                        struct.pack_into("<i", state, bird + 0x34, y)
                        original = reference.run("game_frame", state, args, 123)
                        if candidate.run("game_frame", state, args, 123) != original:
                            raise ValueError(f"pipe pair {pair} at x={x}, bird y={y}, "
                                             f"widths={upper_width}/{lower_width}, warmup={warmup}")
                        count += 1
    return count


def check(arch, original, rebuilt):
    rng = random.Random(354)
    ref_symbols = dict(GLOBALS)
    ref_symbols.update({n: pair[arch == "armv7s"] for n, pair in ENTRIES.items()})
    reference = Machine(original.data, ref_symbols)
    candidate = Machine(rebuilt.data, linked_symbols(rebuilt))
    elapsed = float_bits(1 / 60)
    cases = [("bird_update", [BIRD, elapsed], 200), ("bird_reset", [BIRD], 40),
             ("bird_flap", [BIRD], 80), ("bird_draw", [BIRD, GAME], 40),
             ("game_reset", [GAME], 20), ("game_frame", [GAME, elapsed], 200),
             ("game_touch_begin", [GAME, 72, 300], 40), ("game_touch_end", [GAME, 0, 0, 0, 465], 20)]
    cases += [("game_handle_event", [GAME, event], 10) for event in range(2, 9)]
    total = 0
    for name, args, count in cases:
        for i in range(count):
            memory = initial_state(rng)
            random_value = rng.randrange(2**31)
            expect = reference.run(name, memory, args, random_value)
            actual = candidate.run(name, memory, args, random_value)
            if expect != actual:
                differences = [hex(i) for i, (a, b) in enumerate(zip(expect[0], actual[0])) if a != b]
                raise ValueError(f"{arch} {name} {args} case {i}: differing heap offsets {differences[:8]}, "
                                 f"reference calls {expect[1]}, rebuilt calls {actual[1]}, "
                                 f"reference RNG {expect[2]}, rebuilt RNG {actual[2]}")
            total += 1
    # Exercise contact on the inclusive edges and every scoring x coordinate
    # with the other pipe safely out of reach. The first upper pipe is special.
    def check_frame(first_x, second_x, bird_y, warmup, score_delta, stopped, hit):
        state = initial_state(rng)
        state[0x550] = state[0x1078] = state[0x1079] = 0
        for offset, value in [(0x538, 7), (0x5c0, warmup), (0x5d0, 2), (0x1034, bird_y),
                              (0x5b0, first_x), (0x5b4, second_x), (0x5b8, 400),
                              (0x5a4, 250), (0x5a8, 250), (0x5ac, 250)]:
            state[offset:offset + 4] = word(value)
        args = [GAME, elapsed]
        expect = reference.run("game_frame", state, args, 123)
        actual = candidate.run("game_frame", state, args, 123)
        if expect != actual:
            raise ValueError(f"{arch}: frame differs at x={first_x}, y={bird_y}")
        memory = actual[0]
        if (memory[0x538:0x53c] != word(7 + score_delta) or
                memory[0x5d0:0x5d4] != word(0 if stopped else 2) or memory[0x1078] != hit):
            raise ValueError(f"{arch}: unexpected score or hit at x={first_x}, y={bird_y}")

    for case in [(82, 230, 200, 0, 1, False, 0), (81, 230, 200, 0, 1, False, 0),
                 (80, 230, 200, 0, 0, False, 0), (82, 230, 200, 1, 0, False, 0),
                 (102, 230, 154, 0, 0, True, 0), (230, 102, 154, 0, 0, True, 1),
                 (102, 230, 230, 0, 0, True, 1), (230, 102, 230, 0, 0, True, 1),
                 (103, 230, 154, 0, 0, False, 0), (82, 230, 380, 0, 1, True, 0),
                 (-53, 230, 200, 1, 0, False, 0)]:
        check_frame(*case)
        total += 1
    edge_cases = check_pipe_edges(reference, candidate, rng)
    print(f"{arch}: {total + edge_cases} gameplay cases passed "
          f"(including {edge_cases} pipe-edge comparisons)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, default=verify.ROOT / "Flappy Bird v1.2.ipa")
    parser.add_argument("--candidate-ipa", type=Path, help="execute the linked game in an editable build")
    parser.add_argument("--arch", choices=("armv7", "armv7s"))
    args = parser.parse_args()
    originals = verify.original_images(args.ipa)
    with tempfile.TemporaryDirectory() as temp:
        temp = Path(temp)
        if args.candidate_ipa:
            with zipfile.ZipFile(args.candidate_ipa) as ipa:
                (temp / "universal").write_bytes(ipa.read(verify.EXECUTABLE))
        for arch in [args.arch] if args.arch else originals:
            if args.candidate_ipa:
                thin = temp / arch
                subprocess.run(["xcrun", "lipo", temp / "universal", "-thin", arch, "-output", thin],
                               check=True)
                candidate = verify.Image(thin.read_bytes())
            else:
                candidate = build(arch, temp)
            check(arch, originals[arch], candidate)


if __name__ == "__main__":
    main()
