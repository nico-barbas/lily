@echo off
odin run tests/playground.odin -file -out:tests/playground.exe -strict-style -debug -vet -show-debug-messages
@echo on