extends SceneTree
## Alias del diagn?stico guiado que tambi?n se ofrece en el lanzador del jugador.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var lab=load("res://main.tscn").instantiate()
    root.add_child(lab)
    if lab.mouse_mode: lab._toggle_mode()
    if not OS.get_cmdline_user_args().has("--audit-hands"):
        var guide=preload("res://pruebas/hand_acceptance_guide.gd").new()
        guide.lab=lab
        lab.add_child(guide)
