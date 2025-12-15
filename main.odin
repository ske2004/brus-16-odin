package main

import "core:fmt"
import "core:os"
import "vendor:raylib"
import "core:reflect"
import "core:time"

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
  .K, .L, .I, .O,
  .W, .S, .A, .D,
  .F, .G, .R, .T,
}

main :: proc() {
  if len(os.args) != 2 {
    fmt.eprintf("usage: %s <rom.bin>\n", os.args[0])
    os.exit(1)
  }

  file, ok := os.read_entire_file(os.args[1])
  if !ok {
    fmt.eprintf("noooo file dummy\n")
    os.exit(1)
  }

  title := fmt.caprint("odin-brus-16:", os.args[1])
  defer delete(title, context.allocator)

  defer delete(file, context.allocator)

  cpu := rom_init(file)

  raylib.InitWindow(width = 640, height = 480, title = title)
  defer raylib.CloseWindow()
 
  raylib.SetTargetFPS(60)

  for !raylib.WindowShouldClose() {
    raylib.BeginDrawing()

    raylib.ClearBackground(raylib.BLACK)

    for k, i in INPUT_MAP {
      cpu.ram[MEM_INPUT + i] = cast(u16)raylib.IsKeyDown(k)
    }

    // start_time := time.now()
    for !cpu.wait {
      run_instr(&cpu)
    }
    // fmt.printf("%vns\n", time.now()._nsec - start_time._nsec)

    cpu.wait = false

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