extends Control

var input: TextEdit

func _ready():
	print("[TestInputEvent] 开始测试输入事件")
	
	# 创建一个简单的输入框
	input = TextEdit.new()
	input.placeholder_text = "输入测试内容，Enter发送"
	input.custom_minimum_size = Vector2(400, 100)
	add_child(input)
	
	# 连接信号
	input.gui_input.connect(_on_input_gui_input)
	
	print("[TestInputEvent] 测试场景已准备就绪")

func _on_input_gui_input(event: InputEvent) -> void:
	print("[TestInputEvent] 输入事件: %s" % event)
	if event is InputEventKey and event.pressed:
		print("[TestInputEvent] 按键事件: %s, ctrl_pressed: %s, shift_pressed: %s" % [event.keycode, event.ctrl_pressed, event.shift_pressed])
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[TestInputEvent] 检测到Enter键")
			if event.ctrl_pressed or not event.shift_pressed:
				print("[TestInputEvent] 满足发送条件")
				var t := input.text.strip_edges()
				print("[TestInputEvent] 输入内容: '%s'" % t)
				if t != "":
					print("[TestInputEvent] 处理输入内容")
				input.text = ""
				get_viewport().set_input_as_handled()