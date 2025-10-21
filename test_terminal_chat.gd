extends Control

var input: TextEdit
var output: RichTextLabel
var send_btn: Button
var font_size_slider: HSlider
var settings_btn: Button
var theme_btn: Button

var settings_ui

var fg_color := Color(0.86, 0.9, 0.86)
var bg_color := Color(0.08, 0.08, 0.08)
var system_color := Color(0.7, 0.7, 0.7)

# 模拟MultiAgentOrchestrator
var mock_orchestrator: Node

func _ready():
	print("[TestTerminalChat] 开始测试TerminalChat输入处理")
	
	# 创建UI布局
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# 创建工具栏
	var toolbar = HBoxContainer.new()
	vbox.add_child(toolbar)
	
	# 创建设置按钮
	settings_btn = Button.new()
	settings_btn.text = "⚙ 设置"
	toolbar.add_child(settings_btn)
	
	# 创建主题切换按钮
	theme_btn = Button.new()
	theme_btn.text = "Toggle Theme"
	toolbar.add_child(theme_btn)
	
	# 创建字体大小滑块
	font_size_slider = HSlider.new()
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
	
	# 创建模拟的MultiAgentOrchestrator
	mock_orchestrator = Node.new()
	mock_orchestrator.name = "MockOrchestrator"
	add_child(mock_orchestrator)
	
	# 连接信号
	send_btn.pressed.connect(_on_send)
	input.gui_input.connect(_on_input_gui_input)
	font_size_slider.value_changed.connect(_on_font_size_changed)
	settings_btn.pressed.connect(_open_settings)
	theme_btn.pressed.connect(_on_theme_toggle)
	
	_apply_theme()
	_append_banner()
	_append_system("欢迎来到苏格拉底终端!这里有8位AI思想家等待与您深度对话。")
	_append_system("首次使用请点击左上角 ⚙设置 按钮配置AI角色,或输入 /help 查看命令。")
	_append_system("直接输入话题开始讨论!")
	
	print("[TestTerminalChat] 测试场景已准备就绪")

func _append_banner() -> void:
	var now := Time.get_datetime_dict_from_system()
	var ts := "%04d-%02d-%02d %02d:%02d:%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]
	var banner := """
╔═══════════════════════════════════════════════════════════╗
║          苏格拉底终端 Socratic Terminal v1.0              ║
║     Deep AI Discussion · 深度AI讨论 · %s    ║
╚═══════════════════════════════════════════════════════════╝
""" % ts
	_append_line("system", "System", banner, system_color)

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
	$ColorRect.color = bg_color
	output.bbcode_enabled = true
	output.scroll_following = true
	output.add_theme_color_override("default_color", fg_color)
	_on_font_size_changed(font_size_slider.value)

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
	print("[TestTerminalChat] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TestTerminalChat] 输入为空，忽略")
		return
	input.text = ""
	if t.begins_with("/"):
		print("[TestTerminalChat] 处理命令: %s" % t)
		_handle_command(t)
	else:
		# 总是先显示用户消息
		print("[TestTerminalChat] 显示用户消息: %s" % t)
		_append_line("user", "You", t, Color(0.85, 1.0, 0.85))

		# 模拟开始新的讨论
		print("[TestTerminalChat] 开始新的讨论")
		_append_system("开始新话题：%s" % t)
		
		# 模拟AI响应
		await get_tree().create_timer(1.0).timeout
		_append_line("assistant", "苏格拉底", "这是一个有趣的话题。让我们从基本问题开始思考...", Color(0.8, 0.9, 1.0))

func _handle_command(cmdline: String) -> void:
	var parts := cmdline.substr(1).split(" ", false, 2)
	var cmd := parts[0].to_lower()
	var arg := "" if parts.size() < 2 else parts[1]
	match cmd:
		"help":
			_show_help()
		"topic":
			if arg.strip_edges() == "":
				_append_system("用法：/topic 你的主题")
			else:
				_append_system("开始新话题：%s" % arg.strip_edges())
		_:
			_append_system("未知命令：%s（输入 /help 获取帮助）" % cmd)

func _show_help() -> void:
	var help_text := """
可用命令：
/help - 显示此帮助信息
/topic <主题> - 开始新的讨论主题
/stop - 停止当前讨论
/say <内容> - 在讨论中发言
/agents - 管理AI代理
/color #RRGGBB - 设置前景色
/bg #RRGGBB - 设置背景色
/export [文件名] - 导出讨论记录
/providers - 显示支持的AI提供商
"""
	_append_system(help_text)

func _open_settings() -> void:
	_append_system("设置面板已打开（模拟）")

func _append_line(role: String, name: String, text: String, color: Color) -> void:
	print("[TestTerminalChat] _append_line 被调用 - role: %s, name: %s, text: %s" % [role, name, text])

	var prefix := ""
	match role:
		"system":
			prefix = "[color=#%s][%s][/color]" % [system_color.to_html(false), name]
		"user":
			prefix = "[color=#%s][你][/color]" % [Color(0.7,1,0.7).to_html(false)]
		_:
			prefix = "[color=#%s][%s][/color]" % [color.to_html(false), name]

	# 转换Markdown为BBCode(仅对AI回复)
	var formatted_text := text
	if role == "assistant":
		# 简单的Markdown转换
		formatted_text = formatted_text.replace("**", "[b]").replace("**", "[/b]")
		formatted_text = formatted_text.replace("*", "[i]").replace("*", "[/i]")
	else:
		# 简单的转义
		formatted_text = formatted_text.replace("[", "\\[").replace("]", "\\]")

	var final_text := "%s %s\n" % [prefix, formatted_text]
	print("[TestTerminalChat] 准备添加到output: %s" % final_text)
	output.append_text(final_text)
	output.newline()
	_scroll_to_bottom()
	print("[TestTerminalChat] _append_line 完成")

func _append_system(text: String) -> void:
	_append_line("system", "System", text, system_color)

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	# 使用scroll_to_line替代scroll_vertical
	output.scroll_to_line(output.get_line_count() - 1)