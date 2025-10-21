extends Control

@onready var output: RichTextLabel = $VBox/Scroll/Output
@onready var input: TextEdit = $VBox/InputRow/Input
@onready var send_btn: Button = $VBox/InputRow/Send
@onready var font_size_slider: HSlider = $VBox/Toolbar/FontSize
@onready var settings_btn: Button = $VBox/Toolbar/SettingsBtn
@onready var theme_btn: Button = $VBox/Toolbar/ThemeBtn

@onready var orchestrator = get_node("/root/MultiAgentOrchestrator")
@onready var agents = get_node("/root/AgentManager")

var settings_ui

var fg_color := Color(0.86, 0.9, 0.86)
var bg_color := Color(0.08, 0.08, 0.08)
var system_color := Color(0.7, 0.7, 0.7)

func _ready() -> void:
	# Wire signals
	send_btn.pressed.connect(_on_send)
	input.gui_input.connect(_on_input_gui_input)
	font_size_slider.value_changed.connect(_on_font_size_changed)
	settings_btn.pressed.connect(_open_settings)
	theme_btn.pressed.connect(_on_theme_toggle)
	orchestrator.line_emitted.connect(_on_line)
	orchestrator.discussion_started.connect(func(topic): _append_system("开始新话题：%s" % topic))
	orchestrator.discussion_stopped.connect(func(): _append_system("讨论已停止。"))
	agents.agents_changed.connect(func(): _append_system("代理配置已更新（/agents 查看）。"))

	# 加载设置UI
	var settings_scene := load("res://scene/ui/SettingsUI.tscn")
	settings_ui = settings_scene.instantiate()
	add_child(settings_ui)
	settings_ui.settings_saved.connect(_on_settings_saved)

	_apply_theme()

	# 先测试RichTextLabel是否能显示纯文本
	output.text = "测试文本 - 如果你能看到这行字，说明RichTextLabel工作正常\n"
	print("[TerminalChat] 已设置测试文本，output.text = '%s'" % output.text)
	output.queue_redraw()
	await get_tree().process_frame

	# 现在添加正常的欢迎消息
	_append_banner()
	_append_system("欢迎来到苏格拉底终端!这里有8位AI思想家等待与您深度对话。")
	_append_system("首次使用请点击左上角 ⚙设置 按钮配置AI角色,或输入 /help 查看命令。")
	_append_system("直接输入话题开始讨论!")
	
	# 延迟一帧后设置焦点，确保UI完全加载
	await get_tree().process_frame
	input.grab_focus()
	print("[TerminalChat] 输入框焦点已设置（延迟一帧后）")
	
	# 添加一个测试按钮，用于验证输入处理
	var test_btn = Button.new()
	test_btn.text = "测试输入"
	test_btn.pressed.connect(_test_input)
	$VBox/InputRow.add_child(test_btn)
	print("[TerminalChat] 已添加测试输入按钮")

func _test_input():
	print("[TerminalChat] 测试输入按钮被点击")
	input.text = "测试输入内容"
	_on_send()

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

	# 同步到设置UI (如果已打开)
	if settings_ui and settings_ui.visible:
		if settings_ui.font_size_slider.value != v:
			settings_ui.font_size_slider.value = v
			settings_ui.font_size_value.text = str(size)

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
	# 检测所有按键事件并打印日志
	if event is InputEventKey and event.pressed:
		print("[TerminalChat] 按键事件 - 按键码: ", event.keycode, ", 按下状态: ", event.pressed, ", Ctrl: ", event.ctrl_pressed, ", Shift: ", event.shift_pressed, ", 窗口ID: ", event.window_id)
		
		# 特别处理空格键事件
		if event.keycode == KEY_SPACE:
			print("[TerminalChat] 检测到空格键事件")
			_append_system("测试：检测到空格键事件")
			return
		
		# 检测Enter键
		if event.keycode == KEY_ENTER:
			print("[TerminalChat] 检测到Enter键")
			_on_send()
			return

