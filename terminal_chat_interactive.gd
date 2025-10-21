extends Control
class_name TerminalChatInteractive

@onready var output: RichTextLabel
@onready var input: TextEdit
@onready var send_btn: Button

var fg_color := Color(0.86, 0.9, 0.86)
var bg_color := Color(0.08, 0.08, 0.08)
var system_color := Color(0.7, 0.7, 0.7)

func _ready() -> void:
	# 创建UI布局
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_top = 16.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -16.0
	add_child(vbox)
	
	# 创建滚动容器
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	# 创建输出标签
	output = RichTextLabel.new()
	output.custom_minimum_size = Vector2(800, 300)
	output.bbcode_enabled = true
	output.scroll_following = true
	output.selection_enabled = true
	output.fit_content = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(output)
	
	# 创建输入行容器
	var input_row = HBoxContainer.new()
	input_row.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(input_row)
	
	# 创建输入框
	input = TextEdit.new()
	input.placeholder_text = "输入内容，按Enter发送"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input_row.add_child(input)
	
	# 创建发送按钮
	send_btn = Button.new()
	send_btn.text = "发送"
	send_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	input_row.add_child(send_btn)
	
	# 创建背景
	var bg = ColorRect.new()
	bg.color = bg_color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	
	# 连接信号
	send_btn.pressed.connect(_on_send)
	input.gui_input.connect(_on_input_gui_input)
	
	# 设置焦点到输入框
	input.grab_focus()
	
	# 模拟一些输入事件进行测试
	_append_system("交互式测试场景已准备就绪")
	_append_system("将模拟输入事件进行测试")
	
	print("[TerminalChatInteractive] 测试场景已准备就绪，焦点已设置到输入框")
	
	# 延迟一帧后模拟输入事件
	await get_tree().process_frame
	_simulate_input_events()

func _simulate_input_events():
	print("[TerminalChatInteractive] 开始模拟输入事件")
	
	# 模拟输入文本
	input.text = "测试输入内容"
	print("[TerminalChatInteractive] 已设置输入文本: ", input.text)
	
	# 模拟Enter键按下事件
	var enter_event = InputEventKey.new()
	enter_event.keycode = KEY_ENTER
	enter_event.pressed = true
	print("[TerminalChatInteractive] 模拟Enter键按下事件")
	
	# 直接调用_on_send而不是发送事件，因为事件系统在headless模式下可能不工作
	_on_send()
	
	# 再测试一次空输入
	input.text = ""
	print("[TerminalChatInteractive] 测试空输入")
	_on_send()

func _on_input_gui_input(event: InputEvent) -> void:
	# 打印详细的输入事件信息
	print("[TerminalChatInteractive] 输入事件: ", event)
	if event is InputEventKey:
		print("[TerminalChatInteractive] 键盘事件 - 按键码: ", event.keycode, ", 按下状态: ", event.pressed, ", Ctrl: ", event.ctrl_pressed, ", Shift: ", event.shift_pressed)
	
	# 处理 Enter 发送
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[TerminalChatInteractive] 检测到Enter键")
			_on_send()
			get_viewport().set_input_as_handled()

func _on_send() -> void:
	var t := input.text.strip_edges()
	print("[TerminalChatInteractive] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TerminalChatInteractive] 输入为空，忽略")
		return
	input.text = ""
	_append_line("user", "You", t, Color(0.85, 1.0, 0.85))
	_append_system("收到消息: " + t)

func _append_line(role: String, name: String, text: String, color: Color) -> void:
	print("[TerminalChatInteractive] _append_line 被调用 - role: %s, name: %s, text: %s" % [role, name, text])

	var prefix := ""
	match role:
		"system":
			prefix = "[color=#%s][%s][/color]" % [system_color.to_html(false), name]
		"user":
			prefix = "[color=#%s][你][/color]" % [Color(0.7,1,0.7).to_html(false)]
		_:
			prefix = "[color=#%s][%s][/color]" % [color.to_html(false), name]

	# 简单的转义
	var formatted_text := text.replace("[", "\\[").replace("]", "\\]")

	var final_text := "%s %s\n" % [prefix, formatted_text]
	print("[TerminalChatInteractive] 准备添加到output: %s" % final_text)
	output.append_text(final_text)
	output.newline()
	_scroll_to_bottom()
	print("[TerminalChatInteractive] _append_line 完成")

func _append_system(text: String) -> void:
	_append_line("system", "System", text, system_color)

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	# 使用scroll_to_line替代scroll_vertical
	output.scroll_to_line(output.get_line_count() - 1)