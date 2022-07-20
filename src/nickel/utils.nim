## Internal utility module with miscellaneous definitions.

import pixie

proc integerScaleUp*(img: Image, scale: int): Image =
  ## A function to scale up pixel-art images by integer factors.
  if scale == 1: return img
  result = newImage(img.width * scale, img.height * scale)
  for y in 0..<img.height:
    for x in 0..<img.width:
      let
        rgbx = img.unsafe[x, y]
        resultIdx = result.dataIndex(x * scale, y * scale)
      for i in 0..<scale:
        result.data[resultIdx + i] = rgbx
    
    let rowStart = result.dataIndex(0, y * scale)
    for i in 1 ..< scale:
      copyMem(
        result.data[rowStart + result.width * i].addr,
        result.data[rowStart].addr,
        result.width * 4
      )

type NickelError* = object of ValueError ## Catchable Nickel error.
type NickelDefect* = object of Defect ## Non-catchable Nickel error.

type
  Size* = object
    w*, h*: int
  IRect* = object
    x*, y*, w*, h*: int
proc irect*(x, y, w, h: int): IRect {.inline.} =
  ## Convenience constructor for `IRect`.
  IRect(x: x, y: y, w: w, h: h)