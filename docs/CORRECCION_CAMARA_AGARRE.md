# Corrección de cámara y agarre

Aplicada en la carpeta actual y rama `hector/integracion`, conservando los cambios locales. El trabajo se centra en captura, estabilidad y agarre. Se mantienen el laboratorio, los reactivos, el cuaderno, los modelos y el vertido existente.

## Revisar el resultado

Abre `2_PROBAR_LAB3D.bat`, entra en **Banco → Química** y pulsa **F3**. F3 activa/desactiva una superposición y una traza numérica en `registros/agarre-control-*.jsonl`. No guarda video ni imágenes de la cámara.

Cada mano muestra ID, presencia en detector, aceptación del juego, utilidad de la muestra, edad, razón y representación de pinza, apertura/cierre, estado armado, coordenada final en viewport, objeto bajo la palma, objeto agarrado y motivo del último fallo. La cruz marca el punto exacto utilizado por el selector. Las figuras de mano y el selector comparten esa coordenada. Los colores ámbar/azul identifican IDs persistentes; Left/Right sigue siendo una estimación del detector.

**Mano abierta:** separa pulgar e índice hasta que la depuración indique `armada:true`. No es necesario extender los otros tres dedos. Apunta al cuerpo resaltado del vaso o frasco y cierra la pinza. Una pinza cerrada lejos del objeto consume ese intento: abre antes de otro. Mantén la pinza para mover, abre para soltar. Ratón usa el mismo selector y mantiene arrastre con clic y rueda para inclinar.

Para repetir la comprobación guiada: `2_PROBAR_LAB3D.bat --grip-check`. Son diez intervalos de cuatro segundos por ID, alternando vaso/frasco y orientación frontal/de canto. Sigue el **ID y color indicados**, abre entre intentos y revisa el resultado en `registros/agarre-webcam-intentos.json`. La prueba no confirma automáticamente que una persona siguiera las instrucciones ni certifica lateralidad física.

## Fallos comprobados y correcciones

- La guarda rechazaba una mano con 21 puntos porque el ancho 2D 5–17 era menor de 0,015. Ahora valida varias longitudes muñeca–nudillos y ancho, incluyendo Z local finito. La prueba de ocho cuadros de canto pasa. Un cuadro vacío seguido del mismo centro ya no genera `reacquired`. La ruta del garaje ya tenía un filtro propio por ID; el reinicio del cursor por `reacquired` estaba en la ruta antigua de una mano.
- La razón de pinza dependía del ancho proyectado. Se reprodujo sintéticamente una mano de canto con razón antigua mayor que 1 y razón robusta menor que el umbral de cierre. Ahora se prefieren `hand_world_landmarks` válidos: distancia pulgar–índice / escala robusta de palma en 3D. Si faltan, usa píxeles con relación de aspecto y varias referencias de tamaño.
- Umbrales iniciales por representación: **3D 0,30/0,48**, **2D 0,35/0,55**, con dos cuadros nuevos de confirmación. Se registran razón actual, antigua, representación, escala y estado abierto/cerrado para calibración física posterior. No se afirman umbrales calibrados con poses humanas confirmadas.
- El agarre exigía extensión de los cuatro dedos. Ahora una apertura confirmada de pulgar–índice arma el intento. La pinza índice tiene prioridad sobre la de dedo medio; volver/cerrar solo acepta el gesto medio con índice separado. Así la transición de cerrar índice no activa prematuramente el gesto de volver.
- Cada mano mantiene filtro de ancla, filtro de ángulo, dedos relativos, pinza e identidad independientes. Ancla: muñeca y nudillos. One Euro: **min_cutoff 1 Hz, beta 3**, con tiempo real entre muestras únicas. No reinicia por un cuadro vacío. Godot interpola linealmente entre muestras durante 16–50 ms y no añade otro filtro IIR de cursor. Los dedos se filtran respecto a la palma para que su temblor no mueva el ancla.
- Se separan muestra utilizable, pose visible y propiedad del objeto. Ante ausencia se congela el movimiento y se corta el flujo. Última pose visible hasta **200 ms**, reserva de objeto hasta **400 ms** por mano. Recuperar un agarre vigente recalcula el desplazamiento sin mover el objeto; si venció, exige abrir/cerrar. La otra mano conserva su control. Las muestras retenidas no producen flancos, clics ni agarres.
- Se descartan secuencias repetidas/atrasadas por sesión y muestras viejas; una sesión nueva de cámara no reutiliza un agarre anterior. La selección deja de actuar con una muestra cuya edad de cámara supera 200 ms. El puente informa a Python qué IDs sostienen objetos, para pausar asociaciones ambiguas en vez de reasignarlas.
- La selección reutiliza el raycast del ratón. El margen de 18 px se mide alrededor del cuerpo proyectado completo del collider, en vez de un círculo alrededor de su centro. Conserva el candidato durante hasta 100 ms al cerrar si sigue cerca y libre. Un objeto ocupado no puede ser robado.
- `4_PROBAR_CAMARA_SOLA.bat` y `prueba_camara.py` seguían con una mano. Ahora usan **dos manos y el mismo HandPipeline**, imagen sin espejo en inferencia y espejo aplicado una vez en presentación. Cada ID tiene su ficha, cursor y pinza. ESPACIO inicia una traza numérica.

