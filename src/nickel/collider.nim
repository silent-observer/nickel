import bumpy, vmath

type
  ColliderKind* {.pure.} = enum
    Circle,
    Rect,
    Polygon
  Collider* = object
    ## Collider (for mouse resolution for sprites)
    case kind*: ColliderKind:
    of ColliderKind.Circle: circle*: Circle
    of ColliderKind.Rect: rect*: Rect
    of ColliderKind.Polygon: polygon*: Polygon

proc inside*(p: Vec2, c: Collider): bool =
  ## Check if the point is inside the collider
  case c.kind:
  of ColliderKind.Circle: overlaps(p, c.circle)
  of ColliderKind.Rect: overlaps(p, c.rect)
  of ColliderKind.Polygon: overlaps(p, c.polygon)

proc initCollider*(center: Vec2, radius: float): Collider {.inline.} =
  ## Create a circle collider
  Collider(kind: ColliderKind.Circle, circle: circle(center, radius))
proc initCollider*(x, y, w, h: float): Collider {.inline.} =
  ## Create a rectangle collider
  Collider(kind: ColliderKind.Rect, rect: rect(x, y, w, h))
proc initCollider*(pos, size: Vec2): Collider {.inline.} =
  ## Create a rectangle collider
  Collider(kind: ColliderKind.Rect, rect: rect(pos, size))
proc initCollider*(poly: seq[Vec2]): Collider {.inline.} =
  ## Create a polygon collider
  Collider(kind: ColliderKind.Polygon, polygon: poly)