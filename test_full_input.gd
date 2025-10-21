extends Control

var input: TextEdit
var output: RichTextLabel
var send_btn: Button

func _ready():
	print("[TestFullInput] 开始测试完整输入流程")
	
	# 创建UI布局
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# 创建输出标签
	output = RichTextLabel.new()
	output.custom_minimum_size = Vector2(800, 300)
	output.bbcode_enabled = true
	output.scroll_following = true
	vbox.add_child(output)
	
	# 创建输入行容器
	var input_row = HBoxContainer.new()
	input_row.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(input_row)
	
	# 创建输入框
	input = TextEdit.new()
	input.placeholder_text = "输入主题或命令（/help），支持多行输入，Ctrl+Enter发送"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input_row.add_child(input)
	
	# 创建发送按钮
	send_btn = Button.new()
	send_btn.text = "发送"
	send_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	input_row.add_child(send_btn)
	
	# 连接信号
	input.gui_input.connect(_on_input_gui_input)
	send_btn.pressed.connect(_on_send)
	
	print("[TestFullInput] 测试场景已准备就绪")

func _on_input_gui_input(event: InputEvent) -> void:
	print("[TestFullInput] 输入事件: %s" % event)
	if event is InputEventKey and event.pressed:
		print("[TestFullInput] 按键事件: %s, ctrl_pressed: %s, shift_pressed: %s" % [event.keycode, event.ctrl_pressed, event.shift_pressed])
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[TestFullInput] 检测到Enter键")
			if event.ctrl_pressed or not event.shift_pressed:
				print("[TestFullInput] 满足发送条件")
				_on_send()
				get_viewport().set_input_as_handled()

func _on_send() -> void:
	var t := input.text.strip_edges()
	print("[TestFullInput] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TestFullInput] 输入为空，忽略")
		return
	
	input.text = ""
	
	if t.begins_with("/"):
		print("[TestFullInput] 处理命令: %s" % t)
		_handle_command(t)
	else:
		# 显示用户消息
		print("[TestFullInput] 显示用户消息: %s" % t)
		_append_line("user", "You", t, Color(0.85, 1.0, 0.85))
		
		# 模拟开始新的讨论
		print("[TestFullInput] 开始新的讨论")
		_append_line("system", "System", "开始讨论主题：「%s」" % t, Color(0.7, 0.7, 0.7))

func _handle_command(cmdline: String) -> void:
	var parts := cmdline.substr(1).split(" ", false, 2)
	var cmd := parts[0].to_lower()
	var arg := "" if parts.size() < 2 else parts[1]
	match cmd:
		"help":
			_append_system("可用命令：/help, /topic, /stop")
		"topic":
			if arg.strip_edges() == "":
				_append_system("用法：/topic 你的主题")
			else:
				_append_system("开始讨论主题：「%s」" % arg.strip_edges())
		_:
			_append_system("未知命令：%s（输入 /help 获取帮助）" % cmd)

func _append_line(role: String, name: String, text: String, color: Color) -> void:
	print("[TestFullInput] _append_line 被调用 - role: %s, name: %s, text: %s" % [role, name, text])

	var prefix := ""
	match role:
		"system":
			prefix = "[color=#%s][%s][/color]" % [color.to_html(false), name]
		"user":
			prefix = "[color=#%s][你][/color]" % [Color(0.7,1,0.7).to_html(false)]
		_:
			prefix = "[color=#%s][%s][/color]" % [color.to_html(false), name]

	var formatted_text := text
	if role != "user":
		# 简单的转义
		formatted_text = formatted_text.replace("[", "\\[").replace("]", "\\]")

	var final_text := "%s %s\n" % [prefix, formatted_text]
	print("[TestFullInput] 准备添加到output: %s" % final_text)
	output.append_text(final_text)
	output.newline()
	_scroll_to_bottom()
	print("[TestFullInput] _append_line 完成")

func _append_system(text: String) -> void:
	_append_line("system", "System", text, Color(0.7, 0.7, 0.7))

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	output.scroll_vertical = 1e9