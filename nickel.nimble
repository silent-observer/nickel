# Package

version       = "0.1.0"
author        = "silent-observer"
description   = "A miniature game engine for turn based 2D games"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.6.2"
requires "boxy >= 0.4.0"
requires "pixie >= 4.3.0"
requires "opengl >= 1.2.6"
requires "windy"
requires "vmath"
requires "lrucache >= 1.1.4"
requires "yaml >= 1.0.0"
requires "https://github.com/zacharycarter/soloud-nim.git"
requires "yaecs"

task docs, "Generates the documentation":
  exec "nim doc --mm:orc --gc:orc --project --out:docs src/nickel.nim"