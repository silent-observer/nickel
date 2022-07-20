import ecs, helpers
import nickel/[utils, resources]
import lrucache, pixie
import hashes

var typeSetTable = newLRUCache[Hash, (Arrangement, Vec2)](1000)

proc layoutText*(size: Size, text: TextSpec, align: Alignable): Hash =
  ## Helper proc for layouting text, caches the result of the layout.
  var font = newFont(getFontResource(text.font))
  font.size = text.size
  font.paint.color = text.color

  let uniqueHash = hash((text.text, size.w, text.size, text.color, align.hAlign))
  if uniqueHash notin typeSetTable:
    if align.hAlign == Left:
      let arr = typeset(font, text.text,
        vec2(size.w.float, size.h.float), align.hAlign.convert(), TopAlign)
      let bounds = arr.layoutBounds()
      typeSetTable[uniqueHash] = (arr, bounds)
    else:
      let bounds = typeset(font, text.text,
        vec2(size.w.float, size.h.float), LeftAlign, TopAlign).layoutBounds()
      let arr = typeset(font, text.text, bounds, align.hAlign.convert(), TopAlign)
      typeSetTable[uniqueHash] = (arr, bounds)
  uniqueHash

proc getText*(h: Hash): (Arrangement, Vec2) {.inline.} = 
  ## Gets the result of the layout after calling [layoutText proc](#layoutText,Size,TextSpec,Alignable).
  typeSetTable[h]

proc initText*(text: string, font: FontId, size: float32 = 14, 
    color: Color = color(0, 0, 0, 1)): TextSpec =
  ## Creates a `TextSpec`.
  TextSpec(
    text: text,
    font: font,
    size: size,
    color: color,
  )
