package main

import "core:fmt"
import "core:slice"

CPU :: struct {
  rom:  [ROM_SIZE]u16,
  ram:  [RAM_SIZE]u16,
  rstk: [RSTK_SIZE]u16,
  stk:  [STK_SIZE]u16,
  addr: u16,
  sp:   u16,
  rp:   u16,
  fp:   u16,
  pc:   u16,
  wait: bool
}

Op0 :: enum (u8) {
  ADD,  SUB,  MUL,     AND,
  OR,   XOR,  SHL,     SHR,
  SHRA, EQ,   NEQ,     LT,
  LE,   GT,   GE,      LTU,
  LOAD, STORE,LOCALS,  SET_FP,
  RET,  PUSH, PUSH_MR, WAIT
}

Op1 :: enum (u8) {
  JMP, JZ, CALL, PUSHU
}

Fmt0 :: bit_field u16 {
  simm: i16 | 9,
  i: bool   | 1,
  op: Op0   | 5,
  f: bool   | 1,
}

Fmt1 :: bit_field u16 {
  imm: u16 | 13 `fmt:"X"`,
  op: Op1  | 2,
  f: bool  | 1,
}

Instr :: union {
  Fmt0,
  Fmt1
}

stk_pop :: proc(cpu: ^CPU) -> u16 {
  cpu.sp = (cpu.sp-1)&(STK_SIZE-1)
  return cpu.stk[cpu.sp]
}

stk_push :: proc(cpu: ^CPU, v: u16) {
  cpu.stk[cpu.sp] = v
  cpu.sp = (cpu.sp+1)&(STK_SIZE-1)
}

rstk_pop :: proc(cpu: ^CPU) -> u16 {
  cpu.rp = (cpu.rp-1)&(RSTK_SIZE-1)
  return cpu.rstk[cpu.rp]
}

rstk_push :: proc(cpu: ^CPU, v: u16) {
  cpu.rstk[cpu.rp] = v
  cpu.rp = (cpu.rp+1)&(RSTK_SIZE-1)
}

exec0 :: proc(cpu: ^CPU, i: Fmt0) {
  a, b, simm : u16 = 0, 0, transmute(u16)i.simm

  if i.op < .LOAD {
    b = i.i ? simm : stk_pop(cpu)
    a = stk_pop(cpu)
  }

  switch i.op {
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
    case .LOAD:    cpu.addr = (i.i ? cpu.fp : stk_pop(cpu)) + simm
    case .STORE:   cpu.addr = (i.i ? cpu.fp : stk_pop(cpu)) + simm
                   cpu.ram[cpu.addr&(RAM_SIZE-1)] = stk_pop(cpu)
    case .LOCALS:  cpu.fp = cpu.fp - simm
    case .SET_FP:  cpu.fp = stk_pop(cpu)
    case .RET:     cpu.fp = cpu.fp + simm; cpu.pc = rstk_pop(cpu)
    case .PUSH:    stk_push(cpu, simm)
    case .PUSH_MR: cpu.addr = cpu.ram[cpu.addr&(RAM_SIZE-1)]
                   stk_push(cpu, cpu.addr)
    case .WAIT:    cpu.wait = true
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

decode :: proc(op: u16) -> Instr {
  return (op&0x8000) > 0 ? Fmt1(op) : Fmt0(op)
}

run_instr :: proc (cpu: ^CPU) {
  decoded := decode(cpu.rom[cpu.pc])
  // fmt.printf("%04X %04X %v\n", cpu.pc, cpu.rom[cpu.pc], decoded)
  cpu.pc += 1
  cpu.pc = cpu.pc & (ROM_SIZE-1)

  switch op in decoded {
    case Fmt0: exec0(cpu, op)
    case Fmt1: exec1(cpu, op)
  }
}

rom_init :: proc(bytes: []byte) -> (cpu: CPU) {
  rom := slice.reinterpret([]u16, bytes)

  cpu.fp = MEM_INPUT

  code_size := rom[0]
  data_size := rom[1]

  i := 2
  for n in 0..<code_size {
    cpu.rom[n] = rom[i]
    i += 1 
  }
  for n in 0..<data_size {
    cpu.ram[n] = rom[i]
    i += 1 
  }

  return
}