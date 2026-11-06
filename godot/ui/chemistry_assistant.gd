extends PanelContainer
## Conversación local de solo consulta. Ningún botón ejecuta acciones del laboratorio.
const Expert=preload("res://core/chemistry_expert.gd")
const Walnut=preload("res://ui/walnut_theme.gd")
var provider:Callable
var available:Callable
var entry_button:Button
var notebook_entry:Button
var expert:=Expert.new()
var history:RichTextLabel
var question:LineEdit
var close_button:Button
var messages:Array[String]=[]
var current_session:=""
var poll:=0.0
var last_reply:Dictionary={}
var test_button:Button
var note:Label

func _ready()->void:
	theme=Walnut.make_theme()
	add_theme_stylebox_override("panel",Walnut.panel())
	position=Vector2(24,180)
	size=Vector2(600,410)
	var column:=VBoxContainer.new()
	add_child(column)
	var heading:=HBoxContainer.new()
	column.add_child(heading)
	var title:=Label.new()
	title.text="ASISTENTE DE QUÍMICA · LOCAL"
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button=_button("Cerrar",close_panel)
	heading.add_child(close_button)
	history=RichTextLabel.new()
	history.custom_minimum_size=Vector2(0,220)
	history.size_flags_vertical=Control.SIZE_EXPAND_FILL
	history.scroll_following=true
	history.add_theme_color_override("default_color",Walnut.IVORY)
	column.add_child(history)
	question=LineEdit.new()
	question.placeholder_text="Pregunta corta sobre la práctica abierta…"
	question.max_length=180
	question.text_submitted.connect(ask)
	column.add_child(question)
	var shortcuts:=HBoxContainer.new()
	column.add_child(shortcuts)
	for caption in ["¿Qué hago ahora?","¿Qué significa el resultado?","Modo pruebas"]:
		var control:=_button(caption,_toggle_tests if caption=="Modo pruebas" else ask.bind(caption))
		if caption=="Modo pruebas":
			test_button=control
			control.toggle_mode=true
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		shortcuts.add_child(control)
	note=Label.new()
	note.text="Solo consulta · Tú ejecutas las acciones · Cerrar deja libre el banco"
	note.add_theme_font_size_override("font_size",12)
	note.add_theme_color_override("font_color",Walnut.SECONDARY)
	column.add_child(note)
	hide()

func _button(caption:String,action:Callable)->Button:
	var button:=Button.new()
	button.text=caption
	button.pressed.connect(action)
	return button

func _process(delta:float)->void:
	poll+=delta
	if poll<.15:return
	poll=0
	var active:bool=available.call()
	entry_button.visible=active
	if notebook_entry!=null:notebook_entry.visible=active
	if not active:
		if visible:close_panel()
		return
	if visible:_check_session(provider.call())

func _check_session(facts:Dictionary)->void:
	if current_session==facts.session_id:return
	current_session=facts.session_id
	messages.clear()
	messages.append("Asistente: Nuevo ensayo de «%s». El resultado y su guardado se consultan para esta ejecución." % facts.title)
	_refresh_history()

func open_panel()->void:
	if not available.call():return
	_check_session(provider.call())
	show()
	move_to_front()
	question.grab_focus()

func close_panel()->void:
	question.release_focus()
	hide()

func ask(text:String)->void:
	text=text.strip_edges().left(question.max_length)
	if text.is_empty():return
	var facts:Dictionary=provider.call()
	_check_session(facts)
	last_reply=expert.answer(text,facts)
	test_button.set_pressed_no_signal(expert.testing)
	note.text="Modo pruebas · Escribe «siguiente caso» para avanzar" if expert.testing else "Solo consulta · Tú ejecutas las acciones · Cerrar deja libre el banco"
	messages.append("Estudiante: "+text)
	messages.append("Asistente: "+str(last_reply.text))
	while messages.size()>9:messages.pop_front()
	question.clear()
	_refresh_history()

func _toggle_tests()->void:
	ask("Modo normal" if expert.testing else "Modo pruebas")

func _refresh_history()->void:
	history.text="\n\n".join(messages)
