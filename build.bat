@echo off
rem Build script for FX Hammer disassembly
rgbasm -o fxhammer.obj main.asm
rgblink -p 255 -o fxhammer.gb -n fxhammer.sym fxhammer.obj
rgbfix -v FXHammer.gb