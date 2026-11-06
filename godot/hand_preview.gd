extends Control

var points: Array = []
var active := false
var closed := false
var hands: Array = []
const LINKS := [[0,1],[1,2],[2,3],[3,4],[0,5],[5,6],[6,7],[7,8],[5,9],[9,10],[10,11],[11,12],[9,13],[13,14],[14,15],[15,16],[13,17],[0,17],[17,18],[18,19],[19,20]]

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_box(Color("211d19")), rect)
	if not active:
		return
	if not hands.is_empty():
		for hand in hands:
			if hand.get("present",false):
				_draw_hand(hand.get("landmarks",[]),bool(hand.get("pinched",false)),Color("efbc70") if int(hand.get("id",0))==0 else Color("78cce4"))
	else:
		_draw_hand(points,closed,Color("efbc70"))

func _draw_hand(landmarks: Array, pinched: bool, color: Color) -> void:
	if landmarks.size()!=21: return
	var coords: Array[Vector2] = []
	for p in landmarks:
		coords.append(Vector2(float(p[0]), float(p[1])) * size)
	for link in LINKS:
		draw_line(coords[link[0]], coords[link[1]], color, 2.0, true)
	for p in coords:
		draw_circle(p, 2.0, color)
	var cursor := (coords[0]+coords[5]+coords[9]+coords[13]+coords[17])/5
	draw_arc(cursor, 6.0 if pinched else 4.0, 0, TAU, 20, color, 2.0, true)

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(12)
	return box
