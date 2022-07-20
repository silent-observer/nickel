## Module containing sprites data

import boxy, resources, vmath
import yaecs/pool

type
  Sprite* = object
    ## Sprite object. These objects are normally pooled, don't create them yourself
    key*: string
    x*, y*: int
  SpriteId* = PoolIndex

let spritePool = newPool[Sprite, 1000, 1000]()

proc drawSprite*(boxy: Boxy, sprite: Sprite) {.inline.} =
  boxy.drawImage(sprite.key, vec2(sprite.x.float32, sprite.y.float32))

proc newSprite*(key: ImageId, x: int, y: int): SpriteId {.inline.} =
  spritePool.add Sprite(key: key, x: x, y: y)
proc newSprite*(key: ImageId, pos: IVec2): SpriteId {.inline.} =
  spritePool.add Sprite(key: key, x: pos.x, y: pos.y)
proc newSprite*(ssKey: SpriteSheetId, index: int, x: int, y: int): SpriteId {.inline.} =
  spritePool.add Sprite(key: ssKey & "_" & $index, x: x, y: y)
proc newSprite*(ssKey: SpriteSheetId, index: int, pos: IVec2): SpriteId {.inline.} =
  spritePool.add Sprite(key: ssKey & "_" & $index, x: pos.x, y: pos.y)
proc clearSprites*() {.inline.} =
  ## Deletes all sprites from the pool.
  ## Is usually called at the start of each frame, since the sprites should be
  ## rerendered every frame.
  spritePool.clear()
proc get*(id: SpriteId): Sprite {.inline.} = spritePool[id]