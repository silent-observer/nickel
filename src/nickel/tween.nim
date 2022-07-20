## Tweening module.

import critbits, vmath, times, options, math
import utils

type
  TweenId* = string ## Each tweenable value is identified by a `TweenId`.
  TweenableValueKind* = enum
    Number,
    Vector2D,
    Vector3D
  TweenableValue* = object 
    ## A value that can be tweened. Currently floats and 2D/3D vectors are supported.
    case kind*: TweenableValueKind:
    of Number: number*: float
    of Vector2D: vector2*: Vec2
    of Vector3D: vector3*: Vec3
  TweenEasing* = enum ## Standard easing types.
    None ## Linear
    Sine,
    Quad,
    Cubic,
    Quart,
    Quint,
    Expo,
    Circ,
    Back,
    Elastic,
    Bounce,
  TweenEnds* = enum ## Which ends of the tween should be eased.
    In,
    Out,
    InOut,
  TweenCallback* = proc() ## Callback to be called after tween ends.
  TweenRequest* = object
    ## Request for a value to be tweened.
    to*: TweenableValue ## Target value
    duration*: Duration ## Duration of the tween
    easing*: TweenEasing ## Which easing should be applied
    easingEnds*: TweenEnds ## To what parts of the path should it be applied
    callback*: TweenCallback ## Callback to be called after tween ends
  Tween = object
    ## Data for a tween.
    current: TweenableValue
    tween: Option[TweenRequest]
    duration: Duration

var tweenRegistry: CritBitTree[Tween] ## Global registry for tweenable values

proc addTweenableNumber*(key: TweenId, number: float) {.inline.} =
  ## Creates a new tweenable number with a given TweenId.
  ## 
  ## **See also:**
  ## * [addTweenableVector2D proc](#addTweenableVector2D,TweenId,Vec2)
  ## * [addTweenableVector3D proc](#addTweenableVector3D,TweenId,Vec3)
  tweenRegistry[key] = Tween(current: TweenableValue(kind: Number, number: number), tween: none(TweenRequest))
proc addTweenableVector2D*(key: TweenId, vector2: Vec2) {.inline.} =
  ## Creates a new tweenable 2D vector with a given TweenId.
  ## 
  ## **See also:**
  ## * [addTweenableNumber proc](#addTweenableNumber,TweenId,float)
  ## * [addTweenableVector3D proc](#addTweenableVector3D,TweenId,Vec3)
  tweenRegistry[key] = Tween(current: TweenableValue(kind: Vector2D, vector2: vector2), tween: none(TweenRequest))
proc addTweenableVector3D*(key: TweenId, vector3: Vec3) {.inline.} =
  ## Creates a new tweenable 3D vector with a given TweenId.
  ## 
  ## **See also:**
  ## * [addTweenableNumber proc](#addTweenableNumber,TweenId,float)
  ## * [addTweenableVector2D proc](#addTweenableVector2D,TweenId,Vec2)
  tweenRegistry[key] = Tween(current: TweenableValue(kind: Vector3D, vector3: vector3), tween: none(TweenRequest))

proc easeOutBounce(x: float): float =
  ## Helper function for bounce easing
  const n1 = 7.5625;
  const d1 = 2.75;

  if x < 1 / d1:
      n1 * x * x;
  elif x < 2 / d1:
      n1 * (x - 1.5 / d1)^2 + 0.75
  elif x < 2.5 / d1:
      n1 * (x - 2.25 / d1)^2 + 0.9375
  else:
      n1 * (x - 2.625 / d1)^2 + 0.984375

proc tweenIn(t: float, easing: TweenEasing): float {.inline.} =
  ## Helper function for in-easing
  case easing:
    of None: t
    of Sine: 1 - cos((t * PI) / 2)
    of Quad: t^2
    of Cubic: t^3
    of Quart: t^4
    of Quint: t^5
    of Expo: (if t <= 0: 0.0 else: pow(2, 10 * t - 10))
    of Circ: 1 - sqrt(1 - t^2)
    of Back:
      const
        c1 = 1.70158
        c3 = c1 + 1
      c3 * t^3 - c1 * t^2
    of Elastic:
      const c4 = (2 * PI) / 3
      if t <= 0: 0.0
      elif t >= 1: 1.0
      else: -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * c4)
    of Bounce: 1 - easeOutBounce(1 - t)

