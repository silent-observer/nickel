## This is a resource manager.
## 
## Resource file
## =============
## All resources are read from an external YAML file, which follows the structure of
## [ResourceConfig object](#ResourceConfig).
## An example YAML file is shown below:
## 
## .. code-block:: yaml
##    # path to the resource directory
##    resourceDir: path/to/resources
##    # default scaling factor (for pixel art)
##    defaultScaleUp: 3 
##    # list of all the fonts
##    fonts:
##      mainFont: font1.ttf
##      headerFont: font2.ttf
##    # list of all spritesheets
##    spriteSheets: 
##      # name of the spritesheet
##      spriteSheet1:
##        # its filename
##        imagePath: "spritesheet.png"
##        # width of each sprite
##        tileX: 32
##        # height of each sprite
##        tileY: 25
##        # number of sprites
##        count: 21
##        # override for scale up factor (usually not needed)
##        scaleUp: 6
##    # list of all slice-9s
##    slice9s:
##      # name of the slice-9
##      panel:
##        # its filename
##        imagePath: panel.png
##        # left border (in pixels)
##        left: 8
##        # right border (in pixels)
##        right: 8
##        # bottom border (in pixels)
##        bottom: 8
##        # top border (in pixels)
##        top: 8
##        # override for scale up factor (usually not needed)
##        scaleUp: 2
##      panelPressed: 
##        imagePath: panel_pressed.png
##        left: 8
##        right: 8
##        bottom: 8
##        top: 8
##        scaleUp: 2
##    # list of all images
##    images:
##      logo: logo.png
##    # list of all audio samples
##    audioSamples: 
##      beep: sample.wav
##    # list of all audio streams
##    audioStreams: 
##      bgm: background music.mp3

import pixie, critbits, tables, utils, yaml, streams, boxy
import solouddotnim
from os import `/`

type
  ResourceId* = string
  ImageId* = ResourceId
  FontId* = ResourceId
  SpriteSheetId* = ResourceId
  Slice9Id* = ResourceId
  AudioSampleId* = ResourceId
  AudioStreamId* = ResourceId

  SpriteSheet* = object
    ## Sprite sheet data
    image*: Image
    tileX*, tileY*: int
    countX*, countY*: int
    count*: int
  SpriteSheetSpec* = object
    ## Specification for the sprite sheet
    imagePath*: string ## Path to the image (from the resource directory)
    tileX*, tileY*: int ## Size of an individual sprite
    count*: int ## Number of sprites in the spritesheet
    scaleUp* {.defaultVal: 0.}: int ## Optional scale up factor for the pixel art
  
  Slice9* = object
    ## [Slice-9](https://en.wikipedia.org/wiki/9-slice_scaling) data
    image*: Image
    left*, right*, bottom*, top*: int
  Slice9Spec* = object
    ## Specification for the slice-9
    imagePath*: string ## Path to the image (from the resource directory)
    left*, right*, bottom*, top*: int ## Sizes of the slice-9 border sections
    scaleUp* {.defaultVal: 0.}: int ## Optional scale up factor for the pixel art

  AudioSample = object
    wav: ptr Wav
  AudioStream = object
    wav: ptr WavStream

  ResourceKind {.pure.} = enum
    Image,
    SpriteSheet,
    Slice9,
    Font,
    AudioSample,
    AudioStream
  Resource = object
    case kind: ResourceKind:
    of ResourceKind.Image: image: Image
    of ResourceKind.SpriteSheet: spritesheet: SpriteSheet
    of ResourceKind.Slice9: slice9: Slice9
    of ResourceKind.Font: font: Typeface
    of ResourceKind.AudioSample: audiosample: AudioSample
    of ResourceKind.AudioStream: audiostream: AudioStream

  ResourceConfig* = object
    ## Resource config, which is read from YAML resource file.
    resourceDir*: string ## Path to the resource directory
    defaultScaleUp* {.defaultVal: 1.}: int ## Default scale up factor
    
    images* {.defaultVal: initTable[ImageId, string]().}: Table[ImageId, string]
    ## Names and paths to the images (from the resource directory)
    fonts* {.defaultVal: initTable[FontId, string]().}: Table[FontId, string]
    ## Names and paths to the fonts (from the resource directory)
    spriteSheets* {.defaultVal: initTable[SpriteSheetId, SpriteSheetSpec]().}: 
      Table[SpriteSheetId, SpriteSheetSpec]
    ## Names and specifications for the spritesheets
    slice9s* {.defaultVal: initTable[Slice9Id, Slice9Spec]().}: Table[Slice9Id, Slice9Spec]
    ## Names and specifications for the slice-9s
    audioSamples* {.defaultVal: initTable[AudioSampleId, string]().}: Table[AudioSampleId, string]
    ## Names and paths to the audio samples (from the resource directory)
    audioStreams* {.defaultVal: initTable[AudioStreamId, string]().}: Table[AudioStreamId, string]
    ## Names and paths to the audio streams (from the resource directory)

