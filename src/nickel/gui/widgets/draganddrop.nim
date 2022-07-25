import ".."/[ecs, helpers, primitives]
import ".."/".."/gui
import options
import vmath
from windy import Button

var lastDragPos = ivec2(0, 0)

proc addDragAndDropPlace*(gui: sink GuiElement, id: string, 
    onMove: proc(start, finish: string) = nil, onDrag: proc(start: string) = nil): GuiElement =
  result = gui

  let entity = result.e

  entity.add DragAndDropPlace(
    placeId: id,
    onMove: onMove,
    hasDraggable: false,
    draggablePos: none(IVec2)
  )
  entity.addTracksMouseReleaseEverywhere()
  entity.add OnMousePress(proc (b: Button) =
    let dnd = entity.dnd
    if dnd.hasDraggable and not (entity.has OnMouseRelease):
      if onDrag != nil:
        onDrag(dnd.placeId)
      entity.add OnMouseMove(proc (p: IVec2) =
        entity.dnd.draggablePos = some(p)
      )
      entity.add OnMouseRelease(proc(b: Button) =
        entity.removeOnMouseMove()
        entity.removeOnMouseRelease()
        lastDragPos = entity.dnd.draggablePos.get
        entity.dnd.draggablePos = none(IVec2)
        var movedToSomewhere = false
        for place in gw.queryHoveredDnD():
          if dnd.placeId != place.dnd.placeId and onMove != nil:
            onMove(dnd.placeId, place.dnd.placeId)
            movedToSomewhere = true
        if not movedToSomewhere and onMove != nil:
          onMove(dnd.placeId, "")
      )
  )

proc `hasDraggable=`*(gui: GuiElement, val: bool) =
  gui.e.dnd.hasDraggable = val

proc getDragAndDropPos*(gui: GuiElement): Option[IVec2] =
  load dnd
  dnd.draggablePos

proc placeInDragAndDrop*(item: sink GuiElement, place: var GuiElement, 
    dragLayer: var seq[GuiPrimitive]) =
  place.hasDraggable = true
  if place.getDragAndDropPos.isSome:
    dragLayer.add item.layout(NoConstraint).centerAt(place.getDragAndDropPos.get)
  else:
    place.add item

proc getLastDragPos*(): IVec2 {.inline.} = lastDragPos