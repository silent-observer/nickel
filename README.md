# Nickel

[Documentation](https://silent-observer.github.io/nickel/nickel)

**Nickel** is a miniature 2D game "engine" which is currently still WIP, and mostly for my own
personal use.

Its main philosophy is being more of a _library_ than a _framework_, meaning that it doesn't try to
structure your code for you like most big game engines do: all it does is provide you an ability to
easily draw game's UI without that much pain, and without introducing any graphics or
animation-related code into your game logic.
It should be very easy to just add Nickel to a text UI game, given that there already exists enough
separation between the game logic and the UI.

While it is not necessary to follow any particular architecture while using it, the recommended
architecture is _MVVM_ - `Model`-`View`-`ViewModel` architecture.
- `Model` is all of the game logic and game state, which is completely up to the game developer.
- `View` is the GUI part, and the way it is rendered. This is handled by the engine, you don't have to
  worry about it.
- `ViewModel` is the bridge between the two: it reads the state of the `Model` or any events it sent,
  and constructs the `View` accordingly. This code should also be written by the game developer,
  and is basically the GUI code, completely separated from the game logic. Nevertheless, there are
  many helper components already defined for you in the engine to use, such as
    - builtin GUI widgets (buttons, layouts, text, GUI panels, etc.)
    - displaying sprites from a spritesheet
    - click handling for sprites
    - animators - ability to model sprite animations as Finite State Machines.
    - tweens - ability to smoothly move objects and interpolate values.
    - timers - run code after some delay
    - resource manager - centralized store for all your resources
    - event queue - a simple event queue that can be used for communication between `Model` and `ViewModel`
    - audio manager - playing audio using [Soloud](https://sol.gfxile.net/soloud/index.html) library

For window management and rendering and collision detection Nickel uses some awesome libraries by
[treeform](https://github.com/treeform) and [guzba](https://github.com/guzba), notably
[pixie](https://github.com/treeform/pixie), [boxy](https://github.com/treeform/boxy),
[windy](https://github.com/treeform/windy) and [bumpy](https://github.com/treeform/bumpy).
Without them none of this would be possible. Notably, some of them are still very much WIP, but
they are already definitely good enough for my purposes.

Nickel's GUI also uses my ECS library, [yaecs](https://github.com/silent-observer/yaecs) inside,
and its use is also recommended for the game logic itself.

Note: for running the app you have to have [libsoloud.dll](https://sol.gfxile.net/soloud/downloads.html)

TODO:
- [X] GUI contexts
- [X] Resource packages
- [X] Scrollbar
- [X] Drag and drop
- [ ] Text input field
- [ ] Tabs layout