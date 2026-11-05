extends Control

var points: Array = []
var active := false
var closed := false
const LINKS := [[0,1],[1,2],[2,3],[3,4],[0,5],[5,6],[6,7],[7,8],[5,9],[9,10],[10,11],[11,12],[9,13],[13,14],[14,15],[15,16],[13,17],[0,17],[17,18],[18,19],[19,20]]

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_box(Color("101f2b")), rect)
	if not active or points.size() != 21:
		return
	var coords: Array[Vector2] = []
	for p in points:
		coords.append(Vector2(float(p[0]), float(p[1])) * size)
	for link in LINKS:
		draw_line(coords[link[0]], coords[link[1]], Color("48d5bc"), 2.0, true)
	for p in coords:
		draw_circle(p, 3.0, Color("d6fff5"))
	var cursor := (coords[4] + coords[8]) * 0.5
	draw_arc(cursor, 8.0, 0, TAU, 20, Color("ffce73") if closed else Color.WHITE, 2.0, true)

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(12)
	return box
