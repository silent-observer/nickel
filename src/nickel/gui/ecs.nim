## Interally, the GUI in this engine works with an ECS.
## Here is where it is defined.
## Most of the code here is automatically generated, and since they're needed in other
## modules, they must be exported, and since I can't remove them from the docs, enjoy reading lots
## of machine-generated code.

import yaecs, pixie, windy
import primitives
import nickel/[resources, utils, sprite, collider]

type
  HAlign* {.pure.} = enum
    ## Horizontal alignment
    HLeft,
    HCenter,
    HRight
  VAlign* {.pure.} = enum
    ## Vertical alignment
    VTop,
    VCenter,
    VBottom
  Orientation* {.pure.} = enum
    Vertical,
    Horizontal
  Direction* {.pure.} = enum
    Up
    Down
    Left
    Right

  ClickCallback* = proc (button: Button) ## Callback for mouse clicking
  MouseAreaCallback* = proc() ## Callback for mouse entering or leaving an area
  MouseMoveCallback* = proc(v: IVec2) ## Callback for mouse moving (called every frame)

  DirValues* = object
    ## Something that is defined for each side (like a padding)
    top*, right*, bottom*, left*: int
  Constraint* = object 
    ## Size constraint (look up Flutter constraints to see how that works)
    min*, max*: Size
  TextSpec* = object
    ## All the info needed to render a text string
    text*: string
    font*: FontId
    size*: float32
    color*: Color
  SliderComp* = object
    case isDiscrete*: bool:
    of true:
      discreteVal*: int
      count*: int
    of false:
      continuousVal*: float
    headWidth*: int
  ProgressBarComp* = object
    progress*: float

type
  PreferredSize* = distinct Size
  OnMousePress* = distinct ClickCallback
  OnMouseRelease* = distinct ClickCallback
  OnMouseEnter* = distinct MouseAreaCallback
  OnMouseLeave* = distinct MouseAreaCallback
  OnMouseMove* = distinct MouseMoveCallback
  Alignable* = object
    hAlign*: HAlign
    vAlign*: VAlign
  Padding* = distinct DirValues
  LinearLayoutGap* = distinct int
  PanelComp* = distinct Slice9Id
  AltPanelComp* = distinct Slice9Id
  ImageComp* = distinct ImageId
  PressedImageComp* = distinct ImageId
  SpriteCanvas* = object
    sprites*: seq[SpriteId]
    rect*: IRect
  SavesRect* = distinct IRect

genTagTypesGlobal ButtonPressed, ButtonPressedTemporary, ContainerTag, Layout, 
  Hovered, TracksMouseReleaseEverywhere

genWorldGlobal GuiWorld:
  components:
    OnMousePress(ClickCallback) as onPress
    OnMouseRelease(ClickCallback) as onRelease
    OnMouseEnter(MouseAreaCallback) as onEnter
    OnMouseLeave(MouseAreaCallback) as onLeave
    OnMouseMove(MouseMoveCallback) as onMouseMove

    PreferredSize(Size) as preferredSize
    Alignable as align
    Padding(DirValues) as padding
    LinearLayoutGap(int) as gap
    PanelComp(Slice9Id) as panel
    AltPanelComp(Slice9Id) as altPanel
    TextSpec as text
    ImageComp(ImageId) as img
    PressedImageComp(ImageId) as pressedImg
    Orientation as orientation
    Direction as direction

    SpriteCanvas as canvas
    Collider as collider

    SliderComp as slider
    ProgressBarComp as progressBar
    SavesRect(IRect) as savedRect
  tags:
    Layout
    ContainerTag
    ButtonPressed (rare)
    ButtonPressedTemporary (rare)
    Hovered (rare)
    TracksMouseReleaseEverywhere
  filters:
    (PreferredSize, Alignable, Padding, LinearLayoutGap, Layout, Orientation) as LinearLayout
    (PreferredSize, Alignable, Padding, ContainerTag, PanelComp) as Panel
    (PreferredSize, Alignable, Padding, ContainerTag) as SimpleContainer
    (PreferredSize, Alignable, TextSpec) as Label
    Hovered as Hovered
    (Hovered, OnMousePress) as HoveredAndPress
    (Hovered, OnMouseRelease, not TracksMouseReleaseEverywhere) as HoveredAndRelease
    (OnMouseRelease, TracksMouseReleaseEverywhere) as ReleaseEverywhere
    OnMouseMove as OnMouseMove
    (PreferredSize, Padding, TextSpec, PanelComp, AltPanelComp) as TextButton
    (PreferredSize, ImageComp, PressedImageComp) as ImageButton
    (PreferredSize, SpriteCanvas, Layout, Alignable) as SpriteCamera
    (PreferredSize, Padding, ImageComp, PanelComp, SliderComp, SavesRect) as Slider
    (PreferredSize, Direction, PanelComp, AltPanelComp, ProgressBarComp) as ProgressBar

const
  LengthInfinite* = int.high
  LengthUndefined* = int.low

proc initDirValues*(v: int): DirValues {.inline.} =
  ## Creates the `DirValues` with all the directions being the same
  DirValues(top: v, bottom: v, left: v, right: v)
