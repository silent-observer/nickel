## Defines various behaviours useful for buttons.
## By adding this to a GUI element you can make it behave like a button, i.e.
## react when it is clicked.
## 
## While the behavours can be added to an element, only the button
## elements (like `TextButton`) will visibly react to being pressed by default.
## 
## ..warning:
##    For any click-related behaviour to work, the `GuiElement` must be retained between frames,
##    i.e. if you apply a behaviour to a button that is recreated each frame, it won't work.
##    A correct way to handle this is to create a button `GuiElement` beforehand 
##    (you are still free to delete it if you don't need it and recreate it later),
##    add a behaviour to it, and draw its [disowned](../helpers.html#disowned,GuiElement) copy
##    each frame.

import nickel/gui/[ecs, helpers]
from windy import Button

proc addSimpleOnClick*(gui: sink GuiElement, onClick: proc()): GuiElement =
  ## A simple behaviour that calls `onClick` immediately when the button is pressed.
  ## It is recommended to use [addBasicButton proc](#addBasicButton,GuiElement,proc()) instead.
  result = gui
  result.e.add OnMousePress(proc(b: Button) =
    onClick()
  )

proc addBasicButton*(gui: sink GuiElement, onClick: proc()): GuiElement =
  ## A button-like behaviour. When you pressed this button, it will appear pressed,
  ## but the `onClick` callback will only be called when it is released 
  ## (as any GUI button should work, really).
  ## If the users moves their mouse outside the button while pressing it, the button press will be
  ## canceled.
  ## 
  ## **See also:*
  ## * [addBasicButton proc](#addBasicButton,GuiElement,proc(T),T)
  ## * [addToggleButton proc](#addToggleButton,GuiElement,proc(bool))
  result = gui
  let entity = result.e
  entity.add OnMousePress(proc(b: Button) =
    entity.addButtonPressed()
  )
  entity.add OnMouseRelease(proc(b: Button) =
    if entity.has ButtonPressed:
      entity.removeButtonPressed()
      onClick()
  )
  entity.add OnMouseLeave(proc() =
    entity.removeButtonPressed()
  )

proc addBasicButton*[T](gui: sink GuiElement, onClick: proc(x: T), data: T): GuiElement =
  ## A version of [addBasicButton proc](#addBasicButton,GuiElement,proc()) that allows you to
  ## pass some arbitrary data to the `onClick` callback.
  ## Is useful when you register the same callback for many slightly different buttons.
  ## 
  ## **See also:*
  ## * [addBasicButton proc](#addBasicButton,GuiElement,proc())
  ## * [addToggleButton proc](#addToggleButton,GuiElement,proc(bool))
  result = gui
  let entity = result.e
  entity.add OnMousePress(proc(b: Button) =
    entity.addButtonPressed()
  )
  entity.add OnMouseRelease(proc(b: Button) =
    if entity.has ButtonPressed:
      entity.removeButtonPressed()
      onClick(data)
  )
  entity.add OnMouseLeave(proc() =
    entity.removeButtonPressed()
  )

proc addToggleButton*(gui: sink GuiElement, onSwitch: proc(b: bool)): GuiElement =
  ## A button-like behavour that toggles instead of just being pressed.
  ## Every time its state is changed `onSwitch` is called with the new state.
  ## You can also check its state at any time with
  ## [isPressed proc](../helpers.html#isPressed,GuiElement).
  ## 
  ## **See also:*
  ## * [addBasicButton proc](#addBasicButton,GuiElement,proc())
  ## * [addBasicButton proc](#addBasicButton,GuiElement,proc(T),T)
  result = gui
  let entity = result.e
  entity.add OnMousePress(proc(b: Button) =
    entity.addButtonPressedTemporary()
  )
  entity.add OnMouseRelease(proc(b: Button) =
    if entity.has ButtonPressedTemporary:
      entity.removeButtonPressedTemporary()
      if entity.has ButtonPressed:
        entity.removeButtonPressed()
        onSwitch(false)
      else:
        entity.addButtonPressed()
        onSwitch(true)
  )
  entity.add OnMouseLeave(proc() =
    entity.removeButtonPressedTemporary()
  )