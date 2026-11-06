extends RefCounted
## Vinagre al 5 % m/v. Reacción ideal 1:1; no mide gas real.
const EXPERIMENT_ID := "vinagre-bicarbonato"
const TITLE := "Vinagre y bicarbonato"
const UNIT := "mmol"
const MODEL_VERSION := "estequiometria-5mv-v1"
const DEFAULT_STRENGTH := 5.0
const INPUTS := {
	"initial_ml":{"label":"Inicial (mL)","unit":"mL","min":1.0,"max":500.0,"step":1.0,"default":100.0},
	"capacity_ml":{"label":"Vaso (mL)","unit":"mL","min":1.0,"max":500.0,"step":1.0,"default":150.0},
	"concentration":{"label":"Concentración (%)","unit":"% m/v ácido acético","min":.1,"max":100.0,"step":.1,"default":DEFAULT_STRENGTH},
	"bicarbonate_g":{"label":"Bicarbonato (g)","unit":"g","min":.1,"max":20.0,"step":.1,"default":3.0},
	"target_ml":{"label":"Dosis a verter (mL)","unit":"mL","min":1.0,"max":500.0,"step":1.0,"default":25.0}}

static func validate_field(key:String, value:float)->Dictionary:
	var field:Dictionary=INPUTS[key]
	if is_finite(value) and value>=field.min and value<=field.max:return {}
	return {"field":key,"unit":field.unit,"min":field.min,"max":field.max,"message":"%s: introduce un valor entre %s y %s %s." % [field.label,field.min,field.max,field.unit]}

static func validate_preparation(values:Dictionary)->Dictionary:
	for key in INPUTS:
		if not values.has(key):return {"field":key,"unit":INPUTS[key].unit,"message":"Falta " + str(INPUTS[key].label) + "."}
		var error:=validate_field(key,float(values[key]))
		if not error.is_empty():return error
	if values.target_ml>minf(values.initial_ml,values.capacity_ml):
		return {"field":"target_ml","unit":"mL","min":INPUTS.target_ml.min,"max":minf(values.initial_ml,values.capacity_ml),"message":"La dosis debe caber en el vaso y en el frasco."}
	return {}

static func validate_measurement(vinegar_ml:float,bicarbonate_g:float)->Dictionary:
	if not is_finite(vinegar_ml) or vinegar_ml<=0:return {"field":"used_ml","unit":"mL","message":"El volumen realmente usado debe ser mayor que 0 mL."}
	if not is_finite(bicarbonate_g) or bicarbonate_g<=0:return {"field":"bicarbonate_g","unit":"g","message":"El bicarbonato debe ser mayor que 0 g."}
	return {}

static func estimate(vinegar_ml: float, bicarbonate_g: float, strength: float = DEFAULT_STRENGTH) -> Dictionary:
	if not validate_measurement(vinegar_ml,bicarbonate_g).is_empty() or not is_finite(strength):
		return {}
	var acid := vinegar_ml * strength / 100.0 / 60.052 * 1000.0
	var base := bicarbonate_g / 84.007 * 1000.0
	var limiting := "Ácido acético del vinagre" if acid < base else "Bicarbonato"
	if is_equal_approx(acid, base):
		limiting = "Ambos (proporción estequiométrica)"
	return {"schema_version": 1, "experiment_id": EXPERIMENT_ID,
		"model_version": MODEL_VERSION, "quantity": "CO₂ teórico", "unit": UNIT,
		"source": "simulation", "validity": "estimación teórica", "value": minf(acid, base),
		"limiting_reagent": limiting, "parameters": {"vinagre_ml": vinegar_ml,
		"bicarbonato_g": bicarbonate_g, "acido_acetico_g_por_100ml": strength},
		"assumptions": "CH₃COOH + NaHCO₃ → CH₃COONa + H₂O + CO₂. Reacción completa 1:1; vinagre al %s %% m/v. Estimación teórica." % strength}
