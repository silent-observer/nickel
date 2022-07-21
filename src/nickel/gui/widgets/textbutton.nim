## Defines a text button element.
## This is a button that contains text inside it.
## Button's background is a slice-9, and it has a different slice-9 when pressed.
## 
## Note that this element doesn't react to clicks in any way by default, to add
## such behaviour you should use [behaviours module](../behaviours/buttons.html).

import ".."/[ecs, helpers, primitives, text]
import ".."/".."/[utils, resources]
import vmath

proc newGuiTextButton*(text: TextSpec, slice9: Slice9Id, slice9Pressed: Slice9Id,
    padding: DirValues = ZeroDirValues, paddingPressed: DirValues = padding, 
    width: int = LengthUndefined, height: int = LengthUndefined): GuiElement =
  ## Creates a text button
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: height).PreferredSize
  e.get.add Padding(padding)
  e.get.add text
  e.get.add PanelComp(slice9)
  e.get.add AltPanelComp(slice9Pressed)
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)

proc layoutTextButton*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Layouts a text button
  load text
  load padding
  load preferredSize
  load panel
  load altPanel
  let isPressed = gui.e.has ButtonPressed

  let w = if preferredSize.w == LengthUndefined: c.max.w else: preferredSize.w
  let h = if preferredSize.h == LengthUndefined: c.max.h else: preferredSize.h
  
  let size = Size(w: w, h: h).fitConstraint(c).subtractPadding(padding)
  let align = if preferredSize.w == LengthUndefined: HLeft else: HCenter
  let uniqueHash = layoutText(size, text, Alignable(hAlign: align, vAlign: VTop))
  let (a, b) = getText(uniqueHash)

  let sizePanel = Size(w: b.x.int, h: b.y.int).addPadding(padding)
  var
    rText = irect(padding.left, padding.top, b.x.int, b.y.int)
    rPanel = irect(0, 0, sizePanel.w, sizePanel.h)
  result = initGuiGroup(rPanel, @[
    initGuiPanel(rPanel, (if isPressed: altPanel else: panel), guiId=gui.e.id.int),
    initGuiText(rText, a, uniqueHash, guiId=gui.e.id.int)
  ], guiId=gui.e.id.int)