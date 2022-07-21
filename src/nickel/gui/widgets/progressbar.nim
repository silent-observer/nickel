## Defines a progress bar.
## This progress bar can also be used as a health bar, or anything of that sort.

import ".."/[ecs, helpers, primitives]
import ".."/".."/[utils, resources]

proc newGuiProgressBar*(track: Slice9Id, filling: Slice9Id, direction: Direction, value: float; 
    height, width: int = LengthUndefined): GuiElement =
  ## Creates a progressbar
  let e = gw.newOwnedEntity()
  e.get.add direction
  case direction:
  of Left, Right:
    e.get.add Size(w: width, h: LengthUndefined).PreferredSize
  of Up, Down:
    e.get.add Size(w: LengthUndefined, h: height).PreferredSize
  e.get.add PanelComp(track)
  e.get.add AltPanelComp(filling)
  e.get.add ProgressBarComp(progress: value)
  GuiElement(isOwned: true, eOwned: e, kind: Leaf)

proc layoutProgressBar*(gui: GuiElement, c: Constraint): GuiPrimitive =
  ## Layouts a progress bar
  load preferredSize
  load direction
  load track, panel
  load filling, altPanel
  load progressBar

  case direction:
  of Left, Right:
    let w = if preferredSize.w == LengthUndefined: c.max.w else: preferredSize.w
    let trackHeight = track.getSlice9Resource.bottom + track.getSlice9Resource.top
    if trackHeight > c.max.h: return initGuiEmpty()

    let maskedWidth = (w.float * progressBar.progress).pixelPerfect(1)
    let maskedX = if direction == Right: 0 else: w - maskedWidth

    result = initGuiGroup(irect(0, 0, w, trackHeight), @[
      initGuiPanel(irect(0, 0, w, trackHeight), track),
      initGuiPanel(irect(0, 0, w, trackHeight), filling)
        .initGuiMasked(irect(maskedX, 0, maskedWidth, trackHeight))
    ])
  of Up, Down:
    let h = if preferredSize.h == LengthUndefined: c.max.h else: preferredSize.h
    let trackWidth = track.getSlice9Resource.left + track.getSlice9Resource.right
    if trackWidth > c.max.w: return initGuiEmpty()

    let maskedHeight = (h.float * progressBar.progress).pixelPerfect(1)
    let maskedY = if direction == Down: 0 else: h - maskedHeight

    result = initGuiGroup(irect(0, 0, trackWidth, h), @[
      initGuiPanel(irect(0, 0, trackWidth, h), track),
      initGuiPanel(irect(0, 0, trackWidth, h), filling)
        .initGuiMasked(irect(0, maskedY, trackWidth, maskedHeight))
    ])