proc initDirValues*(h, v: int): DirValues {.inline.} =
  ## Creates the `DirValues` with the vertical and horizontal directions being differrent
  DirValues(top: v, bottom: v, left: h, right: h)
proc initDirValues*(t, r, b, l: int): DirValues {.inline.} =
  ## Creates the `DirValues` with all the directions being differrent
  DirValues(top: t, bottom: b, left: l, right: r)
const ZeroDirValues* = initDirValues(0) ## `DirValues` with all zeros

type
  GuiElementKind* = enum
    Leaf,
    Container
  GuiElement* = object
    ## Main `GuiElement` object.
    ## 
    ## It can either contain an owned reference to the ECS entity, meaning that once the
    ## `GuiElement` gets deleted, so will the entity, or an unowned reference.
    ## Owned references are similar to `unique_ptr` from C++, and are very useful if you create
    ## lots of `GuiElement`s without bothering to clean them up.
    ## Note that to use the owned `GuiElements` in the GUI you first have to disown them with the
    ## [disowned proc](helpers.html#disowned,GuiElement)
    ## 
    ## The `GuiElements` form a tree structure that is not contained in the ECS and must be built
    ## separately every frame.
    case isOwned*: bool:
    of true: eOwned*: OwnedEntityGuiWorld
    of false: eUnowned*: Entity[GuiWorld]

    case kind*: GuiElementKind:
    of Leaf: discard
    of Container: children*: seq[GuiElement]

proc `=destroy`(gui: var GuiElement) =
  if gui.isOwned:
    `=destroy`(gui.eOwned)
  if gui.kind == Container:
    for i in 0..<gui.children.len:
      `=destroy`(gui.children[i])

let gw* = newGuiWorld(entityMaxCount=1000) ## GUI ECS object.

proc add*(c: var GuiElement, gui: sink GuiElement) {.inline.} = 
  ## Adds a child to a `GuiElement`.
  c.children.add gui

proc strictConstraint*(w: int, h: int): Constraint {.inline.} =
  ## A strict constraint that says that the `GuiElement` must be *exactly* the specified size.
  Constraint(min: Size(w: w, h: h), max: Size(w: w, h: h))
proc looseConstraint*(w: int, h: int): Constraint {.inline.} =
  ## A loose constraint that says that the `GuiElement` must be the specified size *or less*.
  Constraint(min: Size(w: 0, h: 0), max: Size(w: w, h: h))
const NoConstraint* =
  Constraint(min: Size(w: 0, h: 0), max: Size(w: LengthInfinite, h: LengthInfinite))
  ## A constraint that allows the `GuiElement` to be whatever size it wants to be.

proc printCount*() {.inline.} = gw.printEntityCount()

proc setHovered*(resolution: MouseResolution) =
  ## Sets the `Hovered` tag for the `GuiElement` that is currently pointed to by the mouse.
  ## The `MouseResolution` can contain either a `GuiPrimitive` or a `Collider`.
  var eAdd: Entity[GuiWorld]

  case resolution.kind:
  of MouseResolutionKind.Primitive, MouseResolutionKind.Collider:
    let guiId = (
      if resolution.kind == Primitive:
        resolution.primitive.guiId
      else:
        resolution.collider)
    if guiId != -1:
      eAdd = Entity[GuiWorld](world: gw, id: guiId.EntityId)
      if eAdd.has Hovered: return

      if eAdd.has OnMouseEnter:
        (eAdd.onEnter)()
  of MouseResolutionKind.None: 
    eAdd = Entity[GuiWorld](world: nil, id: EntityId(-1))

  for eRemove in gw.queryHovered():
    eRemove.removeHovered()
    if eRemove.has OnMouseLeave:
      (eRemove.onLeave)()
  if eAdd.world != nil:
    eAdd.addHovered()

proc handleMousePress*(b: Button) =
  ## Handles mouse press (calls `onPress` if the hovered `GuiElement` has it)
  for e in gw.queryHoveredAndPress():
    (e.onPress)(b)

proc handleMouseRelease*(b: Button) =
  ## Handles mouse release (calls `onRelease` if the hovered `GuiElement` has it)
  for e in gw.queryHoveredAndRelease():
    (e.onRelease)(b)
  for e in gw.queryReleaseEverywhere():
    (e.onRelease)(b)

proc handleMouseMove*(pos: IVec2) =
  ## Handles mouse movement
  for e in gw.queryOnMouseMove():
    (e.onMouseMove)(pos)

proc saveAllRects*(e: GuiPrimitive, offset: IVec2 = ivec2(0, 0)) = 
  if e.kind == Group:
    for child in e.children:
      child.saveAllRects(offset + ivec2(e.rect.x.int32, e.rect.y.int32))
  if e.savesRect and e.guiId != -1:
    let gui = Entity[GuiWorld](world: gw, id: e.guiId.EntityId)
    if gui.has SavesRect:
      gui.savedRect = irect(e.rect.x + offset.x, e.rect.y + offset.y, e.rect.w, e.rect.h)
