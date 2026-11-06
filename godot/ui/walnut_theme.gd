extends RefCounted
## Nogal solo en bordes; centros mate para conservar contraste en texto y cifras.
const IVORY := Color("f4ead5")
const SECONDARY := Color("c8baa3")
const AMBER := Color("e5ae58")
class WalnutFrame extends StyleBox:
	var texture: Texture2D = preload("res://recursos/garaje/texturas/contrachapado_diff_1k.jpg")
	var center := Color("29231e")
	var thickness := 6.0
	var selected := false
	func _draw(canvas: RID, area: Rect2) -> void:
		RenderingServer.canvas_item_add_texture_rect(canvas, area, texture.get_rid(), false, Color(.32,.22,.15))
		var matte := StyleBoxFlat.new()
		matte.bg_color = center
		matte.set_corner_radius_all(5)
		matte.border_color = Color("e5ae58") if selected else Color("6d5137")
		matte.set_border_width_all(1)
		matte.draw(canvas,area.grow(-thickness))

static func panel(center: Color = Color("29231e"), thickness: float = 6, selected: bool = false) -> StyleBox:
	var skin := WalnutFrame.new()
	skin.center = center
	skin.thickness = thickness
	skin.selected = selected
	skin.set_content_margin_all(thickness + 10)
	return skin

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	for type in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit", "SpinBox", "PopupMenu"]:
		theme.set_color("font_color",type,IVORY)
		theme.set_color("font_hover_color",type,IVORY)
		theme.set_color("font_pressed_color",type,AMBER)
		theme.set_color("font_disabled_color",type,SECONDARY.darkened(.2))
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var active: bool = state in ["hover", "pressed", "focus"]
			var skin := panel(Color("513b24") if active else Color("28221c"), 2, active)
			skin.set_content_margin_all(7)
			theme.set_stylebox(state,type,skin)
	for state in ["normal", "focus", "read_only"]:
		theme.set_stylebox(state,"LineEdit",panel(Color("211d19"),2,state=="focus"))
	theme.set_stylebox("panel","PopupMenu",panel())
	theme.set_stylebox("hover","PopupMenu",panel(Color("513b24"),2,true))
	return theme
