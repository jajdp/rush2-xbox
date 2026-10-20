# Cómo funciona, y por qué de esta manera

*(English: [HOW-IT-WORKS.md](HOW-IT-WORKS.md))*

## La decisión que define el port: Ninja y clang-cl, no Visual Studio

Un juego de la familia **N64Recomp + RT64** no se compila como un `.exe` y se empaqueta: se compila
como **bibliotecas estáticas** con `-DUWP_BUILD=ON`, y un segundo proyecto —el del appx— las enlaza
y produce el paquete.

Y esas bibliotecas **no se pueden compilar con el generador de Visual Studio**. Las dos razones, las
dos medidas:

- **MSBuild solo tiene el toolset `v143` para «Application Type = UWP», no `ClangCL`.** Pedir
  `-T ClangCL` con `WindowsStore` da `error MSB8020` y ahí se acaba.
- **Y con `cl.exe` se cae el ecosistema entero**, que está escrito para clang: `ultramodern` y
  `recompinput` usan `-Wno-unused-parameter`, y `rabbitizer` dispara `C4146`, que MSVC trata como
  error.

Lo correcto es **Ninja + clang-cl**, con las bibliotecas como objetivo de **escritorio**, no
`WindowsStore`. Lo que las vuelve UWP es la macro **`_UWP`** de los parches. El único proyecto
`WindowsStore` de verdad es el del appx, con `v143`, que solo compila su `main.cpp` y enlaza.

Se reconoce en el molde del que sale la receta: su `CMakeSettings.json` pide generador Ninja y
entorno `clang_cl_x64`, y las rutas de sus `.lib` **no llevan subcarpeta de configuración**, que es
la firma de Ninja y no la del generador de Visual Studio. Y hay que importar el entorno de MSVC
(`vcvars64.bat`) antes de llamar a cmake, porque clang-cl y Ninja lo necesitan.

## De dónde sale la receta

De los forks de **worleydl**: `rt64-dev` (rama `uwp-dk64`), `N64ModernRuntime-dev` (`uwp-rebase`),
`RecompFrontend-dev` (`uwp-compat`) y el bundle `worleydl/uwp-dep`.

⚠ **El bundle tiene una rama por motor**, y equivocarse cuesta una tarde: para esta familia es
`rt64`, no el commit que fija el fork de Star Fox 64, cuyo `libuwp` no exporta
`uwp_PickMultipleFiles` y deja el enlazado a medias.

## Los cinco escollos del arranque

Todos valen para el siguiente juego de la familia, y están aquí en el orden en que aparecieron:

**1. `SDL_INIT_HAPTIC` no existe en el SDL de WinRT.** Y el juego pide todos los subsistemas de una
vez, comprobando el resultado con `if (SDL_Init(...) > 0)` — que **nunca salta**, porque SDL
devuelve **-1** cuando falla. Resultado: el juego se queda sin vídeo y se cuelga creando la ventana,
sin un mensaje. El arreglo es levantar los subsistemas **uno a uno** desde el envoltorio antes de
entrar al juego; `SDL_Init` lleva cuenta de referencias, así que no molesta.

**2. `SDL_HINT_JOYSTICK_WGI`, o no hay mando.** Tercer port de este catálogo al que le pasa, lo que
lo convierte en paso fijo: ponerla y comprobar el mando por el registro antes de dar nada por
terminado.

**3. `FOLDERID_LocalAppData` no es `LocalState`.** Dentro del contenedor devuelve `…\AC\<id>`, que
el Device Portal **no expone**: lo que se guarde ahí no se puede subir ni bajar. Hay que devolver la
ruta de `SDL_WinRTGetFSPathUTF8`. Y el **modo portátil no vale de rodeo**, que fue lo primero que se
intentó: el driver de vídeo WinRT de SDL cambia el directorio de trabajo al de instalación.

**4. `LocalState` no existe hasta el primer arranque.** Subir antes da «cannot find the path», que
parece un fallo del portal y no lo es.

