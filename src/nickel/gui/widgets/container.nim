## A module defining containers and panels.
## Both containers and panels contain only a single child element, and they
## position it according to their padding and alignment.
## Panel also has a visible slice-9 undernearth the child.

import ".."/[ecs, helpers, primitives]
import ".."/".."/gui
import ".."/".."/[utils, resources]

proc newGuiContainer(children: sink seq[GuiElement], padding: DirValues = ZeroDirValues, 
    vAlign: VAlign = VTop, hAlign: HAlign = HLeft, width: int = LengthUndefined, 
    height: int = LengthUndefined): GuiElement =
  ## Creates a new container element
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: height).PreferredSize
  e.get.add Alignable(hAlign: hAlign, vAlign: vAlign)
  e.get.add Padding(padding)
  e.get.addContainerTag()
  GuiElement(isOwned: true, eOwned: e, kind: Container, children: children)

proc newGuiContainer*(child: sink GuiElement, padding: DirValues = ZeroDirValues, 
    vAlign: VAlign = VTop, hAlign: HAlign = HLeft, width: int = LengthUndefined, 
    height: int = LengthUndefined): GuiElement {.inline.} =
  ## Creates a new container element
  newGuiContainer(@[child], padding, vAlign, hAlign, width, height)
proc newGuiContainer*(padding: DirValues = ZeroDirValues, 
    vAlign: VAlign = VTop, hAlign: HAlign = HLeft, width: int = LengthUndefined, 
    height: int = LengthUndefined): GuiElement {.inline.} =
  ## Creates a new container element
  newGuiContainer(@[], padding, vAlign, hAlign, width, height)

proc newGuiPanel*(child: sink GuiElement, slice9: Slice9Id, padding: DirValues = ZeroDirValues, 
    vAlign: VAlign = VTop, hAlign: HAlign = HLeft, width: int = LengthUndefined, 
    height: int = LengthUndefined): GuiElement =
  ## Creates a new panel element
  result = newGuiContainer(child, padding, vAlign, hAlign, width, height)
  result.e.add PanelComp(slice9)
proc newGuiPanel*(slice9: Slice9Id, padding: DirValues = ZeroDirValues, 
    vAlign: VAlign = VTop, hAlign: HAlign = HLeft, width: int = LengthUndefined, 
    height: int = LengthUndefined): GuiElement =
  ## Creates a new panel element
  result = newGuiContainer(padding, vAlign, hAlign, width, height)
  result.e.add PanelComp(slice9)

proc layoutContainer*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Layouts a container or a panel
  load preferredSize
  load padding
  load align
  if gui.children.len > 0:
    let
      newC = c.fitPreferred(preferredSize).subtractPadding(padding).noMin()
      childLayout = gui.children[0].layout(newC)
      childSize = childLayout.rect.getSize()
      size = childSize.addPadding(padding).fitPreferred(preferredSize).fitConstraint(c)
      sizeP = size.subtractPadding(padding)
    result = initGuiGroup(irect(0, 0, size.w, size.h), @[childLayout], guiId=gui.e.id.int)
    result.children[0].rect.alignHorizontal(sizeP, align.hAlign)
    result.children[0].rect.x += padding.left
    result.children[0].rect.alignVertical(sizeP, align.vAlign)
    result.children[0].rect.y += padding.top
  else:
    let size = preferredSize.fitConstraint(c)
    result = initGuiGroup(irect(0, 0, size.w, size.h), @[], guiId=gui.e.id.int)

  if gui.e.has PanelComp:
    load panel
    result.children.insert(initGuiPanel(
      result.rect, panel, guiId=gui.e.id.int
    ))
  else:
    result.clickTransparent = true