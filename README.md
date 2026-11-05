# Laboratorio virtual de ciencias

Duelistas del Tamarindo · Hack4Edu · Reto 17

Desarrollamos un laboratorio virtual 3D para estudiantes y docentes con acceso limitado a materiales e instrumentos científicos. El prototipo actual permite recorrer la sala y manipular un cubo en la mesa con seguimiento de manos o con el ratón.

## Abrir el prototipo en Windows

1. Instala Python de 64 bits. El instalador del proyecto busca Python 3.13, 3.12 o 3.11.
2. Ejecuta `1_PREPARAR.bat` con internet para instalar las dependencias y descargar Godot y el modelo de seguimiento.
3. Ejecuta `2_PROBAR_LAB3D.bat`. Usa WASD para recorrer la sala y E o Tab para ir a la mesa.
4. Acerca el cursor al cubo y haz una pinza con el pulgar y el índice para agarrarlo. Abre la mano para soltarlo.

Usa `3_COMPARAR_RATON.bat` para probar la mesa con el ratón y `4_PROBAR_CAMARA_SOLA.bat` para revisar la cámara. [LEEME.txt](LEEME.txt) describe los controles, las mediciones de rendimiento y el diagnóstico.

## Trabajar en equipo

| Rama | Trabajo |
| --- | --- |
| `main` | Base compartida y cambios revisados. |
| `hector/integracion` | Núcleo, interacción, interfaz, bitácora y tutor. |
| `mario/experimentos` | Experimentos, modelos, recursos científicos y casos de comprobación. |

Con el remoto `origin` configurado, actualiza tu rama con la base de `main` antes de comenzar. Este ejemplo corresponde a Héctor.

```bash
git switch hector/integracion
git fetch origin
git merge origin/main
```

Publica los avances en tu rama y abre una solicitud de cambios hacia `main`. Indica qué cambió, cómo se prueba y qué revisión necesita tu compañero. Usa Teams para compartir el enlace a la solicitud y las evidencias de la demostración.

## Primer hito

Acordar las entradas, las unidades y la salida de la primera práctica científica. Mario prepara el modelo y sus casos de referencia. Héctor conecta la práctica con la mesa y registra las mediciones en la bitácora.