**5. El `stderr` del contenedor es inválido, y escribir en él es *fail-fast*.** Esto es lo que
mataba el juego al entrar a una carrera de acrobacias: no había excepción, ni volcado, ni mensaje —
el proceso simplemente desaparecía—. Se intercepta con `_set_invalid_parameter_handler` y dándole al
registro un archivo propio.

## Lo que está resuelto y lo que no

El port se juega; lo que queda conviene tenerlo delante:

| | |
|---|---|
| ✅ Arranca, se ve, suena y responde al mando | |
| ✅ **Se juega**: el cierre de las acrobacias era el escollo 5 | |
| ✅ El Controller Pak **se carga** | El juego ve el mando con su accesorio pero **nunca llama a `osPfsInitPak`**, así que el `.mpk` del `LocalState` no lo abría nadie. Ahora se carga desde el bucle de dibujado en cuanto el runtime tiene lista su ruta, sin esperar al juego |
| ✅ Una lista de shaders que se alimenta sola | Con ella el juego pasó de vivir 47 s a 218 s en la prueba de acrobacias, y la segunda entrada a una pista carga de golpe |
| ✅ **El arranque** | **Resuelto el 2026-10-18**: de 5-6 minutos a **unos 20 s**, y sin pantalla negra antes del logo. Eran los **modos de direccionamiento del mipmap**, que hacían a RT64 generar un shader de ~200 s de creación, más el primer fotograma **esperando a una tubería del ubershader que no usa nadie** (sección siguiente). Cachear una tubería sigue siendo imposible aquí —las dos vías de D3D12 matan el dispositivo— y resultó no hacer falta |
| ✅ **El cielo** | Arreglado al subir a la v1.0.20 del juego: era el propio juego, que recortaba su domo contra la vista del fotograma actual, y su autor lo corrigió el 2026-10-13 |
| ⚠ **Los récords del Controller Pak** | Los de fábrica salen, pero el juego sigue sin abrir el pak: lo que se guarde en una partida no se lee |
| ⚠ La suspensión del modo desarrollador | Al volver de Home, el juego empieza de nuevo |


## El arranque: nunca fue la consola

Hasta el 2026-10-18 este documento decía que un primer arranque tarda minutos porque el driver
necesita 180-190 s para construir cuatro de las tuberías, y que no hay forma de cachear una en esta
consola. La segunda mitad es cierta. La primera era un síntoma: el coste estaba en el shader que se
le entregaba al driver.

**Eran los modos de direccionamiento del mipmap.** En el RDP es normal que los niveles altos del
mipmap vengan marcados CLAMP mientras los bajos van en WRAP: en un nivel de dos téxeles no hay nada
que repetir. RT64 compara los modos de *todos* los niveles antes de usar un sampler nativo:

```cpp
// rt64_state.cpp — si un nivel no coincide, sameModes se vuelve false, se descarta el sampler
// nativo y el shader sale con una rama por muestreo.
for (uint32_t t = 1; (t < callDesc.tileCount) && sameModes; t++) { … }
```

En una Xbox Series X ese shader con ramas cuesta **~200 s** de creación de tubería, frente a **0,3 s**
el normal. En este juego siete de ellos se comían **1 337 s de los 1 448 s** del arranque.
Instrumentado para que diga *qué* nivel no cuadra y *en qué campo*, el patrón es siempre el mismo:
`fmt` y `siz` coinciden en todos y solo cambian `cms`/`cmt` de los altos. Tomando el modo del nivel
0 para todos, el shader más caro pasa de **262 s a 8,8 s** y la imagen sale idéntica: lo que se
pierde es el direccionamiento de niveles de un par de téxeles, a una distancia donde no se ve.

**Y la pantalla negra previa al logo era el ubershader.** `State::fullSync()` hace `join()` de los
hilos que crean sus ocho tuberías antes de renderizar nada:

```cpp
// rt64_state.cpp, antes de dibujar un workload
ext.rasterShaderCache->shaderUber->waitForPipelineCreation();   // join() de los hilos de creacion
```

