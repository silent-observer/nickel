## Defines a linear layout element.
## This element can contain multiple children and stacks them in some direction 
## You can also define alignments for the elements, and also specify padding and
## the gap size between consecutive elements.

import ".."/[ecs, helpers, primitives]
when not defined(nimsuggest):
  import ".."/".."/gui
import ".."/".."/utils

proc newGuiLinearLayout*(orientation: Orientation = Vertical, gap: int = LengthUndefined,
    padding: DirValues = ZeroDirValues, vAlign: VAlign = VTop, hAlign: HAlign = HLeft,
    width: int = LengthUndefined, height: int = LengthUndefined): GuiElement =
  ## Creates a new linear layout element
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: height).PreferredSize
  e.get.add Alignable(hAlign: hAlign, vAlign: vAlign)
  e.get.add Padding(padding)
  e.get.add LinearLayoutGap(gap)
  e.get.add Orientation(orientation)
  e.get.addLayout()
  GuiElement(isOwned: true, eOwned: e, kind: Container, children: @[])

proc layoutLinear*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Layouts a linear layout element
  load orientation
  load padding
  load preferredSize
  load align
  load gap

  template swapCond[T](s: T): T = 
    (if orientation == Orientation.Horizontal: s.swap() else: s)

  if gui.children.len == 0:
    let size = 
      Size(w: padding.left + padding.right, h: padding.top + padding.bottom)
      .fitConstraint(c)
    return initGuiGroup(irect(0, 0, size.w, size.h), @[], guiId=gui.e.id.int)

  var newC = subtractPadding(c, padding).swapCond()


  var heightLeft = newC.max.h - (gui.children.len - 1) * gap
  var totalHeight = (gui.children.len - 1) * gap
  var maxWidth = newC.min.w
  var childrenLayouts: seq[GuiPrimitive] = @[]
  for i in 0..<gui.children.len:
    template child: untyped = gui.children[i]
    let
      childC = Constraint(min: Size(w: 0, h: 0), max: Size(w: newC.max.w, h: heightLeft))
      childLayout = child.layout(childC.swapCond())
      childSize = childLayout.rect.getSize().swapCond()

    heightLeft -= childSize.h
    totalHeight += childSize.h
    maxWidth = max(maxWidth, childSize.w)
    childrenLayouts.add childLayout
  let size = Size(w: maxWidth, h: totalHeight).swapCond()
    .addPadding(padding).fitPreferred(preferredSize).fitConstraint(c)

  result = initGuiGroup(irect(0, 0, size.w, size.h), childrenLayouts, guiId=gui.e.id.int)
  result.clickTransparent = true

  case orientation:
  of Vertical:
    var totalChildRect = IRect(x:0, y: 0, w: 0, h: totalHeight)
    totalChildRect.alignVertical(size, align.vAlign)

    var y = totalChildRect.y + padding.top
    for child in result.children.mitems:
      child.rect.y = y
      child.rect.alignHorizontal(size, align.hAlign)
      child.rect.x += padding.left
      y += child.rect.h + gap
  of Horizontal:
    var totalChildRect = IRect(x:0, y: 0, w: totalHeight, h: 0)
    totalChildRect.alignHorizontal(size, align.hAlign)

    var x = totalChildRect.x + padding.left
    for child in result.children.mitems:

      child.rect.x = x
      child.rect.alignVertical(size, align.vAlign)
      child.rect.y += padding.top
      x += child.rect.w + gap
