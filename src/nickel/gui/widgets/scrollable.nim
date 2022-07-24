import ".."/[ecs, helpers, primitives]
import ".."/".."/[utils, resources, gui]
import slider
from math import round

proc newGuiScrollable*(child: sink GuiElement,
    verticalTrack, horizontalTrack, verticalHead, horizontalHead: Slice9Id = "",
    padding: DirValues = ZeroDirValues, sliderPadding: DirValues = ZeroDirValues,
    height, width: int = LengthUndefined): GuiElement =
  let e = gw.newOwnedEntity()
  e.get.add Padding(padding)
  e.get.add Size(w: width, h: height).PreferredSize
  e.get.addScrollable()
  result = GuiElement(isOwned: true, eOwned: e, kind: Container, children: @[])

  result.add child
  if verticalTrack != "" and verticalHead != "":
    result.add newGuiContinuousSlider(
      verticalTrack, verticalHead, Vertical, sliderPadding)
  else:
    result.add initEmptyGuiElement()
  if horizontalTrack != "" and horizontalHead != "":
    result.add newGuiContinuousSlider(
      horizontalTrack, horizontalHead, Horizontal, sliderPadding)
  else:
    result.add initEmptyGuiElement()

proc layoutScrollable*(gui: GuiElement, c: Constraint): GuiPrimitive =
  load padding
  load preferredSize

  let w = if preferredSize.w == LengthUndefined: c.max.w else: preferredSize.w
  let h = if preferredSize.h == LengthUndefined: c.max.h else: preferredSize.h

  var scrollAreaSize = Size(w: w, h: h).subtractPadding(padding)

  var minHeadLenVert, minHeadLenHor = 0

  if not gui.children[1].isEmpty:
    let head = gui.children[1].e.altPanel.getSlice9Resource
    scrollAreaSize.w -= head.left + head.right
    minHeadLenVert = head.top + head.bottom
  if not gui.children[2].isEmpty:
    let head = gui.children[2].e.altPanel.getSlice9Resource
    scrollAreaSize.h -= head.top + head.bottom
    minHeadLenHor = head.left + head.right

  var scrollAreaSizeWithPadding = scrollAreaSize.addPadding(padding)

  var childSize = scrollAreaSize

  if not gui.children[1].isEmpty:
    childSize.h = LengthInfinite
  if not gui.children[2].isEmpty:
    childSize.w = LengthInfinite
  let childLayout = gui.children[0].layout(looseConstraint(childSize.w, childSize.h))
  result = initGuiGroup(irect(0, 0, w, h), @[
    childLayout.initGuiMasked(irect(0, 0, scrollAreaSize.w, scrollAreaSize.h))
  ])

  var 
    x = padding.left.float
    y = padding.top.float

  if not gui.children[1].isEmpty and childLayout.rect.h > scrollAreaSize.h:
    gui.children[1].e.slider.headLength = max(minHeadLenVert.float, 
      scrollAreaSize.h.float / childLayout.rect.h.float * scrollAreaSize.h.float).round().int
    result.children.add gui.children[1].layoutSlider(
        strictConstraint(w - scrollAreaSizeWithPadding.w, 
          scrollAreaSizeWithPadding.h)
      ).adjust(scrollAreaSizeWithPadding.w, 0)
    y -= gui.children[1].e.slider.continuousVal * float(childLayout.rect.h - scrollAreaSize.h)
  if not gui.children[2].isEmpty and childLayout.rect.w > scrollAreaSize.w:
    gui.children[2].e.slider.headLength = max(minHeadLenHor.float, 
      scrollAreaSize.w.float / childLayout.rect.w.float * scrollAreaSize.w.float).round().int
    result.children.add gui.children[2].layoutSlider(
        strictConstraint(scrollAreaSizeWithPadding.w, 
          h - scrollAreaSizeWithPadding.h)
      ).adjust(0, scrollAreaSizeWithPadding.h)
    x -= gui.children[2].e.slider.continuousVal * float(childLayout.rect.w - scrollAreaSize.w)
  result.children[0].masked = result.children[0].masked.adjust(x.round().int, y.round().int)