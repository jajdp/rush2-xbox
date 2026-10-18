# Building the port and getting it onto the console

*(Español: [INSTALL.es.md](INSTALL.es.md))*

⚠ **Read the first section of the [`README.md`](../README.md) before spending an evening on
this.** The game plays at 59 FPS, the sky is fixed and a launch takes about twenty seconds since
1.2.0, but the game never opens the Controller Pak and a remnant of the sky fault is left on
tight curves.

## 0. Where the commands go

In **PowerShell**, the ordinary Windows terminal: **Windows** key, type `powershell`, **Enter** on
*Windows PowerShell*. **No administrator needed**; and in the certificate step, using it breaks
things (the certificate is created in the store of whoever runs the command). **PowerShell 7 is not
needed**, and the examples carry `-ExecutionPolicy Bypass` because a stock Windows will not run a
`.ps1`.

## 1. What you need first

| | What for |
|---|---|
| **Visual Studio 2022** with the C++ tools and the **UWP** component | The MSVC environment (`vcvars64`), **clang-cl**, **Ninja** and the appx |
| **Your ROM** of *Rush 2: Extreme Racing USA* (USA) | The recompiler translates it to C++ |
| **worleydl's UWP bundle**, branch **`rt64`** | SDL2, `libuwp` and `dxc` for the console. ⚠ The branch matters: the one the Star Fox 64 fork pins does not export `uwp_PickMultipleFiles` and leaves the link unfinished |
| **Git and Python 3** | Cloning, patching and recompiling |
| **An Xbox in Developer Mode** and a certificate | Installing and signing |
| **About 3 GB of disk** | The tree, the recompilers and the builds |

## 2. The recipe, in five steps

```powershell
powershell -ExecutionPolicy Bypass -File tools\compilar.ps1 -Arbol C:\rush2 -Rom "C:\roms\rush2.z64"
```

That runs all five in a row. Each can be repeated on its own, which is what helps when something
fails halfway:

| `-Paso` | What it does |
|---|---|
| `herramientas` | Builds `N64Recomp` and `RSPRecomp`, which the game's repository does not ship |
| `recompilar` | Translates the ROM to C++ (1 596 functions) and the audio microcode |
| `parches` | Applies worleydl's UWP patches on top of the ones the game applies to its own submodules, and points plume at its UWP variant |
| `libs` | Builds the game **as static libraries**, with **Ninja and clang-cl** |
| `appx` | The only genuine `WindowsStore` project: links the libraries and produces the package |

⚠ **The `libs` step cannot be done with the Visual Studio generator.** The why is in
[`HOW-IT-WORKS.md`](HOW-IT-WORKS.md), and it is the first thing to know about this port.

## 3. The pipeline cache (optional)

```powershell
git apply --directory=<path to plume> patches\plume-psocache.patch
```

It was the first attempt against the minutes every launch used to take, and it **does not work
on this console**. The launch was fixed another way in 1.2.0 — see `HOW-IT-WORKS` — and this
patch is kept only as a record of the dead end.

## 4. Installing it on the console

### Before touching anything: how the console has to be

- **In Developer Mode**, with Dev Home installed. - **On, and with your profile signed in.** ⚠
  With no user signed in the console **will not launch apps**. - **On the same network**, with
  its address at hand. The Device Portal listens on port **11443** over HTTPS, and asks for the
  username and password you set in Dev Home.

Open `https://<ip>:11443`. ⚠ The browser will warn that the site's certificate is not trusted: it is
the console's own. Go in anyway — in Edge and Chrome, **Advanced** → **Continue to … (unsafe)**; in
Firefox, **Advanced** → **Accept the Risk and Continue**. Then, under **My games & apps → Add**,
your package.

## 5. The ROM and the data, inside the package

⚠ **`LocalState` does not exist until the first launch.** Upload before that and the portal says it
cannot find the path. So: install, **open the game once**, close it, and then upload the ROM with the
portal's **File explorer**.

And ⚠ **`FOLDERID_LocalAppData` is not `LocalState`**: inside the container it returns a folder the
Device Portal does not expose, so the port has to ask SDL for the path. Portable mode is no way
around it, because WinRT's video driver changes the working directory to the install folder.

## If something goes wrong

| Symptom | Cause |
|---|---|
| `error MSB8020` building the libraries | The Visual Studio generator was used: it has to be Ninja + clang-cl ([`HOW-IT-WORKS.md`](HOW-IT-WORKS.md)) |
| The link leaves `uwp_PickMultipleFiles` unresolved | The UWP bundle is from the wrong branch: for this family it is `rt64` |
| Boots with no video and hangs creating the window | `SDL_INIT_HAPTIC`: the subsystems have to be brought up one at a time |
| No button responds | `SDL_HINT_JOYSTICK_WGI` is missing |
| The portal cannot find the path when uploading the ROM | `LocalState` does not exist until the first launch (§5) |
| Exits mid-race with no message | The container's `stderr` is invalid and writing to it is a fail-fast: it needs `_set_invalid_parameter_handler` and a file of its own for the log |
| Every launch takes minutes | Fixed in 1.2.0 (the mipmap addressing modes and the wait for the ubershader). If you still see it, the tree is older than that |
| The sky is black on a track | Fixed by moving to the game's v1.0.20: it was the game's own, not the port's |


## Reinstalling: three things that bite

1. **The appx comes out of MSBuild unsigned.** The console answers *«The app package must be
   digitally signed for signature validation»* (`0x800B0100`). Sign it with a self-signed
   certificate whose **subject is exactly the manifest's `Publisher`** — that is what keeps the
   package family name, so the console treats it as an update and keeps `LocalState`:
   `signtool sign /fd SHA256 /sha1 <thumbprint> <msix>`.
2. **Installing the same version uninstalls the package** instead of updating it. Bump the
   manifest's `Identity Version` first, and anchor the regular expression that does it
   (`\sVersion="…"`), because `MinVersion` contains `Version`.
3. **A shader cache written by an older build is no good.** Delete `LocalState\shadercache\`; the
   game rebuilds it. The first launch afterwards takes about twenty seconds, with the loading bar
   over the logo.
