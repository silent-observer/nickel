## **Nickel** is a miniature 2D game engine library, which is currently very much WIP.
## Everything described in the docs below can change in the future.
## 
## Nickel's recommended game architecture is basically an **MVVM**.
## *Model* part is entirely up to the game code, it contains all the game logic and everything that actually is going on in the game.
## *View* part is managed by the library. Inside the library there are two distinct representations for the View: the `GuiPrimitive` and `GuiElement`, both of them tree-like data structures.
## `GuiPrimitive`s are low-level: they contain the immediate positions at which every image and sprite has to be drawn. 
## `GuiElement`s, on the other hand, are high level: it's a collection of entities, contained in the ECS, which after Flutter-like layout procedure are transformed into `GuiPrimitive`s.
## *ViewModel* part is again up to the game code, but there are some helpful behaviours that are already defined in the library and can be easily used.

import nickel/[resources, sprite, animator, utils, tween, audio, gui, timer]
import nickel/gui/[ecs, primitives]
import boxy, windy, opengl
import std/monotimes, times, critbits
export resources, sprite, animator, utils, windy, tween, primitives, gui, chroma, audio, timer
export critbits.contains

type View* = seq[GuiPrimitive] ## \
  ## This is the result of the rendering that the game has to output at each frame.
type NickelObj = object
  generateView: proc(size: IVec2): View
  boxy: Boxy
  window: Window
  windowSize: IVec2
  lastView: View
  audio: AudioManager
type Nickel* = ref NickelObj ## Main game engine object.
type NickelConfig* = object
  ## Configuration for the game engine.
  resources*: string ## Resource configuration file path.
  windowSize*: IVec2 ## Starting size of the window.
  windowTitle*: string ## Title of the window.

proc newNickel*(c: NickelConfig): Nickel =
  ## Creates a new `Nickel` object with the given `NickelConfig`.
  new(result)
  result.window = newWindow(c.windowTitle, c.windowSize)
  makeContextCurrent(result.window)
  loadExtensions()
  result.boxy = newBoxy()
  loadResources(c.resources, result.boxy)
  result.audio = initAudioManager()

proc drawView(n: Nickel, v: View) =
  ## Draws the given `View` on the screen, starting a new frame.
  n.boxy.beginFrame(n.window.size)
  for g in v:
    n.boxy.drawGui(g)
    g.saveAllRects()

  n.boxy.endFrame()
  n.window.swapBuffers()

var lastFrame: MonoTime ## Timestamp of the last frame.
var prevMeasurement: MonoTime ## Timestamp of the last FPS measurement.
var fps = 0 ## FPS counter

proc registerProcs*(n: Nickel, generateView: proc(size: IVec2): View, 
    handleButton: proc(b: Button) = nil, printFps: bool = false) =
  ## Registers important game-related-procs in the `Nickel`.
  ## 
  ## `generateView`:
  ##    A proc that takes current window size (as `IVec2`) and has to return
  ##    a complete `View` (a collection of `GuiPrimitive`s).
  ##    It is called every frame to rerender the screen completely.
  ## `handleButton`:
  ##    A handler for the keyboard presses. When a key is pressed, this proc is called.
  ## `printFPS`:
  ##    A debug setting specifying if the engine should print FPS to the console or not.

  n.generateView = generateView
  n.window.onFrame = proc() =
    prepareGuiPrimitives()
    n.lastView = n.generateView(n.window.size)
    let 
      newTime = getMonoTime()
      delta = newTime - lastFrame
    n.drawView(n.lastView)
    let newHover = n.lastView.resolveMouse(n.window.mousePos)
    setHovered(newHover)
    handleMouseMove(n.window.mousePos)


    updateAnimations()
    updateTweens(delta)
    updateTimers(delta)
    lastFrame = newTime
    if printFps:
      fps.inc
      if newTime - prevMeasurement > initDuration(seconds=1):
        echo "FPS: ", fps
        #printCount()
        fps = 0
        prevMeasurement = newTime
  
  n.window.onButtonPress = proc(b: Button) =
    if b in {MouseLeft, MouseRight, MouseMiddle, MouseButton4, MouseButton5, 
              DoubleClick, TripleClick, QuadrupleClick}:
      handleMousePress(b)
    else:
      if handleButton != nil:
        handleButton(b)
  
  n.window.onButtonRelease = proc(b: Button) =
    if b in {MouseLeft, MouseRight, MouseMiddle, MouseButton4, MouseButton5, 
              DoubleClick, TripleClick, QuadrupleClick}:
      handleMouseRelease(b)

proc mainLoop*(n: Nickel) =
  ## Game main loop. Call this after initializing, and it will start the game.
  lastFrame = getMonoTime()
  prevMeasurement = getMonoTime()
  while not n.window.closeRequested:
    pollEvents()

template audio*(n: Nickel): AudioManager = n.audio ## Accessor for the Nickel's `AudioManager`.