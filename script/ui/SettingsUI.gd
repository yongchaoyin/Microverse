extends Control
class_name SettingsUI

# 设置UI - 图形化管理AI角色和系统设置

signal settings_saved

@onready var agent_list: ItemList = $Panel/VBox/Tabs/AI角色/AgentList
@onready var add_btn: Button = $Panel/VBox/Tabs/AI角色/Toolbar/AddBtn
@onready var edit_btn: Button = $Panel/VBox/Tabs/AI角色/Toolbar/EditBtn
@onready var delete_btn: Button = $Panel/VBox/Tabs/AI角色/Toolbar/DeleteBtn
@onready var refresh_btn: Button = $Panel/VBox/Tabs/AI角色/Toolbar/RefreshBtn

@onready var global_api_option: OptionButton = $Panel/VBox/Tabs/通用设置/GlobalAPIOption
@onready var global_model_edit: LineEdit = $Panel/VBox/Tabs/通用设置/GlobalModelEdit
@onready var global_key_edit: LineEdit = $Panel/VBox/Tabs/通用设置/GlobalKeyEdit

@onready var language_option: OptionButton = $Panel/VBox/Tabs/通用设置/LanguageOption
@onready var font_size_slider: HSlider = $Panel/VBox/Tabs/通用设置/FontSizeContainer/FontSizeSlider
@onready var font_size_value: Label = $Panel/VBox/Tabs/通用设置/FontSizeContainer/FontSizeValue
@onready var theme_option: OptionButton = $Panel/VBox/Tabs/通用设置/ThemeOption
@onready var fg_color_picker: ColorPickerButton = $Panel/VBox/Tabs/通用设置/FgColorPicker
@onready var bg_color_picker: ColorPickerButton = $Panel/VBox/Tabs/通用设置/BgColorPicker
@onready var opacity_slider: HSlider = $Panel/VBox/Tabs/通用设置/OpacityContainer/OpacitySlider
@onready var opacity_value: Label = $Panel/VBox/Tabs/通用设置/OpacityContainer/OpacityValue
@onready var blur_slider: HSlider = $Panel/VBox/Tabs/通用设置/BlurContainer/BlurSlider
@onready var blur_value: Label = $Panel/VBox/Tabs/通用设置/BlurContainer/BlurValue

@onready var close_btn: Button = $Panel/VBox/Header/CloseBtn
@onready var save_btn: Button = $Panel/VBox/BottomBar/SaveBtn
@onready var cancel_btn: Button = $Panel/VBox/BottomBar/CancelBtn

@onready var agent_edit_dialog: Window = $AgentEditDialog
@onready var name_edit: LineEdit = $AgentEditDialog/VBox/NameEdit
@onready var api_option: OptionButton = $AgentEditDialog/VBox/APIOption
@onready var model_edit: LineEdit = $AgentEditDialog/VBox/ModelEdit
@onready var key_edit: LineEdit = $AgentEditDialog/VBox/KeyEdit
@onready var color_picker: ColorPickerButton = $AgentEditDialog/VBox/ColorPicker
@onready var prompt_edit: TextEdit = $AgentEditDialog/VBox/PromptEdit
@onready var enabled_check: CheckButton = $AgentEditDialog/VBox/Checks/EnabledCheck
@onready var moderator_check: CheckButton = $AgentEditDialog/VBox/Checks/ModeratorCheck
@onready var dialog_save_btn: Button = $AgentEditDialog/VBox/Buttons/SaveBtn
@onready var dialog_cancel_btn: Button = $AgentEditDialog/VBox/Buttons/CancelBtn

var agent_manager: AgentManager
var current_language := "zh_CN"
var editing_agent_name := ""
var is_adding_new := false

# 翻译字典
var translations := {
	"zh_CN": {
		"ai_roles": "AI角色",
		"general_settings": "通用设置",
		"about": "关于",
		"add": "添加",
		"edit": "编辑",
		"delete": "删除",
		"refresh": "刷新",
		"save": "保存",
		"cancel": "取消",
		"close": "关闭",
		"language": "界面语言",
		"font_size": "字体大小",
		"theme": "主题",
		"fg_color": "终端前景色",
		"bg_color": "终端背景色",
		"opacity": "终端透明度",
		"blur": "背景模糊度",
		"dark": "深色",
		"light": "浅色",
		"settings_saved": "设置已保存",
		"agent_name": "角色名称",
		"api_type": "API类型",
		"model": "模型",
		"api_key": "API密钥",
		"color": "颜色",
		"system_prompt": "系统提示词",
		"enabled": "启用",
		"moderator": "主持人",
		"confirm_delete": "确定要删除角色",
		"yes": "是",
		"no": "否"
	},
	"en_US": {
		"ai_roles": "AI Roles",
		"general_settings": "General Settings",
		"about": "About",
		"add": "Add",
		"edit": "Edit",
		"delete": "Delete",
		"refresh": "Refresh",
		"save": "Save",
		"cancel": "Cancel",
		"close": "Close",
		"language": "Interface Language",
		"font_size": "Font Size",
		"theme": "Theme",
		"fg_color": "Terminal Foreground",
		"bg_color": "Terminal Background",
		"opacity": "Terminal Opacity",
		"blur": "Background Blur",
		"dark": "Dark",
		"light": "Light",
		"settings_saved": "Settings saved",
		"agent_name": "Role Name",
		"api_type": "API Type",
		"model": "Model",
		"api_key": "API Key",
		"color": "Color",
		"system_prompt": "System Prompt",
		"enabled": "Enabled",
		"moderator": "Moderator",
		"confirm_delete": "Confirm delete role",
		"yes": "Yes",
		"no": "No"
	}
}

