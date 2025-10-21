extends Control

@onready var input = $VBox/InputRow/Input
@onready var output = $VBox/Scroll/Output
@onready var send_btn = $VBox/InputRow/Send

func _ready():
	print("[TestInput] 场景已准备就绪")
	send_btn.pressed.connect(_on_send)
	input.gui_input.connect(_on_input_gui_input)
	
func _on_input_gui_input(event: InputEvent) -> void:
	print("[TestInput] 输入事件: %s" % event)
	if event is InputEventKey and event.pressed:
		print("[TestInput] 按键事件: %s, ctrl_pressed: %s, shift_pressed: %s" % [event.keycode, event.ctrl_pressed, event.shift_pressed])
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[TestInput] 检测到Enter键")
			if event.ctrl_pressed or not event.shift_pressed:
				print("[TestInput] 满足发送条件")
				_on_send()
				get_viewport().set_input_as_handled()

func _on_send() -> void:
	var t := input.text.strip_edges()
	print("[TestInput] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TestInput] 输入为空，忽略")
		return
	
	# 显示输入内容
	output.append_text("[你] %s\n" % t)
	input.text = ""