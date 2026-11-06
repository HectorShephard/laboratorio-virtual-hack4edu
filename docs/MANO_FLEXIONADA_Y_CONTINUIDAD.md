# Mano flexionada, selección asistida y continuidad

Especificación vigente aplicada a la carpeta actual y rama `hector/integracion`. Los documentos anteriores de pinza y tolerancias de pérdida quedan como historial. Cambios locales, sin commit ni subida.

## Recorrer el Laboratorio 1

Abre **2_PROBAR_LAB3D.bat → Banco → Química**. Prepara el ensayo y añade bicarbonato.

- Apunta con el centro visible de la palma al cuerpo del vaso o frasco. El objeto libre se resalta. **Flexiona naturalmente índice, medio y anular para agarrar**; basta con dos dedos. Puedes flexionar encima o entrar con la mano ya flexionada. El pulgar no decide el agarre.
- Mantén la mano flexionada para mover el objeto. La selección solo decide qué agarrar; el cursor sigue tu palma. Una pose intermedia conserva el estado. **Abre los dedos para soltar**. Cada mano puede sostener un objeto diferente.
- Acerca el pico del frasco al borde resaltado del vaso. Inclina la muñeca unos 18–20° desde la postura inicial para verter. Endereza hasta 9° o menos para parar y vuelve a inclinar para continuar desde el líquido restante.
- Suelta los recipientes, observa la reacción y guarda en el cuaderno como antes. El resultado teórico usa el volumen efectivamente recibido.

El ratón conserva clic/arrastre y rueda. La pinza corta sigue disponible para controles del HUD; pulgar + medio vuelve/cierra. F3 muestra flexión, apertura, votos de dedos, estado de recuperación, coordenada de selección, candidato y objeto agarrado. La traza guarda tiempos y datos de control, sin video.

## Flexión y selección

`hand_flexion.py` mide los ángulos MCP, PIP y DIP de índice, medio y anular. Prefiere los 21 puntos `hand_world_landmarks` en 3D; usa los landmarks de imagen con relación de aspecto y Z local como alternativa. No usa la distancia al pulgar para agarrar.

Umbrales iniciales por dedo: flexionado si PIP ≥40° o MCP ≥55°; abierto si PIP ≤22°, MCP ≤35° y DIP ≤30°. Una mayoría de dos dedos, confirmada en dos **muestras nuevas**, cambia el estado. Las poses intermedias lo conservan. Geometría insuficiente pausa el control. Los umbrales son comunes a ambas manos y se probaron con rotación frontal/de canto; no se presentan como calibración física humana certificada.

El transporte mantiene `flexed`, `hand_open`, `gesture_valid`, estado y medidas por dedo para cada ID. La ruta es cámara → MediaPipe Tasks (dos manos) → HandPipeline → archivo JSON atómico → guardas de Godot → controlador por mano → selector del banco. Los estados de pinza que necesita el HUD se conservan por separado.

La selección usa el mismo raycast que el ratón. Un impacto directo tiene prioridad. Si no lo hay, elige el objeto libre con menor distancia a su silueta proyectada, con margen de **28 px** para webcam. Conserva el candidato **200 ms**, dentro de un margen de salida de **44 px**. Al perder señal brevemente conserva también ese candidato si sigue libre. Un objeto ocupado queda excluido tanto del raycast como de la asistencia.

El agarre es automático en una muestra nueva flexionada y utilizable, sin exigir apertura inicial ni un flanco de pinza. Conserva el desplazamiento X/Z y los límites de velocidad existentes. La orientación al agarrar es la referencia neutra del frasco. La asistencia no mueve ni ajusta el cursor hacia los objetos.

La captura tampoco teletransporta la altura: con webcam alcanza gradualmente la altura fija de manejo a un máximo de 1,5 unidades/s. Esa subida se congela y retoma junto al agarre durante pérdidas breves. El ratón conserva su elevación existente.

## Pérdida y vertido

Cada mano conserva pose, objeto y dueño hasta **550 ms desde su última muestra válida**, incluyendo la edad de cámara. El movimiento se congela durante la pérdida. La otra mano sigue funcionando. Recuperar la mano dentro del plazo reancla el desplazamiento y la inclinación sin mover el objeto ni volver a agarrarlo. Una apertura confirmada al recuperar tiene prioridad y lo suelta inmediatamente.

Al vencer los 550 ms se libera el objeto en su última posición, se oculta la mano y se exige una apertura real antes de habilitar otra captura. La llegada inicial de una mano ya flexionada sí puede agarrar; la recuperación tras vencimiento requiere esa apertura. Las muestras repetidas/atrasadas se descartan y ninguna pose retenida inicia un agarre o un vertido.

El chorro solo empieza con una muestra nueva utilizable y la inclinación requerida. El margen de salida de alineación es mayor que el de entrada: **0,38 / 0,30 unidades**, además de la ayuda suave cerca de la boca. Si ya estaba vertiendo y falta una mano participante, admite una cola de hasta **250 ms desde la última muestra válida**, con límite adicional de **3,125 mL** a la tasa existente de 12,5 mL/s.

