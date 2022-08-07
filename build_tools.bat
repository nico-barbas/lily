@echo off
odin build ./tools/lilyfmt -out:bin/lilyfmt.exe -vet -strict-style -collection:lily=./
odin build ./tools/lily -out:bin/lily.exe -vet -strict-style -collection:lily=./
@echo on