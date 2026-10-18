# Rush 2 en la Xbox — el port UWP

Cómo llevar un juego de la familia **N64Recomp + RT64** a una **Xbox Series en modo desarrollador**,
usando *Rush 2: Extreme Racing USA* ([`bryantmh/rush2recompiled`](https://github.com/bryantmh/rush2recompiled))
como caso real.

*(English: [README.md](README.md))*

## En qué punto está este port

El juego **se juega en la consola**, y el único fallo visible que tenía —el cielo— resultó ser del
propio juego y desapareció al subir este port a la **v1.0.20**. Medido en una Xbox Series X:

| | |
|---|---|
| ✅ Arranca, se ve y responde al mando | Sí, desde el primer día |
| ✅ **Se juega**, a **59 FPS** | Probado por el dueño en una Xbox Series X el 2026-10-15 |
| ⚠ El cielo, casi | **Arreglado aguas arriba**, no aquí: el juego recortaba su domo contra la vista del fotograma *actual*, y su autor lo corrigió el 2026-10-13 (issue #16, commits `47e3465b` y `12262d0f`); este port va sobre la **v1.0.20**. ⚠ Queda un residuo, visto el 2026-10-18: en las curvas cerradas salen unos triángulos claros sin cielo en la **esquina superior izquierda** |
| ✅ **El tiempo de arranque** | **Resuelto el 2026-10-18**: de 5-6 minutos a **unos 20 s**, con el logo y la barra de progreso en pantalla desde el primer fotograma. Dos causas independientes, las dos contadas en [`docs/HOW-IT-WORKS.es.md`](docs/HOW-IT-WORKS.es.md): los **modos de direccionamiento del mipmap**, que hacían a RT64 generar un shader de ~200 s de creación en vez de 0,3 s, y el primer fotograma **esperando a una tubería del ubershader que ninguna llamada de dibujo usa**. Cachear una tubería sigue siendo imposible aquí —las dos vías de D3D12 matan el dispositivo—, pero resultó no hacer falta |
| ⚠ El Controller Pak | El juego ve el mando con su accesorio pero nunca abre el pak, así que lo que se guarde en una partida no se lee |
| ⚠ Las plataformas de aceleración de 2049 | No están implementadas **en el proyecto del juego**: `docs/rush2049_research/collision.md` deja la rama de colisión `0x10` para un parche futuro. En PC tampoco aceleran |

**Una línea que estaba aquí era falsa, y conviene decirlo.** Hasta el 2026-10-18 este README
afirmaba que *el tiempo de arranque es un límite de la consola, no una optimización pendiente*.
No lo era: era un shader que RT64 no debería haber generado, más una tubería que no usa nadie.
Las medidas que había detrás eran buenas; la conclusión que se sacó de ellas, no. Lo que sí
sigue en pie: **las plataformas de aceleración faltan aguas arriba, no aquí**.

## Qué es este repositorio

| Pieza | Qué es |
|---|---|
| `tools/compilar.ps1` | **La receta entera**, en cinco pasos que se pueden repetir uno a uno: clonar, construir los recompiladores, recompilar la ROM, aplicar los parches UWP y compilar las bibliotecas, y generar el appx. Con el *por qué* de cada decisión escrito al lado |
| `patches/plume-psocache-DOES-NOT-WORK.patch` | **Memoria de un callejón sin salida, no algo que aplicar.** Cachea objetos de estado de tubería en plume ([`renderbag/plume`](https://github.com/renderbag/plume), MIT), el RHI que RT64 usa como submódulo, pero llama a `ID3D12PipelineState::GetCachedBlob()`, que **mata el dispositivo D3D12** en una Xbox en modo desarrollador: el port muere a los 0,16 s de arrancar. `ID3D12Device1::CreatePipelineLibrary` falla igual, incluso pidiendo una biblioteca vacía. Se conserva porque al siguiente se le va a ocurrir lo mismo |

## Las dos cosas que hay que entender antes de intentarlo

**1. El generador de Visual Studio NO sirve para las bibliotecas del juego.** MSBuild solo tiene el
toolset `v143` para «Application Type = UWP», no `ClangCL`, así que `-T ClangCL` con `WindowsStore`
da `error MSB8020`; y con `cl.exe` se cae el ecosistema entero, que está escrito para clang
(`-Wno-*` en ultramodern y recompinput, `C4146` tratado como error en rabbitizer). Lo correcto es
**Ninja + clang-cl**, y las bibliotecas como objetivo de **escritorio**: lo que las vuelve UWP es la
macro `_UWP` de los parches. El único proyecto `WindowsStore` de verdad es el del appx.

**2. La receta sale de los forks de worleydl.** `rt64-dev` (rama `uwp-dk64`),
`N64ModernRuntime-dev` (`uwp-rebase`), `RecompFrontend-dev` (`uwp-compat`) y el bundle
[`worleydl/uwp-dep`](https://github.com/worleydl/uwp-dep). ⚠ Ese bundle **tiene una rama por
motor**: para esta familia es `rt64`, no el commit que fija el fork de Star Fox 64, cuyo `libuwp` no
exporta `uwp_PickMultipleFiles` y deja el enlazado a medias.

## Los cinco escollos del arranque

Todos salieron en la consola, y los cinco valen para el siguiente juego de la familia:

| | Qué pasa |
|---|---|
| 1 | **`SDL_INIT_HAPTIC` no existe en el SDL de WinRT**, y el juego pide todos los subsistemas de una vez comprobando `if (SDL_Init(...) > 0)`, que nunca salta porque SDL devuelve **-1**. Se queda sin vídeo y se cuelga creando la ventana. Hay que levantarlos **uno a uno** |
| 2 | **`SDL_HINT_JOYSTICK_WGI`** o no hay mando. Tercer port de este catálogo al que le pasa |
| 3 | **`FOLDERID_LocalAppData` no es `LocalState`**: en el contenedor devuelve `…\AC\<id>`, que el Device Portal no expone. Hay que devolver la ruta de `SDL_WinRTGetFSPathUTF8`. Y el modo portátil **no vale de rodeo**: el driver de vídeo WinRT de SDL cambia el directorio de trabajo al de instalación |
| 4 | **`LocalState` no existe hasta el primer arranque**: subir antes da «cannot find the path» |
| 5 | **El `stderr` del contenedor es inválido**, y escribir en él es *fail-fast*: hay que darle archivo propio. Esto es lo que mataba al juego al entrar a acrobacias, y se intercepta con `_set_invalid_parameter_handler` |

## Qué **no** es

Aquí no hay **ROM, ni código recompilado, ni ejecutable, ni appx**, ni los parches de worleydl (que
están en sus repositorios), ni el bundle de UWP. Y tampoco los cambios que el propio proyecto del
juego necesita: `bryantmh/rush2recompiled` no publica licencia, así que de su código no se copia
nada ([`NOTICE.es.md`](NOTICE.es.md)).

## Créditos y licencia

Receta y herramientas de **Recompilaciones**, bajo la [MIT](LICENSE) —la del único código de
terceros contra el que este repositorio lleva un parche,
[`renderbag/plume`](https://github.com/renderbag/plume) (el RHI que RT64 usa como submódulo), y la de
[N64Recomp](https://github.com/N64Recomp/N64Recomp) y [RT64](https://github.com/rt64/rt64)—.
[N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime) y
[RecompFrontend](https://github.com/N64Recomp/RecompFrontend), que la receta también construye, son
**GPL-3.0**, y aquí no se reproduce nada de ellas. Los forks UWP de los que sale la receta son de
**worleydl**.

*Rush 2: Extreme Racing USA* es © Midway. Este proyecto no está afiliado a ellos, ni a Microsoft, ni
a los autores de N64Recomp, RT64, el proyecto del juego o los forks UWP. Quien tenga derechos puede
escribir a **jajdpmail@gmail.com**.
