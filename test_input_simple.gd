extends Node

func _ready():
	print("[TestInput] 开始测试输入处理")
	
	# 创建一个简单的输入框和按钮
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var input = TextEdit.new()
	input.placeholder_text = "输入测试内容，Enter发送"
	input.custom_minimum_size = Vector2(400, 100)
	vbox.add_child(input)
	
	var send_btn = Button.new()
	send_btn.text = "发送"
	vbox.add_child(send_btn)
	
	var output = RichTextLabel.new()
	output.bbcode_enabled = true
	output.custom_minimum_size = Vector2(400, 200)
	vbox.add_child(output)
	
	# 连接信号
	send_btn.pressed.connect(_on_send.bind(input, output))
	input.gui_input.connect(_on_input_gui_input.bind(input, output, send_btn))
	
	print("[TestInput] 测试场景已准备就绪")

func _on_input_gui_input(input: TextEdit, output: RichTextLabel, send_btn: Button, event: InputEvent) -> void:
	print("[TestInput] 输入事件: %s" % event)
	if event is InputEventKey and event.pressed:
		print("[TestInput] 按键事件: %s, ctrl_pressed: %s, shift_pressed: %s" % [event.keycode, event.ctrl_pressed, event.shift_pressed])
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[TestInput] 检测到Enter键")
			if event.ctrl_pressed or not event.shift_pressed:
				print("[TestInput] 满足发送条件")
				_on_send(input, output)
				get_viewport().set_input_as_handled()

func _on_send(input: TextEdit, output: RichTextLabel) -> void:
	var t := input.text.strip_edges()
	print("[TestInput] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TestInput] 输入为空，忽略")
		return
	
	# 显示输入内容
	output.append_text("[你] %s\n" % t)
	input.text = ""