proc `=destroy`(s: var AudioSample) =
  Wav_destroy(s.wav)
proc `=destroy`(s: var AudioStream) =
  WavStream_destroy(s.wav)
proc `=copy`(dest: var AudioSample, src: AudioSample) {.error.}
proc `=copy`(dest: var AudioStream, src: AudioStream) {.error.}

var images: CritBitTree[Image]
var spriteSheets: CritBitTree[SpriteSheet]
var slice9s: CritBitTree[Slice9]
var fonts: CritBitTree[Typeface]
var audioSamples: CritBitTree[AudioSample]
var audioStreams: CritBitTree[AudioStream]
var resourceRegistry : CritBitTree[Resource]
var resourceCfg: ResourceConfig

proc addSpriteSheet(boxy: Boxy, key: SpriteSheetId, ss: SpriteSheet) =
  for i in 0..<ss.count:
    let
      x = i mod ss.countX
      y = i div ss.countX
      subImg = ss.image.subImage(x * ss.tileX, y * ss.tileY, ss.tileX, ss.tileY)
    boxy.addImage(key & "_" & $i, subImg)

proc addSubImage(boxy: Boxy, key: string, image: Image; x, y, w, h: int) {.inline.} =
  if w > 0 and h > 0:
    boxy.addImage(key, image.subImage(x, y, w, h))

proc addSlice9(boxy: Boxy, key: Slice9Id, s9: Slice9) =
  let
    w = s9.image.width
    h = s9.image.height
    wc = w - s9.left - s9.right
    hc = h - s9.top - s9.bottom
  boxy.addSubImage(key & "_tl", s9.image, 0, 0, s9.left, s9.top)
  boxy.addSubImage(key & "_t", s9.image, s9.left, 0, wc, s9.top)
  boxy.addSubImage(key & "_tr", s9.image, w - s9.right, 0, s9.right, s9.top)
  boxy.addSubImage(key & "_l", s9.image, 0, s9.top, s9.left, hc)
  boxy.addSubImage(key & "_c", s9.image, s9.left, s9.top, wc, hc)
  boxy.addSubImage(key & "_r", s9.image, w - s9.right, s9.top, s9.right, hc)
  boxy.addSubImage(key & "_bl", s9.image, 0, h - s9.bottom, s9.left, s9.bottom)
  boxy.addSubImage(key & "_b", s9.image, s9.left, h - s9.bottom, wc, s9.bottom)
  boxy.addSubImage(key & "_br", s9.image, w - s9.right, h - s9.bottom, s9.right, s9.bottom)

proc loadImage(boxy: Boxy, key: ImageId, path: string, defaultScaleUp: int) {.inline.} =
  let image = readImage(path).integerScaleUp(defaultScaleUp)
  resourceRegistry[key] = Resource(
    kind: ResourceKind.Image,
    image: image
  )
  boxy.addImage(key, image)

