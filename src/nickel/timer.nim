## Module for timers.

import times, critbits

type
  TimerCallback* = proc()
  TimerId* = string
  Timer* = object
    totalTime: Duration
    timeLeft: Duration
    callback: TimerCallback
    isLooping: bool

var timerRegistry: CritBitTree[Timer]
var timerCounter: uint64

proc generateTimerId(): TimerId =
  result = "_" & $timerCounter
  timerCounter.inc

proc newTimer*(id: TimerId, waitFor: Duration, callback: TimerCallback, isLooping: bool = false) =
  ## Creates a new timer. The `callback` will be called after the given time period.
  ## If the timer is looping, it will be called again and again until the timer is stopped.
  timerRegistry[id] = Timer(timeLeft: waitFor, totalTime: waitFor, callback: callback, isLooping: isLooping)

proc callDelayed*(callback: TimerCallback, waitFor: Duration) {.inline.} =
  ## Convenience proc for calling functions after some delay.
  newTimer(generateTimerId(), waitFor, callback)

template delay*(waitFor: Duration, code: untyped): untyped =
  ## Convenience template for running code after some delay.
  newTimer(generateTimerId(), waitFor, (proc() = code))

proc callLooping*(id: TimerId, callback: TimerCallback, period: Duration) {.inline.} =
  ## Convenience proc for starting a timer loop.
  newTimer(id, period, callback, isLooping=true)

template startLoop*(id: TimerId, period: Duration, code: untyped): untyped =
  ## Convenience templated for starting a timer loop out of arbitrary code.
  newTimer(generateTimerId(), waitFor, (proc() = code), isLooping = true)

proc stopTimer*(id: TimerId) {.inline.} =
  ## Stops a timer.
  timerRegistry.excl id

proc update(timer: var Timer, delta: Duration): bool =
  timer.timeLeft -= delta
  if timer.timeLeft < DurationZero:
    timer.callback()
    if timer.isLooping:
      timer.timeLeft += timer.totalTime
    else:
      return true # To delete timer

proc updateTimers*(delta: Duration) =
  ## Function to be called every frame to update the timers
  var deletionList: seq[TimerId]
  for id, timer in timerRegistry.mpairs:
    if timer.update(delta):
      deletionList.add id
  for id in deletionList:
    timerRegistry.excl id