La primera de esas ocho cuesta aquí **26,8 s**; las otras siete salen gratis, porque comparten el
bytecode y el driver reutiliza lo que compiló (RT64 serializa la primera a propósito justo por
eso). Mientras el hilo del juego está en ese `join` no hay workload, así que no hay present — y sin
present no hay logo, ni interfaz, ni barra de carga. **Eso es la pantalla negra.** Quitando la
espera, y dejando que una llamada de dibujo que necesite el ubershader se descarte hasta que esté
listo, el primer fotograma pasa a **~0 s** y el juego arranca en **~22 s** en vez de ~50. Lo único
que no se puede hacer es leer el array de tuberías mientras sus hilos lo escriben: la espera hay que
sustituirla por un `std::atomic<bool>` que esos hilos pongan con `release` y se consulte con
`acquire` antes de tocar nada.

**Cómo saber qué tubería es la cara.** Se apunta el tamaño del bytecode junto al tiempo de creación
—`psoDesc.PS.BytecodeLength`— y se cruza con los tamaños de los `.dxil` compilados. Eso es lo que
le puso nombre a la de 26,8 s: `RasterPSDynamic`, 52 016 bytes, el ubershader.

**Y contar antes de creerse una captura.** Un contador de las llamadas de dibujo que caen al
ubershader marca **cero** en todos los arranques medidos, también en el original: con los shaders
especializados sanos no hace falta, así que esos 27 segundos se gastaban en una tubería que no pinta
ni un triángulo. Ese mismo contador corrigió por el camino una lectura equivocada de una captura
—una escena oscura tomada por geometría sin dibujar, que era sencillamente la pista nocturna del
juego—. **Una captura dice qué se ve, no por qué.**

## Subir el port a una versión nueva del juego

Hecho una vez, a través de **88 commits** del proyecto original (v1.0.12 → v1.0.20, 237 archivos).
Es la parte que nadie escribe, así que queda aquí.

**Lo primero: mirar si el fallo que persigues ya está arreglado aguas arriba.** El cielo que este
port enseñaba roto era un fallo del propio juego, cerrado dos días después de que clonáramos el
árbol. Bajar la release oficial y abrirla con las ROMs en una carpeta aparte lo resuelve en minutos.

1. **Clonar la etiqueta nueva en un árbol nuevo** (`compilar.ps1 -Version v1.0.20`), conservando el
   viejo como referencia.
2. **Mirar si las bibliotecas se movieron** (`git ls-tree <tag> lib/`). Si `rt64`,
   `N64ModernRuntime` y `RecompFrontend` siguen en el mismo commit —nuestro caso—, los parches
   valen y el salto es barato.
3. **No mezclar los `.patch` como texto.** Mezclarlos a tres vías dio **39 conflictos** solo en el
   de rt64. El delta se saca **por código**: el diff entre «commit base + el parche del autor de la
   versión vieja» y el estado del árbol viejo. Eso es lo de worleydl más lo tuyo, y se aplica sobre
   la versión nueva con `git apply -p1 --reject`.
4. **Copiar lo que no vive en ningún parche**: la carpeta `uwp\` y los archivos que añadieras al
   juego.
5. **Guardar el parche de cada submódulo** con `py tools/lib_patch.py save`, o el CMake del juego se
   niega a configurar con «lib/patches/x.patch doesn't apply to lib/x».
6. **Compilar y contar con errores de enlace nuevos**: la v1.0.20 pidió `hid.lib` y `ws2_32.lib` en
   el proyecto del appx, porque el CMakeLists del juego las enlaza contra un ejecutable que con
   `UWP_BUILD=ON` no se produce.
7. **Firmar, subir la versión, instalar.** El appx sale sin firma; la versión del manifiesto tiene
   que subir antes de reinstalar; y en la consola queda `LocalState\shadercache\` con blobs de los
   shaders viejos.

De todo eso salieron cuatro conflictos, y los cuatro se resolvieron **combinando, no eligiendo**: el
bloque de CMake (nuestra envoltura `if (NOT UWP_BUILD)` alrededor de las bibliotecas nuevas del
autor), dos en `main.cpp` (su `lock_guard` de los mandos delante de nuestro bloque UWP; su modo
simulación con nuestra traza detrás) y dos hunks de cabecera cuyas líneas vecinas se habían movido.
