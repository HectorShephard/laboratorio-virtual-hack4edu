extends RefCounted
## Articulaciones inventadas para probar render/controles. Nunca se usan con webcam real.
static func points(center: Vector2, closed: bool, roll: float=0, id: int=0) -> Array:
	var shape:=[Vector2(0,.12),Vector2(-.05,.08),Vector2(-.09,.04),Vector2(-.13,0),Vector2(-.16,-.04),Vector2(-.06,0),Vector2(-.07,-.07),Vector2(-.07,-.13),Vector2(-.07,-.19),Vector2(-.02,-.02),Vector2(-.02,-.10),Vector2(-.02,-.17),Vector2(-.02,-.22),Vector2(.02,-.01),Vector2(.03,-.09),Vector2(.03,-.15),Vector2(.03,-.20),Vector2(.06,.015),Vector2(.08,-.05),Vector2(.09,-.10),Vector2(.10,-.15)]
	if closed:
		shape[4]=Vector2(-.065,-.08)
		shape[8]=Vector2(-.06,-.08)
	var palm:=Vector2.ZERO
	for i in [0,5,9,13,17]: palm+=shape[i]/5
	var result: Array=[]
	for i in 21:
		var relative: Vector2 = shape[i]-palm
		if id==1:relative.x=-relative.x
		relative=relative.rotated(roll)*.55+center
		result.append([relative.x,relative.y,0])
	return result
