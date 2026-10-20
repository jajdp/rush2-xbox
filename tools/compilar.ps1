<#
.SYNOPSIS
    Construye el port UWP (Xbox Series) de Rush 2 Recompiled.

.DESCRIPTION
    Receta tomada de los forks UWP de worleydl para la familia N64Recomp (BanjoRecomp-uwp,
    Starfox64Recomp-uwp, rama uwp-compat). Dos compilaciones:

      1. el juego con -DUWP_BUILD=ON produce bibliotecas estaticas en vez de un .exe;
      2. src\uwp\ las enlaza con el paquete SDL2/libuwp/dxc de worleydl/uwp-dep y genera el appx.

    Antes hacen falta los recompiladores y el codigo recompilado, que el repositorio no trae.
    Cada paso se salta si ya esta hecho, asi que el guion se puede repetir.

.PARAMETER Arbol
    Carpeta de trabajo. Obligatoria: el arbol pesa ~3 GB y no vive dentro de este repositorio.

.PARAMETER Rom
    ROM de Rush 2 (USA). Por defecto, la de dependencias-usuario\ del subproyecto.

.PARAMETER Paso
    Ejecuta solo un paso: herramientas, recompilar, parches, libs, appx. Por defecto, todos.

.PARAMETER Version
    Etiqueta del juego que se clona. Se fija a proposito: el autor publica casi a diario y
    sin esto el arbol saldria distinto cada vez. Subirla es adoptar una version nueva, y eso
    obliga a rehacer los parches UWP (tecnico 13.2).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Arbol,
    [string]$Rom = "$PSScriptRoot\..\dependencias-usuario\Rush 2 - Extreme Racing USA (USA).z64",
    [ValidateSet('todos', 'herramientas', 'recompilar', 'parches', 'libs', 'appx')]
    [string]$Paso = 'todos',
    [string]$Version = 'v1.0.20'
)

$ErrorActionPreference = 'Stop'
$src = Join-Path $Arbol 'src'
$gen = 'Visual Studio 17 2022'

function Hacer([string]$nombre) { $Paso -eq 'todos' -or $Paso -eq $nombre }
function Paso([string]$t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }

# clang-cl y ninja necesitan el entorno de MSVC (INCLUDE, LIB, PATH del SDK), que fuera del
# «x64 Native Tools Command Prompt» no esta puesto: se importa de vcvars64.bat.
function Import-EntornoVS {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vs = & $vswhere -latest -products * -property installationPath
    $bat = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path $bat)) { throw "No esta vcvars64.bat en $bat" }
    $clang = Join-Path $vs 'VC\Tools\Llvm\x64\bin\clang-cl.exe'
    if (-not (Test-Path $clang)) {
        throw 'Falta clang-cl: instala «C++ Clang tools for Windows» en Visual Studio.'
    }
    cmd /c "call `"$bat`" > nul 2>&1 && set" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$' -and $matches[1] -ne 'PSModulePath') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
        }
    }
    # El ninja que trae Visual Studio, para no depender del que haya en el PATH.
    $ninja = Join-Path $vs 'Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja'
    if (Test-Path $ninja) { $env:PATH = "$ninja;$env:PATH" }
}

if (-not (Test-Path $src)) {
    Paso "Clonando el arbol en $Version"
    New-Item -ItemType Directory -Force $Arbol | Out-Null
    git clone --recurse-submodules https://github.com/bryantmh/rush2recompiled.git $src
    git -C $src checkout --quiet $Version
    git -C $src submodule update --init --recursive --quiet
}

# 1. Los recompiladores (N64Recomp.exe y RSPRecomp.exe), que no vienen con el repositorio.
if ((Hacer 'herramientas') -and -not (Test-Path "$src\.tools\N64Recomp.exe")) {
    Paso 'Construyendo N64Recomp y RSPRecomp'
    cmake -S "$src\lib\N64ModernRuntime\N64Recomp" -B "$Arbol\build-tools" -G $gen -A x64
    cmake --build "$Arbol\build-tools" --config Release --target N64RecompCLI RSPRecomp
    New-Item -ItemType Directory -Force "$src\.tools" | Out-Null
    Copy-Item "$Arbol\build-tools\Release\N64Recomp.exe" "$src\.tools\" -Force
    Copy-Item "$Arbol\build-tools\Release\RSPRecomp.exe" "$src\.tools\" -Force
}

# 2. El codigo del juego traducido a C++ (1.596 funciones) y el microcodigo de audio.
if ((Hacer 'recompilar') -and -not (Test-Path "$src\RecompiledFuncs")) {
    Paso 'Recompilando el codigo de la ROM'
    Push-Location $src
    py -3.13 -X utf8 tools\extract.py $Rom
    & "$src\.tools\N64Recomp.exe" us.toml
    & "$src\.tools\RSPRecomp.exe" aspMain.us.toml
    Pop-Location
}

# 3. Los parches UWP de worleydl, encima de los que el propio juego aplica a sus submodulos.
#    uwp\patches\*.patch son los diffs de sus ramas (rt64-dev uwp-dk64, N64ModernRuntime-dev
#    uwp-rebase, RecompFrontend-dev uwp-compat) contra los commits que fija este proyecto.
if (Hacer 'parches') {
    Paso 'Aplicando los parches UWP'
    foreach ($n in 'rt64', 'N64ModernRuntime', 'RecompFrontend') {
        $lib = "$src\lib\$n"
        $propio = "$src\lib\patches\$n.patch"
        $uwp = "$src\uwp\patches\$n-uwp.patch"
        # El parche del juego primero; si ya esta puesto, git lo dice y seguimos.
        git -C $lib apply --whitespace=nowarn $propio 2>$null
        # El de rt64 incluye el cambio de submodulo de plume, que git apply no sabe hacer: se
        # excluye aqui y se resuelve abajo apuntando plume al fork de worleydl.
        $excluir = if ($n -eq 'rt64') { @('--exclude=src/contrib/plume') } else { @() }
        git -C $lib apply --3way --whitespace=nowarn @excluir $uwp
        Write-Host "  $n : parche UWP aplicado (o ya estaba)"
    }

    # plume es el RHI de RT64 y necesita su variante UWP; el parche pide este commit exacto,
    # que es la punta de la rama uwp-dk64 de worleydl/plume-uwp.
    $plume = "$src\lib\rt64\src\contrib\plume"
    $commit = '46171c884c4cfb111541523aacd8f45dcba2cf6f'
    if ((git -C $plume rev-parse HEAD) -ne $commit) {
        Paso 'Apuntando plume a la variante UWP'
        if (-not (git -C $plume remote | Select-String -Quiet worleydl)) {
            git -C $plume remote add worleydl https://github.com/worleydl/plume-uwp.git
        }
        git -C $plume fetch --quiet worleydl uwp-dk64
        git -C $plume checkout --quiet --detach $commit
        Write-Host "  plume en $commit"
    }
}

# 4. El juego como bibliotecas estaticas, con Ninja y clang-cl.
#    Estas bibliotecas NO se compilan como WindowsStore ni con el generador de Visual Studio:
#      - MSBuild solo tiene el toolset v143 para «Application Type = UWP», no ClangCL, asi que
#        -T ClangCL + WindowsStore da «error MSB8020»; y con cl.exe fallan ultramodern y
#        recompinput por los flags -Wno-* y rabbitizer por el aviso C4146 tratado como error.
#      - los forks de worleydl las compilan asi: su CMakeSettings.json pide generador Ninja y
#        entorno clang_cl_x64, y las rutas de .lib de su uwp\CMakeLists.txt no llevan subcarpeta
#        de configuracion, que es la firma de Ninja y no la del generador de Visual Studio.
#    Lo que vuelve UWP a estas bibliotecas es la macro _UWP de los parches; el unico proyecto
#    WindowsStore de verdad es el appx del paso 5.
if (Hacer 'libs') {
    Paso 'Compilando el juego para UWP (bibliotecas estaticas)'
    Import-EntornoVS
    cmake -S $src -B "$Arbol\build-uwp" -G Ninja `
        "-DCMAKE_BUILD_TYPE=Release" "-DUWP_BUILD=ON" `
        "-DCMAKE_C_COMPILER=clang-cl" "-DCMAKE_CXX_COMPILER=clang-cl"
    cmake --build "$Arbol\build-uwp"
}

# 5. El appx, que enlaza esas bibliotecas con el paquete UWP de worleydl.
if (Hacer 'appx') {
    Paso 'Generando el appx'
    cmake -S "$src\uwp" -B "$Arbol\build-appx" -G $gen -A x64 `
        -DRECOMP_DIR="$Arbol\build-uwp"
    cmake --build "$Arbol\build-appx" --config Release
    Get-ChildItem -Recurse "$Arbol\build-appx" -Include *.appx, *.msix, AppxManifest.xml -ErrorAction SilentlyContinue |
        Select-Object FullName, Length
}

Write-Host "`nListo." -ForegroundColor Green
