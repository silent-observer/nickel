## Defines s sprite camera element.
## This is a way to display arbitrary sprites inside your game.
## Each sprite camera has a list of sprites to display, and a rectangular area (canvas)
## they all are supposed to occupy.
## In the GUI, sprite camera displays all the sprites in the list, possibly aligning
## the canvas inside the space that the sprite camera occupies 
## (for example, it can center the view if the space given to the camera is too small to fit
## all the sprites).
## It also contains colliders as children, which can detect mouse clicks or mouse entering
## or leaving their area.

import ".."/[ecs, helpers, primitives]
import ".."/".."/[utils, sprite, collider]
import vmath
from bumpy import `xy=`

proc newSpriteCamera*(sprites: seq[SpriteId], rect: IRect,
    vAlign: VAlign = VCenter, hAlign: HAlign = HCenter,
    width: int = LengthUndefined, height: int = LengthUndefined): GuiElement =
  ## Creates a sprite camera element.
  ## 
  ## Note that it doesn't contain any colliders yet and you should add them with
  ## [add proc](../ecs.html#add,GuiElement,GuiElement).
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: height).PreferredSize
  e.get.add Alignable(hAlign: hAlign, vAlign: vAlign)
  e.get.add SpriteCanvas(sprites: sprites, rect: rect)
  e.get.addLayout()
  GuiElement(isOwned: true, eOwned: e, kind: Container, children: @[])

proc newCollider*(center: Vec2, radius: float): GuiElement =
  ## Creates a new circle collider element
  let e = gw.newOwnedEntity()
  e.get.add initCollider(center, radius)
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)
proc newCollider*(x, y, w, h: float): GuiElement =
  ## Creates a new rectangle collider element
  let e = gw.newOwnedEntity()
  e.get.add initCollider(x, y, w, h)
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)
proc newCollider*(pos, size: Vec2): GuiElement =
  ## Creates a new rectangle collider element
  let e = gw.newOwnedEntity()
  e.get.add initCollider(pos, size)
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)
proc newCollider*(poly: seq[Vec2]): GuiElement =
  ## Creates a new polygon collider element
  let e = gw.newOwnedEntity()
  e.get.add initCollider(poly)
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)
proc updateCollider*(gui: GuiElement, c: Collider) =
  ## Changes a collider in the collider element
  if gui.e.has Collider:
    gui.e.collider = c
proc updateColliderPosition*(gui: GuiElement, pos: Vec2) =
  ## Changes collider's position.
  ## 
  ## Note that only circles and rectangles are supported.
  if gui.e.has Collider:
    case gui.e.collider.kind:
    of ColliderKind.Circle: gui.e.collider.circle.pos = pos
    of ColliderKind.Rect: gui.e.collider.rect.xy = pos
    of ColliderKind.Polygon: discard # not supported

proc layoutSpriteCamera*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Layouts a sprite camera element.
  load preferredSize
  load canvas
  load align

  var colliders: seq[(Collider, int)]
  for i in 0..<gui.children.len:
    template child: GuiElement = gui.children[i]
    if child.e.has Collider:
      colliders.add (child.e.collider, child.e.id.int)

  let
    childSize = canvas.rect.getSize()
    size = childSize.fitPreferred(preferredSize).fitConstraint(c)

  result = initGuiSprites(irect(0, 0, size.w, size.h), canvas.sprites, 
    colliders, guiId=gui.e.id.int)
  result.offset.x = -canvas.rect.x.int32
  result.offset.y = -canvas.rect.y.int32
  case align.hAlign:
  of HLeft: discard
  of HCenter: result.offset.x += int32(size.w - canvas.rect.w) div 2
  of HRight: result.offset.x += int32(size.w - canvas.rect.w)

  case align.vAlign:
  of VTop: discard
  of VCenter: result.offset.y += int32(size.h - canvas.rect.h) div 2
  of VBottom: result.offset.y += int32(size.h - canvas.rect.h)

  result.clickTransparent = true