proc tween*[T: float|Vec2|Vec3](start, finish: T, t: float, easing: TweenEasing, easingEnds: TweenEnds): T =
  ## A standalone tween function.
  ## It calculates a tweened value between `start` and `finish` with `t` between 0 and 1 with specified easings.
  let v = case easingEnds:
    of In: tweenIn(t, easing)
    of Out: 1 - tweenIn(1 - t, easing)
    of InOut: 
      if t < 0.5:
        tweenIn(2 * t, easing) / 2
      else:
        1 - tweenIn(2 - 2 * t, easing) / 2
  result = start * (1 - v) + finish * v

proc getTween[T: float|Vec2|Vec3](key: TweenId): T =
  ## Gets current tween value by its `TweenId`.
  let tw = tweenRegistry[key]
  if tw.tween.isNone:
    when T is float:
      result = tw.current.number
    when T is Vec2:
      result = tw.current.vector2
    when T is Vec3:
      result = tw.current.vector3
  else:
    let request = tw.tween.unsafeGet()
    let t = tw.duration.inNanoseconds.float / request.duration.inNanoseconds.float
    when T is float:
      result = tween(tw.current.number, request.to.number, t, request.easing, request.easingEnds)
    when T is Vec2:
      result = tween(tw.current.vector2, request.to.vector2, t, request.easing, request.easingEnds)
    when T is Vec3:
      result = tween(tw.current.vector3, request.to.vector3, t, request.easing, request.easingEnds)

proc checkKey(key: TweenId) {.inline.} =
  ## Checks if `TweenId` is registered.
  if key notin tweenRegistry:
    raise newException(NickelError, "There is no tweenable " & $key & "!")

proc getTweenNumber*(key: TweenId): float =
  ## Gets the current value of a number tween.
  checkKey(key)
  if tweenRegistry[key].current.kind != Number:
    raise newException(NickelError, "Tweenable " & $key & " isn't a number!")
  getTween[float](key)
proc getTweenVector2*(key: TweenId): Vec2 =
  ## Gets the current value of a Vec2 tween.
  checkKey(key)
  if tweenRegistry[key].current.kind != Vector2D:
    raise newException(NickelError, "Tweenable " & $key & " isn't a 2D vector!")
  getTween[Vec2](key)
proc getTweenVector3*(key: TweenId): Vec3 =
  ## Gets the current value of a Vec3 tween.
  checkKey(key)
  if tweenRegistry[key].current.kind != Vector3D:
    raise newException(NickelError, "Tweenable " & $key & " isn't a 3D vector!")
  getTween[Vec3](key)
proc getTweenValue*(key: TweenId): TweenableValue =
  ## Gets the current value of a tween as a `TweenableValue`.
  checkKey(key)
  case tweenRegistry[key].current.kind:
  of Number: TweenableValue(kind: Number, number: getTween[float](key))
  of Vector2D: TweenableValue(kind: Vector2D, vector2: getTween[Vec2](key))
  of Vector3D: TweenableValue(kind: Vector3D, vector3: getTween[Vec3](key))
proc isComplete*(key: TweenId): bool {.inline.} =
  checkKey(key)
  tweenRegistry[key].tween.isNone

proc updateTween(tween: var Tween, delta: Duration) =
  ## Update a tween
  if tween.tween.isNone: return
  let r = tween.tween.unsafeGet()
  tween.duration += delta
  if tween.duration >= r.duration:
    tween.current = r.to
    tween.tween = none(TweenRequest)
    tween.duration = DurationZero
    if r.callback != nil:
      r.callback()

proc updateTweens*(delta: Duration) =
  ## Updates all tween according to the `delta` duration, which is time that passed since last update.
  for tween in tweenRegistry.mvalues:
    updateTween(tween, delta)

proc requestTween*(key: TweenId, r: TweenRequest) =
  ## Requests a new tween for a tweenable value with given `TweenId`.
  ## 
  ## **See also:**
  ## * [requestTween proc](#requestTween,TweenId,TweenableValue,Duration,TweenEasing,TweenEnds,TweenCallback)
  ## * [requestTween proc](#requestTween,TweenId,T,Duration,TweenEasing,TweenEnds,TweenCallback)
  ## * [requestTweenWithSpeed proc](#requestTweenWithSpeed,TweenId,T,float,TweenEasing,TweenEnds,TweenCallback)
  checkKey(key)
  if tweenRegistry[key].current.kind != r.to.kind:
    raise newException(NickelError, "Tweenable type doesn't match!")
  if tweenRegistry[key].tween.isSome:
    tweenRegistry[key].current = getTweenValue(key)
  tweenRegistry[key].tween = some(r)
  tweenRegistry[key].duration = DurationZero
