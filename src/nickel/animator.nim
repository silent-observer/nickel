## Finite State Machine-based animator module.

import critbits
from sequtils import toSeq
from strutils import join

type
  AnimationEnd* {.pure.} = enum ## What to do after the animation ends.
    NoExit, ## Stop the animation
    Loop, ## Loop it
    ReturnToPrevious, ## Return to the animation that was playing before
    GoTo ## Transition to a specific animation
  AnimationId* = string
  ActionId* = string
  AnimatedEntityId* = string
  AnimatorId* = string

  TransitionFlag* = enum ## Different flags for transitions.
    Immediate ## Transition without waiting for the current animation to end
    Interrupting ## Don't save the current animation as previous

  Transition* = object ## A transition between animations.
    flags: set[TransitionFlag]
    to: AnimationId

  Animation* = object ## `Animation` data (each animation is a state in the FSM).
    id: AnimationId
    indexes: seq[int]
    framesPerStep: int
    transitions: CritBitTree[Transition]
    case animEnd: AnimationEnd:
      of GoTo:
        goToState: AnimationId
      else:
        discard
  Animator* = CritBitTree[Animation]
  
  AnimatedEntity* = object ## An entity which can be animated.
    animator: AnimatorId
    currentAnim: AnimationId
    currentStep: int
    currentFrame: int
    pendingTransition: Transition
    previousAnimation: seq[AnimationId]
  AnimationRegistry = object
    entities: CritBitTree[AnimatedEntity]
    animators: CritBitTree[Animator]


const NoAnimation: AnimationId = ""

var registry: AnimationRegistry

proc getIndex*(id: AnimatedEntityId): int {.inline.} =
  ## Get current index (usually a sprite index in the spritesheet) for the entity.
  let
    entity = registry.entities[id]
    animation = registry.animators[entity.animator][entity.currentAnim]
  animation.indexes[entity.currentStep]

proc update(e: var AnimatedEntity) =
  ## Update one `AnimatedEntity`.
  let anim = registry.animators[e.animator][e.currentAnim]
  if (e.currentStep == anim.indexes.len - 1 and
      e.currentFrame == anim.framesPerStep - 1) or
      (e.pendingTransition.to != NoAnimation and
      Immediate in e.pendingTransition.flags):
    if e.pendingTransition.to != NoAnimation:
      if Interrupting notin e.pendingTransition.flags:
        e.previousAnimation.add e.currentAnim
      e.currentAnim = e.pendingTransition.to
      e.pendingTransition.to = NoAnimation
      e.pendingTransition.flags = {}
      e.currentStep = 0
      e.currentFrame = 0
    else:
      case anim.animEnd:
        of AnimationEnd.NoExit: discard
        of AnimationEnd.Loop:
          e.currentStep = 0
          e.currentFrame = 0
        of AnimationEnd.ReturnToPrevious:
          if e.previousAnimation.len != 0:
            e.currentAnim = e.previousAnimation.pop()
            e.currentStep = 0
            e.currentFrame = 0
        of AnimationEnd.GoTo:
          e.previousAnimation.add e.currentAnim
          e.currentAnim = anim.goToState
          e.currentStep = 0
          e.currentFrame = 0
  else:
    e.currentFrame.inc()
    if e.currentFrame == anim.framesPerStep:
      e.currentFrame = 0
      e.currentStep.inc()
proc notifyAction*(id: AnimatedEntityId, action: ActionId) =
  ## Send a message (an `Action`) to the `AnimatedEntity`.
  ## That might trigger a state transition.
  let
    entity = registry.entities[id]
    anim = registry.animators[entity.animator][entity.currentAnim]
  if action in anim.transitions:
    registry.entities[id].pendingTransition = anim.transitions[action]

proc updateAnimations*() =
  ## Update all the animations.
  ## Should be called once per frame.
  for anim in registry.entities.mvalues:
    anim.update()

proc addAnimator*(id: AnimatorId) {.inline.} =
  ## Register a new `Animator`.
  registry.animators[id] = Animator()
proc addAnimation*(id: AnimatorId, anim: AnimationId, 
    indexes: openArray[int], framesPerStep: int, animEnd: AnimationEnd) =
  ## Add an animation to the animator.
  ## 
  ## `id`:
  ##    The animator you are adding the animation to.
  ## `anim`:
  ##    Name of the animation.
  ## `indexes`:
  ##    Which sprites (indexes) should the animation contain and in what order.
  ## `framesPerStep`:
  ##    How many frames should pass for every step in the animation.
  ## `animEnd`:
  ##    What to do after the animation ends.
  ## 
  ## **See also:**
  ## * [addAnimation proc](#addAnimation,AnimatorId,AnimationId,HSlice[H,U],int,AnimationEnd)
  registry.animators[id][anim] = Animation(
    id: anim,
    indexes: @indexes,
    framesPerStep: framesPerStep,
    animEnd: animEnd
  )
proc addAnimation*[H, U: Ordinal](id: AnimatorId, anim: AnimationId, 
    indexes: HSlice[H, U], framesPerStep: int, animEnd: AnimationEnd) {.inline.} =
  ## A version of [addAnimation proc](#addAnimation,AnimatorId,AnimationId,openArray[int],int,AnimationEnd)
  ## where you specify a range instead of a sequence of indexes.
  addAnimation(id, anim, indexes.toSeq(), framesPerStep, animEnd)

