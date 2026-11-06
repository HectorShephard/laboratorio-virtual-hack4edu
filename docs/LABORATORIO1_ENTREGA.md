# Laboratorio 1 terminable: agarre, vertido y cuaderno

> Informe de la entrega anterior. La guía vigente con manos 3D, cámara diagonal y tolerancia de pérdidas está en [DOS_MANOS_ENTREGA.md](DOS_MANOS_ENTREGA.md).

## Cómo recorrer la demo

Abre `2_PROBAR_LAB3D.bat` para webcam o `7_RECORRER_LABORATORIO.bat` para ratón. Ve a Banco y abre Química. El menú conserva el tema de nogal.

1. Elige la dosis (25 o 50 mL), volumen inicial, capacidad, concentración y bicarbonato. El valor inicial de bicarbonato es **3 g**, para que las dos dosis produzcan resultados teóricos distintos. Pulsa **Preparar vaso y ensayo**.
2. Pulsa **Añadir bicarbonato al vaso**. El polvo aparece en el vaso y se habilita el vertido. Antes de este paso no sale líquido.
3. Agarra el vaso con una mano y el frasco con la otra; ambas tienen los mismos controles y pueden intercambiar los objetos. Abierta: apuntar/soltar. Pinza: agarrar. Una pinza corta activa un botón. Acerca la boca al vaso, gira la muñeca y sigue los mL. Hay una ayuda pequeña de alineación y el borde se ilumina cuando puede recibir. La dosis elegida se detiene automáticamente sin exceder capacidad ni volumen restante.
4. Suelta ambos objetos y pulsa **Observar reacción**. Se ven burbujas y queda preparado el resultado teórico con los mL realmente recibidos.
5. Pulsa **Ver cuaderno**, completa las anotaciones y pulsa **Anotar ensayo**. Solo después del guardado correcto aparece **Laboratorio completado**, con **Ver cuaderno** y **Repetir ensayo**.

Ratón: mantén clic izquierdo para arrastrar; rueda para inclinar/enderezar. Puedes dejar el vaso colocado y manipular el frasco. El resto de los pasos usa los mismos botones. Alcohol sigue disponible como práctica de transferencia y no genera un resultado de CO₂.

## Movimiento corregido

Los rayos de la cámara fija intersectan siempre el plano del banco **Y=0**, independientemente del objeto o la mano. Al agarrar se conserva el desplazamiento X/Z entre la intersección y el centro. La altura se fija en 1 para el frasco, 0,08 para el vaso y 0,18 para la espátula. El giro de muñeca es relativo a la orientación capturada al agarrar y no modifica el destino X/Z.

El motor limita desplazamiento a **2,2 unidades/s**, y en Z a **0,85 hacia el fondo** y **1,6 hacia el frente**, multiplicando por delta. Tras una pausa se limita delta a 0,1 s para impedir saltos. Ratón y ambas manos usan el mismo motor. Una prueba con 30, 60 y 120 FPS produjo la misma distancia al cabo de un segundo. Cursor quieto tras elevar el frasco conserva X/Z.

Se mantiene One Euro independiente por ID para cursor y ángulo, sin añadir de nuevo el filtro exponencial de Godot. Una zona de ayuda menor de 0,43 unidades aplica como máximo un sesgo de 0,075 al destino del frasco; ese ajuste también pasa por el límite de velocidad. No teletransporta ni mueve el vaso. El vertido conserva los umbrales de 45° para empezar y 35° para parar, más margen espacial distinto para inicio/parada.

## Prueba funcional con Godot local

Se ejecutó `godot/pruebas/verificar_laboratorio1.gd`, con eventos de pinza simulados sobre los controles reales de la interfaz y sin colocar directamente los objetos en la posición de vertido. La prueba recorre preparación, bicarbonato, agarres, movimiento proyectado, giro, dosis, reacción, cuaderno y guardado.

