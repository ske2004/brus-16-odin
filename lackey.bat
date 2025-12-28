@echo off 

set Flags=-collection:brus=. -linker:radlink

odin run emu %Flags% -- %*