proc requestTween*(key: TweenId, to: TweenableValue, duration: Duration,
    easing: TweenEasing = None, easingEnds: TweenEnds = InOut, callback: TweenCallback = nil) {.inline.} =
  ## Requests a new tween for a tweenable value with given `TweenId`.
  ## 
  ## **See also:**
  ## * [requestTween proc](#requestTween,TweenId,TweenRequest)
  ## * [requestTween proc](#requestTween,TweenId,T,Duration,TweenEasing,TweenEnds,TweenCallback)
  ## * [requestTweenWithSpeed proc](#requestTweenWithSpeed,TweenId,T,float,TweenEasing,TweenEnds,TweenCallback)
  requestTween(key,
    TweenRequest(to: to, duration: duration, easing: easing, easingEnds: easingEnds, callback: callback))
proc requestTween*[T: float|Vec2|Vec3](key: TweenId, to: T, duration: Duration,
    easing: TweenEasing = None, easingEnds: TweenEnds = InOut, callback: TweenCallback = nil) {.inline.} =
  ## Requests a new tween for a tweenable value with given `TweenId`.
  ## 
  ## **See also:**
  ## * [requestTween proc](#requestTween,TweenId,TweenRequest)
  ## * [requestTween proc](#requestTween,TweenId,TweenableValue,Duration,TweenEasing,TweenEnds,TweenCallback)
  ## * [requestTweenWithSpeed proc](#requestTweenWithSpeed,TweenId,T,float,TweenEasing,TweenEnds,TweenCallback)
  when T is float:
    let v = TweenableValue(kind: Number, number: to)
  when T is Vec2:
    let v = TweenableValue(kind: Vector2D, vector2: to)
  when T is Vec3:
    let v = TweenableValue(kind: Vector3D, vector3: to)
  requestTween(key, v, duration, easing, easingEnds, callback)

proc requestTweenWithSpeed*[T: float|Vec2|Vec3](key: TweenId, to: T, speed: float,
    easing: TweenEasing = None, easingEnds: TweenEnds = InOut, callback: TweenCallback = nil) {.inline.} =
  ## Requests a new tween for a tweenable value with given `TweenId`.
  ## The duration is automatically calculated given the speed (given in units per second).
  ## 
  ## **See also:**
  ## * [requestTween proc](#requestTween,TweenId,TweenRequest)
  ## * [requestTween proc](#requestTween,TweenId,TweenableValue,Duration,TweenEasing,TweenEnds,TweenCallback)
  ## * [requestTween proc](#requestTween,TweenId,T,Duration,TweenEasing,TweenEnds,TweenCallback)
  let current = getTween[T](key)
  when T is float:
    let d = abs(current - to)
  when T is Vec2 or T is Vec3:
    let d = dist(current, to)
  let dur = initDuration(nanoseconds=int(d/speed * 1e9))
  requestTween(key, to, dur, easing, easingEnds, callback)

proc pixelPerfect*(f: float, pixelSize: int): int =
  ## Helper function for rounding to pixel grid.
  ## 
  ## **See also:**
  ## * [pixelPerfect proc](#pixelPerfect,Vec2,int)
  ## * [pixelPerfect proc](#pixelPerfect,Vec3,int)
  round(f / pixelSize.float).int * pixelSize
proc pixelPerfect*(f: Vec2, pixelSize: int): IVec2 =
  ## Helper function for rounding to pixel grid.
  ## 
  ## **See also:**
  ## * [pixelPerfect proc](#pixelPerfect,float,int)
  ## * [pixelPerfect proc](#pixelPerfect,Vec3,int)
  ivec2(f.x.pixelPerfect(pixelSize).int32, f.y.pixelPerfect(pixelSize).int32)
proc pixelPerfect*(f: Vec3, pixelSize: int): IVec3 =
  ## Helper function for rounding to pixel grid.
  ## 
  ## **See also:**
  ## * [pixelPerfect proc](#pixelPerfect,float,int)
  ## * [pixelPerfect proc](#pixelPerfect,Vec3,int)
  ivec3(f.x.pixelPerfect(pixelSize).int32, f.y.pixelPerfect(pixelSize).int32, f.z.pixelPerfect(pixelSize).int32)