# SaveLoadUI.gd - 存档加载界面
# 提供游戏存档、读档和删除存档的功能
# 更新版本: 使用新的 SaveManager API

extends Control

# 节点引用
@onready var save_list = $Panel/VBoxContainer/SaveList
@onready var save_name_input = $Panel/VBoxContainer/SaveNameContainer/SaveNameInput
@onready var save_button = $Panel/VBoxContainer/ButtonContainer/SaveButton
@onready var load_button = $Panel/VBoxContainer/ButtonContainer/LoadButton
@onready var delete_button = $Panel/VBoxContainer/ButtonContainer/DeleteButton
@onready var close_button = $Panel/VBoxContainer/ButtonContainer/CloseButton
@onready var status_label = $Panel/VBoxContainer/StatusLabel

# 当前选中的存档
var selected_save = ""
var selected_save_type = "manual"

func _ready():
	# 连接信号
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# 连接 SaveManager 信号
	if SaveManager:
		SaveManager.save_completed.connect(_on_save_completed)
		SaveManager.load_completed.connect(_on_load_completed)
		SaveManager.save_failed.connect(_on_save_failed)
		SaveManager.load_failed.connect(_on_load_failed)

	# 初始状态
	load_button.disabled = true
	delete_button.disabled = true
	status_label.text = ""

	# 加载存档列表
	refresh_save_list()

	# 默认隐藏
	hide()

# 显示界面
func show_ui():
	show()
	refresh_save_list()

# 隐藏界面
func hide_ui():
	hide()

# 刷新存档列表
func refresh_save_list():
	if not SaveManager:
		status_label.text = "SaveManager 未初始化"
		return

	# 清空列表
	save_list.clear()

	# 获取所有存档
	var saves = SaveManager.get_all_saves()

	# 添加到列表
	for save_info in saves:
		var save_name = save_info.get("save_name", "未知存档")
		var display_text = save_name

		# 如果有时间戳，添加日期信息
		if save_info.has("timestamp") and save_info["timestamp"] > 0:
			var datetime = Time.get_datetime_dict_from_unix_time(save_info["timestamp"])
			display_text += " (%04d-%02d-%02d %02d:%02d)" % [
				datetime["year"],
				datetime["month"],
				datetime["day"],
				datetime["hour"],
				datetime["minute"]
			]

		# 添加游戏时长信息
		if save_info.has("game_time") and save_info["game_time"] > 0:
			var hours = int(save_info["game_time"])
			var minutes = int((save_info["game_time"] - hours) * 60)
			display_text += " - %d小时%d分" % [hours, minutes]

		# 添加版本信息
		if save_info.has("version"):
			display_text += " [v%s]" % save_info["version"]

		save_list.add_item(display_text, null, true)
		save_list.set_item_metadata(save_list.get_item_count() - 1, save_name)

	# 连接选择信号
	if not save_list.item_selected.is_connected(_on_save_selected):
		save_list.item_selected.connect(_on_save_selected)

	# 更新状态
	if saves.size() == 0:
		status_label.text = "暂无存档"
	else:
		status_label.text = "共 %d 个存档" % saves.size()

# 保存按钮回调
func _on_save_pressed():
	if not SaveManager:
		status_label.text = "SaveManager 未初始化"
		return

	var save_name = save_name_input.text.strip_edges()

	# 检查是否输入了存档名
	if save_name.is_empty():
		# 使用自动生成的名称
		status_label.text = "正在保存..."
		await SaveManager.save_game("", "manual", true)
	else:
		status_label.text = "正在保存: %s..." % save_name
		await SaveManager.save_game(save_name, "manual", true)

# 加载按钮回调
func _on_load_pressed():
	if not SaveManager:
		status_label.text = "SaveManager 未初始化"
		return

	if selected_save.is_empty():
		status_label.text = "请先选择一个存档"
		return

	# 加载游戏
	status_label.text = "正在加载: %s..." % selected_save
	SaveManager.load_game(selected_save, selected_save_type)

# 删除按钮回调
func _on_delete_pressed():
	if not SaveManager:
		status_label.text = "SaveManager 未初始化"
		return

	if selected_save.is_empty():
		status_label.text = "请先选择一个存档"
		return

	# 删除存档
	if SaveManager.delete_save(selected_save):
		refresh_save_list()
		selected_save = ""
		selected_save_type = "manual"
		load_button.disabled = true
		delete_button.disabled = true
		status_label.text = "存档已删除"
	else:
		status_label.text = "删除失败"

# 关闭按钮回调
func _on_close_pressed():
	hide_ui()

# 存档选择回调
func _on_save_selected(index):
	selected_save = save_list.get_item_metadata(index)
	load_button.disabled = false
	delete_button.disabled = false
	save_name_input.text = selected_save

	# 判断是否是自动存档
	if selected_save.begins_with("autosave"):
		selected_save_type = "autosave"
	else:
		selected_save_type = "manual"

# 保存完成回调
func _on_save_completed(success: bool, save_name: String):
	if success:
		status_label.text = "保存成功: %s" % save_name
		refresh_save_list()
	else:
		status_label.text = "保存失败"

# 加载完成回调
func _on_load_completed(success: bool, save_name: String):
	if success:
		status_label.text = "加载成功: %s" % save_name
		# 延迟隐藏,让用户看到成功消息
		await get_tree().create_timer(0.5).timeout
		hide_ui()
	else:
		status_label.text = "加载失败"

# 保存失败回调
func _on_save_failed(error_message: String):
	status_label.text = "保存失败: %s" % error_message

# 加载失败回调
func _on_load_failed(error_message: String):
	status_label.text = "加载失败: %s" % error_message
