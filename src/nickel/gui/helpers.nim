import ".."/gui/ecs
import ".."/utils
import yaecs
from pixie import HorizontalAlignment

template getSize*(r: IRect): Size = Size(w: r.w, h: r.h) ## Convert `IRect` to `Size`
template clamp0*(x: int): int = max(x, 0) ## Clamp negatives to 0
template swap*(s: Size): Size = Size(w: s.h, h: s.w) ## Swap x and y axes
template swap*(r: IRect): IRect = IRect(x: r.y, y: r.x, w: r.h, h: r.w) ## Swap x and y axes
template swap*(d: DirValues): DirValues = 
  ## Swap x and y axes
  DirValues(top: d.left, bottom: d.right, left: d.top, right: d.bottom)
template swap*(c: Constraint): Constraint = 
  ## Swap x and y axes
  Constraint(min: c.min.swap(), max: c.max.swap())
template swap*(a: VAlign): HAlign = 
  ## Swap x and y axes
  case a:
  of VTop: HLeft
  of VCenter: HCenter
  of VBottom: HRight
template swap*(a: HAlign): VAlign = 
  ## Swap x and y axes
  case a:
  of HLeft: VTop
  of HCenter: VCenter
  of HRight: VBottom
template convert*(a: HAlign): HorizontalAlignment = 
  ## Convert Nickel's `HAlign` to Pixie's `HorizontalAlignment`
  case a:
  of HLeft: LeftAlign
  of HCenter: CenterAlign
  of HRight: RightAlign


proc subtractPadding*(c: Constraint, padding: DirValues): Constraint {.inline.} =
  ## Subtract paddings from constraint
  let
    hPad = padding.left + padding.right
    vPad = padding.top + padding.bottom
  Constraint(
    min: Size(w: clamp0(c.min.w - hPad), h: clamp0(c.min.h - vPad)),
    max: Size(w: clamp0(c.max.w - hPad), h: clamp0(c.max.h - vPad))
  )
proc subtractPadding*(s: Size, padding: DirValues): Size {.inline.} =
  ## Subtract paddings from size
  let
    hPad = padding.left + padding.right
    vPad = padding.top + padding.bottom
  Size(w: clamp0(s.w - hPad), h: clamp0(s.h - vPad))
proc addPadding*(s: Size, padding: DirValues): Size {.inline.} =
  ## Add paddings to size
  let
    hPad = padding.left + padding.right
    vPad = padding.top + padding.bottom
  Size(w: s.w + hPad, h: s.h + vPad)

proc noMin*(c: Constraint): Constraint {.inline.} =
  ## Make a constraint loose
  Constraint(min: Size(w: 0, h: 0), max: c.max)
proc fitConstraint*(size: Size, c: Constraint): Size {.inline.} =
  ## Make `Size` fit the `Constraint`
  Size(
    w: clamp(size.w, c.min.w, c.max.w),
    h: clamp(size.h, c.min.h, c.max.h)
  )
proc fitPreferred*(size: Size, preferred: Size): Size {.inline.} =
  ## Adjust size according to preferred size
  result = size
  if preferred.w != LengthUndefined and result.w < preferred.w:
    result.w = preferred.w
  if preferred.h != LengthUndefined and result.h < preferred.h:
    result.h = preferred.h
proc fitPreferred*(c: Constraint, preferred: Size): Constraint {.inline.} =
  ## Adjust constraint according to preferred size
  result = c
  if preferred.w != LengthUndefined and result.max.w > preferred.w:
    result.max.w = preferred.w
  if preferred.h != LengthUndefined and result.max.h > preferred.h:
    result.max.h = preferred.h
proc alignHorizontal*(child: var IRect, parentSize: Size, hAlign: HAlign) =
  ## Adjust rectangle according to parent element size and horizontal alignment
  case hAlign:
  of HLeft: discard
  of HCenter: child.x = (parentSize.w - child.w) div 2
  of HRight: child.x = parentSize.w - child.w
proc alignVertical*(child: var IRect, parentSize: Size, vAlign: VAlign) =
  ## Adjust rectangle according to parent element size and vertical alignment
  case vAlign:
  of VTop: discard
  of VCenter: child.y = (parentSize.h - child.h) div 2
  of VBottom: child.y = parentSize.h - child.h

template e*(gui: GuiElement): Entity[GuiWorld] =
  ## Access internal unowned entity
  if gui.isOwned: gui.eOwned.get
  else: gui.eUnowned
template load*(field: untyped) =
  ## Load component from `GuiElement`
  let field = gui.e.field
template load*(name: untyped, field: untyped) =
  ## Load component from `GuiElement` into a variable with a given name
  let name = gui.e.field
proc disowned*(gui: GuiElement): GuiElement =
  ## Get an unowned copy of a `GuiElement`
  result = GuiElement(isOwned: false, eUnowned: gui.e, kind: gui.kind)
  if gui.kind == Container:
    result.children = newSeqOfCap[GuiElement](gui.children.len)
    for i in 0..<gui.children.len:
      result.children.add gui.children[i].disowned

proc isPressed*(gui: GuiElement): bool {.inline.} =
  ## Check if a button is pressed
  gui.e.has ButtonPressed