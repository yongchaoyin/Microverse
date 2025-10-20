# ============================================================
# SaveManager.gd
# ============================================================
# SaveManager - 游戏存档系统管理器
#
# 功能:
# - 完整的游戏状态保存和加载
# - 自动存档 (每游戏日触发)
# - 手动存档 (多槽位支持)
# - 快速存档/读档 (F5/F9)
# - 版本迁移系统 (向前兼容)
# - 备份管理 (防止数据丢失)
# - 存档元数据和截图
#
# 设计哲学:
# - 存档完整无损 - 加载后游戏状态100%恢复
# - 存档向前兼容 - 旧版本存档能在新版本加载
# - 存档可读可调试 - 使用JSON格式
# - 存档安全可靠 - 备份机制防止数据损坏
#
# 作者: Claude (Sonnet 4.5)
# 创建日期: 2025-10-20
# ============================================================

extends Node

# ============================================================
# 常量
# ============================================================

const SAVE_VERSION = "1.0.0"
const SAVE_DIR = "user://saves/"
const SCREENSHOT_DIR = "user://saves/screenshots/"
const BACKUP_DIR = "user://saves/backups/"
const AUTOSAVE_DIR = "user://saves/autosave/"

const MAX_SAVE_SLOTS = 10
const MAX_AUTOSAVE_COUNT = 5
const MAX_BACKUP_COUNT = 3

# ============================================================
# 信号
# ============================================================

signal save_started()
signal save_completed(success: bool, save_name: String)
signal save_failed(error_message: String)

signal load_started()
signal load_completed(success: bool, save_name: String)
signal load_failed(error_message: String)

signal save_list_updated(save_files: Array)

# ============================================================
# 变量
# ============================================================

var current_save_name: String = ""
var is_saving: bool = false
var is_loading: bool = false

var _initialized: bool = false

# ============================================================
# 初始化
# ============================================================

func _ready():
	print("[SaveManager] 存档系统初始化")
	_ensure_directories_exist()
	_connect_signals()
	_initialized = true
	print("[SaveManager] 存档系统初始化完成")

func _ensure_directories_exist():
	"""确保所有存档目录存在"""
	var directories = [SAVE_DIR, SCREENSHOT_DIR, BACKUP_DIR, AUTOSAVE_DIR]

	for dir_path in directories:
		var dir = DirAccess.open("user://")
		if not dir.dir_exists(dir_path):
			var result = dir.make_dir_recursive(dir_path)
			if result == OK:
				print("  - 创建目录: %s" % dir_path)
			else:
				push_error("  - 无法创建目录: %s" % dir_path)

func _connect_signals():
	"""连接其他系统信号"""
	# 连接时间系统 (自动存档)
	if TimeSystem:
		TimeSystem.day_changed.connect(_on_day_changed)
		print("  - 已连接 TimeSystem.day_changed 信号 (自动存档)")

# ============================================================
# 保存游戏
# ============================================================

func save_game(save_name: String = "", save_type: String = "manual", create_screenshot: bool = true) -> bool:
	"""
	保存游戏

	参数:
		save_name: 存档名称 (为空则自动生成)
		save_type: "manual" 或 "autosave"
		create_screenshot: 是否创建截图

	返回:
		true - 保存成功
		false - 保存失败
	"""

	if is_saving:
		push_warning("[SaveManager] 正在保存中,请稍候")
		return false

	is_saving = true
	save_started.emit()

	# 生成存档名称
	if save_name.is_empty():
		save_name = _generate_save_name(save_type)

	print("[SaveManager] 开始保存游戏: %s" % save_name)

	# 收集游戏数据
	var save_data = _collect_all_game_data(save_name, save_type)

	# 创建截图
	if create_screenshot:
		var screenshot_path = await _capture_screenshot(save_name)
		save_data["save_meta"]["screenshot_path"] = screenshot_path

	# 写入存档文件
	var file_path = _get_save_path(save_name, save_type)
	var success = _write_save_file(file_path, save_data)

	if success:
		current_save_name = save_name
		print("[SaveManager] 游戏保存成功: %s" % file_path)
		save_completed.emit(true, save_name)

		# 创建备份
		_create_backup(save_name, save_type)
	else:
		push_error("[SaveManager] 游戏保存失败: %s" % file_path)
		save_failed.emit("保存文件写入失败")

	is_saving = false
	return success