func _on_send() -> void:
	var t := input.text.strip_edges()
	print("[TerminalChat] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TerminalChat] 输入为空，忽略")
		return
	input.text = ""
	if t.begins_with("/"):
		print("[TerminalChat] 处理命令: %s" % t)
		_handle_command(t)
	else:
		# 总是先显示用户消息
		print("[TerminalChat] 显示用户消息: %s" % t)
		_append_line("user", "You", t, Color(0.85, 1.0, 0.85))

		if orchestrator.is_active():
			# 讨论已在进行中，发送用户消息
			print("[TerminalChat] 讨论进行中，发送用户消息")
			orchestrator.user_message(t)
		else:
			# 开始新的讨论
			print("[TerminalChat] 开始新的讨论")
			orchestrator.start(t)

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
				orchestrator.start(arg.strip_edges())
		"stop", "understood":
			orchestrator.stop()
			_append_system("收到停止指令。")
		"say":
			if not orchestrator.is_active():
				_append_system("当前没有进行中的讨论。用 /topic 开始。")
			elif arg.strip_edges() != "":
				_append_line("user", "You", arg.strip_edges(), Color(0.85, 1.0, 0.85))
				orchestrator.user_message(arg.strip_edges())
		"agents":
			_handle_agents_subcommand(arg)
		"color":
			var maybe := arg.strip_edges()
			if maybe == "":
				_append_system("用法：/color #RRGGBB")
			else:
				var c := Color(maybe)
				fg_color = c
				_apply_theme()
				_append_system("终端前景色已更新。")
		"bg":
			var maybe_bg := arg.strip_edges()
			if maybe_bg == "":
				_append_system("用法：/bg #RRGGBB")
			else:
				bg_color = Color(maybe_bg)
				_apply_theme()
				_append_system("终端背景色已更新。")
		"fontsize":
			var n := int(arg)
			if n <= 0:
				_append_system("用法：/fontsize 12..28")
			else:
				font_size_slider.value = clamp(n, 12, 28)
		"export":
			_export_transcript(arg)
		"providers":
			_show_providers()
		"reset":
			_reset_agent_config()
		_:
			_append_system("未知命令：%s（输入 /help 获取帮助）" % cmd)

