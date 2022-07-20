## Module for low-level GUI API (`GuiPrimitive`s)

import nickel/[resources, utils, sprite, collider]
import tables, hashes, options
import boxy, lrucache
from windy import Button
type
  GuiPrimitiveKind* {.pure.} = enum
    ## Kind of a `GuiPrimitive`.
    Group, ## Contains other nested primitives
    Image, ## Image
    Panel, ## Slice-9
    FlatColorRectangle, ## A colored rectangle (TODO)
    Text, ## Text string
    Sprites ## Multiple sprites and their colliders
  GuiPrimitiveId* = string
  GuiPrimitive* = ref object
    ## Main object, constitutes a tree structure that is later rendered.
    case kind*: GuiPrimitiveKind:
    of Group: children*: seq[GuiPrimitive]
    of GuiPrimitiveKind.Image: image*: ImageId
    of Panel:
      slice9*: Slice9Id
      s9l, s9r, s9b, s9t: int
      s9wc, s9hc: int
    of FlatColorRectangle:
      color*: Color
      roundedCorners*: float
    of Text:
      arrangement*: Arrangement
      uniqueHash*: Hash ## Is used for caching.
    of Sprites:
      offset*: IVec2
      sprites*: seq[SpriteId]
      colliders*: seq[(Collider, int)]
    rect*: IRect
    id*: GuiPrimitiveId
    guiId*: int
    
    clickTransparent*: bool

var idCounter: int = 0
proc prepareGuiPrimitives*() =
  idCounter = 0

proc initGuiGroup*(rect: IRect, children: seq[GuiPrimitive], guiId: int = -1): GuiPrimitive =
  ## Creates a `GuiPrimitive` that is a group.
  GuiPrimitive(
    kind: GuiPrimitiveKind.Group,
    children: children,
    rect: rect,
    guiId: guiId
  )
proc initGuiImage*(rect: IRect, image: ImageId, guiId: int = -1): GuiPrimitive =
  ## Creates a `GuiPrimitive` that is an image.
  GuiPrimitive(
    kind: GuiPrimitiveKind.Image,
    image: image,
    rect: rect,
    guiId: guiId
  )
proc initGuiPanel*(rect: IRect, slice9: Slice9Id, guiId: int = -1): GuiPrimitive =
  ## Creates a `GuiPrimitive` that is a slice-9.
  let s9 = getSlice9Resource(slice9)
  GuiPrimitive(
    kind: GuiPrimitiveKind.Panel,
    slice9: slice9,
    s9l: s9.left,
    s9r: s9.right,
    s9t: s9.top,
    s9b: s9.bottom,
    s9wc: s9.image.width - s9.left - s9.right,
    s9hc: s9.image.height - s9.bottom - s9.top,
    rect: rect,
    guiId: guiId
  )
proc initGuiFlatColorRectangle*(rect: IRect, color: Color, roundedCorners: float = 0, guiId: int = -1): GuiPrimitive =
  ## Creates a `GuiPrimitive` that is a colored rectangle.
  GuiPrimitive(
    kind: GuiPrimitiveKind.FlatColorRectangle,
    color: color,
    roundedCorners: roundedCorners,
    rect: rect,
    guiId: guiId
  )
proc initGuiText*(rect: IRect, arrangement: Arrangement, uniqueHash: Hash, guiId: int = -1): GuiPrimitive =
  ## Creates a `GuiPrimitive` that is a text.
  result = GuiPrimitive(
    kind: GuiPrimitiveKind.Text,
    arrangement: arrangement,
    rect: rect,
    uniqueHash: uniqueHash,
    id: "_text_" & $idCounter,
    guiId: guiId
  )
  idCounter.inc()
proc initGuiSprites*(rect: IRect, sprites: seq[SpriteId], 
    colliders: seq[(Collider, int)], guiId: int = -1): GuiPrimitive =
  ## Creates a `GuiPrimitive` that is a collection of sprites and colliders.
  GuiPrimitive(
    kind: Sprites,
    sprites: sprites,
    colliders: colliders,
    rect: rect,
    guiId: guiId
  )
proc adjust*(g: GuiPrimitive, x: int, y: int): GuiPrimitive =
  ## Adjusts the `GuiPrimitive`'s origin position.
  result = g
  result.rect.x += x
  result.rect.y += y

proc initGuiEmpty*(): GuiPrimitive {.inline.} =
  ## Creates an empty `GuiPrimitive` (empty group).
  initGuiGroup(irect(0, 0, 0, 0), @[])

type TextCacheKey = Hash
let textCache = newLRUCache[TextCacheKey, (Image, Vec2)](100)
let textLastUsed = newTable[string, TextCacheKey]()

