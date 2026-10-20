# How it works, and why this way

*(Español: [HOW-IT-WORKS.es.md](HOW-IT-WORKS.es.md))*

## The decision that defines the port: Ninja and clang-cl, not Visual Studio

A game from the **N64Recomp + RT64** family is not built as an `.exe` and then packaged: it is built
as **static libraries** with `-DUWP_BUILD=ON`, and a second project — the appx one — links them and
produces the package.

And those libraries **cannot be built with the Visual Studio generator**. Two reasons, both
measured:

- **MSBuild only has the `v143` toolset for "Application Type = UWP", not `ClangCL`.** Asking for
  `-T ClangCL` with `WindowsStore` gives `error MSB8020`, and that is the end of it.
- **And with `cl.exe` the whole ecosystem falls over**, because it is written for clang:
  `ultramodern` and `recompinput` use `-Wno-unused-parameter`, and `rabbitizer` triggers `C4146`,
  which MSVC treats as an error.

The right way is **Ninja + clang-cl**, with the libraries as a **desktop** target, not
`WindowsStore`. What makes them UWP is the **`_UWP`** macro from the patches. The only genuine
`WindowsStore` project is the appx one, on `v143`, which compiles just its `main.cpp` and links.

You can see it in the template the recipe comes from: its `CMakeSettings.json` asks for the Ninja
generator and a `clang_cl_x64` environment, and its `.lib` paths **carry no configuration
subfolder**, which is Ninja's signature and not the Visual Studio generator's. And the MSVC
environment (`vcvars64.bat`) has to be imported before calling cmake, because clang-cl and Ninja
need it.

## Where the recipe comes from

From **worleydl**'s forks: `rt64-dev` (branch `uwp-dk64`), `N64ModernRuntime-dev` (`uwp-rebase`),
`RecompFrontend-dev` (`uwp-compat`) and the `worleydl/uwp-dep` bundle.

⚠ **The bundle has one branch per engine**, and getting it wrong costs an evening: for this family
it is `rt64`, not the commit the Star Fox 64 fork pins, whose `libuwp` does not export
`uwp_PickMultipleFiles` and leaves the link unfinished.

## The five startup traps

All of them carry over to the next game in the family, and here they are in the order they appeared:

**1. `SDL_INIT_HAPTIC` does not exist in WinRT's SDL.** And the game asks for every subsystem at
once, checking the result with `if (SDL_Init(...) > 0)` — which **never triggers**, because SDL
returns **-1** on failure. The result: the game ends up with no video and hangs creating the window,
with no message at all. The fix is to bring the subsystems up **one at a time** from the wrapper
before entering the game; `SDL_Init` reference-counts, so it does no harm.

**2. `SDL_HINT_JOYSTICK_WGI`, or there is no controller.** Third port in this catalogue to hit it,
which makes it a fixed step: set it, and check the controller through the log before calling
anything finished.

**3. `FOLDERID_LocalAppData` is not `LocalState`.** Inside the container it returns `…\AC\<id>`,
which the Device Portal **does not expose**: whatever is stored there cannot be uploaded or
downloaded. It has to return `SDL_WinRTGetFSPathUTF8`'s path. And **portable mode is no way
around it**, which was the first thing tried: SDL's WinRT video driver changes the working directory
to the install folder.

**4. `LocalState` does not exist until the first launch.** Uploading before that gives "cannot find
the path", which looks like a portal bug and is not.

**5. The container's `stderr` is invalid, and writing to it is a fail-fast.** This is what killed the
game on entering a stunt event: no exception, no dump, no message — the process simply vanished. It
is intercepted with `_set_invalid_parameter_handler` and by giving the log a file of its own.

## What is solved and what is not

The port plays; what is left is worth having in front of you:

| | |
|---|---|
| ✅ Boots, draws, plays sound and takes controller input | |
| ✅ **It plays**: the stunt-event crash was trap 5 | |
| ✅ The Controller Pak **loads** | The game sees the pad with its accessory but **never calls `osPfsInitPak`**, so nobody ever opened the `.mpk` in `LocalState`. It is now loaded from the draw loop as soon as the runtime has its path ready, without waiting for the game |
| ✅ A shader list that feeds itself | With it the game went from surviving 47 s to 218 s in the stunt test, and the second entry into a track loads at once |
| ✅ **The launch** | **Fixed on 2026-10-18**: 5–6 minutes → **~20 s**, and no black screen before the logo. It was the **mipmap addressing modes** making RT64 emit a shader that costs ~200 s to build, plus the first frame **waiting for an ubershader pipeline nothing uses** (next section). Caching a pipeline is still impossible here — both D3D12 ways remove the device — and it turned out not to matter |
| ✅ **The sky** | Fixed by moving to the game's v1.0.20: it was the game clipping its dome against the current frame's view, fixed upstream on 2026-10-13 |
| ⚠ **The Controller Pak's records** | The factory ones show up, but the game still does not open the pak: whatever a save writes is not read back |
| ⚠ Developer Mode suspension | Coming back from Home, the game starts over |


