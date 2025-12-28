package main

import "core:fmt"
import "core:os"
import "vendor:raylib"
import "core:reflect"
import "core:time"
import "core:mem"
import "core:log"
import "base:runtime"
import "core:prof/spall"
import "core:sync"
import "core:slice"
import "core:c"

SAMPLES_PER_FRAME :: 44100/60

Rect :: struct #packed {
  is_abs: u16,
  x: i16,
  y: i16,
  w: u16,
  h: u16,
  color: Rgb565,
}

Rgb565 :: bit_field u16 {
  b: u8 | 5,
  g: u8 | 6,
  r: u8 | 5
}

rgb565_to_rgba :: proc(v: Rgb565) -> raylib.Color {
  return {v.r*8, v.g*4, v.b*8, 0xFF}
}

INPUT_MAP :: [?]raylib.KeyboardKey{
  .UP, .DOWN, .LEFT, .RIGHT,
  .Z, .X, .C, .V,
  .W, .S, .A, .D,
  .H, .J, .K, .L,
}

error :: proc(f: string, args: ..any) -> ! {
  fmt.eprintf(f, ..args)
  os.exit(1)
}

CONST :: 32

// spall_ctx: spall.Context
// @(thread_local) spall_buffer: spall.Buffer

// @(instrumentation_enter)
// spall_enter :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
//   spall._buffer_begin(&spall_ctx, &spall_buffer, "", "", loc)
// }

// @(instrumentation_exit)
// spall_exit :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
//   spall._buffer_end(&spall_ctx, &spall_buffer)
// }

main :: proc() {
  /*
  spall_ctx = spall.context_create("trace_test.spall")
  defer spall.context_destroy(&spall_ctx)

  buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
  defer delete(buffer_backing)

  spall_buffer = spall.buffer_create(buffer_backing, u32(sync.current_thread_id()))
  defer spall.buffer_destroy(&spall_ctx, &spall_buffer)
  */
  when ODIN_DEBUG {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
      if len(track.allocation_map) > 0 {
        fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
        for _, entry in track.allocation_map {
          fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
      }
      mem.tracking_allocator_destroy(&track)
    }
  }
  
  // context.logger = log.create_console_logger()
  // defer log.destroy_console_logger(context.logger)

  if len(os.args) != 2 {
    error("usage: %s <rom.bin>\n", os.args[0])
  }

  file := os.read_entire_file(os.args[1]) or_else error("noooo file dummy\n")

  title := fmt.caprint("odin-brus-16:", os.args[1])
  defer delete(title, context.allocator)

  defer delete(file, context.allocator)

  rom := rom_init(file) or_else error("bad rom file") 

  decompiled_rom := rom_decomp(rom, context.allocator)
  defer delete(decompiled_rom)
  when false {
    context.allocator = context.temp_allocator
    for instr in decompiled_rom {
      fmt.printf("%04X %s\n", instr.addr, instr_fmt(instr.instr))
    }
    free_all(context.allocator)
  }
  
  cpu := cpu_init(rom) 
  apu := APU{}

  raylib.InitWindow(width = 640, height = 480, title = title)
  defer raylib.CloseWindow()

  raylib.InitAudioDevice()
  defer raylib.CloseAudioDevice()

  raylib.SetAudioStreamBufferSizeDefault(SAMPLES_PER_FRAME); 
  raylib.SetTargetFPS(60)

  stream := raylib.LoadAudioStream(44100, 16, 1)
  defer raylib.UnloadAudioStream(stream)

  audio_buf := [SAMPLES_PER_FRAME]i16{}

  raylib.PlayAudioStream(stream)

  for !raylib.WindowShouldClose() {
    raylib.BeginDrawing()

    raylib.ClearBackground(raylib.BLACK)

    for k, i in INPUT_MAP {
      cpu.ram[MEM_INPUT + i] = cast(u16)raylib.IsKeyDown(k)
    }

    start_time := time.now()
    
    for !cpu.wait {
      run_instr(&cpu)
    }
    cpu.wait = false

    apu_update(&apu, transmute(^[16]OscMem)&cpu.ram[MEM_OSC])

    if raylib.IsAudioStreamProcessed(stream) {
      for _, i in audio_buf {
        audio_buf[i] = apu_sample(&apu)
      }
      raylib.UpdateAudioStream(stream, &audio_buf, SAMPLES_PER_FRAME);
    }

    x, y : i16 = 0, 0

    for i in 0..<CNT_RECT {
      rect := (transmute(^Rect)&cpu.ram[MEM_RECT + i * reflect.struct_field_count(Rect)])^

      if rect.is_abs > 0 {
        x, y = rect.x, rect.y
      } else {
        rect.x += x; rect.y += y
      }

      raylib.DrawRectangle(
        posX = cast(i32)rect.x,
        posY = cast(i32)rect.y,
        width = cast(i32)rect.w,
        height = cast(i32)rect.h,
        color = rgb565_to_rgba(rect.color)
      )
    }

    raylib.EndDrawing()
  }

}