proc setGoTo*(id: AnimatorId, fromAnim, toAnim: AnimationId) {.inline.} =
  ## Sets the animation (`toAnim`) to which the `fromAnim` should transition after it ends.
  ## Is only valid if `fromAnim`'s `animEnd` was set to `AnimationEnd.GoTo`.
  if registry.animators[id][fromAnim].animEnd == AnimationEnd.GoTo:
    registry.animators[id][fromAnim].goToState = toAnim
proc addTransition*(id: AnimatorId, fromAnim, toAnim: AnimationId, action: ActionId, flags: set[TransitionFlag] = {}) {.inline.} =
  ## Adds a new transition to the animation.
  ## 
  ## `id`:
  ##    Animator in question.
  ## `fromAnim`:
  ##    Animation, from which the transition will happen
  ## `toAnim`:
  ##    Animation, to which the transition will happen
  ## `action`:
  ##    Action, in response to which the transition happens
  ##    (see [notifyAction proc](#notifyAction,AnimatedEntityId,ActionId))
  ## `flags`:
  ##    Additional flags
  registry.animators[id][fromAnim].transitions[action] = Transition(to: toAnim, flags: flags)
proc addTransition*(id: AnimatorId, fromAnim, toAnim: AnimationId, action: ActionId, flag: TransitionFlag) {.inline.} =
  ## Version of [addTransition](#addTransition,AnimatorId,AnimationId,AnimationId,ActionId,set[TransitionFlag])
  ## that takes only a single flags.
  addTransition(id, fromAnim, toAnim, action, {flag})
proc addAnimatedEntity*(id: AnimatedEntityId, animator: AnimatorId, startAnim: AnimationId) =
  ## Creates a new animated entity with a given `id`, specifies its animator and the initial
  ## animation it starts from.
  registry.entities[id] = AnimatedEntity(
    animator: animator,
    currentAnim: startAnim,
    currentStep: 0,
    currentFrame: 0,
    pendingTransition: Transition(to: NoAnimation, flags: {}),
    previousAnimation: @[],
  )
proc delete*(id: AnimatedEntityId) {.inline.} =
  ## Deletes the animated entity.
  registry.entities.excl id

proc setAnimationStep*(id: AnimatedEntityId, step: int) {.inline.} =
  ## Sets the animation step in the current animation.
  ## Could be used to make the animation immediately end, or to desyncronize the animations of
  ## multiple entities.
  registry.entities[id].currentStep = step

var animatedEntityCounter: CritBitTree[uint64]
proc newArrayId*(base: AnimatedEntityId): AnimatedEntityId {.inline.} =
  ## Helper proc for generating ids for dynamically created entities (such as monsters etc).
  ## For each call it simply generates a new id based on the given one by adding a number to it.
  ## The numbers for each "array base" are always increasing and are never reused.
  ## 
  ## **See also:**
  ## * [restartArrayId proc](#restartArrayId,AnimatedEntityId)
  if base notin animatedEntityCounter:
    animatedEntityCounter[base] = 1
  result = base & "_" & $animatedEntityCounter[base]
  animatedEntityCounter[base].inc
proc restartArrayId*(base: AnimatedEntityId) {.inline.} =
  ## Is used to restart the array counter for the [newArrayId proc](#newArrayId,AnimatedEntityId).
  ## Use this only if you are sure that there are no entities with these ids left
  ## (like after calling [deleteAll proc](#deleteAll,AnimatedEntityId)).
  ## 
  ## **See also:**
  ## * [newArrayId proc](#newArrayId,AnimatedEntityId)
  animatedEntityCounter[base] = 1
proc combineIds*(ids: varargs[string]): string {.inline.} =
  ## Helper function to combine multiple ids.
  ## Useful in conjunction with [deleteAll proc](#deleteAll,AnimatedEntityId).
  ids.join("_")

proc addAnimatedEntities*(base: AnimatedEntityId, count: int, animator: AnimatorId, startAnim: AnimationId): seq[AnimatedEntityId] {.inline.} =
  ## Creates multiple animated entities at once, assigning their ids using [newArrayId](#newArrayId,AnimatedEntityId).
  ## Returns the ids of created entities.
  for i in 1..count:
    let id = base.newArrayId()
    result.add id
    addAnimatedEntity(id, animator, startAnim)
proc deleteAll*(base: AnimatedEntityId) {.inline.} =
  ## Delete all the entities generated with a prefix
  ## 
  ## **See also:**
  ## * [newArrayId proc](#newArrayId,AnimatedEntityId)
  ## * [restartArrayId proc](#restartArrayId,AnimatedEntityId)
  ## * [combineIds proc](#combineIds,varargs[string])
  ## * [addAnimatedEntities proc](#addAnimatedEntities,AnimatedEntityId,int,AnimatorId,AnimationId)
  let allKeys = toSeq(animatedEntityCounter.keysWithPrefix(base & "_"))
  for key in allKeys:
    registry.entities.excl key