Referencias consultadas: [resultado de Hand Landmarker](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker), [ajuste del filtro 1 €](https://gery.casiez.net/1euro/) y [raycast desde Camera3D](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html).

## Verificado con señales simuladas

Trece pruebas Python pasaron. En Godot local, `verificar_agarre.gd` obtuvo **10/10 agarres por ID** alternando vaso y frasco, frontal/de canto. Probó ausencias de uno y dos cuadros, pose retenida, liberación tras 400 ms, reanclaje sin salto, muestras duplicadas, cierre lejos del objeto, prioridad índice/medio, cruce con ambos objetos agarrados y cambio de orden sin cambiar dueños. La guarda aceptó ocho cuadros consecutivos de una palma angosta y no reinició por una ausencia.

La prueba de `verificar_laboratorio1.gd` mantuvo los ensayos de **25 y 50 mL**, roles invertidos, cálculo teórico con volumen recibido, parada/reanudación, cuaderno y guardado. Ratón y rueda siguieron seleccionando y completando 25 mL mediante eventos nativos simulados. Las capturas de F3 usan articulaciones sintéticas.

## Webcam real: resultados y límites

Se ejecutaron `.venv\Scripts\python.exe prueba_camara.py --check`, `4_PROBAR_CAMARA_SOLA.bat --test-exit 8`, el lanzador normal con `--test-exit 10` y `2_PROBAR_LAB3D.bat --grip-check`. La prueba sola abrió la cámara con dos IDs. El último arranque recibió **180 fotogramas nuevos** sin errores de script.

En la prueba guiada la traza registró capturas reales del **frasco con ambos IDs**, además de la espátula. **No se alcanzó ni se certifica el objetivo de 9/10 agarres deliberados por mano.** El fichero de intervalos dio 0/10 por ID para el objetivo/ID/intervalo asignado: en varios intervalos no estaba la mano indicada; hubo capturas en otros intervalos. No hubo confirmación de cumplimiento humano ni de qué mano física correspondía a cada ID. También hubo cierres sin candidato y cierres sin apertura previa después de una pérdida.

Resumen numérico: [AGARRE_WEBCAM_RESULTADO.json](AGARRE_WEBCAM_RESULTADO.json). Traza: `registros/agarre-control-3028.jsonl`. Detector y razones: `registros/manos_juego-11876-2853.jsonl`. Intentos: `registros/agarre-webcam-intentos.json`. No se ocultan esas limitaciones bajo los resultados simulados.

Se midieron fases de cinco segundos antes y después, pero las trayectorias tuvieron movimiento y pérdidas: **no son una certificación de mano quieta**. La fase de una mano pasó de P95 4,721 px antes a 10,835 px después, sobre movimientos distintos; no demuestra mejoría ni empeoramiento atribuible al filtro. En la fase de dos manos, un ID pasó de 1,719 a 0,963 px, también sobre muestras distintas. Se conservan ambos registros completos en `registros/estabilidad_antes.json` y `estabilidad_despues.json`.

Para aislar el filtro se repitieron las **mismas muestras previas**: P95 de desplazamiento entre muestras 4,722 → 4,646 px para una mano; 1,719 → 1,527 px en una de las series de dos manos. En la otra serie, con movimiento grande, 14,982 → 14,308 px. Beta 0 se ensayó primero; beta 3 redujo el tiempo de respuesta al 90 % de un escalón sintético de 400 a 67 ms, antes de interpolación de render. Son resultados de replay/simulación, no latencia física de webcam. Datos: [AGARRE_FILTRO_METRICAS.json](AGARRE_FILTRO_METRICAS.json).

**Pendiente de una persona:** seguir los diez intentos por color/ID con ambas orientaciones y confirmar al menos nueve aciertos por mano; mantener realmente una mano quieta cinco segundos; repetir izquierda, derecha y ambas, movimientos lentos/rápidos; comprobar roles físicos, verter parcialmente y guardar un ensayo usando ambas manos reales. Las correcciones de software y pruebas sintéticas están hechas; la aceptación física completa sigue pendiente.

## Repetir comprobaciones técnicas

```powershell
.\.venv\Scripts\python.exe -m unittest test_hand_identity test_hand_pipeline test_camera_grip
.\.venv\Scripts\python.exe test_hand_pipeline.py --fixture
$env:APPDATA = Join-Path $env:TEMP 'hack4edu-validation'
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_agarre.gd -- --mouse --explore
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_laboratorio1.gd -- --mouse --explore
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_laboratorio1.gd -- --mouse --explore --verify-read
```

Las pruebas de cuaderno usan otra carpeta de bitácora. Cierra esa consola al terminar para recuperar APPDATA habitual. Godot local 4.7.2; el modo sin ventana muestra el aviso de certificados de Windows ya observado. Todos los cambios quedan locales, sin commit ni subida.
