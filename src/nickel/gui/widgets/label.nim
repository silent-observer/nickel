## Defines a simple text GUI element.
## Text inside can be aligned.

import nickel/gui/[ecs, helpers, primitives, text]
import nickel/utils
import vmath

proc newGuiLabel*(text: TextSpec, vAlign: VAlign = Top, hAlign: HAlign = Left, 
    width: int = LengthUndefined, height: int = LengthUndefined): GuiElement =
  ## Creates a new label element
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: height).PreferredSize
  e.get.add Alignable(hAlign: hAlign, vAlign: vAlign)
  e.get.add text
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)

proc layoutLabel*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Layouts a label
  load preferredSize
  load text
  load align

  let w = if preferredSize.w == LengthUndefined: c.max.w else: preferredSize.w
  let h = if preferredSize.h == LengthUndefined: c.max.h else: preferredSize.h
  let size = Size(w: w, h: h).fitConstraint(c)
  let uniqueHash = layoutText(size, text, align)
  let (a, b) = getText(uniqueHash)
  var r = irect(0, 0, b.x.int, b.y.int)
  if preferredSize.h != LengthUndefined:
    r.alignVertical(size, align.vAlign)
  if preferredSize.w != LengthUndefined:
    r.alignHorizontal(size, align.hAlign)
  result = initGuiText(r, a, uniqueHash, guiId=gui.e.id.int)