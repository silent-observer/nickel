## The main GUI module. This simply imports lots of other modules and exports what is actually
## needed for the end user.

import gui/[ecs, primitives, text]

proc layout*(gui: GuiElement, c: Constraint): GuiPrimitive

import gui/widgets/[linearlayout, container, label, textbutton, spritecamera]
import gui/behaviours/buttons
import utils
from gui/helpers import e, disowned, isPressed


export linearlayout, container, label, textbutton, spritecamera, buttons
export HAlign, VAlign, Orientation, ClickCallback, MouseMoveCallback
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
  else: raise newException(NickelDefect, "Undefined type of GUI element")