extends Control

@onready var input = $VBox/InputRow/Input
@onready var output = $VBox/Scroll/Output

func _ready():
	print("[TestInput] 场景已准备就绪")
	input.text_changed.connect(_on_text_changed)
	input.gui_input.connect(_on_input_gui_input)
	$VBox/InputRow/Send.pressed.connect(_on_send)
	
func _on_text_changed():
	print("[TestInput] 输入内容已更改: '%s'" % input.text)

func _on_input_gui_input(event: InputEvent) -> void:
	# 处理 Ctrl+Enter 或 Enter 发送
	if event is InputEventKey and event.pressed:
		# Ctrl+Enter 或单独 Enter 都可以发送
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if event.ctrl_pressed or not event.shift_pressed:
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