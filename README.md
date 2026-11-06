# Laboratorio virtual de ciencias

Duelistas del Tamarindo · Hack4Edu · Reto 17

Laboratorio virtual 3D para estudiantes y docentes con acceso limitado a materiales e instrumentos científicos. La versión actual conserva las tres estaciones dentro de un garaje de experimentación y permite completar el **Laboratorio 1: Vinagre y bicarbonato**, con dos manos independientes o con ratón, cuaderno persistente y asistente local de química.

## Abrir el prototipo en Windows

1. Instala Python de 64 bits. El instalador del proyecto busca Python 3.13, 3.12 o 3.11.
2. Ejecuta `1_PREPARAR.bat` con internet para instalar las dependencias y descargar Godot y el modelo de seguimiento.
3. Ejecuta `2_PROBAR_LAB3D.bat` para usar webcam. Para probar sin cámara, ejecuta `7_RECORRER_LABORATORIO.bat`.
4. Selecciona **Banco** y **Química** en el HUD. Las teclas **1/2/3** cambian entre Entrada, Banco y Estante; **C** abre Química y **B** el Cuaderno.

La vista fija del banco es diagonal. El garaje mantiene el banco de madera único y el menú con tema de nogal. Los modos de recorrido y mesa de pruebas anteriores siguen disponibles; **Tab** alterna con la mesa del cubo.

## Completar el Laboratorio 1

1. Elige volumen inicial, capacidad del vaso, concentración, bicarbonato y dosis. Por defecto: frasco de **100 mL**, vaso de **150 mL**, vinagre al **5 % m/v**, bicarbonato **3 g** y dosis **25 mL**. Pulsa **Preparar vaso y ensayo**.
2. Pulsa **Añadir bicarbonato al vaso**.
3. Apunta con la palma al vaso o frasco y **flexiona los dedos** para agarrarlo. También puedes acercarte con la mano ya flexionada. Cada mano puede sostener un objeto; **abre la mano** para soltarlo. La pinza corta activa botones del HUD.
4. Acerca el pico del frasco al vaso hasta resaltar su borde e inclina la muñeca respecto a la postura de agarre. Los umbrales actuales son **18° para empezar** y **9° para parar**. Enderezar, alejar o abrir detiene el vertido; los mL transferidos y restantes se actualizan en vivo.
5. Suelta los recipientes y pulsa **Observar reacción**. El cálculo usa el vinagre que realmente entró al vaso. Las burbujas son ilustrativas y el CO₂ se expresa como estimación teórica en **mmol**.
6. Abre **Ver cuaderno**, completa tus notas y pulsa **Anotar ensayo**. Solo tras el guardado correcto aparece **Laboratorio completado**. Puedes consultar el registro o **Repetir ensayo**.

Con ratón, mantén clic izquierdo para arrastrar y usa la rueda para inclinar/enderezar el frasco. El vaso puede quedar apoyado mientras mueves el frasco. Durante pérdidas breves de cámara se conserva el agarre hasta unos 550 ms; un chorro ya iniciado tiene una cola acotada de hasta 250 ms, contabilizada una sola vez. Al vencer la tolerancia debes mostrar la mano abierta antes de volver a agarrar. Detalles en [Mano flexionada y continuidad](docs/MANO_FLEXIONADA_Y_CONTINUIDAD.md).

El selector de alcohol conserva la práctica de transferencia de volumen; no genera un resultado de CO₂.

## Asistente de química y cuaderno

**Asistente de química** abre un panel cerrable con historial breve, preguntas y accesos **¿Qué hago ahora?**, **¿Qué significa el resultado?** y **Modo pruebas**. Funciona sin internet, cuentas ni claves. Sus reglas consultan datos de solo lectura del ensayo activo: no manipulan objetos, ejecutan mezclas ni registran resultados. El estudiante realiza todas las acciones.

El asistente distingue cantidades preparadas y realmente usadas, explica el reactivo limitante y confirma el registro solo tras la respuesta del cuaderno. Al reiniciar deja de presentar el resultado anterior como actual. Escribir en sus campos no activa atajos del juego. Se activa únicamente en Vinagre y bicarbonato del Laboratorio 1.

El cuaderno conserva los ensayos en `user://bitacora/ensayos`, dentro de los datos de usuario de Godot. Consulta [la guía del asistente](docs/ASISTENTE_QUIMICA.md) y [Cuaderno y química](docs/CUADERNO_Y_QUIMICA.md).

## Comprobación y diagnóstico

- `4_PROBAR_CAMARA_SOLA.bat`: detector de hasta dos manos sin Godot. Cierra el laboratorio antes de abrir esta prueba.
- `2_PROBAR_LAB3D.bat --assistant-check --test-exit 10`: arranque con webcam, práctica y asistente abiertos.
- `2_PROBAR_LAB3D.bat --grip-check`: recorrido guiado de agarre con diagnóstico. **F3** alterna la superposición de control.
- `3_COMPARAR_RATON.bat` y `5_IR_A_LA_MESA.bat`: mesa del cubo conservada para comparar controles.
- `registros/inicio_directo.log` y `registros/godot_directo.log`: arranque y recepción de fotogramas. El HUD ofrece **Reintentar webcam** y **Webcam / ratón**.

Con Godot local se verificaron dos ensayos completos, guardado, recuperación y reinicio mediante señales simuladas y controles de ratón. La suite del asistente comprobó **45 consultas sin fallos**. A 5 % m/v, 50 mL de vinagre con 3 g producen **35,711 mmol** teóricos (bicarbonato limitante); con 5 g, **41,631 mmol** (ácido acético limitante). La rama actual rechaza 0 mL y cantidades negativas.

En el arranque más reciente del asistente, la webcam real entregó **60 fotogramas nuevos** a Godot. El recorrido completo con dos manos humanas, intercambio de roles y consulta del panel durante el agarre sigue pendiente de validación presencial. Los resultados simulados y los de cámara se separan en [el informe de verificación](docs/ASISTENTE_QUIMICA_VERIFICACION.json). [LEEME.txt](LEEME.txt) resume instalación y recuperación.

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

## Modelo y recursos

La práctica activa usa `vinagre-bicarbonato` y el modelo `godot/core/chemistry_model.gd`. El modelo centraliza fórmula, unidades, valores iniciales, límites y validación; la interfaz y el asistente reutilizan esos datos. Los recursos del garaje se incluyen en `godot/recursos/garaje/`.

El [contrato de experimentos](docs/contrato_experimentos.md) documenta el intercambio entre modelo y laboratorio. Las guías del prototipo anterior se conservan como referencia; los controles vigentes están descritos arriba y en las entregas enlazadas.

Abre `6_VER_MODELOS_3D.bat` para revisar y girar los modelos del cohete, el instrumental de química y el sapo exterior. Consulta [los recursos 3D](docs/modelos/recursos_3d.md) para preparar su integración.
