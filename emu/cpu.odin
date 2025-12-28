package main

import "core:fmt"
import "core:slice"

CPU :: struct {
  using rom_data: ROM_Data,
  rstk: [RSTK_SIZE]u16,
  stk:  [STK_SIZE]u16,
  addr: u16,
  sp:   u16,
  rp:   u16,
  fp:   u16,
  pc:   u16,
  wait: bool,
}

stk_pop :: proc(using cpu: ^CPU) -> u16 {
  sp = (sp-1)&(STK_SIZE-1)
  #no_bounds_check return stk[sp]
}

stk_push :: proc(using cpu: ^CPU, v: u16) {
  #no_bounds_check stk[sp] = v
  sp = (sp+1)&(STK_SIZE-1)
}

rstk_pop :: proc(using cpu: ^CPU) -> u16 {
  rp = (rp-1)&(RSTK_SIZE-1)
  #no_bounds_check return rstk[rp]
}

rstk_push :: proc(using cpu: ^CPU, v: u16) {
  #no_bounds_check rstk[rp] = v
  rp = (rp+1)&(RSTK_SIZE-1)
}

exec0 :: proc(using cpu: ^CPU, i: Fmt0) {
  a, b, simm : u16 = 0, 0, transmute(u16)i.simm

  op := i.op

  if op < .LOAD {
    b = i.i ? simm : stk_pop(cpu)
    a = stk_pop(cpu)
  }

  switch op {
    // math instructions
    case .ADD:  stk_push(cpu, a + b)
    case .SUB:  stk_push(cpu, a - b)
    case .MUL:  stk_push(cpu, transmute(u16)((transmute(i16)a) * (transmute(i16)b)))
    case .AND:  stk_push(cpu, a & b)
    case .OR:   stk_push(cpu, a | b)
    case .XOR:  stk_push(cpu, a ~ b)
    case .SHL:  stk_push(cpu, a << b)
    case .SHR:  stk_push(cpu, a >> b)
    case .SHRA: stk_push(cpu, transmute(u16)(transmute(i16)a >> b))
    case .EQ:   stk_push(cpu, u16(a == b))
    case .NEQ:  stk_push(cpu, u16(a != b))
    case .LT:   stk_push(cpu, u16((transmute(i16)a) < (transmute(i16)b)))
    case .LE:   stk_push(cpu, u16((transmute(i16)a) <= (transmute(i16)b)))
    case .GT:   stk_push(cpu, u16((transmute(i16)a) > (transmute(i16)b)))
    case .GE:   stk_push(cpu, u16((transmute(i16)a) >= (transmute(i16)b)))
    case .LTU:  stk_push(cpu, u16(a < b))

    // control instructions
    case .LOAD:    addr = (i.i ? fp : stk_pop(cpu)) + simm
    case .STORE:   addr = (i.i ? fp : stk_pop(cpu)) + simm
                   #no_bounds_check ram[addr&(RAM_SIZE-1)] = stk_pop(cpu)
    case .LOCALS:  fp = fp - simm
    case .SET_FP:  fp = stk_pop(cpu)
    case .RET:     fp = fp + simm; cpu.pc = rstk_pop(cpu)
    case .PUSH:    stk_push(cpu, simm)
    case .PUSH_MR: #no_bounds_check addr = ram[addr&(RAM_SIZE-1)]
                   stk_push(cpu, addr)
    case .WAIT:    wait = true
  }
}

exec1 :: proc(cpu: ^CPU, i: Fmt1) {
  switch i.op {
    case .JMP:   cpu.pc = i.imm
    case .JZ:    cpu.pc = stk_pop(cpu) > 0 ? cpu.pc : i.imm
    case .CALL:  rstk_push(cpu, cpu.pc); cpu.pc = i.imm
    case .PUSHU: stk_push(cpu, i.imm)
  }
}

run_instr :: proc (cpu: ^CPU) {
  #no_bounds_check decoded := isa_decode(cpu.rom[cpu.pc])
  // fmt.printf("%04X %04X %v\n", cpu.pc, cpu.rom[cpu.pc], decoded)
  cpu.pc += 1
  cpu.pc = cpu.pc & (ROM_SIZE-1)

  switch op in decoded {
    case Fmt0: exec0(cpu, op)
    case Fmt1: exec1(cpu, op)
  }
}

cpu_init :: proc(rom: ROM_Data) -> (cpu: CPU) {
  cpu.rom_data = rom
  cpu.fp = MEM_OSC
  return
}