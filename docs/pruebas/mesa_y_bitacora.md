# Comprobación de la mesa y la bitácora

Este avance conecta la mesa al módulo técnico. La entrada de prueba entre 0 y 10 produce su doble en unidades de prueba. Ambos registros se identifican con origen `test`.

## Comprobación automática en Windows

Abre PowerShell en la carpeta del repositorio. Con Godot preparado mediante `1_PREPARAR.bat`, ejecuta una sola línea.

```powershell
.\runtime\Godot.exe --headless --path godot --script res://pruebas/verificar_integracion.gd -- --mouse
```

La prueba comprueba entradas inválidas, dos ensayos guardados y recuperados, rechazo de un guardado duplicado y apertura de la práctica desde la sala. También configura y guarda un ensayo desde los botones y recupera su nota y su resultado al volver a crear la sala. Usa un directorio de prueba independiente. Debe terminar con código 0 y sin errores de Godot. Si aparece un error, conserva la primera línea y el archivo indicado.

La prueba automática pasó en Godot 4.7.2 en Linux sin interfaz gráfica. La comprobación visual y los controles con webcam se revisan en Windows.

## Comprobación manual en Windows

1. Abre `3_COMPARAR_RATON.bat` y pulsa **Práctica de prueba**.
2. Escribe **3**, añade una pregunta o nota y pulsa **Configurar**, **Iniciar** y **Medir y guardar**. Comprueba **6 u**.
3. Pulsa **Reiniciar ensayo**, repite con **7** y comprueba **14 u**. Verifica ambos registros en la bitácora.
4. Cierra la aplicación, vuelve a abrirla y confirma que se conservan los dos registros y las notas.
5. Pulsa **Volver a la mesa** y comprueba que puedes mover el cubo. Abre después `2_PROBAR_LAB3D.bat`, pulsa E y repite la comprobación del cubo con cámara.

Registra commit, equipo, modo de entrada, resultados y problemas en el PR. El botón **Medir 60 s** pertenece a la prueba técnica de rendimiento. Los registros de ensayos se guardan por separado en `user://bitacora/ensayos/`.