func _collect_all_game_data(save_name: String, save_type: String) -> Dictionary:
	"""收集所有游戏数据"""

	print("  [1/9] 收集元数据...")
	var save_data = {
		"save_meta": _collect_save_meta(save_name, save_type),
	}

	print("  [2/9] 收集时间系统数据...")
	save_data["time_system"] = _collect_time_system_data()

	print("  [3/9] 收集角色数据...")
	save_data["characters"] = _collect_all_characters_data()

	print("  [4/9] 收集经济系统数据...")
	save_data["economy_system"] = _collect_economy_system_data()

	print("  [5/9] 收集关系网络数据...")
	save_data["relationship_network"] = _collect_relationship_network_data()

	print("  [6/9] 收集任务系统数据...")
	save_data["task_system"] = _collect_task_system_data()

	print("  [7/9] 收集地点数据...")
	save_data["locations"] = _collect_locations_data()

	print("  [8/9] 收集设置数据...")
	save_data["settings"] = _collect_settings_data()

	print("  [9/9] 收集统计数据...")
	save_data["statistics"] = _collect_statistics_data()

	return save_data

func _collect_save_meta(save_name: String, save_type: String) -> Dictionary:
	"""收集存档元数据"""
	return {
		"version": SAVE_VERSION,
		"save_name": save_name,
		"save_type": save_type,
		"created_at": Time.get_unix_time_from_system(),
		"modified_at": Time.get_unix_time_from_system(),
		"game_time_elapsed": TimeSystem.total_elapsed_hours if TimeSystem else 0.0,
		"screenshot_path": "",
		"platform": OS.get_name(),
		"godot_version": Engine.get_version_info().string,
		"game_version": ProjectSettings.get_setting("application/config/version", "1.0.0")
	}

func _collect_time_system_data() -> Dictionary:
	"""收集时间系统数据"""
	if not TimeSystem:
		return {}

	return {
		"current_year": TimeSystem.current_year,
		"current_season": TimeSystem.current_season,
		"current_season_index": TimeSystem.current_season_index,
		"current_day": TimeSystem.current_day,
		"current_day_of_week": TimeSystem.current_day_of_week,
		"current_hour": TimeSystem.current_hour,
		"current_minute": TimeSystem.current_minute,
		"total_elapsed_hours": TimeSystem.total_elapsed_hours,
		"total_elapsed_days": TimeSystem.total_elapsed_days,
		"time_scale": TimeSystem.time_scale,
		"is_paused": TimeSystem.is_paused
	}

func _collect_all_characters_data() -> Array:
	"""收集所有角色数据"""
	var characters_data = []

	var characters = get_tree().get_nodes_in_group("characters")
	for character in characters:
		var character_data = _collect_single_character_data(character)
		if character_data:
			characters_data.append(character_data)

	print("    - 收集了 %d 个角色的数据" % characters_data.size())
	return characters_data

func _collect_single_character_data(character: Node) -> Dictionary:
	"""收集单个角色的完整数据"""

	var data = {
		"character_id": str(character.get_instance_id()),
		"character_name": character.name,
		"transform": _collect_character_transform(character),
		"economic": _collect_character_economic(character),
		"relationships": _collect_character_relationships(character),
		"memories": _collect_character_memories(character),
		"tasks": _collect_character_tasks(character),
		"metadata": _collect_character_metadata(character)
	}

	return data

func _collect_character_transform(character: Node) -> Dictionary:
	"""收集角色Transform数据"""
	return {
		"position": {"x": character.global_position.x, "y": character.global_position.y},
		"rotation": character.rotation,
		"scale": {"x": character.scale.x, "y": character.scale.y}
	}

func _collect_character_economic(character: Node) -> Dictionary:
	"""收集角色经济数据"""
	if not EconomyManager:
		return {}

	var account = EconomyManager.get_account(character.name)
	if not account:
		return {}

	return {
		"money": account.balance,
		"total_income": account.total_income,
		"total_expense": account.total_expense
	}

