# Dos manos articuladas · Laboratorio 1

> La corrección posterior de cámara, pinza y tolerancias 200/400 ms está documentada en [CORRECCION_CAMARA_AGARRE.md](CORRECCION_CAMARA_AGARRE.md). Este documento conserva el estado de la entrega anterior.

Entrega local sobre `hector/integracion`, conservando los cambios existentes. No se aplicó código de otra copia ni se hizo commit o push.

## Recorrer la práctica

Abre **2_PROBAR_LAB3D.bat** con webcam o **7_RECORRER_LABORATORIO.bat** con ratón. Entra en **Banco → Química**. Entrada y Estante siguen disponibles.

1. Elige 100 mL iniciales de vinagre, concentración 5 %, bicarbonato 3 g y dosis 25 mL. Pulsa **Preparar vaso y ensayo → Añadir bicarbonato al vaso**.
2. Muestra ambas manos abiertas. **ID 0 ámbar** y **ID 1 azul** tienen palma y cinco dedos articulados. El anillo de la palma es la zona de interacción. Apúntalo al objeto y junta pulgar e índice para agarrar. Cualquiera puede tomar vaso o frasco; la etiqueta estimada Left/Right no restringe el acceso.
3. Mantén la pinza para mover. Acerca el pico al vaso y gira la muñeca respecto a la postura inicial del agarre. El borde del vaso se ilumina y una ayuda pequeña facilita alinearlo. Endereza o aparta el frasco para parar; vuelve a inclinar para continuar. Abrir pulgar e índice suelta únicamente ese objeto.
4. Al llegar a la dosis aparecen **25 % vertido · 75 mL restantes**, además de la capacidad libre del vaso. Suelta ambos objetos y pulsa **Observar reacción → Ver cuaderno**.
5. Completa las anotaciones y pulsa **Anotar ensayo**. Aparece **Laboratorio completado**. Pulsa **Repetir ensayo**, elige 50 mL e invierte las manos. **Ver cuaderno** permite comparar los registros.

Ratón: clic izquierdo sostenido para arrastrar y rueda para inclinar/enderezar. Coloca el vaso y después manipula el frasco. Se conservan los botones y teclas 1/2/3, C y B. Una pinza corta activa un botón; pulgar + dedo medio vuelve/cierra; mano abierta con desplazamiento lateral pasa páginas. Una pinza ocupada por un objeto no activa el HUD.

**Pérdida:** se congelan las acciones de esa mano y se corta el chorro. Su objeto queda reservado durante **0,65 s**. Si vuelve con pinza, reancla el agarre sin salto. Hay que **enderezar el frasco** para habilitar otro vertido. Una ausencia más larga libera el objeto en su última posición y exige mano abierta antes del siguiente agarre. La otra mano sigue respondiendo. Perder el vaso también detiene el vertido hacia él.

Alcohol conserva la práctica de transferencia con **100 mL iniciales configurables**. El porcentaje vertido y la concentración se registran por separado; no se calcula CO₂ para alcohol.

## Cambios en esta copia

Ya existían `num_hands=2`, IDs y transporte de dos manos. El antiguo `num_hands=1` no estaba presente. Sin embargo, la miniatura sobrescribía los puntos con la última mano y una pérdida soltaba inmediatamente el objeto. La compatibilidad de un cursor se calculaba aparte con `hand_landmarks[0]`.

`hand_pipeline.py` centraliza las dos detecciones, estados de pinza y filtros One Euro independientes. La asociación usa continuidad de muñeca y lateralidad como apoyo, nunca orden de detecciones ni orden en pantalla. La histéresis es 0,35 / 0,55, con dos observaciones de confirmación. Durante una pérdida breve conserva la pinza. Una asociación dudosa pausa el controlador. Los campos del banco antiguo proceden ahora del ID 0 estable; el garaje y las miniaturas consumen todo el arreglo `hands`.

El cursor sigue el **centro de palma**, que no cambia al cerrar la pinza. Godot no vuelve a filtrar la posición recibida. El ángulo tiene su propio filtro y considera ancho/alto de captura. La inferencia usa imagen sin espejo y la presentación transforma X una sola vez. Se consultó la documentación oficial de [Hand Landmarker Python](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker/python) y [lateralidad](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker). La identidad física sigue requiriendo observación humana cuando el detector fluctúa.

Las manos se dibujan como mallas 3D independientes con palma, 21 articulaciones y segmentos de dedos en un viewport transparente. El Z de MediaPipe solo da relieve local a la representación: **no mueve objetos en profundidad**. La zona visible de palma coincide con el punto de interacción; cambia al agarrar y se atenúa durante pérdidas breves.

El banco usa cámara fija ortográfica, elevada y diagonal, dentro del garaje. Reserva el tercio derecho al panel y usa el corte de techo ya disponible. Se conservan garaje, banco único, luces, sombras y cuaderno. La cámara de escena es independiente de la captura de webcam.

El arrastre intersecta el plano Y=0 y conserva el desplazamiento inicial X/Z. Límites: 2,2 unidades/s y, en Z, 0,85 hacia el fondo / 1,6 hacia delante, multiplicados por delta. La inclinación es independiente. Los rayos excluyen objetos reservados por la otra mano para que no bloqueen la selección de un objeto situado detrás.

