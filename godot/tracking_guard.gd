extends RefCounted

# Filtro de continuidad del control, no una nueva deteccion ni una medida de certeza.
var initialized := false
var last_cursor := Vector2.ZERO
var last_time := 0.0
var last_scale := 0.0
var interrupted := false
var candidate := Vector2.ZERO
var candidate_count := 0

func reset() -> void:
	initialized = false
	interrupted = false
	candidate_count = 0
	last_scale = 0.0

func missing() -> Dictionary:
	interrupted = true
	candidate_count = 0
	return {"stable": false, "reacquired": false}

func evaluate(cursor: Vector2, landmarks: Array, now: float) -> Dictionary:
	if not cursor.is_finite() or cursor.x < -.15 or cursor.x > 1.15 or cursor.y < -.15 or cursor.y > 1.15:
		return missing()
	var scale := 0.0
	if landmarks.size() == 21:
		for p in landmarks:
			if p.size()<3 or not Vector3(p[0],p[1],p[2]).is_finite(): return missing()
		# Una mano de canto conserva longitud aunque desaparezca el ancho 5–17.
		for pair in [[0,9],[0,5],[0,17],[5,17]]:
			var a: Array = landmarks[pair[0]]
			var b: Array = landmarks[pair[1]]
			scale=maxf(scale,Vector3(a[0],a[1],a[2]).distance_to(Vector3(b[0],b[1],b[2])))
		if not is_finite(scale) or scale < .015 or scale > 1.2:
			return missing()
	var max_step := clampf((now - last_time) * 2.4, .14, .22)
	var scale_ok := last_scale <= 0 or scale <= 0 or (scale / last_scale >= .4 and scale / last_scale <= 2.5)
	if initialized and cursor.distance_to(last_cursor) <= max_step and scale_ok:
		var recovered := interrupted and now-last_time>.55
		_accept(cursor, scale, now)
		return {"stable": true, "reacquired": recovered}
	# Reubicaciones grandes necesitan varias observaciones cercanas entre si.
	interrupted = true
	if candidate_count > 0 and cursor.distance_to(candidate) < .055:
		candidate_count += 1
	else:
		candidate_count = 1
	candidate = cursor
	var required := 3 if initialized else 2
	if candidate_count >= required:
		var recovered := initialized
		_accept(cursor, scale, now)
		return {"stable": true, "reacquired": recovered}
	return {"stable": false, "reacquired": false}

func _accept(cursor: Vector2, scale: float, now: float) -> void:
	initialized = true
	last_cursor = cursor
	last_scale = scale
	last_time = now
	interrupted = false
	candidate_count = 0