proc loadSpriteSheet(boxy: Boxy, key: SpriteSheetId, spec: SpriteSheetSpec, 
    resourceDir: string, defaultScaleUp: int) {.inline.} =
  let scaleUp = if spec.scaleUp == 0: defaultScaleUp else: spec.scaleUp
  let image = readImage(resourceDir / spec.imagePath).integerScaleUp(scaleUp)
  let spriteSheet = SpriteSheet(
      image: image,
      tileX: spec.tileX * scaleUp, tileY: spec.tileY * scaleUp,
      countX: image.width div (spec.tileX * scaleUp),
      countY: image.height div (spec.tileY * scaleUp),
      count: spec.count
    )
  
  resourceRegistry[key] = Resource(
    kind: ResourceKind.SpriteSheet,
    spriteSheet: spriteSheet
  )
  boxy.addSpriteSheet(key, spriteSheet)

proc loadSlice9(boxy: Boxy, key: Slice9Id, spec: Slice9Spec, resourceDir: string,
    defaultScaleUp: int) {.inline.} =
  let scaleUp = if spec.scaleUp == 0: defaultScaleUp else: spec.scaleUp
  let image = readImage(resourceDir / spec.imagePath).integerScaleUp(scaleUp)
  let slice9 = Slice9(
    image: image,
    left: spec.left * scaleUp,
    right: spec.right * scaleUp,
    bottom: spec.bottom * scaleUp,
    top: spec.top * scaleUp,
  )
  resourceRegistry[key] = Resource(
    kind: ResourceKind.Slice9,
    slice9: slice9
  )
  boxy.addSlice9(key, slice9)

proc loadFont(key: FontId, path: string) {.inline.} =
  resourceRegistry[key] = Resource(
    kind: ResourceKind.Font,
    font: readTypeface(path)
  )

proc loadAudioSample(key: AudioSampleId, path: string) {.inline.} =
  let wav = Wav_create()
  echo Wav_load(wav, path)
  resourceRegistry[key] = Resource(
    kind: ResourceKind.AudioSample,
    audioSample: AudioSample(wav: wav)
  )
proc loadAudioStream*(key: AudioStreamId, path: string) {.inline.} =
  let wav = WavStream_create()
  echo WavStream_load(wav, path)
  resourceRegistry[key] = Resource(
    kind: ResourceKind.AudioStream,
    audioStream: AudioStream(wav: wav)
  )

proc loadResources*(cfg: ResourceConfig, boxy: Boxy) =
  ## Loads all the resources specified in the config
  resourceCfg = cfg
  for key, path in cfg.images:
    loadImage(boxy, key, cfg.resourceDir / path, cfg.defaultScaleUp)
  for key, path in cfg.fonts:
    loadFont(key, cfg.resourceDir / path)
  for key, spec in cfg.spriteSheets:
    loadSpriteSheet(boxy, key, spec, cfg.resourceDir, cfg.defaultScaleUp)
  for key, spec in cfg.slice9s:
    loadSlice9(boxy, key, spec, cfg.resourceDir, cfg.defaultScaleUp)
  for key, path in cfg.audioSamples:
    loadAudioSample(key, cfg.resourceDir / path)
  for key, path in cfg.audioStreams:
    loadAudioStream(key, cfg.resourceDir / path)

proc loadResources*(cfgPath: string, boxy: Boxy) =
  ## Loads all the resources specified in the config, which is read from the YAML file
  var cfg: ResourceConfig
  var s = openFileStream(cfgPath)
  load(s, cfg)
  s.close()
  loadResources(cfg, boxy)

proc getImageResource*(key: ImageId): Image {.inline.} = 
  ## Get an image resource
  resourceRegistry[key].image
proc getFontResource*(key: FontId): Typeface {.inline.} =
  ## Get a font resource
  resourceRegistry[key].font
proc getSpriteSheetResource*(key: SpriteSheetId): SpriteSheet {.inline.} =
  ## Get a spritesheet resource
  resourceRegistry[key].spriteSheet
proc getSlice9Resource*(key: Slice9Id): Slice9 {.inline.} =
  ## Get a slice-9 resource
  resourceRegistry[key].slice9
proc getAudioSampleResource*(key: AudioSampleId): ptr Wav {.inline.} =
  ## Get an audio sample resource
  resourceRegistry[key].audioSample.wav
proc getAudioStreamResource*(key: AudioStreamId): ptr WavStream {.inline.} =
  ## Get an audio stream resource
  resourceRegistry[key].audioStream.wav