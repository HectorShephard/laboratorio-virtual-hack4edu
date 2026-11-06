# Asistente local del Laboratorio 1

Implementado sobre la carpeta actual y rama `hector/integracion`, conservando el trabajo integrado. Esta guía acompaña la actualización del Laboratorio 1 en esa rama.

## Abrirlo

Ejecuta `2_PROBAR_LAB3D.bat` con webcam o `7_RECORRER_LABORATORIO.bat` con ratón. Entra en **Banco → Química → Asistente de química**. También hay un acceso en el encabezado del cuaderno cuando está activo el Laboratorio 1.

El panel tiene un historial breve, un campo de pregunta corta y tres accesos:

- **¿Qué hago ahora?**: un paso según la fase y los controles realmente disponibles.
- **¿Qué significa el resultado?**: medición actual, cantidad usada, limitante y carácter teórico.
- **Modo pruebas**: un caso a la vez. Escribe **siguiente caso** para avanzar. Vuelve a pulsar el botón o escribe **modo normal** para salir.

El panel ocupa la zona izquierda y puede tapar parte del banco; **Cerrar** o **Esc** lo aparta con una acción. Los controles de la práctica siguen a la derecha. Abrirlo, preguntar o activar Modo pruebas no prepara, mueve, mezcla ni guarda nada. El estudiante ejecuta las acciones. Escribir en el campo del asistente y en otros campos de texto no dispara B, C, E, Q, R, 1/2/3 ni F3. La pinza corta del HUD puede activar sus controles, también sobre el cuaderno; el agarre de objetos sigue usando mano flexionada.

## Qué práctica tiene esta rama

No existen aquí `godot/experimentos/acetato.gd` ni el identificador `quimica_vinagre_bicarbonato` de la copia de referencia. El Laboratorio 1 activo es **Vinagre y bicarbonato**, con identificador **`vinagre-bicarbonato`**, modelo **`estequiometria-5mv-v1`** en `godot/core/chemistry_model.gd`.

El recorrido vigente es **Preparar vaso y ensayo → Añadir bicarbonato al vaso → verter la dosis → Observar reacción → Ver cuaderno → Anotar ensayo → Repetir ensayo**. El frasco comienza con 100 mL por defecto; la dosis inicial es 25 mL, el vaso tiene 150 mL, la concentración predeterminada es 5 % m/v y el bicarbonato 3 g. Son configurables.

Los controles actuales son palma visible para apuntar, flexión para agarrar y apertura para soltar; inclinación relativa de muñeca para verter, con umbrales 18°/9°. Ratón: clic/arrastre y rueda. El asistente toma los ángulos del controlador y los nombres de los botones de sus nodos. Si el encuadre no permite seleccionar recipientes, indica volver a Banco antes de agarrar.

La práctica de transferencia de **alcohol** no activa este asistente. Biología y física tampoco lo activan.

## Arquitectura y límites

- **Modelo y esquema único:** `chemistry_model.gd` conserva la reacción ideal 1:1 y centraliza el identificador, versión, unidades, valores iniciales, rangos de preparación y validación. La interfaz y los casos de prueba leen ese esquema. No se copió la fórmula al asistente.
- **Hechos de solo lectura:** `chemistry_panel.expert_snapshot()` construye una copia recursivamente inmutable con identificador de sesión, fase, valores seleccionados y preparados, mL usados/restantes, validación, última medición del ensayo, estado del cuaderno, acciones disponibles y modo de control. No incluye funciones que permitan actuar sobre la escena.
- **Reglas:** `core/chemistry_expert.gd` recibe únicamente esos hechos. Reconoce frases españolas sobre pasos, materiales, unidades, cantidades, verter/mezclar, resultado, registro, consulta y reinicio. Fuera de alcance vuelve a la práctica; ante ambigüedad ofrece opciones. Las preguntas puntuales se responden aunque la fase sea otra.
- **Identidad:** cada preparación/reinicio tiene una sesión nueva. La medición y los estados de registro solo se exponen si su `lab1_session` coincide con esa sesión. El cuaderno confirma después de que `Journal.save()` devuelva éxito. Un fallo conserva el borrador, expone el mensaje real y permite reintentar. Repetir invalida el resultado y la confirmación anterior.
- **Interfaz:** `ui/chemistry_assistant.gd` mantiene la conversación en memoria y la reinicia al cambiar de ensayo. El modo de pruebas conserva solo el caso seleccionado; compara con la medición del ensayo actual. Si las cantidades no corresponden al caso, lo indica. Sus botones solo hacen consultas.

Funciona sin internet, cuentas, claves ni servicios de conversación. Las respuestas son reglas locales; no interpreta libremente cualquier materia. Las burbujas se describen como ilustración, separadas de los mmol teóricos calculados por el modelo.

