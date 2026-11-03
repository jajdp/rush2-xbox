# Rush 2 on Xbox — the UWP port

How to take a game from the **N64Recomp + RT64** family to an **Xbox Series X in Developer Mode**,
using *Rush 2: Extreme Racing USA*
([`bryantmh/rush2recompiled`](https://github.com/bryantmh/rush2recompiled)) as the real case.

*(Español: [README.es.md](README.es.md))*

## Which console this was tested on

**An Xbox Series X**, in Developer Mode. Both of the consoles this was built and tested on are Series X,
so that is the only hardware anything claimed here covers.

**A Series S has never been tried — not once.** It is a different machine: less memory available to a
game and a weaker GPU. This may work on one, it may run slower, or it may not start at all; nothing here
has been measured on it. If you run it on a Series S, what you get is not what this README reports, and
none of the numbers here are a promise about that console.

## Where this port stands

The game **plays on the console**, and the one visible fault it had — the sky — turned out to be the
game's own and is gone since this port moved to **v1.0.20**. Measured on an Xbox Series X:

| | |
|---|---|
| ✅ Boots, draws and takes controller input | Yes, from day one |
| ✅ **It plays**, at **59 FPS** | Tested by the owner on an Xbox Series X on 2026-10-15 |
| ⚠ The sky, almost | **Fixed upstream**, not here: the game clipped its sky dome against the *current* frame's view, and its author corrected that on 2026-10-13 (issue #16, commits `47e3465b` and `12262d0f`); this port tracks **v1.0.20**. ⚠ A remnant is left, seen on 2026-10-18: on tight curves a few light triangles with no sky show up in the **top-left corner** |
| ✅ **Launch time** | **Fixed on 2026-10-18**: 5–6 minutes → **~20 s**, with the logo and the progress bar on screen from the first frame. Two independent causes, both written up in [`docs/HOW-IT-WORKS.md`](docs/HOW-IT-WORKS.md): the **mipmap addressing modes**, which made RT64 emit a shader costing ~200 s to build instead of 0.3 s, and the first frame **waiting for an ubershader pipeline that no draw call ever uses**. Caching a pipeline is still impossible here — both D3D12 ways remove the device — but it turned out not to matter |
| ⚠ The Controller Pak | The game sees the pad with its accessory but never opens the pak, so whatever a save writes is not read back |
| ⚠ The 2049 boost pads do nothing — **anywhere**, not only in Stunt | **Settled on 2026-11-02**, by reading upstream's own research rather than by playing. Two things, both in `docs/rush2049_research/`: `func_800E1F80`'s `0x10` branch is **not ported** (`collision.md` lists it as work to do), and the **collision converter strips info bits `0x10`/`0x20`** (`movers.md`), so a converted file cannot tell a boost pad from ordinary road in the first place. It looks like a Stunt-only fault because Rush 2's own tracks have no `0x10` polygons at all and 2049's race tracks have very few (78, 3 and 4 across three of six), while the arenas are full of them. **It is a feature this port does not have yet, not a fault**, and upstream has the implementation plan written out. Tracked as issue #3 |

**One line that used to be here was wrong, and it is worth saying so.** Until 2026-10-18 this
README stated that *the launch time is a console limit, not a missing optimisation*. It was
not: it was a shader RT64 should never have generated, plus a pipeline nobody uses. The
measurements behind that claim were sound; the conclusion drawn from them was not.

**And a second one, corrected on 2026-11-02.** This README said the boost pads misbehaved *in
Stunt events only*, and that the missing `0x10` branch did not explain a Stunt-only fault. The
first half was an honest description of what a player sees; the second was reasoning from an
incomplete reading of upstream's notes. They do nothing anywhere — the converter discards the
bit that marks a pad — and Stunt is merely where a player meets one. What held all along:
**the boost pads are not the console's fault**, because the physics that would push the car is
the same code on PC.

## What this repository is

| Piece | What it is |
|---|---|
| `tools/compilar.ps1` | **The whole recipe**, in five steps you can repeat one at a time: clone, build the recompilers, recompile the ROM, apply the UWP patches and build the libraries, and generate the appx. With the *why* of each decision written beside it |
| `patches/plume-psocache-DOES-NOT-WORK.patch` | **A record of a dead end, not something to apply.** It caches pipeline state objects in plume ([`renderbag/plume`](https://github.com/renderbag/plume), MIT), the RHI RT64 uses as a submodule, but it calls `ID3D12PipelineState::GetCachedBlob()`, which **removes the D3D12 device** on an Xbox in Developer Mode — the port dies 0.16 s into startup. `ID3D12Device1::CreatePipelineLibrary` fails the same way, even asked for an empty library. Kept because the next person will have the same idea |

## The two things to understand before trying

**1. The Visual Studio generator will NOT do for the game's libraries.** MSBuild only has the `v143`
toolset for "Application Type = UWP", not `ClangCL`, so `-T ClangCL` with `WindowsStore` gives
`error MSB8020`; and with `cl.exe` the whole ecosystem falls over, because it is written for clang
(`-Wno-*` in ultramodern and recompinput, `C4146` as an error in rabbitizer). The right way is
**Ninja + clang-cl**, with the libraries as a **desktop** target: what makes them UWP is the `_UWP`
macro from the patches. The only genuine `WindowsStore` project is the appx one.

**2. The recipe comes from worleydl's forks.** `rt64-dev` (branch `uwp-dk64`),
`N64ModernRuntime-dev` (`uwp-rebase`), `RecompFrontend-dev` (`uwp-compat`) and the
[`worleydl/uwp-dep`](https://github.com/worleydl/uwp-dep) bundle. ⚠ That bundle **has one branch per
engine**: for this family it is `rt64`, not the commit the Star Fox 64 fork pins, whose `libuwp`
does not export `uwp_PickMultipleFiles` and leaves the link unfinished.

## The five startup traps

All of them came up on the console, and all five carry over to the next game in the family:

| | What happens |
|---|---|
| 1 | **`SDL_INIT_HAPTIC` does not exist in WinRT's SDL**, and the game asks for every subsystem at once while checking `if (SDL_Init(...) > 0)`, which never triggers because SDL returns **-1**. It ends up with no video and hangs creating the window. They have to be brought up **one at a time** |
| 2 | **`SDL_HINT_JOYSTICK_WGI`**, or there is no controller. Third port in this catalogue to hit it |
| 3 | **`FOLDERID_LocalAppData` is not `LocalState`**: inside the container it returns `…\AC\<id>`, which the Device Portal does not expose. It has to return `SDL_WinRTGetFSPathUTF8`'s path. And portable mode is **no way around it**: SDL's WinRT video driver changes the working directory to the install folder |
| 4 | **`LocalState` does not exist until the first launch**: uploading before that gives "cannot find the path" |
| 5 | **The container's `stderr` is invalid**, and writing to it is a fail-fast: it needs a file of its own. That is what killed the game on entering stunt events, and it is intercepted with `_set_invalid_parameter_handler` |

## What it is not

There is no **ROM, no recompiled code, no executable, no appx** here, nor worleydl's patches (they
are in his repositories), nor the UWP bundle. Nor the changes the game project itself needs:
`bryantmh/rush2recompiled` publishes no license, so none of its code is copied here
([`NOTICE.md`](NOTICE.md)).

## Credits and license

**Almost none of what makes this work is ours.** This repository is a recipe that glues together other people's work; without any one of these pieces there would be no port at all.

| What it does | Who made it | License |
|---|---|---|
| **[rush2recompiled](https://github.com/bryantmh/rush2recompiled)** — recompiles *Rush 2* | **bryantmh** | none declared |
| **[plume](https://github.com/renderbag/plume)** — the low-level rendering interface RT64 uses | **renderbag** | MIT |
| **[uwp-dep](https://github.com/worleydl/uwp-dep)** — Dawn, SDL3, nod and dxcompiler **built for UWP** — the single reason any of this runs on an Xbox | **Daniel Worley** (worleydl) | libuwp: zlib, © 2025 |
| **[N64Recomp](https://github.com/N64Recomp/N64Recomp)** — statically recompiles N64 games into native executables | **Mr-Wiseguy** and the N64Recomp project | MIT |
| **[rt64](https://github.com/rt64/rt64)** — the N64 renderer, with its enhancements | the **RT64** project | MIT |
| **[N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime)** — the runtime those recompilations run on | the **N64Recomp** project | GPL-3.0 |
| **[RecompFrontend](https://github.com/N64Recomp/RecompFrontend)** — the in-game menus and configuration UI | the **N64Recomp** project | GPL-3.0 |
| **[SDL](https://github.com/libsdl-org/SDL)** — window, input and audio | **Sam Lantinga** and the SDL contributors | zlib |

Special mention to **Daniel Worley**: the UWP builds in `uwp-dep` are what make an Xbox port of this possible. We did not build them, we used them.

**The packaging recipe, the tooling and this documentation** are by **Recompilaciones**.


Recipe and tooling by **Recompilaciones**, under the [MIT](LICENSE) — the license of the one piece
of third-party code this repository carries a patch against,
[`renderbag/plume`](https://github.com/renderbag/plume) (the RHI RT64 uses as a submodule), and of
[N64Recomp](https://github.com/N64Recomp/N64Recomp) and [RT64](https://github.com/rt64/rt64).
[N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime) and
[RecompFrontend](https://github.com/N64Recomp/RecompFrontend), which the recipe also builds, are
**GPL-3.0**, and nothing of theirs is reproduced here. The UWP forks the recipe comes from are
**worleydl**'s.

*Rush 2: Extreme Racing USA* is © Midway. This project is not affiliated with them, with Microsoft,
or with the authors of N64Recomp, RT64, the game project or the UWP forks. Rights holders:
**jajdpmail@gmail.com**.
