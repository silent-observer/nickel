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
import sets
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

  ResourceKind* {.pure.} = enum
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
  ResourceSpec = object
    case kind: ResourceKind:
    of ResourceKind.Image, ResourceKind.Font,
       ResourceKind.AudioSample, ResourceKind.AudioStream: 
        path: string
    of ResourceKind.SpriteSheet: 
      spritesheet: SpriteSheetSpec
    of ResourceKind.Slice9: 
      slice9: Slice9Spec
  ResourcePackage = HashSet[ResourceId]

when defined(nimsuggest):
  type
    ResourceConfig* = object
      resourceDir*: string
      defaultScaleUp*: int
      
      images*: Table[ImageId, string]
      fonts*: Table[FontId, string]
      spriteSheets*: Table[SpriteSheetId, SpriteSheetSpec]
      slice9s*: Table[Slice9Id, Slice9Spec]
      audioSamples*: Table[AudioSampleId, string]
      audioStreams*: Table[AudioStreamId, string]
      packages*: Table[ResourceId, seq[string]]
else:
  type
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
      ## Names and contents of resource packages (to be loaded at once)
      packages* {.defaultVal: initTable[ResourceId, seq[string]]().}: Table[ResourceId, seq[string]]

proc `=destroy`(s: var AudioSample) =
  Wav_destroy(s.wav)
proc `=destroy`(s: var AudioStream) =
  WavStream_destroy(s.wav)
proc `=copy`(dest: var AudioSample, src: AudioSample) {.error.}
proc `=copy`(dest: var AudioStream, src: AudioStream) {.error.}

var resourceStorage : CritBitTree[Resource]
var resourceRegistry : CritBitTree[ResourceSpec]
var resourcePackages : CritBitTree[ResourcePackage]
var currentlyLoadedResources = initHashSet[ResourceId]()
var resourceCfg: ResourceConfig

proc addSpriteSheet(boxy: Boxy, key: SpriteSheetId, ss: SpriteSheet) =
  for i in 0..<ss.count:
    let
      x = i mod ss.countX
      y = i div ss.countX
      subImg = ss.image.subImage(x * ss.tileX, y * ss.tileY, ss.tileX, ss.tileY)
    boxy.addImage(key & "_" & $i, subImg)

proc removeSpriteSheet(boxy: Boxy, key: SpriteSheetId) =
  let ss = resourceStorage[key].spritesheet
  for i in 0..<ss.count:
    boxy.removeImage(key & "_" & $i)

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

proc removeSlice9(boxy: Boxy, key: SpriteSheetId) =
  for k in ["tl", "t", "tr", "l", "c", "r", "bl", "b", "br"]:
    boxy.removeImage(key & "_" & k)