## Casos ejecutados con Godot local

Se ejecutó `godot/pruebas/verificar_asistente.gd` con la escena, controles de interfaz y señales de mano simuladas. Completó dos ensayos mediante preparación, agarre, vertido, observación y registro. Los parámetros se introducen para la prueba; las consultas del asistente se comprueban antes/después para confirmar que no los cambian.

| Caso | Resultado observado |
|---|---|
| 50 mL realmente vertidos, 3 g, vinagre al 5 % | **35,7113097718 mmol** de CO₂ teórico; **bicarbonato** limitante |
| 50 mL realmente vertidos, 5 g, vinagre al 5 % | **41,6305868248 mmol** de CO₂ teórico; **ácido acético** limitante |
| 0 mL y 3 g | **Rechazado en esta rama**: la dosis de interfaz empieza en 1 mL y el modelo de medición exige volumen usado mayor que cero. No se inventa una medición cero |
| 50 mL y −1 g | SpinBox limita la entrada; se registra el rechazo del dato escrito y el asistente informa **Bicarbonato, g, 0,1–20**. El modelo también rechaza bicarbonato negativo |
| Cuaderno/reinicio | Confirmación solo tras guardado exitoso; consulta disponible; sesión nueva sin medición ni confirmación anterior |

El caso cero se adaptó a la implementación activa: la versión de referencia aceptaba cero, pero esta rama ya lo rechazaba. No se cambió el modelo para fingir ese resultado.

También pasaron:

- Resultado antes de observar: pendiente; unidades antes de preparar; cantidades durante vertido; pregunta de fotosíntesis fuera de alcance; pregunta ambigua con opciones.
- Modo pruebas: esperado calculado por el modelo, observado pendiente o medido, cambio de caso, salida del modo y detección de cantidades que no corresponden al caso.
- Campo inválido con mensaje/rango real, tanto al pulsar Enter como al cambiar el foco después de escribir −1; fallo de guardado inyectado mediante una bitácora de prueba y reintento exitoso, sin confirmación falsa.
- Panel abierto/cerrado con botones reales; acceso desde cuaderno; pinza de HUD simulada sobre el panel; escritura sin atajos; apertura/consulta sin soltar objetos agarrados.
- Dos registros sin duplicados causados por la conversación y limpieza del contexto después de reiniciar. La instantánea y sus diccionarios anidados son de solo lectura.

El informe final contiene **45 consultas verificadas** y **0 fallos**: [ASISTENTE_QUIMICA_VERIFICACION.json](ASISTENTE_QUIMICA_VERIFICACION.json). El diálogo completo de la prueba está en `registros/asistente-aceptacion.json`. Los registros de prueba usan una bitácora separada de los ensayos del estudiante.

También pasó la suite vigente de agarre/vertido de 25/50 mL y ratón, y la prueba de integración de bitácora. Godot local 4.7.2 / OpenGL Compatibility; el aviso de certificados de Windows en modo sin ventana no impidió estas comprobaciones.

## Escena gráfica y webcam

Se abrió la escena gráfica con `verificar_asistente.gd --capture` y se revisaron capturas del panel y las confirmaciones de guardado. El panel y los botones caben en la ventana de 1100×720; se comprobó que al cerrarlo se pueden mover los objetos y terminar el ensayo. Esas manipulaciones usaron señales simuladas y eventos nativos de ratón.

Se ejecutó **`2_PROBAR_LAB3D.bat --assistant-check --test-exit 10`** con webcam real. Abrió Química y el panel, respondió **«Pulsa Preparar vaso y ensayo»** usando el control de la escena y recibió **60 fotogramas nuevos**. No se ejecutaron mezclas ni guardados desde esa consulta.

**Pendiente de una persona con webcam:** conversar/cerrar el panel mediante gestos físicos mientras sostiene los recipientes y completar un ensayo real de principio a fin. La recepción de cámara y apertura del asistente se comprobaron; la manipulación completa se verificó con simulación y ratón.

## Repetir las comprobaciones

```powershell
.\.venv\Scripts\python.exe test_hand_pipeline.py --fixture
.\.venv\Scripts\python.exe test_flexion.py --fixture
$env:APPDATA = Join-Path $env:TEMP 'hack4edu-validation'
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_asistente.gd -- --mouse --explore
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_laboratorio1.gd -- --mouse --explore
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_integracion.gd -- --mouse --explore
```

Cierra esa consola al terminar para recuperar APPDATA habitual en otra consola. Para comprobar la interfaz con webcam desde el lanzador: `2_PROBAR_LAB3D.bat --assistant-check --test-exit 10`. Para usarla normalmente, abre el lanzador sin esos argumentos.
