## Audio manager module.
## [Soloud](https://sol.gfxile.net/soloud/index.html) library is used for audio.
## In this module, `AudioSample` is a short "sound effect" audio source that is completely loaded
## into memory.
## On the other hand, `AudioStream` is a long audio source that is continuously read from file
## and is usually used as background music.

import resources, solouddotnim, critbits

type
  AudioManager* = object
    ## A main object of the audio manager
    soloud: ptr Soloud
    bgHandle: cuint
    sfxMixer: ptr Bus
    fadeSeconds: float

    masterVolume: float
    bgVolume: float
    sfxVolume: float
    loopingSfx: CritBitTree[cuint]

proc `=copy`(d: var AudioManager, s: AudioManager) {.error.}
proc `=destroy`(m: var AudioManager) =
  if m.sfxMixer != nil:
    Bus_destroy(m.sfxMixer)
  if m.soloud != nil:
    Soloud_deinit(m.soloud)
    Soloud_destroy(m.soloud)

proc initAudioManager*(): AudioManager =
  ## Creates an audio manager and initializes the library
  result.soloud = Soloud_create()
  discard Soloud_init(result.soloud)
  result.soloud.Soloud_setGlobalVolume(1)
  result.bgHandle = 0
  result.sfxMixer = Bus_create()
  Bus_setVolume(result.sfxMixer, 1)
  discard Soloud_play(result.soloud, result.sfxMixer)

  result.masterVolume = 1
  result.bgVolume = 1
  result.sfxVolume = 1

  result.fadeSeconds = 2

proc fadeBackground*(m: var AudioManager, audio: AudioStreamId) =
  ## Switches the current background music to `audio`.
  ## If there was no music playing, it just starts `audio`.
  ## If `audio` is `""`, then it stops the current one.
  ## The background music volume is smoothly faded for 2 seconds before switching.
  if m.bgHandle != 0:
    Soloud_fadeVolume(m.soloud, m.bgHandle, 0, m.fadeSeconds)
    Soloud_scheduleStop(m.soloud, m.bgHandle, m.fadeSeconds)
  if audio != "":
    m.bgHandle = Soloud_playEx(m.soloud, getAudioStreamResource(audio), 0, 0, 1, 0)
    Soloud_setPanAbsolute(m.soloud, m.bgHandle, 1, 1)
    Soloud_setProtectVoice(m.soloud, m.bgHandle, 1)
    Soloud_setLooping(m.soloud, m.bgHandle, 1)
    Soloud_setPause(m.soloud, m.bgHandle, 0)
    Soloud_fadeVolume(m.soloud, m.bgHandle, m.bgVolume, m.fadeSeconds)

proc playSample*(m: var AudioManager, audio: AudioSampleId, volume: float = 1, pan: float = 0) =
  ## Plays a sample `audio`.
  ## You can also specify its `volume` (from 0 to 1) and `pan` (from -1 to 1)
  discard Bus_playEx(m.sfxMixer, getAudioSampleResource(audio), volume, pan, 0)
proc playSampleLoop*(m: var AudioManager, audio: AudioSampleId, volume: float = 1, pan: float = 0) =
  ## Plays a sample `audio` and loops it.
  ## You can also specify its `volume` (from 0 to 1) and `pan` (from -1 to 1)
  ## 
  ## **See also:**
  ## * [stopSample proc](#stopSample,AudioManager,AudioSampleId)
  let wav = getAudioSampleResource(audio)
  Wav_setLooping(wav, 1)
  m.loopingSfx[audio] = Bus_playEx(m.sfxMixer, wav, volume, pan, 0)
proc stopSample*(m: var AudioManager, audio: AudioSampleId) =
  ## Stops a sample `audio` that was previously looping.
  ## 
  ## **See also:**
  ## * [playSampleLoop proc](#playSampleLoop,AudioManager,AudioSampleId,float,float)
  if audio in m.loopingSfx:
    Soloud_stop(m.soloud, m.loopingSfx[audio])
    m.loopingSfx.excl audio
