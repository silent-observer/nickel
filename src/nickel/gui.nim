## The main GUI module. This simply imports lots of other modules and exports what is actually
## needed for the end user.

import gui/[ecs, primitives, text]

proc layout*(gui: GuiElement, c: Constraint): GuiPrimitive

import gui/widgets/[linearlayout, container, label, textbutton, spritecamera, 
  slider, progressbar, buttonBehaviours, scrollable, draganddrop, image]
import utils
from gui/helpers import e, disowned, isPressed
import gui/context


export linearlayout, container, label, textbutton, spritecamera, slider, progressbar, scrollable
export image
export buttonBehaviours, draganddrop
export HAlign, VAlign, Direction, Orientation, ClickCallback, MouseAreaCallback
export DirValues, Constraint, TextSpec, LengthInfinite, LengthUndefined
export GuiElementKind, GuiElement, ZeroDirValues, initDirValues
export add, looseConstraint, strictConstraint, NoConstraint
export disowned, isPressed, initText, newContext, withContext, addTotallyClickTransparent

proc layout*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Run a Flutter-like layout algorithm on the `GuiElement` tree, given a constraint `c`,
  ## and return a `GuiPrimitive` tree.
  if gui.e.isSimpleContainer: result = layoutContainer(gui, c)
  elif gui.e.isLabel: result = layoutLabel(gui, c)
  elif gui.e.isLinearLayout: result = layoutLinear(gui, c)
  elif gui.e.isTextButton: result = layoutTextButton(gui, c)
  elif gui.e.isSpriteCamera: result = layoutSpriteCamera(gui, c)
  elif gui.e.isSlider: result = layoutSlider(gui, c)
  elif gui.e.isProgressBar: result = layoutProgressBar(gui, c)
  elif gui.e.isScrollable: result = layoutScrollable(gui, c)
  elif gui.e.isImage or gui.e.isSlice9 or gui.e.isSprite:
    result = layoutImage(gui, c)
  else: raise newException(NickelDefect, "Undefined type of GUI element")

  if gui.e.has TotallyClickTransparent:
    result.makeTotallyClickTransparent()

proc addTotallyClickTransparent*(gui: sink GuiElement): GuiElement {.inline.} =
  gui.e.addTotallyClickTransparent()
  gui