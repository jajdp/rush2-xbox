# Aviso

*(English: [NOTICE.md](NOTICE.md))*

## Sin afiliación

Esto es un proyecto de aficionado, no oficial y sin ánimo de lucro. **No está afiliado a Midway,
Warner Bros. ni Microsoft**, ni cuenta con su respaldo, ni lo está con los autores de
[N64Recomp](https://github.com/N64Recomp/N64Recomp), [RT64](https://github.com/rt64/rt64),
[`rush2recompiled`](https://github.com/bryantmh/rush2recompiled) ni de los forks UWP sobre los que se
apoya esta receta. *Rush 2: Extreme Racing USA*, *Xbox* y todos los nombres y marcas relacionados son
de sus respectivos propietarios.

Aquí no se vende nada, y nada de esto está monetizado.

## Qué no distribuye este repositorio

Ni ROM. Ni código recompilado del juego. Ni ejecutable. Ni appx. Ni partidas. Ni el bundle de
dependencias de UWP, que son binarios de otros.

## Qué contiene de trabajo de otros

**Un parche contra plume** —[`renderbag/plume`](https://github.com/renderbag/plume), **MIT**,
Copyright (c) 2024 renderbag and contributors—, la interfaz de hardware de render que RT64 usa como
submódulo propio. RT64 (MIT, (c) 2024 RT64 Contributors) y N64Recomp (MIT, (c) 2024 Wiseguy) también
son MIT, y la MIT permite versiones modificadas; este repositorio se publica bajo
[esa misma licencia](LICENSE).

**Nada de las dos bibliotecas GPL.** [N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime)
y [RecompFrontend](https://github.com/N64Recomp/RecompFrontend), que la receta también construye, son
**GPL-3.0**. Aquí no se reproduce ni una línea de ellas, y cualquier obra derivada tendría que llevar
**su** licencia y no esta — conviene saberlo antes de publicar parches propios contra ellas.

**Nada del proyecto del juego.** `bryantmh/rush2recompiled` no publica licencia, así que **aquí no se
reproduce ni una línea suya**: ni los cambios que necesita para UWP, ni su CMake, ni sus cabeceras.
Lo que hace `tools/compilar.ps1` es **dirigir** la compilación: clona, construye los recompiladores,
corre la recompilación, aplica parches que viven en los repositorios de otros y configura CMake. Las
decisiones y el razonamiento que lleva dentro son propios.

**Tampoco nada de los forks de worleydl.** La receta dice qué ramas usar y por qué; sus parches se
traen de sus propios repositorios.

**Aquí no hay capturas de pantalla.**

## Retirada y contacto

Si tienes derechos sobre este material y quieres que algo de aquí se quite o se cambie, escribe a
**jajdpmail@gmail.com**. Las peticiones de quien tiene los derechos se atienden sin discutir.
