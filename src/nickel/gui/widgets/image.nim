import ".."/[ecs, helpers, primitives]
import ".."/".."/[utils, resources]

proc newGuiImage*(image: ResourceId,  index: int = 0, width, height: int = LengthUndefined): GuiElement =
  ## Creates a new image element
  let e = gw.newOwnedEntity()
  e.get.add Size(w: width, h: height).PreferredSize
  case image.getResourceKind:
  of ResourceKind.Image: e.get.add ImageComp(image)
  of ResourceKind.Slice9: e.get.add PanelComp(image)
  of ResourceKind.SpriteSheet: e.get.add SpriteComp(ss: image, i: index)
  else: raise newException(NickelDefect, 
    "Image element head has to be either an image, a slice-9 or a sprite")
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)

proc layoutImage*(gui: GuiElement, c: Constraint): GuiPrimitive =
  if gui.e.has ImageComp:
    load img
    let size = img.getImageSize.fitConstraint(c)
    initGuiImage(irect(0, 0, size.w, size.h), img)
  elif gui.e.has PanelComp:
    load preferredSize
    load panel
    let size = preferredSize.fitConstraint(c)
    initGuiPanel(irect(0, 0, size.w, size.h), panel)
  else:
    load sprite
    let size = sprite.ss.getSpriteSize.fitConstraint(c)
    initGuiImage(irect(0, 0, size.w, size.h), sprite.ss & "_" & $sprite.i)