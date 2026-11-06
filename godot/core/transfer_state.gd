extends RefCounted
## Conservación de volumen. Concentración y porcentaje transferido son distintos.
const Model=preload("res://core/chemistry_model.gd")
var initial_ml:float=Model.INPUTS.initial_ml.default
var remaining_ml:float=initial_ml
var poured_ml := 0.0
var capacity_ml:float=Model.INPUTS.capacity_ml.default
var liquid := "alcohol"
var concentration := 70.0
var interrupted := false
var mixed := false
var pouring := false
var enabled := true
var dose_limit_ml := -1.0
var tail_used_ml := 0.0
const TAIL_SECONDS := .25
const TAIL_MAX_ML := 3.125
const START_ANGLE := 45.0
const STOP_ANGLE := 35.0
const HAND_START_ANGLE := 18.0
const HAND_STOP_ANGLE := 9.0

func configure(amount: float, capacity: float, kind: String, strength: float) -> void:
	initial_ml = clampf(amount, Model.INPUTS.initial_ml.min, Model.INPUTS.initial_ml.max)
	remaining_ml = initial_ml
	poured_ml = 0
	capacity_ml = clampf(capacity, Model.INPUTS.capacity_ml.min, Model.INPUTS.capacity_ml.max)
	liquid = kind
	concentration = clampf(strength, 0, Model.INPUTS.concentration.max)
	interrupted = false
	mixed = false
	pouring = false
	enabled = true
	dose_limit_ml = -1
	tail_used_ml=0

func advance(delta: float, held: bool, aligned: bool, tilt: float, webcam: bool=false, usable: bool=true, missing_age: float=0, unique: bool=true) -> float:
	var start_angle := HAND_START_ANGLE if webcam else START_ANGLE
	var stop_angle := HAND_STOP_ANGLE if webcam else STOP_ANGLE
	var upright := absf(tilt) <= HAND_STOP_ANGLE if webcam else absf(tilt) < 30
	if upright and usable:
		interrupted = false
	if upright and unique:
		pouring=false
	var limit := minf(capacity_ml, dose_limit_ml) if dose_limit_ml > 0 else capacity_ml
	if not enabled or not held or not aligned or interrupted or mixed or remaining_ml <= .000001 or poured_ml >= limit - .000001:
		pouring = false
		return 0
	var dt:=maxf(0,minf(delta,.1))
	if webcam and not usable:
		# Solo prolonga una emisión ya iniciada; consume tiempo y volumen una vez.
		if not pouring:
			return 0
		dt=minf(dt,maxf(0,TAIL_SECONDS-maxf(0,missing_age-delta)))
		if dt<=0 or tail_used_ml>=TAIL_MAX_ML-.000001:
			pouring=false
			return 0
	elif unique:
		tail_used_ml=0
	if usable and pouring and absf(tilt) <= stop_angle:
		pouring = false
	elif not pouring and usable and (not webcam or unique) and absf(tilt) >= start_angle:
		pouring = true
	if dt <= 0 or not pouring:
		return 0
	var amount := minf(12.5 * dt, minf(remaining_ml, limit - poured_ml))
	if webcam and not usable:
		amount=minf(amount,TAIL_MAX_ML-tail_used_ml)
		tail_used_ml+=amount
	amount = maxf(0, amount)
	remaining_ml -= amount
	poured_ml += amount
	if webcam and not usable and (missing_age>=TAIL_SECONDS or tail_used_ml>=TAIL_MAX_ML-.000001):
		pouring=false
	return amount

func summary() -> String:
	return "%s %% vertido · %s mL restantes" % [String.num(poured_ml / initial_ml * 100, 1).trim_suffix(".0"), String.num(remaining_ml, 1).trim_suffix(".0")]

func record(bicarbonate: float) -> Dictionary:
	if poured_ml <= 0 or mixed:
		return {}
	var result: Dictionary
	if liquid == "vinagre":
		result = Model.estimate(poured_ml, bicarbonate, concentration)
	else:
		result = {"schema_version": 1, "experiment_id": "transferencia-alcohol", "model_version": "volumen-v1", "quantity": "Volumen transferido", "value": poured_ml, "unit": "mL", "source": "simulation", "validity": "práctica de transferencia", "parameters": {}, "assumptions": "Transferencia de volumen simulada; sin reacción química definida para alcohol."}
	if result.is_empty():
		return {}
	result.parameters.merge({"liquido": liquid, "volumen_inicial_ml": initial_ml, "vertido_ml": poured_ml, "restante_ml": remaining_ml, "capacidad_vaso_ml": capacity_ml, "porcentaje_vertido": poured_ml / initial_ml * 100, "concentracion": concentration, "unidad_concentracion": "% m/v ácido acético" if liquid == "vinagre" else "% v/v alcohol"})
	return result