proc loadImage(boxy: Boxy, key: ImageId, path: string, defaultScaleUp: int) {.inline.} =
  let image = readImage(path).integerScaleUp(defaultScaleUp)
  resourceStorage[key] = Resource(
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
  
  resourceStorage[key] = Resource(
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
  resourceStorage[key] = Resource(
    kind: ResourceKind.Slice9,
    slice9: slice9
  )
  boxy.addSlice9(key, slice9)

proc loadFont(key: FontId, path: string) {.inline.} =
  resourceStorage[key] = Resource(
    kind: ResourceKind.Font,
    font: readTypeface(path)
  )

proc loadAudioSample(key: AudioSampleId, path: string) {.inline.} =
  let wav = Wav_create()
  echo Wav_load(wav, path)
  resourceStorage[key] = Resource(
    kind: ResourceKind.AudioSample,
    audioSample: AudioSample(wav: wav)
  )
proc loadAudioStream(key: AudioStreamId, path: string) {.inline.} =
  let wav = WavStream_create()
  echo WavStream_load(wav, path)
  resourceStorage[key] = Resource(
    kind: ResourceKind.AudioStream,
    audioStream: AudioStream(wav: wav)
  )

proc loadResource*(boxy: Boxy, key: ResourceId) =
  ## Loads the resource
  if key notin currentlyLoadedResources:
    let spec = resourceRegistry[key]
    case spec.kind:
    of ResourceKind.Image:
      loadImage(boxy, key, resourceCfg.resourceDir / spec.path, resourceCfg.defaultScaleUp)
    of ResourceKind.Font:
      loadFont(key, resourceCfg.resourceDir / spec.path)
    of ResourceKind.SpriteSheet:
      loadSpriteSheet(boxy, key, spec.spriteSheet, resourceCfg.resourceDir, resourceCfg.defaultScaleUp)
    of ResourceKind.Slice9:
      loadSlice9(boxy, key, spec.slice9, resourceCfg.resourceDir, resourceCfg.defaultScaleUp)
    of ResourceKind.AudioSample:
      loadAudioSample(key, resourceCfg.resourceDir / spec.path)
    of ResourceKind.AudioStream:
      loadAudioStream(key, resourceCfg.resourceDir / spec.path)
    currentlyLoadedResources.incl key

proc unloadResource*(boxy: Boxy, key: ResourceId) =
  if key in currentlyLoadedResources:
    case resourceRegistry[key].kind:
    of ResourceKind.Image: boxy.removeImage(key)
    of ResourceKind.SpriteSheet: boxy.removeSpriteSheet(key)
    of ResourceKind.Slice9: boxy.removeSlice9(key)
    else: discard
    resourceStorage.excl key
    currentlyLoadedResources.excl key

proc registerPackage(cfg: ResourceConfig, key: ResourceId, path: seq[ResourceId] = @[]) =
  if key in resourcePackages: return
  if key in path:
    raise newException(NickelDefect, "Cyclic dependency in resource package " & key & "!")
  let newPath = path & @[key]
  var newPackage = initHashSet[ResourceId]()
  for id in cfg.packages[key]:
    if id in resourceRegistry:
      newPackage.incl id
    else:
      cfg.registerPackage(id, newPath)
      newPackage.incl resourcePackages[id]
  resourcePackages[key] = newPackage

proc loadPackage*(boxy: Boxy, key: ResourceId, removeOthers = true) =
  var targetSet = resourcePackages[key]
  if not removeOthers:
    targetSet.incl currentlyLoadedResources
  for r in (currentlyLoadedResources - targetSet):
    boxy.unloadResource(r)
  for r in (targetSet - currentlyLoadedResources):
    boxy.loadResource(r)

proc registerResources*(cfg: ResourceConfig) =
  ## Registers all the resources specified in the config
  resourceCfg = cfg
  resourcePackages["all"] = initHashSet[ResourceId]()

  for key, path in cfg.images:
    resourceRegistry[key] = ResourceSpec(kind: ResourceKind.Image, path: path)
    resourcePackages["all"].incl key
  for key, path in cfg.fonts:
    resourceRegistry[key] = ResourceSpec(kind: ResourceKind.Font, path: path)
    resourcePackages["all"].incl key
  for key, spec in cfg.spriteSheets:
    resourceRegistry[key] = ResourceSpec(kind: ResourceKind.SpriteSheet, spriteSheet: spec)
    resourcePackages["all"].incl key
  for key, spec in cfg.slice9s:
    resourceRegistry[key] = ResourceSpec(kind: ResourceKind.Slice9, slice9: spec)
    resourcePackages["all"].incl key
  for key, path in cfg.audioSamples:
    resourceRegistry[key] = ResourceSpec(kind: ResourceKind.AudioSample, path: path)
    resourcePackages["all"].incl key
  for key, path in cfg.audioStreams:
    resourceRegistry[key] = ResourceSpec(kind: ResourceKind.AudioStream, path: path)
    resourcePackages["all"].incl key
  for key in cfg.packages.keys:
    cfg.registerPackage(key)

proc registerResources*(cfgPath: string) =
  ## Registers all the resources specified in the config, which is read from the YAML file
  var cfg: ResourceConfig
  var s = openFileStream(cfgPath)
  load(s, cfg)
  s.close()
  registerResources(cfg)

proc getImageResource*(key: ImageId): Image {.inline.} = 
  ## Get an image resource
  resourceStorage[key].image
proc getImageSize*(key: ImageId): Size {.inline.} = 
  ## Get an image resource's size
  Size(w: resourceStorage[key].image.width, h: resourceStorage[key].image.height)
proc getFontResource*(key: FontId): Typeface {.inline.} =
  ## Get a font resource
  resourceStorage[key].font
proc getSpriteSheetResource*(key: SpriteSheetId): SpriteSheet {.inline.} =
  ## Get a spritesheet resource
  resourceStorage[key].spriteSheet
proc getSpriteSize*(key: SpriteSheetId): Size {.inline.} = 
  ## Get an image resource's size
  Size(w: resourceStorage[key].spriteSheet.tileX, h: resourceStorage[key].spriteSheet.tileY)
proc getSlice9Resource*(key: Slice9Id): Slice9 {.inline.} =
  ## Get a slice-9 resource
  resourceStorage[key].slice9
proc getAudioSampleResource*(key: AudioSampleId): ptr Wav {.inline.} =
  ## Get an audio sample resource
  resourceStorage[key].audioSample.wav
proc getAudioStreamResource*(key: AudioStreamId): ptr WavStream {.inline.} =
  ## Get an audio stream resource
  resourceStorage[key].audioStream.wav
proc getResourceKind*(key: ResourceId): ResourceKind {.inline.} =
  ## Get resource kind
  resourceStorage[key].kind