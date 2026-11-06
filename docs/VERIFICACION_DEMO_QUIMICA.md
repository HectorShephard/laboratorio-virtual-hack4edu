# Verificación de la demo de química

Fecha local: 5 de noviembre de 2026. Proyecto revisado directamente sobre los cambios locales. Godot utilizado: 4.7.2, OpenGL Compatibility; Python de `.venv`, MediaPipe 0.10.35.

## Medición real de estabilidad

Se capturaron fotogramas reales sin guardar imágenes. La primera captura se hizo antes de modificar el seguimiento (`registros/estabilidad_antes.json`): no detectó una mano durante su primera fase y la fase de dos manos incluyó movimiento; no sirve como referencia válida de reposo. Se repitió la medición con la señal cruda y One Euro calculadas simultáneamente sobre los mismos fotogramas.

La fase final de una mano contiene 149 fotogramas consecutivos con exactamente una mano. La fase de dos manos contiene 149 fotogramas con exactamente dos manos: aproximadamente cinco segundos cada una. Las métricas incluyen movimiento residual de la mano y ruido del detector, no una precisión absoluta del dispositivo.

Escala: viewport 1100×720, incluida la expansión `(coordenada − 0,1) / 0,8` del cursor del garaje. Esto corrige los números preliminares de consola que no incluían ese margen.

| Señal en reposo | RMS crudo → One Euro (px) | Salto entre fotogramas, P95 crudo → One Euro (px) | Filtro anterior reproducido, P95 (px) |
|---|---:|---:|---:|
| Una mano, ID 0 | 2,970 → 2,501 | 3,813 → 0,724 | 1,207 |
| Dos manos, ID 0 | 2,371 → 2,037 | 2,689 → 0,450 | 0,805 |
| Dos manos, ID 1 | 2,581 → 1,360 | 6,039 → 0,964 | 1,649 |

La columna del filtro anterior es una **reproducción** de la suavización exponencial de 75 ms con las mismas muestras y tiempos; no una segunda captura de un programa anterior. El resultado One Euro se midió en vivo. Comparado con esa reproducción, el P95 baja aproximadamente 40 %, 44 % y 42 % respectivamente. El filtro adaptativo admite más movimiento rápido para reducir retraso: no se interpreta la fase de cruce como temblor en reposo.

Los resúmenes están en [verificacion_demo_quimica.json](verificacion_demo_quimica.json). Los datos numéricos completos permanecen en `registros/estabilidad_antes.json`, `registros/estabilidad_despues.json` y `registros/estabilidad_una_mano.json`. `resumir_estabilidad.py` reproduce los resúmenes.

## Cruces, identidad y espejo

En la fase real de cruce hubo 147 fotogramas: 66 con dos manos, 80 con una y uno sin manos. Se registraron dos cambios de orden horizontal y dos interrupciones por ID. Eso confirma cambios de orden en la imagen y pérdidas de detección, **no demuestra ni descarta por sí solo un intercambio físico de identidad**. No hay una anotación humana externa que permita certificarlo. Los desacuerdos entre etiquetas del detector tampoco se cuentan como intercambios: durante el reposo una etiqueta fluctuó sin reasignar el ID.

El detector asocia por la muñeca previa y una predicción corta de velocidad. La lateralidad tiene peso secundario. No ordena IDs por posición izquierda/derecha en la pantalla. La superposición ambigua conserva los estados anteriores y emite pérdida de seguimiento antes que adjudicar un objeto a otra mano. El objeto se congela, el chorro se corta y hace falta abrir la mano para rearmar; la otra mano conserva su control.

La inferencia se hace con la imagen sin espejo. Las coordenadas de muñeca, cursor y landmarks se espejan una sola vez para la presentación. La etiqueta del detector no se invierte de nuevo. Esto sigue la indicación del [Hand Landmarker actual de MediaPipe](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker?tab=Web); no se mezcla con la convención de la API Hands antigua. Queda pendiente confirmar con la mano física izquierda/derecha del usuario la interpretación de las etiquetas en su webcam.

One Euro se instancia por ID para cursor y orientación, siguiendo el [algoritmo de Casiez y colaboradores](https://gery.casiez.net/publications/CHI2012-casiez.pdf). El cursor usa corte mínimo 1,25 Hz, beta 3 y derivada a 1 Hz. Se reinicia tras pérdida; Godot evita aplicar encima la antigua suavización de 75 ms. Cada ID tiene también su pinza independiente: cierra por debajo de 0,35 y abre a partir de 0,55, con dos observaciones de confirmación.

## Vertido y ensayos comprobados

La prueba `godot/pruebas/verificar_dos_manos.gd` pasó con señales simuladas y eventos nativos de ratón:

- Vaso y frasco agarrados por manos distintas; cruce de cursores con **cero intercambios de objetos**.
- Orientación al agarrar como neutra; giro relativo de muñeca y ratón con rueda.
- Inicio del flujo a 45°; continúa por encima de 35°; parada a 35° o menos. Tras parar, debe superar de nuevo 45°. Un temblor 44°/46° no produce parpadeo.
- Boca sobre el interior del vaso, con margen espacial de inicio/parada; una boca dirigida hacia fuera no vierte aunque esté cerca.
- Frasco inicial de 100 mL, transferencia de 25 mL y 75 mL restantes. Reanudación desde el volumen restante, parada al enderezar o apartar y limitación por vaso lleno.
- Pérdida de una mano a mitad del vertido: objeto congelado, chorro detenido, reaparecer con pinza cerrada no toma el control. La otra mano continúa moviendo su objeto.
- Arrastre sobre el HUD sin activar botones; pinza corta, cerrar y páginas del cuaderno.
- Ratón: agarrar, arrastrar, inclinar con rueda, transferir 25 mL y soltar.
- Dos ensayos de vinagre al 5 % m/v con 1 g de bicarbonato: 5 mL vertidos ≈ 4,163 mmol de CO₂; 20 mL vertidos ≈ 11,904 mmol. Cantidades y resultado teórico guardados en la bitácora y recuperados al abrir otro proceso de Godot.
- Alcohol registrado solo como transferencia de volumen, sin atribuirle una reacción de CO₂.

También pasaron los cinco casos Python de identidad, ambigüedad, pinza y filtrado, y la integración de la bitácora anterior. El arranque final con webcam entregó nuevos fotogramas a Godot en la vista del garaje y mostró los IDs 0 y 1. Se revisaron capturas gráficas del tema nogal y del cuaderno.

Godot emitió el aviso ya existente sobre el almacén de certificados de Windows durante las pruebas sin ventana; no impidió estas comprobaciones.

## Qué falta comprobar con el usuario

La medición del detector sí es real. El vertido completo y los intercambios de objetos se verificaron con señales simuladas y ratón. Queda una prueba humana de extremo a extremo con dos manos: agarrar, cruzarlas sosteniendo los objetos, inclinar sobre el vaso y sacar una mano de cámara durante el chorro. No se certifica identidad física tras una oclusión completa; se interrumpe el control ante duda.

Arranque: `2_PROBAR_LAB3D.bat` con webcam o `7_RECORRER_LABORATORIO.bat` con ratón. Banco → Química → seleccionar líquido y preparar → verter → soltar → Mezclar/Registrar → Cuaderno → Anotar ensayo. Los datos de las pruebas se aislaron en una carpeta temporal; el cuaderno del usuario permanece en su bitácora habitual.