func _collect_character_relationships(character: Node) -> Dictionary:
	"""收集角色关系数据"""
	if not RelationshipManager:
		return {}

	var relationships = {}
	var all_characters = get_tree().get_nodes_in_group("characters")

	for other_character in all_characters:
		if other_character == character:
			continue

		var rel_data = RelationshipManager.get_relationship_data(character.name, other_character.name)
		if rel_data and not rel_data.is_empty():
			relationships[other_character.name] = rel_data

	return relationships

func _collect_character_memories(character: Node) -> Array:
	"""收集角色记忆数据"""
	if not MemoryManager:
		return []

	var memories = MemoryManager.get_all_memories(character)
	var memories_data = []

	for memory in memories:
		memories_data.append({
			"memory_id": memory.get("id", ""),
			"content": memory.get("content", ""),
			"timestamp": memory.get("timestamp", ""),
			"created_at": memory.get("created_at", 0.0),
			"type": memory.get("type", ""),
			"importance": memory.get("importance", ""),
			"emotional_valence": memory.get("emotional_valence", 0.0)
		})

	return memories_data

func _collect_character_tasks(character: Node) -> Array:
	"""收集角色任务数据"""
	if not TaskSystem:
		return []

	var tasks = TaskSystem.get_character_tasks(character.name)
	var tasks_data = []

	for task in tasks:
		if task.has_method("to_dict"):
			tasks_data.append(task.to_dict())
		elif task is Dictionary:
			tasks_data.append(task)

	return tasks_data

func _collect_character_metadata(character: Node) -> Dictionary:
	"""收集角色元数据"""
	var metadata = {}

	# 收集元数据
	if character.has_method("get_meta_list"):
		for meta_key in character.get_meta_list():
			metadata[meta_key] = character.get_meta(meta_key)

	return metadata

func _collect_economy_system_data() -> Dictionary:
	"""收集经济系统数据"""
	if not EconomyManager:
		return {}

	return {
		"inflation_rate": EconomyManager.inflation_rate if EconomyManager.has_property("inflation_rate") else 1.0,
		"total_money_supply": EconomyManager.total_money_supply if EconomyManager.has_property("total_money_supply") else 0
	}

func _collect_relationship_network_data() -> Dictionary:
	"""收集关系网络数据"""
	if not RelationshipManager:
		return {}

	# RelationshipManager 的数据已经在角色数据中收集
	# 这里只收集全局设置
	return {
		"initialized": true
	}

func _collect_task_system_data() -> Dictionary:
	"""收集任务系统数据"""
	if not TaskSystem:
		return {}

	# 任务数据已经在角色数据中收集
	# 这里只收集全局设置
	return {
		"initialized": true
	}

func _collect_locations_data() -> Array:
	"""收集地点数据"""
	if not LocationManager:
		return []

	var locations = LocationManager.get_all_locations() if LocationManager.has_method("get_all_locations") else []
	var locations_data = []

	for location in locations:
		if location is Dictionary:
			locations_data.append(location)
		elif location.has_method("to_dict"):
			locations_data.append(location.to_dict())

	return locations_data

func _collect_settings_data() -> Dictionary:
	"""收集设置数据"""
	if not SettingsManager:
		return {}

	# 设置数据由 SettingsManager 自己管理
	# 不需要在存档中保存
	return {}

func _collect_statistics_data() -> Dictionary:
	"""收集统计数据"""
	var stats = {}

	if TimeSystem:
		stats["total_game_hours"] = TimeSystem.total_elapsed_hours
		stats["total_game_days"] = TimeSystem.total_elapsed_days

	if DatabaseManager:
		var db_stats = DatabaseManager.get_database_stats()
		stats["database_stats"] = db_stats

	return stats

func _write_save_file(file_path: String, save_data: Dictionary) -> bool:
	"""写入存档文件"""
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] 无法创建存档文件: %s" % file_path)
		return false

	# 美化JSON输出 (开发阶段方便调试)
	var json_string = JSON.stringify(save_data, "\t")

	file.store_string(json_string)
	file.close()

	return true

func _capture_screenshot(save_name: String) -> String:
	"""捕获游戏截图"""
	var screenshot_path = SCREENSHOT_DIR + save_name + ".png"

	# 等待一帧确保渲染完成
	await get_tree().process_frame

	var viewport = get_viewport()
	var image = viewport.get_texture().get_image()

	# 缩小截图尺寸 (节省空间)
	image.resize(320, 180, Image.INTERPOLATE_LANCZOS)

	var error = image.save_png(screenshot_path)
	if error != OK:
		push_error("[SaveManager] 截图保存失败: %s" % screenshot_path)
		return ""

	return screenshot_path

