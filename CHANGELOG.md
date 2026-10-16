# Changelog

All notable changes to this repository. Dates are `YYYY-MM-DD`.

## [1.1.1] — 2026-10-16

### Fixed

- **`LICENSE`: the explanatory block named the wrong project.** Everything after the MIT text had
  been copied from the `dkr-xbox` repository and never adapted: it claimed this was a derivative of
  Golden Balloon, denied granting rights in Diddy Kong Racing, quoted "the 57 lines of the upstream
  project", and listed `src/` and `package/`, which this repository does not have. It now states
  what is actually here.
- **plume was credited to the wrong author.** It is
  [`renderbag/plume`](https://github.com/renderbag/plume) — MIT, Copyright (c) 2024 renderbag and
  contributors — which RT64 uses as a submodule of its own; it is not RT64's code. The one patch
  this repository publishes is against it, so the credit matters. Corrected in `LICENSE`, `NOTICE`
  and `README`, in both languages.

### Added

- **The two GPL-3.0 libraries are now named.** `N64ModernRuntime` and `RecompFrontend`, which the
  recipe also builds, are **GPL-3.0** and not MIT. Nothing of theirs is reproduced here, but anyone
  publishing their own patches against them has to carry **their** license, not this one — and the
  documentation never said so.

## [1.1.0] — 2026-10-15

**The port plays, and the sky is fixed.** The sky that failed on specific tracks was never the
port's: the game clipped its dome against the current frame's view, and its author fixed it upstream
on 2026-10-13 (issue #16, `47e3465b` and `12262d0f`). The port was rebuilt on the game's **v1.0.20**
and the owner confirmed it on an Xbox Series X: correct sky, **59 FPS**.

### Changed

- **`tools/compilar.ps1`** now takes `-Version` and clones that tag (today `v1.0.20`). These
  projects publish almost daily; without pinning it the tree comes out different every time.
- **`docs/HOW-IT-WORKS`** gains *Moving the port to a new version of the game*: the step-by-step that
  took this port across 88 upstream commits, including why you should **diff the code, not the
  `.patch` files** (merging the patch text gave 39 conflicts; by code there were four).
- **`docs/INSTALL`** gains the three things that bite when you reinstall: the appx comes out of
  MSBuild **unsigned**, installing the **same version** uninstalls the package instead of updating
  it, and the console's shader cache from an older version has to go.
- `patches/plume-psocache.patch` → **`patches/plume-psocache-DOES-NOT-WORK.patch`**. It calls
  `GetCachedBlob()`, which removes the D3D12 device on this console. It had been archived before
  that was known, and applying it on the new tree cost a build: a patch saved by hand ages in
  silence.

### Added

- Two link libraries the game's v1.0.20 needs and the appx did not ask for: `hid.lib` (HID haptics)
  and `ws2_32.lib` (`in6addr_any`, from the online play's UPnP).

## [1.0.0] — 2026-10-13

First publication. **The port is unfinished**, and the README says so in its first section: the game
plays, but the sky fails on specific tracks, every launch spends 3–4 minutes recompiling pipelines,
and the Controller Pak is never opened by the game.

It is published because the recipe carries over to any other game in the N64Recomp + RT64 family.

### Added

- **`tools/compilar.ps1`** — the whole recipe in five repeatable steps, with the reasoning written
  beside each decision. The two that matter most: the game's libraries **cannot** be built with the
  Visual Studio generator (MSBuild has no `ClangCL` toolset for UWP — `MSB8020` — and `cl.exe`
  breaks the ecosystem, which is written for clang), and the UWP dependency bundle **has one branch
  per engine**: taking the wrong one leaves the link unfinished with a missing export.
- **`patches/plume-psocache.patch`** — a pipeline-state-object cache in RT64's plume (MIT), the
  first step against the 3–4 minute launch.
- **Documentation in both languages**, with the five startup traps that carry over: `SDL_INIT_HAPTIC`
  not existing in WinRT's SDL (and the game's `if (SDL_Init(...) > 0)` check never catching the -1),
  the Windows.Gaming.Input hint, `FOLDERID_LocalAppData` not being `LocalState`, `LocalState` not
  existing until first launch, and the container's invalid `stderr` being a fail-fast — which is what
  killed the game mid-race until it was intercepted.

### Not included, on purpose

- The ROM, the recompiled code, the executable and the appx.
- **Nothing of the game project**, which publishes no license.
- Nothing of worleydl's UWP forks: the recipe names the branches and fetches the patches from his
  repositories.