func _ready() -> void:
	agent_manager = get_node("/root/AgentManager")

	# 连接信号
	add_btn.pressed.connect(_on_add_agent)
	edit_btn.pressed.connect(_on_edit_agent)
	delete_btn.pressed.connect(_on_delete_agent)
	refresh_btn.pressed.connect(_refresh_agent_list)

	close_btn.pressed.connect(hide)
	save_btn.pressed.connect(_on_save_settings)
	cancel_btn.pressed.connect(hide)

	language_option.item_selected.connect(_on_language_changed)
	font_size_slider.value_changed.connect(_on_font_size_changed)
	theme_option.item_selected.connect(_on_theme_changed)
	fg_color_picker.color_changed.connect(_on_fg_color_changed)
	bg_color_picker.color_changed.connect(_on_bg_color_changed)
	opacity_slider.value_changed.connect(_on_opacity_changed)
	blur_slider.value_changed.connect(_on_blur_changed)

	dialog_save_btn.pressed.connect(_on_dialog_save)
	dialog_cancel_btn.pressed.connect(func(): agent_edit_dialog.hide())

	agent_list.item_selected.connect(_on_agent_selected)

	# 初始化
	_init_language_options()
	_init_theme_options()
	_init_api_providers()
	_init_global_api_options()
	_load_global_ai_config()
	_refresh_agent_list()

	# 隐藏窗口
	hide()

func _init_language_options() -> void:
	language_option.clear()
	language_option.add_item("中文 (简体)", 0)
	language_option.add_item("English", 1)
	language_option.select(0)

func _init_theme_options() -> void:
	theme_option.clear()
	theme_option.add_item("深色 Dark", 0)
	theme_option.add_item("浅色 Light", 1)
	theme_option.select(0)

func _init_api_providers() -> void:
	api_option.clear()
	var providers := APIConfig.get_api_types()
	for i in range(providers.size()):
		var provider := APIConfig.get_provider(providers[i])
		api_option.add_item("%s (%s)" % [provider.name, provider.display_name], i)

func _init_global_api_options() -> void:
	# 初始化全局API提供商选项
	global_api_option.clear()
	var api_types := APIConfig.get_api_types()
	for api_type in api_types:
		global_api_option.add_item(api_type)

func _load_global_ai_config() -> void:
	# 从SettingsManager加载全局AI配置
	var settings_mgr = get_node_or_null("/root/SettingsManager")
	if settings_mgr and settings_mgr.has_method("get_global_ai_config"):
		var config: Dictionary = settings_mgr.get_global_ai_config()
		if config.has("api_type"):
			for i in range(global_api_option.item_count):
				if global_api_option.get_item_text(i) == config.api_type:
					global_api_option.select(i)
					break
		if config.has("model"):
			global_model_edit.text = config.model
		if config.has("api_key"):
			global_key_edit.text = config.api_key

func _refresh_agent_list() -> void:
	agent_list.clear()
	var agents := agent_manager.get_agents()

	for agent in agents:
		var status_icon := "✓" if agent.enabled else "✗"
		var moderator_icon := " 👑" if agent.is_moderator else ""
		var api_key_icon := " 🔑" if agent.api_key != "" else " ⚠"

		var item_text := "%s %s [%s/%s]%s%s" % [
			status_icon,
			agent.name,
			agent.api_type,
			agent.model,
			moderator_icon,
			api_key_icon
		]

		var idx := agent_list.add_item(item_text)
		agent_list.set_item_metadata(idx, agent.name)

		# 设置颜色
		if agent.enabled:
			agent_list.set_item_custom_fg_color(idx, agent.color)
		else:
			agent_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))

