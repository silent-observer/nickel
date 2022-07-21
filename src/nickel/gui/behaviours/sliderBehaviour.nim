## Slider behaviour. To be applied specifically to [sliders](..\widgets\slider.html)

import ".."/[ecs, helpers]
import ".."/".."/utils
from windy import Button
import vmath

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
      onChange(entity.slider.discreteVal)
  )