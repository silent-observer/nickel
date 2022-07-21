## Defines a slider, like the regular audio volume slider in settings.
## Behaviour for it is defined in [behaviours/slider module](../behaviours/sliderBehaviour.html)
##
## Slice-9 for the slider track will be rendered as a slice-3, i.e. only the top and bottom parts
## will be used, without the middle one.
## 
## Sliders can be discrete and continuous.
## Discrete sliders can have values from 0 to `count` (not inclusive), so if `count` is 10, then
## the slider will have 10 possible values: from 0 to 9.
## Continuous sliders always have values from 0 to 1.

import nickel/gui/[ecs, helpers, primitives]
import nickel/[utils, resources]

proc newGuiDiscreteSlider*(track: Slice9Id, head: ImageId, count: int, padding: DirValues = ZeroDirValues,
    width: int = LengthUndefined): GuiElement =
  ## Creates a discrete slider
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: LengthUndefined).PreferredSize
  e.get.add Padding(padding)
  e.get.add ImageComp(head)
  e.get.add PanelComp(track)
  e.get.add SliderComp(isDiscrete: true, count: count, discreteVal: 0)
  e.get.add SavesRect(irect(0, 0, 0, 0))
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)

proc newGuiContinuousSlider*(track: Slice9Id, head: ImageId, padding: DirValues = ZeroDirValues,
    width: int = LengthUndefined): GuiElement =
  ## Creates a continous slider
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: LengthUndefined).PreferredSize
  e.get.add Padding(padding)
  e.get.add ImageComp(head)
  e.get.add PanelComp(track)
  e.get.add SliderComp(isDiscrete: false, continuousVal: 0, headWidth: head.getImageResource.width)
  e.get.add SavesRect(irect(0, 0, 0, 0))
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)

proc discreteSliderVal*(gui: GuiElement): int =
  ## Gets the value of a discrete slider
  if gui.e.has SliderComp:
    load slider
    if slider.isDiscrete:
      return slider.discreteVal
  raise newException(NickelDefect, "This GuiElement is not a discrete slider")

proc continuousSliderVal*(gui: GuiElement): float =
  ## Gets the value of a continuous slider
  if gui.e.has SliderComp:
    load slider
    if not slider.isDiscrete:
      return slider.continuousVal
  raise newException(NickelDefect, "This GuiElement is not a continuous slider")

proc `discreteSliderVal=`*(gui: GuiElement, val: int) =
  ## Gets the value of a discrete slider
  if gui.e.has SliderComp:
    load slider
    if slider.isDiscrete:
      gui.e.slider.discreteVal = val
      return
  raise newException(NickelDefect, "This GuiElement is not a discrete slider")

proc `continuousSliderVal=`*(gui: GuiElement, val: float) =
  ## Gets the value of a continuous slider
  if gui.e.has SliderComp:
    load slider
    if not slider.isDiscrete:
      gui.e.slider.continuousVal = val
      return
  raise newException(NickelDefect, "This GuiElement is not a continuous slider")

proc layoutSlider*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Layout a slider
  load preferredSize
  load padding
  load track, panel
  load head, img
  load slider

  let w = if preferredSize.w == LengthUndefined: c.max.w else: preferredSize.w
  let headHeight = head.getImageResource.height
  let headWidth = head.getImageResource.width
  let trackHeight = track.getSlice9Resource.bottom + track.getSlice9Resource.top
  let h = max(c.min.h, max(headHeight, trackHeight))

  let slidableWidth = w - padding.left - padding.right - headWidth
  let portion = if slider.isDiscrete: slider.discreteVal.float / float(slider.count - 1) else: slider.continuousVal
  let x = padding.left + (slidableWidth.float * portion).pixelPerfect(1)
  
  result = initGuiGroup(irect(0, 0, w, h), @[
    initGuiPanel(irect(0, 0, w, trackHeight), track, guiId=gui.e.id.int),
    initGuiImage(irect(x, 0, headWidth, headHeight), head, guiId=gui.e.id.int)
  ])
  result.clickTransparent = true
  result.children[0].rect.alignVertical(Size(w: w, h: h), VCenter)
  result.children[1].rect.alignVertical(Size(w: w, h: h), VCenter)
  result.children[0].savesRect = true