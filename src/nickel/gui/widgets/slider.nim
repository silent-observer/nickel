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

proc newGuiDiscreteSliderRaw*(track: Slice9Id, head: ResourceId, count: int, 
    orientation: Orientation = Horizontal, 
    padding: DirValues = ZeroDirValues; height, width: int = LengthUndefined): GuiElement =
  ## Creates a discrete slider, which is raw and doesn't have any behaviour.
  ## Normally you should use
  ## [newGuiDiscreteSlider proc](#newGuiDiscreteSlider,Slice9Id,ImageId,int,DirValues,int,proc(int))
  let e = gw.newOwnedEntity()
  e.get.add orientation
  var headLength : int
  var headSize: Size

  case head.getResourceKind:
  of ResourceKind.Image: 
    e.get.add ImageComp(head)
    headSize = Size(w: head.getImageResource.width, h: head.getImageResource.height)
  of ResourceKind.Slice9:
    e.get.add AltPanelComp(head)
    headSize = Size(w: head.getSlice9Resource.left + head.getSlice9Resource.right, 
                    h: head.getSlice9Resource.top + head.getSlice9Resource.bottom)
  else: raise newException(NickelDefect, "Slider head has to be either an image or a slice-9")

  case orientation:
  of Horizontal:
    e.get.add Size(w: width, h: LengthUndefined).PreferredSize
    headLength = headSize.w
  of Vertical:
    e.get.add Size(w: LengthUndefined, h: height).PreferredSize
    headLength = headSize.h
  e.get.add Padding(padding)
  e.get.add PanelComp(track)
  e.get.add SliderComp(isDiscrete: true, count: count, discreteVal: 0, headLength: headLength)
  e.get.add SavesRect(irect(0, 0, 0, 0))
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)

proc newGuiContinuousSliderRaw*(track: Slice9Id, head: ResourceId, 
    orientation: Orientation = Horizontal, padding: DirValues = ZeroDirValues;
    height, width: int = LengthUndefined): GuiElement =
  ## Creates a continuous slider, which is raw and doesn't have any behaviour.
  ## Normally you should use
  ## [newGuiContinuousSlider proc](#newGuiDiscreteSlider,Slice9Id,ImageId,DirValues,int,proc(float))
  let e = gw.newOwnedEntity()
  e.get.add orientation
  var headLength : int
  var headSize : Size

  case head.getResourceKind:
  of ResourceKind.Image: 
    e.get.add ImageComp(head)
    headSize = Size(w: head.getImageResource.width, h: head.getImageResource.height)
  of ResourceKind.Slice9:
    e.get.add AltPanelComp(head)
    headSize = Size(w: head.getSlice9Resource.left + head.getSlice9Resource.right, 
                    h: head.getSlice9Resource.top + head.getSlice9Resource.bottom)
  else: raise newException(NickelDefect, "Slider head has to be either an image or a slice-9")

  case orientation:
  of Horizontal:
    e.get.add Size(w: width, h: LengthUndefined).PreferredSize
    headLength = headSize.w
  of Vertical:
    e.get.add Size(w: LengthUndefined, h: height).PreferredSize
    headLength = headSize.h
  e.get.add Padding(padding)
  e.get.add PanelComp(track)
  e.get.add SliderComp(isDiscrete: false, continuousVal: 0, headLength: headLength)
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

proc `sliderHeadLength=`*(gui: GuiElement, val: int) =
  ## Sets the length of the slider. Should only work if the slider has slice-9 as its head
  if (gui.e.has SliderComp) and (gui.e.has AltPanelComp):
    gui.e.slider.headLength = val
  else:
    raise newException(NickelDefect, "This GuiElement is not a slider with a slice 9!")