| Ensayo simulado | Mano del vaso | Mano del frasco | Vinagre recibido | Bicarbonato | CO₂ teórico | Restante de 100 mL |
|---|---|---|---:|---:|---:|---:|
| 1 | Izquierda (ID 0 del escenario) | Derecha (ID 1) | 25 mL | 3 g | 20,815 mmol | 75 mL |
| 2 | Derecha (ID 1) | Izquierda (ID 0) | 50 mL | 3 g | 35,711 mmol | 50 mL |

Los IDs y las etiquetas de este escenario son datos simulados; no se presentan como una identificación física realizada con la webcam. En el ensayo de 25 mL se interrumpió la mano del frasco a mitad del chorro: el frasco quedó congelado, no se transfirió más líquido, la otra mano siguió moviendo el vaso y reaparecer con pinza cerrada no recuperó el agarre. Abrir, agarrar y volver a inclinar permitió terminar.

También se verificaron vaso lleno sin desbordamiento, histéresis, agarre sin salto, límites de movimiento en cada paso, conservación del volumen y vertido de 25 mL con eventos de ratón y rueda. Los dos ensayos se recuperaron abriendo otro proceso de Godot y recorriendo las páginas del cuaderno. Se revisaron capturas gráficas de preparación, dosis, cuaderno y finalización. Los ensayos de prueba se guardaron en una carpeta separada de la bitácora del usuario.

## Webcam real: detector frente al juego

La prueba guiada mostró fases de izquierda sola, derecha sola, ambas cruzándose y una saliendo del cuadro. Godot recibió **818 fotogramas reales** y escribió una muestra por ID con detección cruda asignada, aceptación del juego, muñeca, etiquetas, pérdidas, saltos y cambios de época. No guarda imágenes.

| ID persistente | Detecciones asignadas | Aceptadas por Godot | Rechazos | Pérdidas en detector / juego | Saltos crudos | Cambios de etiqueta del detector |
|---|---:|---:|---:|---:|---:|---:|
| 0 | 566 | 562 | 4 | 2 / 5 | 2 | 14 |
| 1 | 417 | 412 | 5 | 4 / 4 | 0 | 16 |

Durante la fase indicada como izquierda sola, el ID activo tuvo 128/128 muestras aceptadas; durante derecha sola, el otro ID tuvo 124/124. Los criterios, calibración y acceso a objetos son idénticos. Las diferencias de pérdidas registradas no se ocultaron como si fueran detección perfecta.

El detector devolvió frecuentemente `Right` en ambas fases. Sin confirmación humana de qué mano se mostró, **no queda certificada la etiqueta física izquierda/derecha**. Por ello la etiqueta no decide acceso al vaso/frascos ni ordena los IDs por lado de la pantalla: la muñeca previa y su trayectoria mantienen la asociación, y una identidad dudosa interrumpe únicamente su controlador. La inferencia sigue sin espejo y la presentación transforma X una sola vez (`x_pantalla=1-x_detector`).

Los cambios de etiqueta o de época no son una prueba de intercambio físico. No hubo cambios de la etiqueta anclada del ID en esta captura, pero eso tampoco certifica identidad humana durante una oclusión. El recorrido completo de vertido con dos manos humanas sigue pendiente; el recorrido funcional descrito arriba se probó con señales simuladas. El ratón se probó con eventos nativos de Godot.

Resumen por fase: [LAB1_AUDITORIA_MANOS.json](LAB1_AUDITORIA_MANOS.json). Datos locales detallados: `registros/manos_juego-2028-2251.jsonl` y su `.json`. `resumir_auditoria_juego.py` reproduce el resumen. La ventana de prueba puede repetirse con `godot/pruebas/medir_manos_juego.gd`.

## Repetir las comprobaciones

Usa una carpeta APPDATA temporal para las pruebas, así se mantienen separados los datos del usuario:

```powershell
$env:APPDATA = Join-Path $env:TEMP 'hack4edu-lab1'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_laboratorio1.gd -- --mouse --explore
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_laboratorio1.gd -- --mouse --explore --verify-read
```

Godot local: 4.7.2, OpenGL Compatibility. Las pruebas sin ventana siguen mostrando el aviso de certificados de Windows ya observado; no impidió estas verificaciones. Todos los cambios permanecen locales, sin commit ni subida.
