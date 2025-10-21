extends Control
class_name TerminalChatTest

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
	
	# 创建工具栏
	var toolbar = HBoxContainer.new()
	vbox.add_child(toolbar)
	
	var settings_btn = Button.new()
	settings_btn.text = "⚙ 设置"
	toolbar.add_child(settings_btn)
	
	var theme_btn = Button.new()
	theme_btn.text = "Toggle Theme"
	toolbar.add_child(theme_btn)
	
	var font_size_slider = HSlider.new()
	font_size_slider.min_value = 12.0
	font_size_slider.max_value = 32.0
	font_size_slider.step = 1.0
	font_size_slider.value = 20.0
	font_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(font_size_slider)
	
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
	
	# 创建背景
	var bg = ColorRect.new()
	bg.color = bg_color
	add_child(bg)
	move_child(bg, 0)
	
	# 连接信号
	send_btn.pressed.connect(_on_send)
	input.gui_input.connect(_on_input_gui_input)
	font_size_slider.value_changed.connect(_on_font_size_changed)
	settings_btn.pressed.connect(_open_settings)
	theme_btn.pressed.connect(_on_theme_toggle)
	
	_apply_theme()
	_append_system("测试场景已准备就绪")
	_append_system("请尝试输入内容并按Enter或Ctrl+Enter发送")
	
	print("[TerminalChatTest] 测试场景已准备就绪")

func _on_font_size_changed(v: float) -> void:
	var size := int(clamp(v, 12, 32))
	output.add_theme_font_size_override("normal_font_size", size)
	input.add_theme_font_size_override("font_size", size)

func _on_theme_toggle() -> void:
	# simple dark/light invert
	var old_bg := bg_color
	bg_color = Color(0.95, 0.95, 0.95) if bg_color.v < 0.5 else Color(0.08, 0.08, 0.08)
	fg_color = Color(0.1, 0.1, 0.1) if old_bg.v < 0.5 else Color(0.86, 0.9, 0.86)
	system_color = Color(0.35, 0.35, 0.35) if old_bg.v >= 0.5 else Color(0.7, 0.7, 0.7)
	_apply_theme()

func _apply_theme() -> void:
	add_theme_color_override("font_color", fg_color)
	self.modulate = Color(1,1,1,1)
	# 检查ColorRect节点是否存在
	var bg = get_node_or_null("ColorRect")
	if bg:
		bg.color = bg_color
	output.bbcode_enabled = true
	output.scroll_following = true
	output.add_theme_color_override("default_color", fg_color)
	_on_font_size_changed(20.0)

func _on_input_gui_input(event: InputEvent) -> void:
	# 打印详细的输入事件信息
	print("[TerminalChatTest] 输入事件: ", event)
	if event is InputEventKey:
		print("[TerminalChatTest] 键盘事件 - 按键码: ", event.keycode, ", 按下状态: ", event.pressed, ", Ctrl: ", event.ctrl_pressed, ", Shift: ", event.shift_pressed)
	
	# 处理 Ctrl+Enter 或 Enter 发送
	if event is InputEventKey and event.pressed:
		# Ctrl+Enter 或单独 Enter 都可以发送
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[TerminalChatTest] 检测到Enter键 - Ctrl: ", event.ctrl_pressed, ", Shift: ", event.shift_pressed)
			if event.ctrl_pressed or not event.shift_pressed:
				print("[TerminalChatTest] 满足发送条件，调用_on_send")
				_on_send()
				get_viewport().set_input_as_handled()
			else:
				print("[TerminalChatTest] 不满足发送条件，忽略")

func _on_send() -> void:
	var t := input.text.strip_edges()
	print("[TerminalChatTest] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TerminalChatTest] 输入为空，忽略")
		return
	input.text = ""
	_append_line("user", "You", t, Color(0.85, 1.0, 0.85))
	_append_system("收到消息: " + t)

func _open_settings() -> void:
	_append_system("设置面板已打开（模拟）")

func _append_line(role: String, name: String, text: String, color: Color) -> void:
	print("[TerminalChatTest] _append_line 被调用 - role: %s, name: %s, text: %s" % [role, name, text])

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
	print("[TerminalChatTest] 准备添加到output: %s" % final_text)
	output.append_text(final_text)
	output.newline()
	_scroll_to_bottom()
	print("[TerminalChatTest] _append_line 完成")

func _append_system(text: String) -> void:
	_append_line("system", "System", text, system_color)

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	# 使用scroll_to_line替代scroll_vertical
	output.scroll_to_line(output.get_line_count() - 1)