## The launch: it was never the console

Until 2026-10-18 this document said a first launch takes minutes because the driver needs 180–190 s
to build four of the pipelines, and that there is no way to cache one on this console. The second
half is true. The first was a symptom: the cost was in the shader being handed to the driver.

**It was the mipmap addressing modes.** On the RDP it is normal for the higher mipmap levels to be
marked CLAMP while the lower ones are WRAP — there is nothing to repeat on a two-texel level. RT64
compares the modes of *every* level before using a native sampler:

```cpp
// rt64_state.cpp — if any level disagrees, sameModes goes false, the native sampler is dropped
// and the shader gets a branch per sample.
for (uint32_t t = 1; (t < callDesc.tileCount) && sameModes; t++) { … }
```

On an Xbox Series X that branchy shader costs **~200 s** of pipeline creation, against **0.3 s** for
the plain one. In this game seven of them ate **1 337 s of a 1 448 s** launch. Instrumented to say
*which* level disagrees and *in what field*, the pattern is always the same: `fmt` and `siz` match
everywhere and only `cms`/`cmt` of the higher levels differ. Taking level 0's mode for every level
brings the worst shader from **262 s to 8.8 s**, and the image is identical — what is lost is the
addressing of mipmap levels a couple of texels wide, at a distance where it cannot be seen.

**And the black screen before the logo was the ubershader.** `State::fullSync()` joins the threads
that create the ubershader's eight pipelines before rendering anything:

```cpp
// rt64_state.cpp, before drawing a workload
ext.rasterShaderCache->shaderUber->waitForPipelineCreation();   // join() of the creation threads
```

The first of those eight costs **26.8 s** here; the other seven are free, because they share the
bytecode and the driver reuses what it compiled (RT64 serialises the first one on purpose for
exactly that reason). While the game thread sits in that `join` there is no workload, so there is
no present — and with no present there is no logo, no interface and no loading bar. **That is the
black screen.** Skipping the wait, and letting a draw call that needs the ubershader be dropped
until it is ready, puts the first frame at **~0 s** and the game running at **~22 s** instead of
~50. The one thing that must not be done is reading the pipeline array while its threads write it:
the wait has to be replaced by an `std::atomic<bool>` those threads set with `release`, read with
`acquire` before touching anything.

**How to find out which pipeline is the expensive one.** Log the bytecode size next to the creation
time — `psoDesc.PS.BytecodeLength` — and match it against the sizes of the compiled `.dxil` files.
That is what named the 26.8 s one: `RasterPSDynamic`, 52 016 bytes, the ubershader.

**And count before believing a capture.** A counter of the draw calls that fall back to the
ubershader reads **zero** across every measured launch, the original included: with healthy
specialised shaders nothing needs it, so those 27 seconds were spent on a pipeline that does not
draw a triangle. The same counter corrected a wrong reading of a screenshot along the way — a dark
scene taken for missing geometry that was simply the game's night track. **A capture says what is
on screen, not why.**

## Moving the port to a new version of the game

Done once, across **88 upstream commits** (v1.0.12 → v1.0.20, 237 files). It is the part nobody
writes down, so here it is.

**First: check whether the bug you are chasing is already fixed upstream.** The sky that this port
showed broken was the game's own bug, closed two days after our tree was cloned. Downloading the
official release and running it with the ROMs in a separate folder settles that in minutes.

1. **Clone the new tag into a new tree** (`compilar.ps1 -Version v1.0.20`), and keep the old one as
   a reference.
2. **Check whether the libraries moved** (`git ls-tree <tag> lib/`). If `rt64`, `N64ModernRuntime`
   and `RecompFrontend` still point at the same commits — our case — the patches still apply and
   the jump is cheap.
3. **Do not merge the `.patch` files as text.** Three-way merging them gave **39 conflicts** in
   rt64's alone. Take the delta **by code**: diff «base commit + the author's patch from the old
   version» against the old tree's working state. That is worleydl's work plus yours, and it applies
   onto the new version with `git apply -p1 --reject`.
4. **Copy what lives in no patch**: the `uwp\` folder and any file you added to the game.
5. **Save each submodule's patch** with `py tools/lib_patch.py save`, or the game's CMake refuses to
   configure with *«lib/patches/x.patch doesn't apply to lib/x»*.
6. **Build and expect new link errors**: v1.0.20 needed `hid.lib` and `ws2_32.lib` in the appx
   project, because the game's own CMakeLists links them into an executable that `UWP_BUILD=ON`
   never produces.
7. **Sign, bump, install.** The appx comes out unsigned; the manifest version must go up before
   reinstalling; and the console's `LocalState\shadercache\` holds blobs of the old shaders.

Four conflicts came out of all that, and all four were resolved by **combining, not choosing**: the
CMake block (our `if (NOT UWP_BUILD)` wrapper around the author's new libraries), two in `main.cpp`
(his controller `lock_guard` before our UWP block; his simulation mode with our trace behind), and
two header hunks whose neighbouring lines had moved.
