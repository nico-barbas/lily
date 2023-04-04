@echo off
odin build ./tools/lilyfmt -out:bin/lilyfmt.exe -vet -strict-style 
odin build ./tools/lily -out:bin/lily.exe -vet -strict-style -debug
@echo on