extends RefCounted
## Una apertura real arma una sola confirmación. La pérdida la cancela.
var armed := false
var candidate := -1

func reset() -> void:
	armed = false
	candidate = -1

func update(valid: bool, opened: bool, pinched: bool, x: float) -> int:
	if not valid:
		reset()
		return -1
	if opened and not pinched:
		candidate = 0 if x < .35 else (2 if x > .65 else 1)
		armed = true
	if pinched and armed and candidate >= 0:
		armed = false
		return candidate
	return -1

static func is_open(points: Array) -> bool:
	if points.size() != 21:
		return false
	var wrist := Vector2(points[0][0], points[0][1])
	for pair in [[8, 6], [12, 10], [16, 14], [20, 18]]:
		var tip := Vector2(points[pair[0]][0], points[pair[0]][1])
		var joint := Vector2(points[pair[1]][0], points[pair[1]][1])
		if tip.distance_to(wrist) < joint.distance_to(wrist) * 1.15:
			return false
	return true