func _handle_agents_subcommand(arg: String) -> void:
	var subparts := arg.split(" ", false, 3)
	var sub := subparts[0].to_lower() if subparts.size() > 0 and subparts[0] != "" else "list"
	match sub:
		"list":
			var rows := []
			for a in agents.get_agents():
				rows.append("- %s [%s/%s] %s %s%s" % [
					a.name, a.api_type, a.model,
					("启用" if a.enabled else "禁用"),
					("(主持)" if a.is_moderator else ""),
					("" if a.api_key != "" else " (未设置APIKey)")
				])
			var rows_text := "(无)" if rows.size() == 0 else "\n".join(rows)
			_append_system("当前代理：\n" + rows_text)
		"add":
			if subparts.size() < 4:
				_append_system("用法：/agents add 名称 API类型 模型名")
				return
			var a := {
				"name": subparts[1],
				"api_type": subparts[2],
				"model": subparts[3],
				"api_key": "",
				"system_prompt": "",
				"color": Color(0.8,0.9,1.0),
				"enabled": true,
				"is_moderator": false
			}
			agents.upsert_agent(a)
			_append_system("已添加代理：%s" % subparts[1])
		"remove":
			if subparts.size() < 2:
				_append_system("用法：/agents remove 名称")
				return
			agents.remove_agent(subparts[1])
			_append_system("已移除代理：%s" % subparts[1])
		"key":
			if subparts.size() < 3:
				_append_system("用法：/agents key 名称 APIKEY（可用 ${ENV:VAR} 读取环境变量）")
				return
			agents.set_agent_key(subparts[1], subparts[2])
			_append_system("已更新 API Key：%s" % subparts[1])
		"color":
			if subparts.size() < 3:
				_append_system("用法：/agents color 名称 #RRGGBB")
				return
			agents.set_agent_color(subparts[1], Color(subparts[2]))
			_append_system("已更新颜色：%s" % subparts[1])
		"model":
			if subparts.size() < 4:
				_append_system("用法：/agents model 名称 API类型 模型名")
				return
			agents.set_agent_model(subparts[1], subparts[2], subparts[3])
			_append_system("已更新模型：%s -> %s/%s" % [subparts[1], subparts[2], subparts[3]])
		"moderator":
			if subparts.size() < 2:
				_append_system("用法：/agents moderator 名称")
				return
			agents.set_agent_moderator(subparts[1], true)
			_append_system("主持人已设置为：%s" % subparts[1])
		"enable":
			if subparts.size() < 2:
				_append_system("用法：/agents enable 名称")
				return
			agents.set_agent_enabled(subparts[1], true)
			_append_system("已启用代理：%s" % subparts[1])
		"disable":
			if subparts.size() < 2:
				_append_system("用法：/agents disable 名称")
				return
			agents.set_agent_enabled(subparts[1], false)
			_append_system("已禁用代理：%s" % subparts[1])
		"prompt":
			if subparts.size() < 3:
				_append_system("用法：/agents prompt 名称 系统提示词")
				return
			agents.set_agent_prompt(subparts[1], subparts[2])
			_append_system("已更新提示词：%s" % subparts[1])
		"rename":
			if subparts.size() < 3:
				_append_system("用法：/agents rename 旧名称 新名称")
				return
			agents.set_agent_name(subparts[1], subparts[2])
			_append_system("已重命名：%s -> %s" % [subparts[1], subparts[2]])
		"info":
			if subparts.size() < 2:
				_append_system("用法：/agents info 名称")
				return
			var agent: Dictionary = agents.get_agent_by_name(subparts[1])
			if agent.is_empty():
				_append_system("未找到代理：%s" % subparts[1])
				return
			var info := """
代理详情：%s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
API类型: %s
模型: %s
状态: %s
主持人: %s
颜色: #%s
API Key: %s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
系统提示词:
%s
""" % [
				agent.name,
				agent.api_type,
				agent.model,
				("启用" if agent.enabled else "禁用"),
				("是" if agent.is_moderator else "否"),
				agent.color.to_html(false),
				("已设置" if agent.api_key != "" else "未设置"),
				agent.system_prompt
			]
			_append_system(info)
		_:
			_append_system("用法：/agents [list|add|remove|key|color|model|moderator|enable|disable|prompt|rename|info] ...")

func _export_transcript(arg: String) -> void:
	var dt := Time.get_datetime_dict_from_system()
	var ts := "%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	var name := arg.strip_edges()
	if name == "":
		name = "topic"
	var dir := "res://docs/runing"
	# Attempt to write to res://docs/runing in project tree
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%s_%s.md" % [dir, name, ts]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		_append_system("导出失败：无法写入 %s" % path)
		return
	var lines := []
	for m in orchestrator.history():
    # keep plain text transcript
		lines.append("[%s] %s: %s" % [m.role, m.name, m.text])
	f.store_string("\n".join(lines))
	f.close()
	_append_system("已导出到 %s" % path)

func _on_line(role: String, name: String, text: String, color: Color) -> void:
	_append_line(role, name, text, color)

func _append_line(role: String, name: String, text: String, color: Color) -> void:
	print("[TerminalChat] _append_line 被调用 - role: %s, name: %s, text: %s" % [role, name, text])

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
		formatted_text = _markdown_to_bbcode(text)
	else:
		formatted_text = _escape_bbcode(text)

	var final_text := "%s %s\n" % [prefix, formatted_text]
	print("[TerminalChat] 准备添加到output: %s" % final_text)
	output.append_text(final_text)
	output.newline()

	# 强制更新和重绘（修复ANGLE渲染器的显示问题）
	output.queue_redraw()
	await get_tree().process_frame

	_scroll_to_bottom()
	print("[TerminalChat] _append_line 完成，当前output.text长度: %d" % output.text.length())

