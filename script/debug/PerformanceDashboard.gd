extends CanvasLayer

# ========================================
# PerformanceDashboard - 性能可视化面板
# ========================================
#
# 功能:
# - 实时性能监控仪表盘
# - FPS/内存/LLM统计可视化
# - 系统状态监控
# - 性能历史图表
#
# 快捷键:
# - F3: 切换显示/隐藏
#
# ========================================

# UI引用
@onready var main_container = $MainContainer
@onready var tab_container = $MainContainer/TabContainer

# 面板引用
var performance_panel = null
var llm_stats_panel = null
var system_status_panel = null

# 系统引用
var _performance_monitor = null

# 显示状态
var _is_visible: bool = false

# 更新间隔
var _update_interval: float = 1.0  # 每秒更新
var _time_since_update: float = 0.0

func _ready():
	"""初始化性能面板"""
	# 获取系统引用
	_performance_monitor = get_node_or_null("/root/PerformanceMonitor")

	# 应用主题
	_apply_theme()

	# 创建面板
	_create_panels()

	# 初始隐藏
	if main_container:
		main_container.visible = false

	print("[PerformanceDashboard] 性能面板初始化完成 (按F3打开)")

func _apply_theme():
	"""应用统一主题"""
	var MicroverseTheme = load("res://script/ui/themes/MicroverseTheme.gd")
	if MicroverseTheme:
		var theme = MicroverseTheme.create_theme()
		if main_container:
			main_container.theme = theme

func _create_panels():
	"""创建面板"""
	if not tab_container:
		_create_main_container()

	# 创建性能仪表盘
	_create_performance_panel()

	# 创建LLM统计面板
	_create_llm_stats_panel()

	# 创建系统状态面板
	_create_system_status_panel()

func _create_main_container():
	"""创建主容器"""
	main_container = PanelContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	main_container.position = Vector2(10, 10)
	main_container.custom_minimum_size = Vector2(700, 500)
	add_child(main_container)

	tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(tab_container)

func _create_performance_panel():
	"""创建性能监控面板"""
	performance_panel = Panel.new()
	performance_panel.name = "性能监控"

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	performance_panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "⚡ 性能监控面板"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# FPS区域
	var fps_panel = PanelContainer.new()
	fps_panel.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(fps_panel)

	var fps_vbox = VBoxContainer.new()
	fps_vbox.name = "FPSVBox"
	fps_panel.add_child(fps_vbox)

	var fps_title = Label.new()
	fps_title.text = "🎯 帧率 (FPS)"
	fps_title.add_theme_font_size_override("font_size", 16)
	fps_vbox.add_child(fps_title)

	var fps_hbox = HBoxContainer.new()
	fps_hbox.name = "FPSContainer"
	fps_vbox.add_child(fps_hbox)

	var fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.text = "当前: --"
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_hbox.add_child(fps_label)

	_add_spacer(fps_hbox, 20)

	var fps_avg_label = Label.new()
	fps_avg_label.name = "FPSAvgLabel"
	fps_avg_label.text = "平均: --"
	fps_avg_label.add_theme_font_size_override("font_size", 14)
	fps_hbox.add_child(fps_avg_label)

	_add_spacer(fps_hbox, 20)

	var fps_min_label = Label.new()
	fps_min_label.name = "FPSMinLabel"
	fps_min_label.text = "最低: --"
	fps_min_label.add_theme_font_size_override("font_size", 14)
	fps_hbox.add_child(fps_min_label)

	# 内存区域
	var mem_panel = PanelContainer.new()
	mem_panel.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(mem_panel)

	var mem_vbox = VBoxContainer.new()
	mem_vbox.name = "MemVBox"
	mem_panel.add_child(mem_vbox)

	var mem_title = Label.new()
	mem_title.text = "💾 内存使用"
	mem_title.add_theme_font_size_override("font_size", 16)
	mem_vbox.add_child(mem_title)

	var mem_hbox = HBoxContainer.new()
	mem_hbox.name = "MemoryContainer"
	mem_vbox.add_child(mem_hbox)

	var memory_label = Label.new()
	memory_label.name = "MemoryLabel"
	memory_label.text = "内存: -- MB"
	memory_label.add_theme_font_size_override("font_size", 14)
	mem_hbox.add_child(memory_label)

	_add_spacer(mem_hbox, 20)

	var node_label = Label.new()
	node_label.name = "NodeLabel"
	node_label.text = "节点数: --"
	node_label.add_theme_font_size_override("font_size", 14)
	mem_hbox.add_child(node_label)

	# FPS历史
	var history_panel = PanelContainer.new()
	history_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(history_panel)

	var history_vbox = VBoxContainer.new()
	history_panel.add_child(history_vbox)

	var history_title = Label.new()
	history_title.text = "📊 FPS历史 (最近60秒)"
	history_title.add_theme_font_size_override("font_size", 16)
	history_vbox.add_child(history_title)

	var history_label = Label.new()
	history_label.name = "HistoryLabel"
	history_label.text = "[等待数据...]"
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	history_vbox.add_child(history_label)

	# 警告信息
	var warning_label = Label.new()
	warning_label.name = "WarningLabel"
	warning_label.text = ""
	warning_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	warning_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(warning_label)

	tab_container.add_child(performance_panel)

	# 连接性能警告信号
	if _performance_monitor:
		if _performance_monitor.has_signal("fps_warning"):
			_performance_monitor.fps_warning.connect(_on_fps_warning)
		if _performance_monitor.has_signal("fps_critical"):
			_performance_monitor.fps_critical.connect(_on_fps_critical)
		if _performance_monitor.has_signal("memory_warning"):
			_performance_monitor.memory_warning.connect(_on_memory_warning)

