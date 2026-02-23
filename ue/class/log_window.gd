extends CanvasLayer

@onready var panel = $LogWindow
@onready var log_text : RichTextLabel = $LogWindow/VBoxContainer/LogText
@onready var clear_btn = $LogWindow/VBoxContainer/TitleBar/clearButton
@onready var close_btn = $LogWindow/VBoxContainer/TitleBar/closeButton
@onready var titlebar = $LogWindow/VBoxContainer/TitleBar
var dragging := false
var drag_offset := Vector2.ZERO
var log_buffer:Array = []

func _ready():
	clear_btn.pressed.connect(_on_clear)
	close_btn.pressed.connect(_on_close)

func add_log(text:String):
	call_deferred("_add_log_safe", text)

func _add_log_safe(text:String):
	var time = Time.get_time_string_from_system()
	log_buffer.append("[%s] %s" % [time, text])

#func add_log_thread(text:String) -> void:
	#var time = Time.get_time_string_from_system()
	#log_text.append_text("[%s] %s\n" % [time, text])
	#log_text.scroll_to_line(log_text.get_line_count())
	#print("[%s] %s\n" % [time, text])
	
func _on_clear():
	log_text.clear()

func _on_close():
	panel.visible = false

# -------- 拖动功能 --------
func _input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if titlebar.get_global_rect().has_point(event.position):
				dragging = true
				drag_offset = event.position - panel.position
		else:
			dragging = false

	if event is InputEventMouseMotion and dragging:
		panel.position = event.position - drag_offset

func _process(_delta: float) -> void:
	if log_buffer.size() > 0:
		for t in log_buffer:
			log_text.append_text(t + '\n')
			print(t)
		log_buffer.clear()
		log_text.scroll_to_line(log_text.get_line_count())