La ayuda de alineación actúa dentro de 0,52 unidades con un sesgo máximo de 0,10 al destino, sometido al mismo límite de velocidad. Histéresis espacial de vertido: 0,30 / 0,38; angular: 45° / 35°. Dosis, capacidad y líquido restante limitan la transferencia.

## Comprobación simulada en Godot local

`verificar_laboratorio1.gd` recorrió menú, preparación, bicarbonato, agarres, desplazamiento, vertido, reacción, cuaderno y reinicio mediante controles reales con señales de mano **simuladas**. Las figuras de mano de las capturas de verificación son también simuladas.

| Ensayo | Vaso | Frasco | Recibido | Bicarbonato | CO₂ teórico | Restante |
|---|---|---|---:|---:|---:|---:|
| 1 | ID 0, izquierda del escenario | ID 1, derecha | 25 mL | 3 g | 20,815 mmol | 75 mL |
| 2 | ID 1, derecha del escenario | ID 0, izquierda | 50 mL | 3 g | 35,711 mmol | 50 mL |

El cálculo usa los mL **recibidos**, no el volumen inicial ni la dosis solicitada. Con 25 mL se agota antes el ácido; con 50 mL se agota antes el bicarbonato. Otra ejecución de Godot recuperó ambos ensayos y sus páginas del cuaderno. Los datos de prueba están separados de los ensayos del estudiante.

También pasaron: propiedad exclusiva, dos manos 3D simultáneas, agarre sin salto, velocidad equivalente a 30/60/120 FPS, arrastre sobre HUD, vertido parcial/parada/reanudación, frasco lejos y vacío, vaso lleno, conservación, pérdida breve y prolongada del frasco, pérdida del vaso y reanclaje sin salto. Ratón y rueda completaron 25 mL con eventos nativos simulados. La integración de bitácora recuperó también registros técnicos anteriores.

Las nueve pruebas Python cubren entrada en ambos órdenes, orden alternado, etiquetas fluctuantes, cruces, oclusión, filtros y conservación de pinza durante pérdidas breves. Una secuencia JSON del mismo `HandPipeline` se verificó también en recepción de Godot → guardas → controladores → ambas manos 3D.

## Webcam real

Se ejecutó `prueba_camara.py --check` con `.venv`. **2_PROBAR_LAB3D.bat --test-exit 10** recibió 240 fotogramas nuevos. Después, **2_PROBAR_LAB3D.bat --audit-hands** usó el mismo supervisor, archivo atómico y escena del jugador para la prueba guiada.

Esta segunda ejecución recibió **1.288 fotogramas**: MediaPipe produjo dos detecciones en **446**, y Godot aceptó ambos IDs simultáneamente en **433**. Entrar una segunda detección no sustituyó sistemáticamente a la primera.

| ID | Asignadas | Aceptadas | Pérdidas aceptadas | Cambios de etiqueta cruda | Saltos aceptados >0,14 entre cuadros consecutivos |
|---|---:|---:|---:|---:|---:|
| 0 | 1.094 | 1.081 | 12 | 41 | 0 |
| 1 | 507 | 499 | 15 | 168 | 0 |

Las seis fases indicaban izquierda sola, derecha sola, entradas en ambos órdenes, cruce y pérdida temporal. **No hubo confirmación humana de qué mano física se mostró en cada fase.** Las etiquetas fluctuaron; una etiqueta anclada sin cambios no demuestra ausencia de intercambios físicos. El diagnóstico inhibe acciones para evitar clics involuntarios: **no valida un vertido humano ni agarres físicos con roles invertidos**. Eso quedó probado con señales simuladas.

Resumen: [DOS_MANOS_AUDITORIA_REAL.json](DOS_MANOS_AUDITORIA_REAL.json). Datos completos, sin fotos ni video: `registros/manos_juego-9416-1989.jsonl` y `.json`. La medición anterior sigue en `LAB1_AUDITORIA_MANOS.json`.

**Paso manual pendiente:** completa los pasos 1–5 con izquierda en el vaso y derecha en el frasco. Cruza las manos manteniendo la pinza; oculta una menos de 0,65 s y luego más de 0,65 s, comprobando que la otra responde. Repite a 50 mL invirtiendo roles. Confirma visualmente que cada color sigue a la misma mano y que ambos registros aparecen al cerrar y reabrir. Para repetir solo el diagnóstico: `2_PROBAR_LAB3D.bat --audit-hands`.

## Repetir las pruebas técnicas

```powershell
.\.venv\Scripts\python.exe -m unittest test_hand_identity test_hand_pipeline
.\.venv\Scripts\python.exe test_hand_pipeline.py --fixture
$env:APPDATA = Join-Path $env:TEMP 'hack4edu-validation'
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_laboratorio1.gd -- --mouse --explore
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_laboratorio1.gd -- --mouse --explore --verify-read
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_integracion.gd -- --mouse --explore
```

Cierra esa consola al terminar para recuperar APPDATA habitual en la próxima. Godot local 4.7.2 / OpenGL Compatibility. El aviso de certificados de Windows en modo sin ventana no impidió las pruebas locales.
