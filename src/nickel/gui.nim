## The main GUI module. This simply imports lots of other modules and exports what is actually
## needed for the end user.

import gui/[ecs, primitives, text]

proc layout*(gui: GuiElement, c: Constraint): GuiPrimitive

import gui/widgets/[linearlayout, container, label, textbutton, spritecamera, slider, progressbar]
import gui/behaviours/[buttons, sliderBehaviour]
import utils
from gui/helpers import e, disowned, isPressed


export linearlayout, container, label, textbutton, spritecamera, slider, progressbar
export buttons, sliderBehaviour
export HAlign, VAlign, Direction, Orientation, ClickCallback, MouseAreaCallback
export DirValues, Constraint, TextSpec, LengthInfinite, LengthUndefined
export GuiElementKind, GuiElement, ZeroDirValues, initDirValues
export add, looseConstraint, strictConstraint, NoConstraint
export disowned, isPressed, initText

proc layout*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Run a Flutter-like layout algorithm on the `GuiElement` tree, given a constraint `c`,
  ## and return a `GuiPrimitive` tree.
  if gui.e.isSimpleContainer: layoutContainer(gui, c)
  elif gui.e.isLabel: layoutLabel(gui, c)
  elif gui.e.isLinearLayout: layoutLinear(gui, c)
  elif gui.e.isTextButton: layoutTextButton(gui, c)
  elif gui.e.isSpriteCamera: layoutSpriteCamera(gui, c)
  elif gui.e.isSlider: layoutSlider(gui, c)
  elif gui.e.isProgressBar: layoutProgressBar(gui, c)
  else: raise newException(NickelDefect, "Undefined type of GUI element")