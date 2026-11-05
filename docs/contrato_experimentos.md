# Contrato de experimentos v1

Propuesta de Héctor para revisión científica con Mario. La mesa controla la sesión y la bitácora. Cada práctica aporta su escena, sus entradas y su modelo.

## Interfaz del módulo

La raíz es un `Node3D`. El adaptador llama a estos métodos.

| Método | Entrada y resultado |
| --- | --- |
| `describe()` | Diccionario de metadatos. Se puede llamar antes de añadir la escena al árbol. |
| `configure(parameters)` | Valida los campos y rangos. Devuelve `{"ok": true}` o `{"ok": false, "error": "explicación"}`. |
| `start_run(run_id)` | Inicia un ensayo configurado. Devuelve el mismo formato de éxito o error. |
| `measure()` | Devuelve un diccionario con `quantity`, `value`, `unit` y, si corresponde, `time_s`. Usa `value: null` mientras el resultado esté pendiente. |
| `reset_run()` | Borra el estado del ensayo. La bitácora conserva los registros ya guardados. |

El módulo declara `state_changed(state)` y `measurement_taken(data)` para notificar cambios. En esta primera mesa, el botón **Medir y guardar** consulta `measure()` en el momento que el estudiante elige.

## Metadatos y unidades

`describe()` entrega `experiment_id`, `title`, `model_version`, `source`, `validity` y `parameters`. Cada parámetro numérico tiene `id`, `label`, `unit`, `min`, `max`, `step` y `default`. `assumptions` y `reference_ids` conservan los límites y las fuentes. El módulo valida nuevamente las entradas recibidas desde cualquier interfaz.

Usen SI para los cálculos y el registro. Documenten conversiones de pantalla. El cohete propone `water_volume_m3` como primera variable y presión absoluta en `pressure_pa` cuando se exponga. Antes de fijar los controles, Mario debe entregar el rango, las condiciones fijas, la magnitud que se medirá y casos con valores esperados. Para química se acordarán las cantidades, concentración y condiciones del CO₂. Para biología se fijarán especie, fuente, escala y estructuras medibles.

## Registro de la bitácora

El esquema 1 guarda un JSON por ensayo. Incluye `schema_version`, `experiment_id`, `run_id`, `model_version`, `parameters`, `quantity`, `value`, `unit`, `source`, `validity`, `time_s`, `assumptions`, `reference_ids`, `question`, `hypothesis`, `notes`, `conclusion` y `saved_at_utc`. La bitácora se guarda en `user://bitacora/ensayos/`, separada de los informes de rendimiento.

Los datos de comprobación de interfaz llevan `source: "test"` y `validity: "prueba"`. Un modelo de práctica lleva `source: "simulation"` y validez explícita según la revisión científica. Un resultado pendiente se muestra como tal. La mesa guarda la medición final al pulsar **Medir y guardar**.

## Revisión del primer módulo

1. Mario publica la ficha, los parámetros y el caso de referencia. Ambos acuerdan nombres, unidades y tolerancia.
2. Héctor prueba configuración, inicio, medición y reinicio usando el módulo técnico.
3. Mario prueba el módulo científico por separado. Héctor lo conecta con la mesa tras la revisión.
4. Ambos ejecutan dos ensayos, comparan la pantalla y la bitácora con los casos y recuperan los registros después de reiniciar.