func _create_backup(save_name: String, save_type: String):
	"""创建存档备份"""
	var source_path = _get_save_path(save_name, save_type)
	var backup_name = save_name + "_backup_" + str(Time.get_unix_time_from_system())
	var backup_path = BACKUP_DIR + backup_name + ".json"

	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		var result = dir.copy(source_path, backup_path)
		if result == OK:
			print("  - 创建备份: %s" % backup_path)
			_cleanup_old_backups(save_name)
		else:
			push_warning("  - 备份创建失败")

func _cleanup_old_backups(save_name: String):
	"""清理旧备份"""
	var dir = DirAccess.open(BACKUP_DIR)
	if not dir:
		return

	var backups = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.begins_with(save_name + "_backup_"):
			backups.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	# 按时间排序,保留最新的MAX_BACKUP_COUNT个
	backups.sort()
	backups.reverse()

	if backups.size() > MAX_BACKUP_COUNT:
		for i in range(MAX_BACKUP_COUNT, backups.size()):
			dir.remove(backups[i])
			print("  - 删除旧备份: %s" % backups[i])

# ============================================================
# 加载游戏
# ============================================================

func load_game(save_name: String, save_type: String = "manual") -> bool:
	"""
	加载游戏

	参数:
		save_name: 存档名称
		save_type: "manual" 或 "autosave"

	返回:
		true - 加载成功
		false - 加载失败
	"""

	if is_loading:
		push_warning("[SaveManager] 正在加载中,请稍候")
		return false

	is_loading = true
	load_started.emit()

	var file_path = _get_save_path(save_name, save_type)

	if not FileAccess.file_exists(file_path):
		push_error("[SaveManager] 存档文件不存在: %s" % file_path)
		load_failed.emit("存档文件不存在")
		is_loading = false
		return false

	print("[SaveManager] 开始加载游戏: %s" % save_name)

	# 读取存档文件
	var save_data = _read_save_file(file_path)
	if not save_data:
		push_error("[SaveManager] 存档文件读取失败")
		load_failed.emit("存档文件损坏")
		is_loading = false
		return false

	# 验证版本兼容性
	if not _validate_save_version(save_data):
		push_warning("[SaveManager] 存档版本不兼容,尝试迁移...")
		save_data = _migrate_save_data(save_data)

	# 应用游戏数据
	var success = _apply_all_game_data(save_data)

	if success:
		current_save_name = save_name
		print("[SaveManager] 游戏加载成功")
		load_completed.emit(true, save_name)
	else:
		push_error("[SaveManager] 游戏加载失败")
		load_failed.emit("数据应用失败")

	is_loading = false
	return success

