## Defines a slider, like the regular audio volume slider in settings.
##
## Slice-9 for the slider track will be rendered as a slice-3, i.e. only the top and bottom parts
## will be used, without the middle one.
## 
## Sliders can be discrete and continuous.
## Discrete sliders can have values from 0 to `count` (not inclusive), so if `count` is 10, then
## the slider will have 10 possible values: from 0 to 9.
## Continuous sliders always have values from 0 to 1.

import ".."/[ecs, helpers, primitives]
import ".."/".."/[utils, resources]
import math, windy

proc newGuiDiscreteSliderRaw*(track: Slice9Id, head: ImageId, count: int, padding: DirValues = ZeroDirValues,
    width: int = LengthUndefined): GuiElement =
  ## Creates a discrete slider, which is raw and doesn't have any behaviour.
  ## Normally you should use
  ## [newGuiDiscreteSlider proc](#newGuiDiscreteSlider,Slice9Id,ImageId,int,DirValues,int,proc(int))
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: LengthUndefined).PreferredSize
  e.get.add Padding(padding)
  e.get.add ImageComp(head)
  e.get.add PanelComp(track)
  e.get.add SliderComp(isDiscrete: true, count: count, discreteVal: 0)
  e.get.add SavesRect(irect(0, 0, 0, 0))
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)

proc newGuiContinuousSliderRaw*(track: Slice9Id, head: ImageId, padding: DirValues = ZeroDirValues,
    width: int = LengthUndefined): GuiElement =
  ## Creates a continuous slider, which is raw and doesn't have any behaviour.
  ## Normally you should use
  ## [newGuiContinuousSlider proc](#newGuiDiscreteSlider,Slice9Id,ImageId,DirValues,int,proc(float))
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
  if c.max.h < max(headHeight, trackHeight): return initGuiEmpty()
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


proc calculateClosest(trackX: int, trackLength: int, headWidth: int, padding: DirValues, mouseX: int): float =
  let offset = mouseX.float - (trackX.float + padding.left.float + headWidth.float / 2)
  let normalized = offset / float(trackLength - padding.left - padding.right - headWidth)
  clamp(normalized, 0, 1)

proc calculateDiscrete(x: float, count: int): int =
  round(x * float(count - 1)).int

proc addContinuousSliderBehaviour*(gui: sink GuiElement, onChange: proc(x: float)): GuiElement =
  load padding
  result = gui
  let entity = result.e
  
  if entity.slider.isDiscrete:
    raise newException(NickelDefect, "This slider is discrete!")
  entity.addTracksMouseReleaseEverywhere()
  entity.add OnMousePress(proc(b: Button) =
    entity.addButtonPressed()
    entity.add OnMouseMove(proc(pos: IVec2) =
      let savedRect = entity.savedRect
      let v = calculateClosest(savedRect.x, savedRect.w, entity.slider.headWidth, padding, pos.x)
      entity.slider.continuousVal = v
    )
  )
  entity.add OnMouseRelease(proc(b: Button) =
    if entity.has ButtonPressed:
      entity.removeButtonPressed()
      entity.removeOnMouseMove()
      if onChange != nil:
        onChange(entity.slider.continuousVal)
  )

proc addDiscreteSliderBehaviour*(gui: sink GuiElement, onChange: proc(x: int)): GuiElement =
  load padding
  result = gui
  let entity = result.e
  
  if not entity.slider.isDiscrete:
    raise newException(NickelDefect, "This slider is continuous!")
  entity.addTracksMouseReleaseEverywhere()
  entity.add OnMousePress(proc(b: Button) =
    #echo "Slider press"
    entity.addButtonPressed()
    entity.add OnMouseMove(proc(pos: IVec2) =
    #  echo "Slider move"
      let savedRect = entity.savedRect
      let v = calculateClosest(savedRect.x, savedRect.w, entity.slider.headWidth, padding, pos.x)
        .calculateDiscrete(entity.slider.count)
      entity.slider.discreteVal = v
    )
  )
  entity.add OnMouseRelease(proc(b: Button) =
    if entity.has ButtonPressed:
      entity.removeButtonPressed()
      entity.removeOnMouseMove()
      if onChange != nil:
        onChange(entity.slider.discreteVal)
  )

proc newGuiDiscreteSlider*(track: Slice9Id, head: ImageId, count: int, padding: DirValues = ZeroDirValues,
    width: int = LengthUndefined, onChange: proc(x: int) = nil): GuiElement =
  ## Creates a discrete slider
  newGuiDiscreteSliderRaw(track, head, count, padding, width)
    .addDiscreteSliderBehaviour(onChange)

proc newGuiContinuousSlider*(track: Slice9Id, head: ImageId, padding: DirValues = ZeroDirValues,
    width: int = LengthUndefined, onChange: proc(x: float) = nil): GuiElement =
  ## Creates a continous slider
  newGuiContinuousSliderRaw(track, head, padding, width)
    .addContinuousSliderBehaviour(onChange)