proc drawGui*(boxy: Boxy, e: GuiPrimitive) =
  ## Draws a `GuiPrimitive` (possibly recursively).
  template drawImage(boxy: Boxy, key: string, x: int, y: int) =
    drawImage(boxy, key, vec2(x.float, y.float))
  template rect(x, y, w, h: int): Rect =
    rect(x.float32, y.float32, w.float32, h.float32)
  
  boxy.saveTransform()
  boxy.translate(vec2(e.rect.x.float, e.rect.y.float))
  case e.kind:
  of Group:
    for child in e.children:
      boxy.drawGui(child)
  of GuiPrimitiveKind.Image:
    boxy.drawImage(e.image, vec2(0, 0))
  of Panel:
    boxy.drawImage(e.slice9 & "_tl", 0, 0)
    boxy.drawImage(e.slice9 & "_tr", e.rect.w - e.s9r, 0)
    boxy.drawImage(e.slice9 & "_bl", 0, e.rect.h - e.s9b)
    boxy.drawImage(e.slice9 & "_br", e.rect.w - e.s9r, e.rect.h - e.s9b)
    
    
    boxy.pushLayer()
    var x = e.s9l
    while x < e.rect.w - e.s9r:
      boxy.drawImage(e.slice9 & "_t", x, 0)
      boxy.drawImage(e.slice9 & "_b", x, e.rect.h - e.s9b)
      x += e.s9wc

    var y = e.s9t
    while y < e.rect.h - e.s9b:
      boxy.drawImage(e.slice9 & "_l", 0, y)
      boxy.drawImage(e.slice9 & "_r", e.rect.w - e.s9r, y)
      y += e.s9hc
    boxy.pushLayer()
    boxy.drawRect(rect(e.s9l, 0, e.rect.w - e.s9l - e.s9r, e.s9t), color(1, 1, 1))
    boxy.drawRect(rect(e.s9l, e.rect.h - e.s9b, e.rect.w - e.s9l - e.s9r, e.s9b), color(1, 1, 1))
    boxy.drawRect(rect(0, e.s9t, e.s9l, e.rect.h - e.s9t - e.s9b), color(1, 1, 1))
    boxy.drawRect(rect(e.rect.w - e.s9r, e.s9t, e.s9r, e.rect.h - e.s9t - e.s9b), color(1, 1, 1))

    boxy.saveTransform()
    boxy.setTransform(mat3())
    boxy.popLayer(blendMode=MaskBlend)
    boxy.popLayer()
    boxy.restoreTransform()

    boxy.pushLayer()
    y = e.s9t
    while y < e.rect.h - e.s9b:
      x = e.s9l
      while x < e.rect.w - e.s9r:
        boxy.drawImage(e.slice9 & "_c", x, y)
        x += e.s9wc
      y += e.s9hc
    
    boxy.pushLayer()
    boxy.drawRect(rect(e.s9l, e.s9t, e.rect.w - e.s9l - e.s9r, e.rect.h - e.s9t - e.s9b), color(1, 1, 1))
    boxy.saveTransform()
    boxy.setTransform(mat3())
    boxy.popLayer(blendMode=MaskBlend)
    boxy.popLayer()
    boxy.restoreTransform()

  of FlatColorRectangle:
    discard
  of Text:
    let key = e.uniqueHash
    if key in textCache:
      if e.id notin textLastUsed or textLastUsed[e.id] != key:
        boxy.addImage(e.id, textCache[key][0])
        textLastUsed[e.id] = key
      boxy.drawImage(e.id, textCache[key][1])
    else:
      let
        globalBounds = e.arrangement.computeBounds().snapToPixels()
        textImage = newImage(globalBounds.w.int, globalBounds.h.int)
      textImage.fillText(e.arrangement, translate(-globalBounds.xy))
      textCache[key] = (textImage, globalBounds.xy)
      boxy.addImage(e.id, textImage)
      boxy.drawImage(e.id, globalBounds.xy)
  of Sprites:
    boxy.translate(vec2(e.offset))
    for sprite in e.sprites:
      boxy.drawSprite(sprite.get)
  boxy.restoreTransform()

type
  MouseResolutionKind* {.pure.} = enum
    None
    Primitive
    Collider
  MouseResolution* = object
    ## An object containing what the mouse is currently pointing at.
    ## Can be a `GuiPrimitive`, a `Collider` or nothing.
    case kind*: MouseResolutionKind:
    of MouseResolutionKind.None: discard
    of MouseResolutionKind.Primitive: primitive*: GuiPrimitive
    of MouseResolutionKind.Collider: collider*: int

proc resolveMouse*(e: GuiPrimitive, p: IVec2): MouseResolution =
  ## Walks `GuiPrimitive` tree and resolves which object the mouse points to.
  ## 
  ## **See also:**
  ## * [resolveMouse proc](#resolveMouse,seq[GuiPrimitive],IVec2)
  if p.x < e.rect.x or p.y < e.rect.y or 
      p.x > e.rect.x + e.rect.w or
      p.y > e.rect.y + e.rect.h: 
    return MouseResolution(kind: None)
  if e.kind == Group:
    template ivec2(x, y: int): IVec2 = ivec2(x.int32, y.int32)
    for i in countdown(high(e.children), 0):
      let r = resolveMouse(e.children[i], ivec2(p.x - e.rect.x, p.y - e.rect.y))
      if r.kind != None:
        return r
  elif e.kind == Sprites:
    for (c, t) in e.colliders:
      if vec2(p).inside(c):
        return MouseResolution(kind: MouseResolutionKind.Collider, collider: t)

  if e.clickTransparent: MouseResolution(kind: None)
  else: MouseResolution(kind: Primitive, primitive: e)

proc resolveMouse*(gui: seq[GuiPrimitive], p: IVec2): MouseResolution =
  ## Resolves mouse in multiple `GuiPrimitives`
  ## 
  ## **See also:**
  ## * [resolveMouse proc](#resolveMouse,GuiPrimitive,IVec2)
  for i in countdown(high(gui), 0):
    result = gui[i].resolveMouse(p)
    if result.kind != None: 
      return