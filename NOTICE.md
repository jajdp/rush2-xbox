# Notice

*(Español: [NOTICE.es.md](NOTICE.es.md))*

## Not affiliated

This is an unofficial, noncommercial fan project. It is **not affiliated with, endorsed by or
connected to Midway, Warner Bros. or Microsoft**, nor to the authors of
[N64Recomp](https://github.com/N64Recomp/N64Recomp), [RT64](https://github.com/rt64/rt64),
[`rush2recompiled`](https://github.com/bryantmh/rush2recompiled) or the UWP forks this recipe builds
on. *Rush 2: Extreme Racing USA*, *Xbox* and all related names and marks are the property of their
respective owners.

Nothing here is for sale, and nothing here is monetized.

## What this repository does not distribute

No ROM. No recompiled game code. No built executable. No appx. No save data. And none of the UWP
dependency bundle, which is other people's binaries.

## What it does contain of other people's work

**One patch against plume** — [`renderbag/plume`](https://github.com/renderbag/plume), **MIT**,
Copyright (c) 2024 renderbag and contributors — the rendering hardware interface RT64 uses as a
submodule of its own. RT64 (MIT, (c) 2024 RT64 Contributors) and N64Recomp (MIT, (c) 2024 Wiseguy)
are MIT as well, and MIT permits modified versions; this repository is released under
[that same license](LICENSE).

**Nothing of the two GPL libraries.** [N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime)
and [RecompFrontend](https://github.com/N64Recomp/RecompFrontend), which the recipe also builds, are
**GPL-3.0**. No line of either is reproduced here, and anything derived from them would have to carry
**their** license and not this one — worth knowing before you publish your own patches to them.

**Nothing of the game project.** `bryantmh/rush2recompiled` publishes no license, so **no line of it
is reproduced here** — not the changes it needs for UWP, not its CMake, not its headers. What
`tools/compilar.ps1` does is *drive* the build: it clones, builds the recompilers, runs the
recompilation, applies patches that live in other people's repositories, and configures CMake. The
decisions and the reasoning in it are first-party.

**Nothing of worleydl's forks either.** The recipe says which branches to use and why; their patches
are fetched from their own repositories.

**There are no screenshots here.**

## Takedown and contact

If you hold rights in this material and want something here removed or changed, write to
**jajdpmail@gmail.com**. Requests from rights holders are honoured without argument.
