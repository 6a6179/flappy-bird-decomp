PYTHON ?= python3
IPA ?= Flappy Bird v1.2.ipa
OUTPUT ?= build/Flappy Bird.ipa
EDITABLE ?= build/Flappy Bird editable.ipa
ASSETS ?= assets
EMULATOR := .toolchains/emulator/bin/python

.PHONY: all editable verify test test-editable setup setup-editable source-zip

all:
	$(PYTHON) tools/verify.py --ipa "$(IPA)" --rebuild "$(OUTPUT)"

editable:
	$(PYTHON) tools/build_game.py --assets "$(ASSETS)" --output "$(EDITABLE)"

verify:
	$(PYTHON) tools/verify.py --ipa "$(IPA)"

test: .toolchains/emulator/.unicorn-2.1.4
	$(EMULATOR) tools/check_gameplay.py --ipa "$(IPA)"

test-editable: editable .toolchains/emulator/.unicorn-2.1.4
	$(EMULATOR) tools/check_gameplay.py --ipa "$(IPA)" --candidate-ipa "$(EDITABLE)"

.toolchains/emulator/.unicorn-2.1.4:
	$(PYTHON) -m venv .toolchains/emulator
	$(EMULATOR) -m pip install unicorn==2.1.4
	@touch $@

setup-editable:
	$(PYTHON) tools/get_apple502.py
	$(PYTHON) tools/get_ios7_headers.py --full
	$(PYTHON) tools/get_admob680.py

setup: setup-editable
	$(PYTHON) tools/get_llvm33.py
	$(PYTHON) tools/get_apple_clang.py
	$(PYTHON) tools/get_ios7_headers.py --sdk .toolchains/iPhoneOS7.0.sdk

source-zip:
	$(PYTHON) tools/package_source.py