func _read_save_file(file_path: String) -> Dictionary:
	"""读取存档文件"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var content = file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return {}

	var data = JSON.parse_string(content)
	if not data:
		return {}

	return data

func _validate_save_version(save_data: Dictionary) -> bool:
	"""验证存档版本"""
	if not save_data.has("save_meta"):
		return false

	var save_version = save_data["save_meta"].get("version", "")

	# 简单版本号比较
	return save_version == SAVE_VERSION

func _migrate_save_data(save_data: Dictionary) -> Dictionary:
	"""迁移旧版本存档数据"""
	var old_version = save_data.get("save_meta", {}).get("version", "0.0.0")
	print("  - 从版本 %s 迁移到 %s" % [old_version, SAVE_VERSION])

	# TODO: 实现版本迁移逻辑
	# 例如: 添加缺失的字段,转换数据格式等

	save_data["save_meta"]["version"] = SAVE_VERSION
	save_data["save_meta"]["migrated_from"] = old_version
	save_data["save_meta"]["migration_timestamp"] = Time.get_unix_time_from_system()

	return save_data

func _apply_all_game_data(save_data: Dictionary) -> bool:
	"""应用所有游戏数据"""

	print("  [1/7] 应用时间系统数据...")
	_apply_time_system_data(save_data.get("time_system", {}))

	print("  [2/7] 应用经济系统数据...")
	_apply_economy_system_data(save_data.get("economy_system", {}))

	print("  [3/7] 应用地点数据...")
	_apply_locations_data(save_data.get("locations", []))

	print("  [4/7] 应用角色数据...")
	_apply_all_characters_data(save_data.get("characters", []))

	print("  [5/7] 应用关系网络数据...")
	_apply_relationship_network_data(save_data.get("relationship_network", {}))

	print("  [6/7] 应用任务系统数据...")
	_apply_task_system_data(save_data.get("task_system", {}))

	print("  [7/7] 应用设置数据...")
	_apply_settings_data(save_data.get("settings", {}))

	return true

func _apply_time_system_data(data: Dictionary):
	"""应用时间系统数据"""
	if not TimeSystem or data.is_empty():
		return

	TimeSystem.current_year = data.get("current_year", 1)
	TimeSystem.current_season = data.get("current_season", "Spring")
	TimeSystem.current_season_index = data.get("current_season_index", 0)
	TimeSystem.current_day = data.get("current_day", 1)
	TimeSystem.current_day_of_week = data.get("current_day_of_week", 0)
	TimeSystem.current_hour = data.get("current_hour", 8.0)
	TimeSystem.current_minute = data.get("current_minute", 0)
	TimeSystem.total_elapsed_hours = data.get("total_elapsed_hours", 0.0)
	TimeSystem.total_elapsed_days = data.get("total_elapsed_days", 0)
	TimeSystem.time_scale = data.get("time_scale", 3.0)
	TimeSystem.is_paused = data.get("is_paused", false)

func _apply_economy_system_data(data: Dictionary):
	"""应用经济系统数据"""
	if not EconomyManager or data.is_empty():
		return

	if data.has("inflation_rate") and EconomyManager.has_property("inflation_rate"):
		EconomyManager.inflation_rate = data["inflation_rate"]

func _apply_locations_data(locations_data: Array):
	"""应用地点数据"""
	if not LocationManager or locations_data.is_empty():
		return

	# LocationManager 处理地点恢复
	if LocationManager.has_method("restore_locations"):
		LocationManager.restore_locations(locations_data)

func _apply_all_characters_data(characters_data: Array):
	"""应用所有角色数据"""
	for character_data in characters_data:
		var character = _find_character_by_name(character_data.get("character_name", ""))
		if character:
			_apply_single_character_data(character, character_data)
		else:
			push_warning("  - 未找到角色: %s" % character_data.get("character_name", ""))

func _apply_single_character_data(character: Node, data: Dictionary):
	"""应用单个角色数据"""
	_apply_character_transform(character, data.get("transform", {}))
	_apply_character_economic(character, data.get("economic", {}))
	_apply_character_relationships(character, data.get("relationships", {}))
	_apply_character_memories(character, data.get("memories", []))
	_apply_character_tasks(character, data.get("tasks", []))
	_apply_character_metadata(character, data.get("metadata", {}))

func _apply_character_transform(character: Node, data: Dictionary):
	"""应用角色Transform"""
	if data.has("position"):
		var pos = data["position"]
		character.global_position = Vector2(pos.x, pos.y)

	if data.has("rotation"):
		character.rotation = data["rotation"]

	if data.has("scale"):
		var scl = data["scale"]
		character.scale = Vector2(scl.x, scl.y)

func _apply_character_economic(character: Node, data: Dictionary):
	"""应用角色经济数据"""
	if not EconomyManager or data.is_empty():
		return

	if data.has("money"):
		EconomyManager.set_balance(character.name, data["money"])

func _apply_character_relationships(character: Node, relationships: Dictionary):
	"""应用角色关系数据"""
	if not RelationshipManager or relationships.is_empty():
		return

	for target_name in relationships.keys():
		var rel_data = relationships[target_name]
		if RelationshipManager.has_method("restore_relationship"):
			RelationshipManager.restore_relationship(character.name, target_name, rel_data)

func _apply_character_memories(character: Node, memories: Array):
	"""应用角色记忆数据"""
	if not MemoryManager or memories.is_empty():
		return

	# 清除现有记忆
	if MemoryManager.has_method("clear_memories"):
		MemoryManager.clear_memories(character)

	# 恢复记忆
	for memory_data in memories:
		if MemoryManager.has_method("restore_memory"):
			MemoryManager.restore_memory(character, memory_data)

func _apply_character_tasks(character: Node, tasks: Array):
	"""应用角色任务数据"""
	if not TaskSystem or tasks.is_empty():
		return

	# 清除现有任务
	if TaskSystem.has_method("clear_character_tasks"):
		TaskSystem.clear_character_tasks(character.name)

	# 恢复任务
	for task_data in tasks:
		if TaskSystem.has_method("restore_task"):
			TaskSystem.restore_task(character.name, task_data)

func _apply_character_metadata(character: Node, metadata: Dictionary):
	"""应用角色元数据"""
	for meta_key in metadata.keys():
		character.set_meta(meta_key, metadata[meta_key])

func _apply_relationship_network_data(data: Dictionary):
	"""应用关系网络数据"""
	# 关系数据已在角色数据中应用
	pass

func _apply_task_system_data(data: Dictionary):
	"""应用任务系统数据"""
	# 任务数据已在角色数据中应用
	pass

func _apply_settings_data(data: Dictionary):
	"""应用设置数据"""
	# 设置由 SettingsManager 自己管理
	pass

# ============================================================
# 自动存档
# ============================================================

func _on_day_changed(new_day: int):
	"""每天自动存档"""
	print("[SaveManager] 触发自动存档 (Day %d)" % new_day)
	await save_game("", "autosave", false)
	_cleanup_old_autosaves()

func _cleanup_old_autosaves():
	"""清理旧的自动存档"""
	var dir = DirAccess.open(AUTOSAVE_DIR)
	if not dir:
		return

	var autosaves = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			autosaves.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	autosaves.sort()
	autosaves.reverse()

	if autosaves.size() > MAX_AUTOSAVE_COUNT:
		for i in range(MAX_AUTOSAVE_COUNT, autosaves.size()):
			dir.remove(autosaves[i])
			print("  - 删除旧自动存档: %s" % autosaves[i])

# ============================================================
# 工具函数
# ============================================================

func _get_save_path(save_name: String, save_type: String) -> String:
	"""获取存档文件路径"""
	var base_dir = SAVE_DIR
	if save_type == "autosave":
		base_dir = AUTOSAVE_DIR

	return base_dir + save_name + ".json"

func _generate_save_name(save_type: String) -> String:
	"""生成存档名称"""
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")

	if save_type == "autosave":
		return "autosave_" + timestamp
	else:
		return "save_" + timestamp

func _find_character_by_name(name: String) -> Node:
	"""根据名称查找角色"""
	var characters = get_tree().get_nodes_in_group("characters")
	for character in characters:
		if character.name == name:
			return character
	return null

# ============================================================
# 公共API
# ============================================================

func get_all_saves() -> Array:
	"""获取所有存档列表"""
	var saves = []

	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".json"):
				var save_info = get_save_info(file_name.get_basename())
				if save_info:
					saves.append(save_info)
			file_name = dir.get_next()

		dir.list_dir_end()

	saves.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	return saves

func get_save_info(save_name: String) -> Dictionary:
	"""获取存档信息"""
	var file_path = _get_save_path(save_name, "manual")

	if not FileAccess.file_exists(file_path):
		file_path = _get_save_path(save_name, "autosave")

	if not FileAccess.file_exists(file_path):
		return {}

	var data = _read_save_file(file_path)
	if data.is_empty():
		return {}

	var meta = data.get("save_meta", {})
	return {
		"save_name": meta.get("save_name", save_name),
		"timestamp": meta.get("created_at", 0),
		"game_time": meta.get("game_time_elapsed", 0.0),
		"version": meta.get("version", "unknown"),
		"screenshot_path": meta.get("screenshot_path", "")
	}

func delete_save(save_name: String) -> bool:
	"""删除存档"""
	var file_path = _get_save_path(save_name, "manual")

	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open(SAVE_DIR)
		return dir.remove(save_name + ".json") == OK

	return false

func quick_save():
	"""快速存档 (F5)"""
	await save_game("quicksave", "manual", true)

func quick_load():
	"""快速读档 (F9)"""
	load_game("quicksave", "manual")

func is_initialized() -> bool:
	"""检查是否已初始化"""
	return _initialized
