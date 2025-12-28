package main

// poorly copied from original impl

import "core:math"

OSC_COUNT :: 16

OscMem :: struct #packed {
  abs:   u16,
  step:  u16,
  amp:   u16,
  decay: u16,
}

Osc :: struct {
  tgt_amp: u16,
  amp:     u16,
  phase:   u16,
  step:    u16,
  decay:   u16,
}

APU :: struct {
  oscs: [OSC_COUNT]Osc,
  decay_counter: uint,
}

sin_int :: proc(t: int) -> int {
  return cast(int)(math.sin_f32(cast(f32)t/1024*math.PI*2)*32767)
}

apu_update :: proc(apu: ^APU, osc_mem: ^[OSC_COUNT]OscMem) {
  abs_step: u16 = 0
  abs_amp: u16 = 0

  for osc, i in osc_mem {
    amp, step := osc.amp, osc.step

    if osc.abs > 0 {
      abs_step, abs_amp = step, amp
    } else {
      amp = cast(u16)((cast(int)amp * cast(int)abs_amp) >> 10)
      step = cast(u16)((cast(int)step * cast(int)abs_step) >> 10)
    }

    if amp > 0 {
      apu.oscs[i].tgt_amp = amp
    }

    apu.oscs[i].step = step
    apu.oscs[i].decay = osc.decay
  }
}

apu_sample :: proc(apu: ^APU) -> i16 {
  volume: int = 0
  decaying := (apu.decay_counter&63) == 0

  for &osc, i in apu.oscs {
    osc.amp += cast(u16)((cast(int)osc.tgt_amp - cast(int)osc.amp) >> 6)
    pos := cast(int)(osc.phase >> 6) & 1023
    volume += (sin_int(pos) * cast(int)osc.amp) >> 15
    osc.phase += osc.step
    if decaying {
      osc.tgt_amp = cast(u16)((int(osc.tgt_amp) * int(osc.decay)) >> 15)
    }
  }

  apu.decay_counter += 1
  return cast(i16)clamp(volume, -32768, 32767);
}