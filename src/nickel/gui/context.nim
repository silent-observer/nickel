## GUI contexts.
## This allows you to not define every GUI element that has to preserve state globally, but
## instead simply create a context and then use it to store GUI elements inside it.
## It also automatically disowns the elements you take from it.
## 
## ..code-block:
##    let context = newContext()
##    
##    proc generateView(size: IVec2): View =
##      withContext context:
##        let btn = linearHor.add newGuiTextButton(
##            initText("Hello world!", "font", 20, color=color(1, 0, 0, 1)),
##            slice9="blue",
##            slice9Pressed= "blue_pressed",
##            padding=panelPadding
##          ).addToggleButton(proc (b: bool) =
##            echo "toggled ", b
##          ).stored("helloWorldBtn")
##        result = @[btn]

import critbits
import ecs, helpers

type GuiContext* = ref object
  guis: CritBitTree[GuiElement]

proc newContext*(): GuiContext {.inline.} = 
  ## Creates a new context
  new(result)

template withContext*(context: GuiContext, body: untyped): untyped =
  ## Allows you to use `context` as a context inside.
  ## While using this, a new template `stored` is defined inside the `body`.
  ## It takes a `GuiElement` to store in the context, and an `id`, which is a string.
  ## It then stores it inside the context if it wasn't stored there already, and returns its
  ## disowned copy.
  ## 
  ## You can also give it multiple arguments as parts of id, which will be joined with `_` between
  ## them, and if the arguments aren't strings, they'll be converted to strings with `$`.
  template stored(gui: GuiElement, ids: varargs[string, `$`]): GuiElement =
    let id = combineIds(ids)
    if id notin context.guis:
      context.guis[id] = gui
    context.guis[id].disowned
  body