Durante esa cola se comprueba de nuevo la geometría del vaso, capacidad, volumen restante y dosis. Apartar el vaso, vaciar el frasco, llenar el recipiente o detectar apertura corta la emisión. Una muestra nueva de muñeca enderezada también corta aunque la otra mano esté perdida. El tramo visual ya emitido se desvanece durante 100 ms sin sumar volumen. Cada actualización transfiere una sola cantidad, restándola del frasco y sumándola al vaso. Burbujas/reacción existentes conservan su animación.

## Pruebas con señales simuladas

Pasaron **17 pruebas Python**, incluidas mayoría de dedos, pulgar en posiciones distintas, manos izquierda/derecha, frontal/de canto, 3D y alternativa de imagen, histéresis, apertura mayoritaria, muestras únicas e identidades independientes.

`verificar_flexion.gd` usa paquetes producidos por el HandPipeline real y la escena local. Pasaron:

- Flexionar sobre el objeto y entrar ya flexionado, con `pinched=false`; apertura para soltar; mantenimiento al salir de la selección y cruzar cursores; propiedad exclusiva y prioridad entre objetos cercanos.
- Ausencias de uno/dos cuadros y pérdidas más largas; pose y dueño conservados hasta 550 ms; apertura válida que gana a la tolerancia; reanclaje sin salto; bloqueo hasta abrir al volver tras vencimiento.
- Muestras duplicadas sin iniciar agarre o chorro; una cola ya iniciada que termina con tiempo/volumen acotados; frasco vacío, vaso lleno o apartado; fin visual sin volumen adicional. El límite de cola coincide a **10, 30, 60 y 120 FPS**.
- Laboratorio completo a **25 y 50 mL** con 3 g de bicarbonato, manos intercambiadas, vertido parcial/parada/reanudación, registro y lectura desde otro proceso. Se incluyen los mL transferidos durante la cola. Los resultados fueron 20,815 y 35,711 mmol teóricos de CO₂, respectivamente.
- Arrastre, selección y vertido con ratón y rueda; aceptación de dos cursores en transporte, miniaturas y render 3D.

Se revisaron capturas gráficas de ambas manos y de la pausa con chorro. Esas capturas son de articulaciones sintéticas. Los ensayos de prueba se guardan en una bitácora separada.

Los puntos de entrada `verificar_laboratorio1.gd`, `verificar_agarre.gd` y `verificar_controles_suaves.gd` ejecutan ahora la suite vigente. Sus versiones anteriores se conservaron localmente en `registros/pruebas_previas_flexion/`; las aserciones históricas de pinza/corte inmediato ya no describen el encargo actual.

## Webcam real

Se abrió **2_PROBAR_LAB3D.bat --grip-check**. Godot recibió **1.263 fotogramas nuevos**. ID 0 tuvo 547 muestras aceptadas e ID 1 tuvo 471. La traza registró ocho capturas: cinco de frasco, dos de espátula y una de vaso. Hubo capturas del frasco con ambos IDs y **tres capturas con `pinched=false`**, usando mayoría de dedos flexionados. El vaso quedó registrado con ID 0.

La clasificación produjo 556/482 muestras geométricamente válidas por ID, de ellas 497/400 en estado flexionado y 10/10 en estado abierto. Los ángulos y votos completos están registrados para revisar los umbrales. Los intervalos guiados contaron dos aciertos para el ID 0 y ninguno para ID 1; hubo capturas fuera del objetivo/intervalo indicado. **No se confirma cumplimiento humano de las poses guiadas ni lateralidad física**. No se afirma que esos intervalos sean diez intentos deliberados correctos por mano.

Resumen: [FLEXION_WEBCAM_RESULTADO.json](FLEXION_WEBCAM_RESULTADO.json). Trazas locales: `registros/agarre-control-2925.jsonl` y `registros/manos_juego-17848-2754.jsonl`. También pasó un arranque normal final con webcam desde el lanzador, con 120 fotogramas nuevos en el intervalo de comprobación.

**Pendiente de validación humana:** repetir con izquierda/derecha físicas, frontal/de canto, entrada ya flexionada, dos objetos cercanos y uno ocupado; pérdidas cortas/largas durante agarre y vertido; abrir al recuperar; completar el ensayo sosteniendo vaso y frasco a la vez e invertir roles. La continuidad exacta y el recorrido completo con ambas manos están verificados con simulación, no certificados como ensayo humano.

## Repetir las comprobaciones

```powershell
.\.venv\Scripts\python.exe -m unittest test_hand_identity test_hand_pipeline test_camera_grip test_soft_controls test_flexion
.\.venv\Scripts\python.exe test_hand_pipeline.py --fixture
.\.venv\Scripts\python.exe test_flexion.py --fixture
$env:APPDATA = Join-Path $env:TEMP 'hack4edu-validation'
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_flexion.gd -- --mouse --explore
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_flexion.gd -- --mouse --explore --verify-read
```

Cierra esa consola al terminar para recuperar APPDATA habitual en otra consola. Para webcam guiada: `2_PROBAR_LAB3D.bat --grip-check`. La prueba sola de cámara también usa el mismo clasificador de flexión y la tolerancia de 550 ms.

Referencias consultadas: [landmarks de MediaPipe](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker) y [operaciones de Vector3 en Godot](https://docs.godotengine.org/en/stable/classes/class_vector3.html). Godot local 4.7.2 / Compatibility; el aviso de certificados de Windows en ejecución sin ventana no impidió las verificaciones.
