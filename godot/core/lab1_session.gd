extends RefCounted
enum Step { PREPARE, BICARBONATE, POUR, OBSERVE, REGISTER, COMPLETED }
const Model=preload("res://core/chemistry_model.gd")
var step := Step.PREPARE
var target_ml:float=Model.INPUTS.target_ml.default
var bicarbonate_g:float=Model.INPUTS.bicarbonate_g.default
var session_id := ""

func _init()->void:reset()

func reset()->void:
	step=Step.PREPARE
	session_id="lab1-"+Crypto.new().generate_random_bytes(8).hex_encode()

func prepare(target: float, grams: float) -> void:
	target_ml = target
	bicarbonate_g = grams
	session_id = "lab1-" + Crypto.new().generate_random_bytes(8).hex_encode()
	step = Step.BICARBONATE

func add_bicarbonate() -> bool:
	if step != Step.BICARBONATE:
		return false
	step = Step.POUR
	return true

func update_volume(volume: float) -> void:
	if step == Step.POUR and volume >= target_ml - .00001:
		step = Step.OBSERVE

func observe() -> bool:
	if step != Step.OBSERVE:
		return false
	step = Step.REGISTER
	return true

func saved(record: Dictionary) -> bool:
	if step != Step.REGISTER or record.get("lab1_session", "") != session_id:
		return false
	step = Step.COMPLETED
	return true

func instruction() -> String:
	match step:
		Step.PREPARE: return "1/5 · Prepara un vaso limpio y elige la dosis."
		Step.BICARBONATE: return "2/5 · Añade %s g de bicarbonato al vaso." % String.num(bicarbonate_g, 1)
		Step.POUR: return "3/5 · Vierte %s mL de vinagre. Puedes intercambiar las manos." % String.num(target_ml, 1)
		Step.OBSERVE: return "4/5 · Dosis lista. Suelta los objetos y observa la reacción."
		Step.REGISTER: return "5/5 · Registra pregunta, hipótesis y conclusión en el cuaderno."
		Step.COMPLETED: return "Laboratorio completado"
	return ""
