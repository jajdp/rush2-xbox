# Construir el port y meterlo en la consola

*(English: [INSTALL.md](INSTALL.md))*

⚠ **Lee la primera sección del [`README.es.md`](../README.es.md) antes de invertir una tarde en
esto.** El juego se juega a 59 FPS y el cielo está arreglado, pero un primer arranque sigue tardando
minutos y el juego nunca abre el Controller Pak.

## 0. Dónde se escriben las órdenes

En **PowerShell**, la terminal normal de Windows: tecla **Windows**, escribe `powershell`, **Enter**
sobre *Windows PowerShell*. **No hace falta administrador**; y en el paso del certificado, usarlo lo
estropea (el certificado se crea en el almacén del usuario que ejecuta la orden). **PowerShell 7 no
hace falta**, y los ejemplos llevan `-ExecutionPolicy Bypass` porque un Windows de fábrica no
ejecuta un `.ps1`.

## 1. Lo que hace falta antes

| | Para qué |
|---|---|
| **Visual Studio 2022** con las herramientas de C++ y el componente de **UWP** | El entorno de MSVC (`vcvars64`), **clang-cl**, **Ninja** y el appx |
| **Tu ROM** de *Rush 2: Extreme Racing USA* (USA) | El recompilador la traduce a C++ |
| **El bundle de UWP de worleydl**, rama **`rt64`** | SDL2, `libuwp` y `dxc` para la consola. ⚠ La rama importa: la que fija el fork de Star Fox 64 no exporta `uwp_PickMultipleFiles` y deja el enlazado a medias |
| **Git y Python 3** | Clonar, parchear y recompilar |
| **Una Xbox en modo desarrollador** y un certificado | Instalar y firmar |
| **Unos 3 GB de disco** | El árbol, los recompiladores y las compilaciones |

## 2. La receta, en cinco pasos

```powershell
powershell -ExecutionPolicy Bypass -File tools\compilar.ps1 -Arbol C:\rush2 -Rom "C:\roms\rush2.z64"
```

Eso hace los cinco pasos seguidos. Cada uno se puede repetir solo, que es lo que sirve cuando algo
falla a mitad:

| `-Paso` | Qué hace |
|---|---|
| `herramientas` | Construye `N64Recomp` y `RSPRecomp`, que el repositorio del juego no trae |
| `recompilar` | Traduce la ROM a C++ (1 596 funciones) y el microcódigo de audio |
| `parches` | Aplica los parches UWP de worleydl encima de los que el propio juego aplica a sus submódulos, y apunta plume a su variante UWP |
| `libs` | Compila el juego **como bibliotecas estáticas**, con **Ninja y clang-cl** |
| `appx` | El único proyecto `WindowsStore` de verdad: enlaza las bibliotecas y genera el paquete |

⚠ **El paso `libs` no se puede hacer con el generador de Visual Studio.** El por qué está en
[`HOW-IT-WORKS.es.md`](HOW-IT-WORKS.es.md), y es la primera cosa que hay que saber de este port.

## 3. La caché de tuberías (opcional)

```powershell
git apply --directory=<ruta de plume> patches\plume-psocache.patch
```

Es el primer paso contra los 3-4 minutos de cada arranque. No está terminado: ver el estado en el
README.

## 4. Instalarlo en la consola

### Antes de tocar nada: cómo tiene que estar la consola

- **En modo desarrollador**, con Dev Home instalado. - **Encendida y con tu perfil iniciado.**
  ⚠ Sin un usuario conectado, la consola **no abre aplicaciones**. - **En la misma red**, con
  su dirección a mano. El Device Portal escucha en el puerto **11443** por HTTPS, y pide el
  usuario y la contraseña que definiste en Dev Home.

Abre `https://<ip>:11443`. ⚠ El navegador avisará de que el certificado del sitio no es de
confianza: es el de la propia consola. Entra igual — en Edge y Chrome, **Avanzado** → **Continuar
a … (no seguro)**; en Firefox, **Avanzado** → **Aceptar el riesgo y continuar**. Después, en
**My games & apps → Add**, tu paquete.

## 5. La ROM y los datos, dentro del paquete

⚠ **`LocalState` no existe hasta el primer arranque.** Si subes antes, el portal responde que no
encuentra la ruta. Así que: instala, **abre el juego una vez**, ciérralo, y entonces sube la ROM con
el **File explorer** del portal.

Y ⚠ **`FOLDERID_LocalAppData` no es `LocalState`**: dentro del contenedor devuelve una carpeta que
el Device Portal no expone, así que el port tiene que pedir la ruta a SDL. El modo portátil no vale
de rodeo, porque el driver de vídeo de WinRT cambia el directorio de trabajo al de instalación.

## Si algo no sale bien

| Síntoma | Causa |
|---|---|
| `error MSB8020` al compilar las bibliotecas | Se intentó con el generador de Visual Studio: hay que usar Ninja + clang-cl ([`HOW-IT-WORKS.es.md`](HOW-IT-WORKS.es.md)) |
| El enlazado deja `uwp_PickMultipleFiles` sin resolver | El bundle de UWP es de la rama equivocada: para esta familia es `rt64` |
| Arranca sin vídeo y se cuelga creando la ventana | `SDL_INIT_HAPTIC`: hay que levantar los subsistemas uno a uno |
| No responde ningún botón | Falta `SDL_HINT_JOYSTICK_WGI` |
| El portal no encuentra la ruta al subir la ROM | `LocalState` no existe hasta el primer arranque (§5) |
| Se cierra a mitad de una carrera, sin mensaje | El `stderr` del contenedor es inválido y escribir en él es *fail-fast*: hace falta `_set_invalid_parameter_handler` y un archivo propio para el registro |
| Cada arranque tarda 3-4 minutos | Conocido: RT64 recompila las tuberías en cada arranque (§3) |
| El cielo sale negro en una pista | Conocido y sin resolver: el domo llega al display list y no al framebuffer |


## Reinstalar: tres cosas que muerden

1. **El appx sale de MSBuild sin firmar.** La consola responde «The app package must be digitally
   signed for signature validation» (`0x800B0100`). Se firma con un certificado autofirmado cuyo
   **subject sea exactamente el `Publisher` del manifiesto** —eso es lo que conserva el package
   family name, y por eso la consola lo trata como actualización y respeta `LocalState`—:
   `signtool sign /fd SHA256 /sha1 <huella> <msix>`.
2. **Instalar la misma versión desinstala el paquete** en vez de actualizarlo. Hay que subir el
   `Identity Version` del manifiesto antes, y anclar la expresión regular que lo hace
   (`\sVersion="…"`), porque `MinVersion` contiene `Version`.
3. **La caché de shaders de una compilación anterior no vale.** Se borra
   `LocalState\shadercache\` y el juego la rehace. El primer arranque siguiente tarda minutos, con
   la barra de carga sobre el logo.