proc layoutSlider*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Layout a slider
  load orientation
  load preferredSize
  load padding
  load track, panel
  var head: ResourceId
  var isHeadSlice9 : bool
  if gui.e.has AltPanelComp:
    head = gui.e.altPanel
    isHeadSlice9 = true
  else:
    head = gui.e.img
    isHeadSlice9 = false
  load slider
  
  case orientation:
  of Horizontal:
    let w = if preferredSize.w == LengthUndefined: c.max.w else: preferredSize.w
    let headHeight = head.getImageResource.height
    let headWidth = slider.headLength
    let trackHeight = track.getSlice9Resource.bottom + track.getSlice9Resource.top
    if c.max.h < max(headHeight, trackHeight): return initGuiEmpty()
    let h = max(c.min.h, max(headHeight, trackHeight))

    let slidableWidth = w - padding.left - padding.right - headWidth
    let portion = if slider.isDiscrete: slider.discreteVal.float / float(slider.count - 1) else: slider.continuousVal
    let x = padding.left + (slidableWidth.float * portion).pixelPerfect(1)
    
    let headPrimitive =
      if isHeadSlice9:
        initGuiPanel(irect(x, 0, headWidth, headHeight), head, guiId=gui.e.id.int)
      else:
        initGuiImage(irect(x, 0, headWidth, headHeight), head, guiId=gui.e.id.int)

    result = initGuiGroup(irect(0, 0, w, h), @[
      initGuiPanel(irect(0, 0, w, trackHeight), track, guiId=gui.e.id.int),
      headPrimitive
    ])
    result.clickTransparent = true
    result.children[0].rect.alignVertical(Size(w: w, h: h), VCenter)
    result.children[1].rect.alignVertical(Size(w: w, h: h), VCenter)
    result.children[0].savesRect = true
  of Vertical:
    let h = if preferredSize.h == LengthUndefined: c.max.h else: preferredSize.h
    let headWidth = head.getImageResource.width
    let headHeight = slider.headLength
    let trackWidth = track.getSlice9Resource.left + track.getSlice9Resource.right
    if c.max.w < max(headWidth, trackWidth): return initGuiEmpty()
    let w = max(c.min.w, max(headWidth, trackWidth))

    let slidableHeight = h - padding.top - padding.bottom - headHeight
    let portion = if slider.isDiscrete: slider.discreteVal.float / float(slider.count - 1) else: slider.continuousVal
    let y = padding.top + (slidableHeight.float * portion).pixelPerfect(1)
    
    let headPrimitive =
      if isHeadSlice9:
        initGuiPanel(irect(0, y, headWidth, headHeight), head, guiId=gui.e.id.int)
      else:
        initGuiImage(irect(0, y, headWidth, headHeight), head, guiId=gui.e.id.int)

    result = initGuiGroup(irect(0, 0, w, h), @[
      initGuiPanel(irect(0, 0, trackWidth, h), track, guiId=gui.e.id.int),
      headPrimitive
    ])
    result.clickTransparent = true
    result.children[0].rect.alignHorizontal(Size(w: w, h: h), HCenter)
    result.children[1].rect.alignHorizontal(Size(w: w, h: h), HCenter)
    result.children[0].savesRect = true


proc calculateClosest(trackStart, trackLength, headLength, paddingStart, paddingEnd, mousePos: int): float =
  let offset = mousePos.float - (trackStart.float + paddingStart.float + headLength.float / 2)
  let normalized = offset / float(trackLength - paddingStart - paddingEnd - headLength)
  clamp(normalized, 0, 1)

proc calculateDiscrete(pos: float, count: int): int =
  round(pos * float(count - 1)).int

proc addContinuousSliderBehaviour*(gui: sink GuiElement, onChange: proc(x: float)): GuiElement =
  load padding
  load orientation
  result = gui
  let entity = result.e
  
  if entity.slider.isDiscrete:
    raise newException(NickelDefect, "This slider is discrete!")
  entity.addTracksMouseReleaseEverywhere()
  entity.add OnMousePress(proc(b: Button) =
    entity.addButtonPressed()
    entity.add OnMouseMove(proc(pos: IVec2) =
      let savedRect = entity.savedRect
      let v = case orientation:
        of Horizontal: calculateClosest(savedRect.x, savedRect.w, 
          entity.slider.headLength, padding.left, padding.right, pos.x)
        of Vertical: calculateClosest(savedRect.y, savedRect.h, 
          entity.slider.headLength, padding.top, padding.bottom, pos.y)
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
  load orientation
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
      let v = case orientation:
        of Horizontal: calculateClosest(savedRect.x, savedRect.w, 
          entity.slider.headLength, padding.left, padding.right, pos.x)
        of Vertical: calculateClosest(savedRect.y, savedRect.h, 
          entity.slider.headLength, padding.top, padding.bottom, pos.y)
      let realV = v.calculateDiscrete(entity.slider.count)
      entity.slider.discreteVal = realV
    )
  )
  entity.add OnMouseRelease(proc(b: Button) =
    if entity.has ButtonPressed:
      entity.removeButtonPressed()
      entity.removeOnMouseMove()
      if onChange != nil:
        onChange(entity.slider.discreteVal)
  )

proc newGuiDiscreteSlider*(track: Slice9Id, head: ResourceId, count: int, 
    orientation: Orientation = Horizontal, padding: DirValues = ZeroDirValues,
    height, width: int = LengthUndefined, onChange: proc(x: int) = nil): GuiElement =
  ## Creates a discrete slider
  newGuiDiscreteSliderRaw(track, head, count, orientation, padding, height, width)
    .addDiscreteSliderBehaviour(onChange)

proc newGuiContinuousSlider*(track: Slice9Id, head: ResourceId, 
    orientation: Orientation = Horizontal, padding: DirValues = ZeroDirValues,
    height, width: int = LengthUndefined, onChange: proc(x: float) = nil): GuiElement =
  ## Creates a continous slider
  newGuiContinuousSliderRaw(track, head, orientation, padding, height, width)
    .addContinuousSliderBehaviour(onChange)