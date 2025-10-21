extends Control

var input: TextEdit
var output: RichTextLabel

func _ready():
	print("[TestInputDebug] 开始调试输入事件")
	
	# 创建UI布局
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# 创建输出标签
	output = RichTextLabel.new()
	output.custom_minimum_size = Vector2(800, 300)
	output.bbcode_enabled = true
	vbox.add_child(output)
	
	# 创建输入框
	input = TextEdit.new()
	input.placeholder_text = "输入测试内容，Enter发送"
	input.custom_minimum_size = Vector2(800, 100)
	vbox.add_child(input)
	
	# 创建发送按钮
	var send_btn = Button.new()
	send_btn.text = "发送"
	vbox.add_child(send_btn)
	
	# 连接信号
	input.gui_input.connect(_on_input_gui_input)
	send_btn.pressed.connect(_on_send)
	
	print("[TestInputDebug] 测试场景已准备就绪")

func _on_input_gui_input(event: InputEvent) -> void:
	print("[TestInputDebug] 输入事件: %s" % event)
	if event is InputEventKey and event.pressed:
		print("[TestInputDebug] 按键事件: %s, ctrl_pressed: %s, shift_pressed: %s" % [event.keycode, event.ctrl_pressed, event.shift_pressed])
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[TestInputDebug] 检测到Enter键")
			if event.ctrl_pressed or not event.shift_pressed:
				print("[TestInputDebug] 满足发送条件")
				_on_send()
				get_viewport().set_input_as_handled()

func _on_send() -> void:
	var t := input.text.strip_edges()
	print("[TestInputDebug] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TestInputDebug] 输入为空，忽略")
		return
	
	# 显示消息
	output.append_text("[你] %s\n" % t)
	input.text = ""
	print("[TestInputDebug] 处理完成")