func _append_system(text: String) -> void:
	_append_line("system", "System", text, system_color)

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	$VBox/Scroll.scroll_vertical = 1e9

static func _escape_bbcode(s: String) -> String:
	return s.replace("[", "\\[").replace("]", "\\]")

# Markdown转BBCode(支持代码块、粗体、斜体、引用)
static func _markdown_to_bbcode(md: String) -> String:
	var result := md

	# 1. 代码块 ```code``` -> [code]code[/code]
	var code_block_regex := RegEx.new()
	code_block_regex.compile("```([\\s\\S]*?)```")
	result = code_block_regex.sub(result, "[code]$1[/code]", true)

	# 2. 行内代码 `code` -> [code]code[/code]
	var inline_code_regex := RegEx.new()
	inline_code_regex.compile("`([^`]+)`")
	result = inline_code_regex.sub(result, "[code]$1[/code]", true)

	# 3. 粗体 **text** -> [b]text[/b]
	var bold_regex := RegEx.new()
	bold_regex.compile("\\*\\*([^*]+)\\*\\*")
	result = bold_regex.sub(result, "[b]$1[/b]", true)

	# 4. 斜体 *text* -> [i]text[/i]
	var italic_regex := RegEx.new()
	italic_regex.compile("\\*([^*]+)\\*")
	result = italic_regex.sub(result, "[i]$1[/i]", true)

	# 5. 引用 > text -> [color=#888]▌ text[/color]
	var quote_regex := RegEx.new()
	quote_regex.compile("^> (.+)$")
	var lines := result.split("\n")
	for i in range(lines.size()):
		var match_result := quote_regex.search(lines[i])
		if match_result:
			lines[i] = "[color=#888888]▌ %s[/color]" % match_result.get_string(1)
	result = "\n".join(lines)

	# 6. 转义剩余的BBCode字符
	result = result.replace("[code]", "___CODE_START___")
	result = result.replace("[/code]", "___CODE_END___")
	result = result.replace("[b]", "___BOLD_START___")
	result = result.replace("[/b]", "___BOLD_END___")
	result = result.replace("[i]", "___ITALIC_START___")
	result = result.replace("[/i]", "___ITALIC_END___")
	result = result.replace("[color=", "___COLOR_START_")
	result = result.replace("[/color]", "___COLOR_END___")

	result = result.replace("[", "\\[").replace("]", "\\]")

	result = result.replace("___CODE_START___", "[code]")
	result = result.replace("___CODE_END___", "[/code]")
	result = result.replace("___BOLD_START___", "[b]")
	result = result.replace("___BOLD_END___", "[/b]")
	result = result.replace("___ITALIC_START___", "[i]")
	result = result.replace("___ITALIC_END___", "[/i]")
	result = result.replace("___COLOR_START_", "[color=")
	result = result.replace("___COLOR_END___", "[/color]")

	return result

func _show_help() -> void:
	var txt := """
═══════════════ 苏格拉底终端命令手册 ═══════════════

【核心功能】
  直接输入话题         → 开始深度讨论
  /topic 主题          → 明确开始新话题
  /say 文本            → 在讨论中插话
  /stop 或 /understood → 停止讨论(也可说"懂了")

【AI角色管理】
  /agents list                    → 查看所有AI角色
  /agents info 名称                → 查看角色详细信息
  /agents add 名称 API类型 模型名  → 添加新角色
  /agents remove 名称              → 删除角色
  /agents rename 旧名称 新名称     → 重命名角色
  /agents key 名称 APIKEY         → 设置API密钥
  /agents color 名称 #RRGGBB      → 设置角色颜色
  /agents model 名称 API类型 模型 → 更改模型
  /agents prompt 名称 提示词      → 修改系统提示词
  /agents enable 名称             → 启用角色
  /agents disable 名称            → 禁用角色
  /agents moderator 名称          → 设为主持人

【外观定制】
  /color #RRGGBB    → 设置终端前景色
  /bg #RRGGBB       → 设置终端背景色
  /fontsize N       → 设置字号(12-32)

【其他】
  /export 文件名    → 导出对话到 docs/runing/
  /providers        → 查看支持的AI厂商列表
  /reset            → 重置AI角色配置为默认值
  /help             → 显示此帮助

提示: ⚙ 点击左上角设置按钮可进行图形化配置
      API密钥支持环境变量,如 ${ENV:OPENAI_API_KEY}
═══════════════════════════════════════════════════
"""
	_append_system(txt)

