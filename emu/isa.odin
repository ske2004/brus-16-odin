package main

import "core:fmt"
import "brus:gui"

Op0 :: enum u8 {
  ADD,  SUB,  MUL,     AND,
  OR,   XOR,  SHL,     SHR,
  SHRA, EQ,   NEQ,     LT,
  LE,   GT,   GE,      LTU,
  LOAD, STORE,LOCALS,  SET_FP,
  RET,  PUSH, PUSH_MR, WAIT
}

Op1 :: enum u8 {
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

Instr :: union #no_nil {
  Fmt0,
  Fmt1
}

Decomp_Instr :: struct {
  addr: uint,
  instr: Instr,
}

isa_decode :: proc(op: u16) -> Instr {
  return (op&0x8000) > 0 ? Fmt1(op) : Fmt0(op)
}

instr_fmt :: proc(instr: Instr) -> string {
  switch v in instr {
  case Fmt0:
    name := fmt.aprintf("%v", v.op)
    if v.op == .LOAD && v.i do name = "GET_LOCAL"
    else if v.op == .STORE && v.i do name = "SET_LOCAL"

    has_simm := v.i || v.op == .LOAD || v.op == .STORE || v.op == .PUSH

    if has_simm {
      if v.simm < 0 {
        return fmt.aprintf("%-10v %v (%v)", name, v.simm, cast(uint)(v.simm&0x1FF))
      } else {
        return fmt.aprintf("%-10v %v", name, cast(uint)(v.simm&0x1FF))
      }
    } else {
      return fmt.aprintf("%-10v", name)
    }
  case Fmt1:
    return fmt.aprintf("%-10v $%04X", v.op, v.imm)
  }

  unreachable()
}