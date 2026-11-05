# Recursos 3D para las tres prácticas

Abre `6_VER_MODELOS_3D.bat` y selecciona el modelo. Usa la barra para girarlo. Las escenas son editables en Godot y están construidas con geometría propia.

| Práctica | Escena en `godot/recursos/modelos3d/` | Qué debes preparar para integrarla |
| --- | --- | --- |
| Cohete | `cohete_agua.tscn` | Confirma con Mario proporciones y componentes. Mantén la plataforma fija y separa el cohete móvil. Usa los marcadores de agarre, boquilla y lanzamiento. Comprueba la escala y coloca un colisionador sencillo en la pieza manipulable. |
| Química | `instrumental_quimica.tscn` | Separa vaso, recipiente y espátula en objetos manipulables. Revisa el agarre y el punto de vertido. Vincula el nivel visual a las cantidades del módulo cuando se defina la calibración. Las marcas actuales ilustran la forma. |
| Biología | `sapo_exterior.tscn` | Acuerda especie, referencia y unidad de escala antes de medir. Integra los órganos identificados como piezas seleccionables en el anclaje anatómico. La maqueta actual representa el exterior. |

Los marcadores son puntos de integración. La simulación, el registro de medidas y las colisiones de cada práctica se conectan en el módulo correspondiente. Usa las proporciones actuales para revisar encuadre y legibilidad.

## Qué subir al repositorio

Versiona las escenas, scripts, texturas originales y sus fuentes o licencias. Si incorporas un recurso externo, registra autor, origen, licencia y escala en la ficha de la práctica. Conserva los archivos `.uid` que se generen para scripts que referencien las escenas. Comparte una captura o evidencia de la versión revisada por el enlace del PR. Los cachés de importación de `.godot/` se regeneran localmente.
