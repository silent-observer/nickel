import deques

type EventQueue*[T] = object
  ## Helper object for defining event queues (useful for communication between Model and ViewModel)
  q: Deque[T]

proc add*[T](q: var EventQueue[T], e: sink T) {.inline.} =
  ## Add event to `EventQueue`
  q.q.addLast e
proc pop*[T](q: var EventQueue[T]): T {.inline.} =
  ## Pop one event from `EventQueue`
  q.q.popFirst()
proc add*[T](q: var EventQueue[T], events: sink openArray[T]) {.inline.} =
  ## Add multiple events to `EventQueue`
  for e in events:
    q.q.addLast e
proc initEventQueue*[T](): EventQueue[T] {.inline.} =
  ## Initialize `EventQueue`
  result.q = initDeque[T]()
proc empty*[T](q: EventQueue[T]): bool {.inline.} =
  ## Check if `EventQueue` is empty
  q.q.len == 0