func _create_llm_stats_panel():
	"""创建LLM统计面板"""
	llm_stats_panel = Panel.new()
	llm_stats_panel.name = "LLM统计"

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	llm_stats_panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "🤖 LLM API统计"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# 总览面板
	var summary_panel = PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(summary_panel)

	var summary_vbox = VBoxContainer.new()
	summary_vbox.name = "SummaryContainer"
	summary_panel.add_child(summary_vbox)

	var total_calls_label = Label.new()
	total_calls_label.name = "TotalCallsLabel"
	total_calls_label.text = "📞 总调用次数: --"
	total_calls_label.add_theme_font_size_override("font_size", 14)
	summary_vbox.add_child(total_calls_label)

	var success_rate_label = Label.new()
	success_rate_label.name = "SuccessRateLabel"
	success_rate_label.text = "✅ 成功率: --"
	success_rate_label.add_theme_font_size_override("font_size", 14)
	summary_vbox.add_child(success_rate_label)

	var avg_time_label = Label.new()
	avg_time_label.name = "AvgTimeLabel"
	avg_time_label.text = "⏱️ 平均响应时间: --"
	avg_time_label.add_theme_font_size_override("font_size", 14)
	summary_vbox.add_child(avg_time_label)

	var total_tokens_label = Label.new()
	total_tokens_label.name = "TotalTokensLabel"
	total_tokens_label.text = "🎫 总Token消耗: --"
	total_tokens_label.add_theme_font_size_override("font_size", 14)
	summary_vbox.add_child(total_tokens_label)

	# 按角色统计(滚动列表)
	var char_title = Label.new()
	char_title.text = "👥 按角色统计"
	char_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(char_title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var character_stats_container = VBoxContainer.new()
	character_stats_container.name = "CharacterStatsContainer"
	scroll.add_child(character_stats_container)

	tab_container.add_child(llm_stats_panel)

func _create_system_status_panel():
	"""创建系统状态面板"""
	system_status_panel = Panel.new()
	system_status_panel.name = "系统状态"

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	system_status_panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "🖥️ 系统状态监控"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# 运行时间
	var uptime_panel = PanelContainer.new()
	uptime_panel.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(uptime_panel)

	var uptime_vbox = VBoxContainer.new()
	uptime_panel.add_child(uptime_vbox)

	var uptime_label = Label.new()
	uptime_label.name = "UptimeLabel"
	uptime_label.text = "⏰ 运行时间: --"
	uptime_label.add_theme_font_size_override("font_size", 14)
	uptime_vbox.add_child(uptime_label)

	# 系统活动
	var activity_panel = PanelContainer.new()
	activity_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(activity_panel)

	var activity_vbox = VBoxContainer.new()
	activity_vbox.name = "ActivityContainer"
	activity_panel.add_child(activity_vbox)

	var activity_title = Label.new()
	activity_title.text = "📈 系统活动"
	activity_title.add_theme_font_size_override("font_size", 16)
	activity_vbox.add_child(activity_title)

	var dialogs_label = Label.new()
	dialogs_label.name = "DialogsLabel"
	dialogs_label.text = "💬 活跃对话: --"
	dialogs_label.add_theme_font_size_override("font_size", 14)
	activity_vbox.add_child(dialogs_label)

	var tasks_label = Label.new()
	tasks_label.name = "TasksLabel"
	tasks_label.text = "📋 活跃任务: --"
	tasks_label.add_theme_font_size_override("font_size", 14)
	activity_vbox.add_child(tasks_label)

	var conflicts_label = Label.new()
	conflicts_label.name = "ConflictsLabel"
	conflicts_label.text = "⚔️ 活跃冲突: --"
	conflicts_label.add_theme_font_size_override("font_size", 14)
	activity_vbox.add_child(conflicts_label)

	var transactions_label = Label.new()
	transactions_label.name = "TransactionsLabel"
	transactions_label.text = "💰 总交易数: --"
	transactions_label.add_theme_font_size_override("font_size", 14)
	activity_vbox.add_child(transactions_label)

	tab_container.add_child(system_status_panel)

func _add_spacer(parent: Control, width: float):
	"""添加间距"""
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(width, 0)
	parent.add_child(spacer)

func _input(event: InputEvent):
	"""处理输入事件"""
	if event is InputEventKey and event.pressed:
		# F3切换显示
		if event.keycode == KEY_F3 and not event.is_echo():
			toggle_visibility()

func toggle_visibility():
	"""切换显示/隐藏"""
	_is_visible = not _is_visible

	if main_container:
		main_container.visible = _is_visible

	if _is_visible:
		_refresh_all_panels()
		print("[PerformanceDashboard] 显示性能面板")
	else:
		print("[PerformanceDashboard] 隐藏性能面板")

func _process(delta: float):
	"""更新面板"""
	if not _is_visible:
		return

	_time_since_update += delta

	if _time_since_update >= _update_interval:
		_time_since_update = 0.0
		_refresh_all_panels()

func _refresh_all_panels():
	"""刷新所有面板"""
	_update_performance_panel()
	_update_llm_stats_panel()
	_update_system_status_panel()

func _update_performance_panel():
	"""更新性能面板"""
	if not performance_panel or not _performance_monitor:
		return

	# 更新FPS
	var fps_vbox = performance_panel.get_node_or_null("VBoxContainer/PanelContainer/FPSVBox")
	if fps_vbox:
		var fps_container = fps_vbox.get_node_or_null("FPSContainer")
		if fps_container:
			var fps_label = fps_container.get_node_or_null("FPSLabel")
			if fps_label:
				var fps = _performance_monitor.get_current_fps()
				fps_label.text = "当前: %.1f" % fps

				# 根据FPS设置颜色
				if fps < 30:
					fps_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				elif fps < 45:
					fps_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
				else:
					fps_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))

			var fps_avg_label = fps_container.get_node_or_null("FPSAvgLabel")
			if fps_avg_label:
				fps_avg_label.text = "平均: %.1f" % _performance_monitor.get_average_fps()

			var fps_min_label = fps_container.get_node_or_null("FPSMinLabel")
			if fps_min_label:
				fps_min_label.text = "最低: %.1f" % _performance_monitor.get_min_fps()

	# 更新内存
	var mem_vbox = performance_panel.get_node_or_null("VBoxContainer/PanelContainer2/MemVBox")
	if mem_vbox:
		var mem_container = mem_vbox.get_node_or_null("MemoryContainer")
		if mem_container:
			var memory_label = mem_container.get_node_or_null("MemoryLabel")
			if memory_label:
				var memory = _performance_monitor.get_current_memory_mb()
				memory_label.text = "内存: %.2f MB" % memory

				if memory > 512:
					memory_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				elif memory > 256:
					memory_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
				else:
					memory_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))

			var node_label = mem_container.get_node_or_null("NodeLabel")
			if node_label:
				node_label.text = "节点数: %d" % _performance_monitor.get_current_node_count()

	# 更新FPS历史
	var history_panel = performance_panel.get_node_or_null("VBoxContainer/PanelContainer3/VBoxContainer")
	if history_panel:
		var history_label = history_panel.get_node_or_null("HistoryLabel")
		if history_label:
			var fps_history = _performance_monitor.get_fps_history()
			if fps_history.size() > 0:
				var recent = fps_history.slice(-60)  # 最近60个
				var history_text = ""
				for i in range(0, recent.size(), 6):  # 每行显示10个值
					for j in range(6):
						if i + j < recent.size():
							history_text += "%.0f " % recent[i + j]
					history_text += "\n"
				history_label.text = history_text

