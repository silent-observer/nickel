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

import pixie, critbits, tables, utils, yaml, streams
import solouddotnim
from os import `/`

type
  ImageId* = string
  FontId* = string
  SpriteSheetId* = string
  Slice9Id* = string
  AudioSampleId* = string
  AudioStreamId* = string

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
var resourceCfg: ResourceConfig

proc loadImage(key: ImageId, path: string, defaultScaleUp: int) {.inline.} =
  images[key] = readImage(path).integerScaleUp(defaultScaleUp)

proc loadSpriteSheet(key: SpriteSheetId, spec: SpriteSheetSpec, 
    resourceDir: string, defaultScaleUp: int) {.inline.} =
  let scaleUp = if spec.scaleUp == 0: defaultScaleUp else: spec.scaleUp
  let image = readImage(resourceDir / spec.imagePath).integerScaleUp(scaleUp)
  spriteSheets[key] = SpriteSheet(
    image: image,
    tileX: spec.tileX * scaleUp, tileY: spec.tileY * scaleUp,
    countX: image.width div (spec.tileX * scaleUp),
    countY: image.height div (spec.tileY * scaleUp),
    count: spec.count
  )

proc loadSlice9(key: Slice9Id, spec: Slice9Spec, resourceDir: string,
    defaultScaleUp: int) {.inline.} =
  let scaleUp = if spec.scaleUp == 0: defaultScaleUp else: spec.scaleUp
  let image = readImage(resourceDir / spec.imagePath).integerScaleUp(scaleUp)
  slice9s[key] = Slice9(
    image: image,
    left: spec.left * scaleUp,
    right: spec.right * scaleUp,
    bottom: spec.bottom * scaleUp,
    top: spec.top * scaleUp,
  )

proc loadFont(key: FontId, path: string) {.inline.} =
  fonts[key] = readTypeface(path)

proc loadAudioSample(key: AudioSampleId, path: string) {.inline.} =
  let wav = Wav_create()
  echo Wav_load(wav, path)
  audioSamples[key] = AudioSample(wav: wav)
proc loadAudioStream*(key: AudioStreamId, path: string) {.inline.} =
  let wav = WavStream_create()
  echo WavStream_load(wav, path)
  audioStreams[key] = AudioStream(wav: wav)

proc loadResources*(cfg: ResourceConfig) =
  ## Loads all the resources specified in the config
  resourceCfg = cfg
  for key, path in cfg.images:
    loadImage(key, cfg.resourceDir / path, cfg.defaultScaleUp)
  for key, path in cfg.fonts:
    loadFont(key, cfg.resourceDir / path)
  for key, spec in cfg.spriteSheets:
    loadSpriteSheet(key, spec, cfg.resourceDir, cfg.defaultScaleUp)
  for key, spec in cfg.slice9s:
    loadSlice9(key, spec, cfg.resourceDir, cfg.defaultScaleUp)
  for key, path in cfg.audioSamples:
    loadAudioSample(key, cfg.resourceDir / path)
  for key, path in cfg.audioStreams:
    loadAudioStream(key, cfg.resourceDir / path)

proc loadResources*(cfgPath: string) =
  ## Loads all the resources specified in the config, which is read from the YAML file
  var cfg: ResourceConfig
  var s = openFileStream(cfgPath)
  load(s, cfg)
  s.close()
  loadResources(cfg)

proc getImageResource*(key: ImageId): Image {.inline.} = images[key] ## \
  ## Get an image resource
proc getFontResource*(key: FontId): Typeface {.inline.} = fonts[key] ## \
  ## Get a font resource
proc getSpriteSheetResource*(key: SpriteSheetId): SpriteSheet {.inline.} = spriteSheets[key] ## \
  ## Get a spritesheet resource
proc getSlice9Resource*(key: Slice9Id): Slice9 {.inline.} = slice9s[key] ## \
  ## Get a slice-9 resource
proc getAllSpriteSheetResources*(): CritBitTree[SpriteSheet] {.inline.} = spriteSheets ## \
  ## Get a table of all spritesheet resources for iterating
proc getAllSlice9Resources*(): CritBitTree[Slice9] {.inline.} = slice9s ## \
  ## Get a table of all slice-9 resources for iterating
proc getAllImageResources*(): CritBitTree[Image] {.inline.} = images ## \
  ## Get a table of all image resources for iterating

proc getAudioSampleResource*(key: AudioSampleId): ptr Wav {.inline.} = audioSamples[key].wav ## \
  ## Get an audio sample resource
proc getAudioStreamResource*(key: AudioStreamId): ptr WavStream {.inline.} = audioStreams[key].wav ## \
  ## Get an audio stream resource