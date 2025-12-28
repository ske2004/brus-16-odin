package main

import "core:slice"
import "core:fmt"

ROM_Data :: struct {
  rom: [ROM_SIZE]u16,
  ram: [RAM_SIZE]u16,
}

rom_traverse :: proc(valid_addresses: ^map[uint]bool, code: []u16, ip: uint) {
  ip := ip

  if valid_addresses[ip] {
    return
  }

  for ip < len(code) {
    instr := isa_decode(code[ip])
    valid_addresses[ip] = true

    switch v in instr {
    case Fmt0:
      #partial switch v.op {
      case .RET: return
      }
    case Fmt1:
      #partial switch v.op {
      case .JMP: rom_traverse(valid_addresses, code, cast(uint)v.imm); return
      case .JZ, .CALL: rom_traverse(valid_addresses, code, cast(uint)v.imm)
      }
    }
    
    ip += 1
  }
}

rom_decomp :: proc(rom: ROM_Data, allocator := context.allocator) -> (result: [dynamic]Decomp_Instr) {
  rom := rom

  valid_addresses := make(map[uint]bool, allocator=allocator)
  defer delete(valid_addresses)

  rom_traverse(&valid_addresses, rom.rom[:], 0)
  
  result = make([dynamic]Decomp_Instr)

  for v, k in rom.rom {
    if valid_addresses[cast(uint)k] {
      append(&result, Decomp_Instr{cast(uint)k, isa_decode(v)})
    }
  }

  return
}

rom_init :: proc(data: []byte) -> (rom: ROM_Data, ok: bool) {
  if (len(data) & 1) == 1  {
    return
  }

  words := slice.reinterpret([]u16, data)

  code_size := words[0]
  data_size := words[1]

  i := 2
  for n in 0..<code_size {
    rom.rom[n] = words[i]
    i += 1 
  }
  for n in 0..<data_size {
    rom.ram[n] = words[i]
    i += 1 
  }
  
  ok = true
  return
}