func _update_llm_stats_panel():
	"""更新LLM统计面板"""
	if not llm_stats_panel or not _performance_monitor:
		return

	var summary_vbox = llm_stats_panel.get_node_or_null("VBoxContainer/PanelContainer/SummaryContainer")
	if summary_vbox:
		var total_calls_label = summary_vbox.get_node_or_null("TotalCallsLabel")
		if total_calls_label:
			total_calls_label.text = "📞 总调用次数: %d" % _performance_monitor.get_llm_total_calls()

		var success_rate_label = summary_vbox.get_node_or_null("SuccessRateLabel")
		if success_rate_label:
			var rate = _performance_monitor.get_llm_success_rate() * 100
			success_rate_label.text = "✅ 成功率: %.1f%%" % rate

			if rate < 90:
				success_rate_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			elif rate < 95:
				success_rate_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
			else:
				success_rate_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))

		var avg_time_label = summary_vbox.get_node_or_null("AvgTimeLabel")
		if avg_time_label:
			avg_time_label.text = "⏱️ 平均响应时间: %.2fs" % _performance_monitor.get_llm_average_response_time()

		var total_tokens_label = summary_vbox.get_node_or_null("TotalTokensLabel")
		if total_tokens_label:
			total_tokens_label.text = "🎫 总Token消耗: %d" % _performance_monitor.get_llm_total_tokens()

	# 更新按角色统计
	var scroll = llm_stats_panel.get_node_or_null("VBoxContainer/ScrollContainer")
	if scroll:
		var char_container = scroll.get_node_or_null("CharacterStatsContainer")
		if char_container:
			# 清空旧数据
			for child in char_container.get_children():
				child.queue_free()

			# 添加新数据
			var stats_by_char = _performance_monitor.get_llm_stats_by_character()
			for character_name in stats_by_char.keys():
				var char_stat = stats_by_char[character_name]

				var char_label = Label.new()
				char_label.text = "%s: %d次 | %.1f%% | %.2fs | %d tokens" % [
					character_name,
					char_stat.total,
					(float(char_stat.success) / char_stat.total * 100) if char_stat.total > 0 else 0.0,
					(char_stat.total_time / char_stat.total) if char_stat.total > 0 else 0.0,
					char_stat.tokens
				]
				char_container.add_child(char_label)