func _on_add_agent() -> void:
	is_adding_new = true
	editing_agent_name = ""

	# 清空表单
	name_edit.text = ""
	api_option.select(0)
	model_edit.text = ""
	key_edit.text = ""
	color_picker.color = Color(0.8, 0.9, 1.0)
	prompt_edit.text = ""
	enabled_check.button_pressed = true
	moderator_check.button_pressed = false

	agent_edit_dialog.title = "添加AI角色 Add Agent"
	agent_edit_dialog.popup_centered()

func _on_edit_agent() -> void:
	var selected := agent_list.get_selected_items()
	if selected.size() == 0:
		_show_message("请先选择一个角色 Please select an agent")
		return

	var agent_name: String = agent_list.get_item_metadata(selected[0])
	var agent := agent_manager.get_agent_by_name(agent_name)

	if agent.is_empty():
		_show_message("未找到角色 Agent not found")
		return

	is_adding_new = false
	editing_agent_name = agent_name

	# 填充表单
	name_edit.text = agent.name

	# 选择API提供商
	var providers := APIConfig.get_api_types()
	for i in range(providers.size()):
		if providers[i] == agent.api_type:
			api_option.select(i)
			break

	model_edit.text = agent.model
	key_edit.text = agent.api_key if agent.api_key != "" else ""
	color_picker.color = agent.color
	prompt_edit.text = agent.system_prompt
	enabled_check.button_pressed = agent.enabled
	moderator_check.button_pressed = agent.is_moderator

	agent_edit_dialog.title = "编辑AI角色 Edit Agent: " + agent_name
	agent_edit_dialog.popup_centered()

func _on_delete_agent() -> void:
	var selected := agent_list.get_selected_items()
	if selected.size() == 0:
		_show_message("Please select an agent first")
		return

	var agent_name: String = agent_list.get_item_metadata(selected[0])

	# 确认对话框
	var confirm := "%s '%s'?" % [_tr("confirm_delete"), agent_name]

	# 简单确认 (Godot没有内置确认对话框,这里用AcceptDialog)
	var dialog := AcceptDialog.new()
	dialog.dialog_text = confirm
	dialog.ok_button_text = _tr("delete")
	add_child(dialog)

	dialog.confirmed.connect(func():
		agent_manager.remove_agent(agent_name)
		_refresh_agent_list()
		_show_message("Deleted: " + agent_name)
		dialog.queue_free()
	)

	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

func _on_dialog_save() -> void:
	var agent_name := name_edit.text.strip_edges()

	if agent_name == "":
		_show_message("角色名称不能为空 Agent name cannot be empty")
		return

	# 获取选中的API提供商
	var selected_api_idx := api_option.selected
	var providers := APIConfig.get_api_types()
	var api_type := providers[selected_api_idx]

	var agent_data := {
		"name": agent_name,
		"api_type": api_type,
		"model": model_edit.text.strip_edges(),
		"api_key": key_edit.text.strip_edges(),
		"color": color_picker.color,
		"system_prompt": prompt_edit.text,
		"enabled": enabled_check.button_pressed,
		"is_moderator": moderator_check.button_pressed
	}

	# 如果是重命名
	if not is_adding_new and editing_agent_name != agent_name:
		agent_manager.remove_agent(editing_agent_name)

	agent_manager.upsert_agent(agent_data)
	agent_edit_dialog.hide()
	_refresh_agent_list()

	var action := "添加 Added" if is_adding_new else "更新 Updated"
	_show_message("%s角色: %s\n%s agent: %s" % [action, agent_name, action, agent_name])

func _on_agent_selected(_index: int) -> void:
	edit_btn.disabled = false
	delete_btn.disabled = false

func _on_language_changed(index: int) -> void:
	current_language = "zh_CN" if index == 0 else "en_US"
	_apply_language()

func _on_font_size_changed(value: float) -> void:
	font_size_value.text = str(int(value))

	# 实时应用字体大小到终端
	var terminal_chat = get_parent()
	if terminal_chat and "font_size_slider" in terminal_chat and terminal_chat.font_size_slider:
		terminal_chat.font_size_slider.value = value

func _on_theme_changed(_index: int) -> void:
	# 主题切换将在保存时应用
	pass

func _on_fg_color_changed(color: Color) -> void:
	# 实时应用前景色到终端
	var terminal_chat = get_parent()
	if terminal_chat and "fg_color" in terminal_chat:
		terminal_chat.fg_color = color
		if "_apply_theme" in terminal_chat:
			terminal_chat._apply_theme()

func _on_bg_color_changed(color: Color) -> void:
	# 实时应用背景色到终端
	var terminal_chat = get_parent()
	if terminal_chat and "bg_color" in terminal_chat:
		terminal_chat.bg_color = color
		if "_apply_theme" in terminal_chat:
			terminal_chat._apply_theme()

