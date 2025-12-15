// ok:
// check out sets

package main

import "core:fmt"
import "core:sort"
import "core:reflect"

SomeType :: struct {
  blah: string
}

helloooo :: proc () {
  slice := []int{2, 7, 2, 6, 1, 0, -3}
  sort.merge_sort(slice)

  fmt.printf("%v\n", slice)

  fmt.printf("%v\n", reflect.struct_fields_zipped(SomeType))

  for i in 0..<10 {
    fmt.printf("Hiiiiiiiii %v\n", i)
  }
}