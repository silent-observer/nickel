#import nimprof
import nickel, vmath, times, random, sugar
#from nickel/resources import SpriteSheetSpec

let n = newNickel(NickelConfig(
  resources: "tests/resources.yaml",
  windowSize: ivec2(1280, 800),
  windowTitle: "Slime"
))

addAnimator("slime")
"slime".addAnimation "idle", 0..3, 5, AnimationEnd.Loop
"slime".addAnimation "attack", 8..12, 5, AnimationEnd.ReturnToPrevious
"slime".addAnimation "hurt", 13..16, 5, AnimationEnd.ReturnToPrevious
"slime".addAnimation "die", 13..20, 5, AnimationEnd.NoExit
"slime".addTransition "idle", "attack", "attack", Immediate
"slime".addTransition "idle", "hurt", "hurt", Immediate
"slime".addTransition "idle", "die", "die", Immediate

let slimeAnims = addAnimatedEntities("slime", 4, "slime", "idle")
slimeAnims[0].setAnimationStep 0
slimeAnims[1].setAnimationStep 1
slimeAnims[2].setAnimationStep 2
slimeAnims[3].setAnimationStep 3

var pos = 300
var height = 200
var width = 150
addTweenableVector2D "slimePos_1", vec2(500, 300)
addTweenableVector2D "slimePos_2", vec2(600, 300)
addTweenableNumber "panelHeight", height.float
addTweenableNumber "panelWidth", width.float
addTweenableNumber "progressBar", 0

proc randomSlimeMove() =
  let 
    x = rand(0..<1000)
    y = rand(0..<700)
    newPos = vec2(x.float, y.float)
  "slimePos_2".requestTweenWithSpeed newPos, 200, callback=randomSlimeMove

proc progressBarMove() =
  const tweenDuration = initDuration(seconds=2)
  "progressBar".requestTween 1.0, tweenDuration, Quad, callback=proc() =
    "progressBar".requestTween 0.0, tweenDuration, Quad, callback=progressBarMove

const lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce viverra porttitor arcu eget auctor. Cras aliquet dictum dolor mollis pulvinar. Pellentesque rhoncus id sem ac vulputate. Nunc nisl nibh, cursus id blandit nec, rutrum in nisl. Nunc mattis tempus dolor, nec porta libero ullamcorper sed. Donec convallis non turpis eu gravida. Aenean interdum justo faucibus, laoreet augue ut, fringilla orci. Vivamus quis nisi dui."

let panelPadding = initDirValues(10, 10, 14, 10)

let slimeSpriteSheet = getSpriteSheetResource("slime")
let slimeSize = vec2(slimeSpriteSheet.tileX.float, slimeSpriteSheet.tileY.float)

let context = newContext()

proc generateView(size: IVec2): View =
  withContext context:
    let panelW = "panelWidth".getTweenNumber().pixelPerfect(2)
    var linearHor = newGuiLinearLayout(gap=10, vAlign=VCenter, orientation=Horizontal)
    # let linear = newGuiLinearLayout(gap=10, hAlign=HCenter)
    linearHor.add newGuiPanel(slice9 = "blue", padding=panelPadding, child=newGuiLabel(
        initText("Hello world!", "font")
      ))
    linearHor.add newGuiPanel(slice9 = "blue", padding=panelPadding, child=newGuiLabel(
        initText(lorem, "font", color=color(1, 0, 0, 1))
      ), width=panelW)
    linearHor.add newGuiTextButton(
        initText("Hello world!", "font", 20, color=color(1, 0, 0, 1)),
        slice9= "blue",
        slice9Pressed= "blue_pressed",
        padding=panelPadding
      ).addToggleButton(proc (b: bool) =
        echo "toggled ", b
      ).stored("helloWorldBtn")

    let slider1 = newGuiDiscreteSlider("track", "head", 5, initDirValues(8), width=200)
      .addDiscreteSliderBehaviour(proc(x: int) = echo x).stored("slider1")
    let slider2 = newGuiContinuousSlider("track", "head", initDirValues(8), width=200)
      .addContinuousSliderBehaviour(proc(x: float) = echo x).stored("slider2")

    var linearVer = newGuiLinearLayout(gap=10, hAlign=HCenter, orientation=Vertical)
    linearVer.add linearHor
    linearVer.add slider1
    linearVer.add slider2
    linearVer.add newGuiProgressBar("track", "progress", Right, "progressBar".getTweenNumber(), width=200)
    linearVer.add newGuiProgressBar("track", "progress", Left, "progressBar".getTweenNumber(), width=200)
    let gui = newGuiPanel(slice9= "green", padding=panelPadding, child=linearVer)
    
    clearSprites()
    var camera = newSpriteCamera(@[
        newSprite("slime", slimeAnims[0].getIndex(), 
          "slimePos_1".getTweenVector2().pixelPerfect(1)),
        newSprite("slime", slimeAnims[1].getIndex(), 
          "slimePos_2".getTweenVector2().pixelPerfect(1)),
        newSprite("slime", slimeAnims[2].getIndex(), 500, 400),
        newSprite("slime", slimeAnims[3].getIndex(), 600, 400)
      ], irect(0, 0, 1280, 800))

    var slimeColliders: seq[GuiElement]
    for i in 0..3:
      capture i:
        slimeColliders.add newCollider(vec2(0, 0), slimeSize).addBasicButton(proc() =
          slimeAnims[i].notifyAction "hurt"
        ).stored("slimeCollider", i)

    slimeColliders[0].updateColliderPosition "slimePos_1".getTweenVector2()
    slimeColliders[1].updateColliderPosition "slimePos_2".getTweenVector2()
    slimeColliders[2].updateColliderPosition vec2(500, 400)
    slimeColliders[3].updateColliderPosition vec2(600, 400)
    
    for c in slimeColliders:
      camera.add c.disowned

    result = @[
      camera.layout(looseConstraint(1280, 800)),
      gui.layout(looseConstraint(1000, 800)).adjust(300, 200)
    ]
  # echo result.gui
  # quit "end"

proc handleButton(button: Button) =
  case button:
    of KeyA:
      slimeAnims[0].notifyAction "attack"
    of KeyH:
      slimeAnims[1].notifyAction "hurt"
    of KeyD:
      slimeAnims[2].notifyAction "die"
    of KeyW: 
      pos -= 100
      height -= 50
      "slimePos_1".requestTweenWithSpeed vec2(500, pos.float), 200, Quad
      "panelHeight".requestTweenWithSpeed height.float, 200, Quad
    of KeyS:
      pos += 100
      height += 50
      "slimePos_1".requestTweenWithSpeed vec2(500, pos.float), 200, Quad
      "panelHeight".requestTweenWithSpeed height.float, 200, Quad
    of KeyLeft:
      width -= 20
      "panelWidth".requestTweenWithSpeed width.float, 200, Quad
    of KeyRight:
      width += 20
      "panelWidth".requestTweenWithSpeed width.float, 200, Quad
    of KeyP:
      n.audio.playSample("beep")
    of KeyT:
      delay initDuration(seconds=1):
        n.audio.playSample("beep")
    else:
      discard

# n.audio.fadeBackground("bgm")

n.registerProcs(generateView, handleButton)
randomSlimeMove()
progressBarMove()
n.mainLoop()