func _show_providers() -> void:
	var api_types := APIConfig.get_api_types()
	var txt := "支持的AI厂商:\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
	for api_type in api_types:
		var provider := APIConfig.get_provider(api_type)
		var models_subset := provider.models.slice(0, 3)
		var models_str: String = ", ".join(models_subset)
		if provider.models.size() > 3:
			models_str += "..."
		txt += "• %s (%s)\n  模型: %s\n" % [provider.name, provider.display_name, models_str]
	txt += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	_append_system(txt)

func _reset_agent_config() -> void:
	# 删除所有配置文件，重新加载默认配置
	_append_system("正在重置所有AI配置...")
	_append_system("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# 要删除的配置文件列表
	var config_files := [
		"user://agents.json",
		"user://settings.cfg",
		"user://character_ai_settings.cfg"
	]

	var deleted_count := 0
	for file_path in config_files:
		if FileAccess.file_exists(file_path):
			var globalized := ProjectSettings.globalize_path(file_path)
			_append_system("删除: %s" % file_path)
			var err := DirAccess.remove_absolute(globalized)
			if err != OK:
				_append_system("  ❌ 删除失败 (错误: %d)，尝试移动到回收站..." % err)
				OS.move_to_trash(globalized)

			# 验证是否删除成功
			if not FileAccess.file_exists(file_path):
				_append_system("  ✅ 已删除")
				deleted_count += 1
			else:
				_append_system("  ⚠️ 文件仍然存在")
		else:
			_append_system("跳过: %s (不存在)" % file_path)

	_append_system("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	_append_system("已删除 %d 个配置文件" % deleted_count)

	# 重新加载所有配置
	_append_system("正在重新加载默认配置...")
	var settings_mgr := get_node_or_null("/root/SettingsManager")
	if settings_mgr:
		settings_mgr.load_settings()
	agents.load_agents()

	var enabled_count: int = agents.get_enabled_agents().size()
	var all_agents: Array = agents.get_agents()

	_append_system("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	_append_system("✅ 配置重置完成")
	_append_system("   总角色数: %d" % all_agents.size())
	_append_system("   已启用: %d" % enabled_count)

	if all_agents.size() > 0:
		var first_agent: Dictionary = all_agents[0]
		_append_system("   API提供商: %s" % first_agent.get("api_type", "未知"))
		_append_system("   模型: %s" % first_agent.get("model", "未知"))
		_append_system("   API密钥: %s" % ("已设置" if first_agent.get("api_key", "") != "" else "未设置"))

	_append_system("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	_append_system("提示：输入 /agents list 查看所有角色详情")

func _open_settings() -> void:
	if settings_ui:
		settings_ui.show_settings()

func _on_settings_saved(settings: Dictionary) -> void:
	# 应用设置
	if settings.has("font_size"):
		font_size_slider.value = settings.font_size

	if settings.has("theme"):
		if settings.theme == 1:  # Light theme
			if bg_color.v < 0.5:
				_on_theme_toggle()

	_append_system("设置已应用 Settings applied")

func _input(event: InputEvent) -> void:
	# ESC打开设置
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and not settings_ui.visible:
			_open_settings()
			get_viewport().set_input_as_handled()