func _on_opacity_changed(value: float) -> void:
	opacity_value.text = str(int(value * 100)) + "%"

	# 实时应用透明度到终端
	var terminal_chat = get_parent()
	if terminal_chat:
		terminal_chat.modulate.a = value

func _on_blur_changed(value: float) -> void:
	blur_value.text = str(value)

	# 实时应用模糊度 (需要在终端添加背景模糊材质)
	var terminal_chat = get_parent()
	if terminal_chat and "blur_amount" in terminal_chat:
		terminal_chat.blur_amount = value

func _on_save_settings() -> void:
	# 保存全局AI配置
	var global_ai_config := {
		"api_type": global_api_option.get_item_text(global_api_option.selected),
		"model": global_model_edit.text,
		"api_key": global_key_edit.text
	}
	var settings_mgr = get_node_or_null("/root/SettingsManager")
	if settings_mgr and settings_mgr.has_method("set_global_ai_config"):
		settings_mgr.set_global_ai_config(global_ai_config)

	# 保存通用设置
	var settings := {
		"language": current_language,
		"font_size": int(font_size_slider.value),
		"theme": theme_option.selected,
		"fg_color": fg_color_picker.color,
		"bg_color": bg_color_picker.color,
		"opacity": opacity_slider.value,
		"blur": blur_slider.value
	}

	# 发出信号
	settings_saved.emit(settings)

	_show_message(_tr("settings_saved"))
	hide()

func _tr(key: String) -> String:
	# 翻译辅助函数
	return translations[current_language].get(key, key)

func _apply_language() -> void:
	# 应用语言设置到所有UI元素
	# 按钮
	add_btn.text = _tr("add")
	edit_btn.text = _tr("edit")
	delete_btn.text = _tr("delete")
	refresh_btn.text = _tr("refresh")
	save_btn.text = _tr("save")
	cancel_btn.text = _tr("cancel")
	close_btn.text = _tr("close")

	# 标签 - 通用设置
	$Panel/VBox/Tabs/通用设置/LanguageLabel.text = _tr("language") + ":"
	$Panel/VBox/Tabs/通用设置/FontSizeLabel.text = _tr("font_size") + ":"
	$Panel/VBox/Tabs/通用设置/ThemeLabel.text = _tr("theme") + ":"
	$Panel/VBox/Tabs/通用设置/FgColorLabel.text = _tr("fg_color") + ":"
	$Panel/VBox/Tabs/通用设置/BgColorLabel.text = _tr("bg_color") + ":"
	$Panel/VBox/Tabs/通用设置/OpacityLabel.text = _tr("opacity") + ":"
	$Panel/VBox/Tabs/通用设置/BlurLabel.text = _tr("blur") + ":"

	# 主题选项
	theme_option.set_item_text(0, _tr("dark"))
	theme_option.set_item_text(1, _tr("light"))

	# 对话框标签
	$AgentEditDialog/VBox/NameLabel.text = _tr("agent_name") + ":"
	$AgentEditDialog/VBox/APILabel.text = _tr("api_type") + ":"
	$AgentEditDialog/VBox/ModelLabel.text = _tr("model") + ":"
	$AgentEditDialog/VBox/KeyLabel.text = _tr("api_key") + ":"
	$AgentEditDialog/VBox/ColorLabel.text = _tr("color") + ":"
	$AgentEditDialog/VBox/PromptLabel.text = _tr("system_prompt") + ":"
	enabled_check.text = _tr("enabled")
	moderator_check.text = _tr("moderator")
	dialog_save_btn.text = _tr("save")
	dialog_cancel_btn.text = _tr("cancel")

func _show_message(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = text
	dialog.ok_button_text = "确定 OK"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

	# 自动关闭
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(dialog):
		dialog.hide()
		dialog.queue_free()

func show_settings() -> void:
	_refresh_agent_list()
	_sync_current_settings()
	show()

func _sync_current_settings() -> void:
	# 从终端同步当前设置
	var terminal_chat = get_parent()
	if not terminal_chat:
		return

	# 字体大小
	if "font_size_slider" in terminal_chat and terminal_chat.font_size_slider:
		font_size_slider.value = terminal_chat.font_size_slider.value
		font_size_value.text = str(int(terminal_chat.font_size_slider.value))

	# 颜色
	if "fg_color" in terminal_chat:
		fg_color_picker.color = terminal_chat.fg_color
	if "bg_color" in terminal_chat:
		bg_color_picker.color = terminal_chat.bg_color

	# 透明度
	opacity_slider.value = terminal_chat.modulate.a
	opacity_value.text = str(int(terminal_chat.modulate.a * 100)) + "%"

	# 模糊度
	if "blur_amount" in terminal_chat:
		blur_slider.value = terminal_chat.blur_amount
		blur_value.text = str(terminal_chat.blur_amount)
