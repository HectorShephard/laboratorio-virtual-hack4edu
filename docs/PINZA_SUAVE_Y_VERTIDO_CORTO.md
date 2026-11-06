# Pinza suave e inclinación corta

> Historial. El agarre vigente usa flexión y las nuevas tolerancias se describen en [MANO_FLEXIONADA_Y_CONTINUIDAD.md](MANO_FLEXIONADA_Y_CONTINUIDAD.md).

Aplicado localmente en la rama actual `hector/integracion`. Esta entrega ajusta el agarre y el vertido con webcam. Conserva las dos manos, el ratón y el recorrido del Laboratorio 1.

## Probar

Abre `2_PROBAR_LAB3D.bat` → **Banco → Química**. Prepara el ensayo y añade bicarbonato como antes.

1. Separa pulgar e índice para armar la mano y apunta la palma al **cuerpo** del vaso o frasco. El objeto se resalta.
2. Acerca los dedos con una **pinza suave**, sin tocar las puntas. Mantén esa separación para mover. Abre claramente los dedos para soltar. Cada mano puede sostener un objeto diferente.
3. Acerca el frasco al vaso hasta ver el borde resaltado. Esto lo deja listo y ayuda a alinear el pico, pero **no vierte sin inclinación**.
4. Inclina unos **18–20°** hacia cualquiera de los lados desde la postura que tenías al agarrar. Endereza a **9° o menos** para parar. Vuelve a inclinar para continuar desde el volumen restante. Apartar, soltar o perder la mano corta el chorro.

F3 mantiene la depuración disponible. El ratón conserva su selección, arrastre y rueda existentes.

## Ajustes

- Pulgar–índice en 3D: cierra por debajo de **0,50** y abre por encima de **0,75** de la escala robusta de palma. Alternativa 2D: **0,55 / 0,80**. Se conservan dos muestras nuevas de confirmación y el seguimiento independiente por mano. La pinza pulgar–medio conserva sus umbrales anteriores.
- Margen de selección con webcam: **24 px** alrededor del cuerpo proyectado. El candidato se conserva hasta **160 ms** durante el cierre, siempre que siga libre y a menos de **40 px**. El ratón conserva su margen previo de 18 px. Cerrar lejos consume el intento hasta abrir; nadie puede robar un objeto ocupado.
- Vertido con webcam: inicio **18°**, parada **9°**. La referencia angular sigue siendo la postura capturada al agarrar. La ayuda actúa al acercar o inclinar; agarrar con la mano quieta conserva la posición X/Z. El pico debe estar sobre el interior del vaso. La tasa, capacidad, dosis y conservación de volumen existentes siguen limitando la transferencia.
- Tras perder seguimiento, se conserva el requisito de enderezar antes de reanudar. El ratón conserva sus umbrales anteriores de 45°/35°.

## Verificado con simulación

`test_soft_controls.py` recorre ambas manos, 2D y 3D, frontal y de canto. Comprueba que una separación de 0,45 de la escala de palma cierra la pinza sin tocar las puntas, que aumentar a 0,65 conserva el agarre y que separar a 0,95 lo libera. La otra mano mantiene su propio estado.

`godot/pruebas/verificar_controles_suaves.gd` usa la escena actual, su proyección y sus objetos. Comprueba:

- Resaltado antes de cerrar, margen ampliado, candidato conservado al desplazarse un poco y propiedad exclusiva.
- Vaso con ID 0 y frasco con ID 1, y luego al revés. Referencias neutras distintas por mano: 55° y −35°. Inclinación relativa corta en ambos sentidos.
- Frasco cerca y sin inclinar: borde listo, cero transferencia. A 17° todavía no empieza; a 18° inicia en el modelo, a 20° vierte en la escena; a 9° para en el modelo y a 8° para en la escena.
- Vertido parcial, parada y reanudación; mover el vaso con la otra mano; frasco alejado; soltar; pérdida de seguimiento y recuperación. En todos los casos se conserva recibido + restante = 100 mL.
- Selección y vertido con ratón y rueda.

Las pruebas previas de agarre, identidad y Laboratorio 1 también pasaron. Los ensayos de 25 y 50 mL siguieron calculando CO₂ con el volumen recibido y guardándose en el cuaderno.

## Webcam real

Se ejecutó **`2_PROBAR_LAB3D.bat --grip-check`** con esta versión. Godot recibió **2.040 fotogramas nuevos**. La traza registró **siete capturas del frasco**, cuatro con ID 0 y tres con ID 1. Hubo capturas con razones 3D de **0,39–0,44**, superiores al antiguo umbral de cierre 0,30, lo que confirma que la pinza ampliada llegó al selector real.

No hubo confirmación humana de que se siguieran las orientaciones/intervalos indicados. La prueba guiada no contó aciertos dentro de sus objetivos asignados. Solo dos cuadros tuvieron ambas manos aceptadas al mismo tiempo en esta captura; no se presenta como una validación física simultánea. **Vaso y frasco simultáneos, roles físicos invertidos y vertido real corto/parada/reanudación quedaron probados solo con simulación y siguen pendientes de una persona con webcam.**

Datos: [CONTROLES_SUAVES_VERIFICACION.json](CONTROLES_SUAVES_VERIFICACION.json). Coordenadas y estados, sin video: `registros/agarre-control-3067.jsonl` y `registros/manos_juego-18468-2900.jsonl`.

Para la comprobación manual pendiente, recorre los cuatro pasos de arriba sosteniendo vaso y frasco con manos distintas, detén el vertido a mitad y retómalo, y repite invirtiendo manos, incluida la palma de canto.

## Repetir las pruebas técnicas

```powershell
.\.venv\Scripts\python.exe -m unittest test_hand_identity test_hand_pipeline test_camera_grip test_soft_controls
$env:APPDATA = Join-Path $env:TEMP 'hack4edu-validation'
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_controles_suaves.gd -- --mouse --explore
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_laboratorio1.gd -- --mouse --explore
```

Las pruebas usan una bitácora aparte. Cierra esa consola al terminar para recuperar APPDATA habitual. Godot local 4.7.2; el aviso de certificados de Windows en modo sin ventana no afectó estas comprobaciones. Cambios locales, sin commit ni subida.