func _update_system_status_panel():
	"""更新系统状态面板"""
	if not system_status_panel or not _performance_monitor:
		return

	# 更新运行时间
	var uptime_panel = system_status_panel.get_node_or_null("VBoxContainer/PanelContainer/VBoxContainer")
	if uptime_panel:
		var uptime_label = uptime_panel.get_node_or_null("UptimeLabel")
		if uptime_label:
			var summary = _performance_monitor.get_performance_summary()
			uptime_label.text = "⏰ 运行时间: %s" % summary.get("uptime_formatted", "--")

	# 更新系统活动
	var activity_vbox = system_status_panel.get_node_or_null("VBoxContainer/PanelContainer2/ActivityContainer")
	if activity_vbox:
		var system_status = _performance_monitor.get_system_status()

		var dialogs_label = activity_vbox.get_node_or_null("DialogsLabel")
		if dialogs_label:
			dialogs_label.text = "💬 活跃对话: %d" % system_status.get("active_dialogs", 0)

		var tasks_label = activity_vbox.get_node_or_null("TasksLabel")
		if tasks_label:
			tasks_label.text = "📋 活跃任务: %d" % system_status.get("active_tasks", 0)

		var conflicts_label = activity_vbox.get_node_or_null("ConflictsLabel")
		if conflicts_label:
			conflicts_label.text = "⚔️ 活跃冲突: %d" % system_status.get("active_conflicts", 0)

		var transactions_label = activity_vbox.get_node_or_null("TransactionsLabel")
		if transactions_label:
			transactions_label.text = "💰 总交易数: %d" % system_status.get("total_transactions", 0)

func _on_fps_warning(fps: float):
	"""处理FPS警告"""
	if not performance_panel:
		return

	var warning_label = performance_panel.get_node_or_null("VBoxContainer/WarningLabel")
	if warning_label:
		warning_label.text = "⚠️ 警告: FPS下降至%.1f" % fps

func _on_fps_critical(fps: float):
	"""处理FPS危急警告"""
	if not performance_panel:
		return

	var warning_label = performance_panel.get_node_or_null("VBoxContainer/WarningLabel")
	if warning_label:
		warning_label.text = "🚨 危急: FPS严重下降至%.1f!" % fps

func _on_memory_warning(memory_mb: float):
	"""处理内存警告"""
	if not performance_panel:
		return

	var warning_label = performance_panel.get_node_or_null("VBoxContainer/WarningLabel")
	if warning_label:
		warning_label.text = "⚠️ 警告: 内存使用%.2fMB" % memory_mb
