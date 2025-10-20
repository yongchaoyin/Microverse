# script/core/ConfigManager.gd
# 配置管理器 - 负责加载和管理所有JSON配置文件
# 职责:
#   1. 启动时加载所有配置文件到内存缓存
#   2. 提供配置数据的查询接口
#   3. 支持配置热重载
#   4. 提供配置验证和错误处理
extends Node

# ==================== 常量定义 ====================
const CONFIG_DIR = "res://config/"
const DATA_DIR = "res://data/"

# 配置文件名常量
const CAREERS_CONFIG = "careers.json"
const PERSONALITIES_CONFIG = "personalities.json"
const LOCATIONS_CONFIG = "locations.json"
const SCHEDULES_CONFIG = "schedules.json"
const PROMPTS_CONFIG = "prompts.json"
const TASKS_CONFIG = "tasks.json"

# ==================== 私有变量 ====================
# 配置缓存: {filename: parsed_json_data}
var _config_cache: Dictionary = {}

# 配置文件加载状态: {filename: bool}
var _load_status: Dictionary = {}

# 配置文件最后修改时间(用于热重载检测)
var _file_modified_times: Dictionary = {}

# 是否初始化完成
var _is_initialized: bool = false

# ==================== 生命周期方法 ====================
func _ready():
	print("[ConfigManager] 🚀 初始化配置管理器")
	_load_all_configs()
	_is_initialized = true
	print("[ConfigManager] ✅ 配置管理器初始化完成")

# ==================== 公共接口 ====================

## 检查是否初始化完成
func is_ready() -> bool:
	return _is_initialized

## 加载所有配置文件
func _load_all_configs() -> void:
	print("[ConfigManager] 📂 开始加载所有配置文件")

	# 按照依赖顺序加载配置
	_load_json_config(CAREERS_CONFIG)        # 职业配置
	_load_json_config(PERSONALITIES_CONFIG)  # 性格模板配置
	_load_json_config(LOCATIONS_CONFIG)      # 地点配置
	_load_json_config(SCHEDULES_CONFIG)      # 日程模板配置
	_load_json_config(PROMPTS_CONFIG)        # Prompt模板配置
	_load_json_config(TASKS_CONFIG)          # 任务配置

	# 打印加载统计
	var success_count = 0
	var failed_count = 0
	for filename in _load_status:
		if _load_status[filename]:
			success_count += 1
		else:
			failed_count += 1

	print("[ConfigManager] 📊 配置加载统计: 成功 %d 个, 失败 %d 个" % [success_count, failed_count])

## 加载单个JSON配置文件
## @param filename: 配置文件名(例如: "careers.json")
## @return: 解析后的Dictionary数据,失败返回空字典
func _load_json_config(filename: String) -> Dictionary:
	var path = CONFIG_DIR + filename

	# 检查文件是否存在
	if not FileAccess.file_exists(path):
		push_warning("[ConfigManager] ⚠️ 配置文件不存在: %s" % path)
		_load_status[filename] = false
		_config_cache[filename] = {}
		return {}

	# 读取文件内容
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[ConfigManager] ❌ 无法打开配置文件: %s, 错误码: %d" % [path, FileAccess.get_open_error()])
		_load_status[filename] = false
		_config_cache[filename] = {}
		return {}

	var json_string = file.get_as_text()
	file.close()

	# 检查文件是否为空
	if json_string.strip_edges().is_empty():
		push_warning("[ConfigManager] ⚠️ 配置文件为空: %s" % path)
		_load_status[filename] = false
		_config_cache[filename] = {}
		return {}

	# 解析JSON
	var json = JSON.new()
	var error = json.parse(json_string)

	if error != OK:
		var error_line = json.get_error_line()
		var error_msg = json.get_error_message()
		push_error("[ConfigManager] ❌ JSON解析错误: %s, 行号: %d, 错误: %s" % [path, error_line, error_msg])
		_load_status[filename] = false
		_config_cache[filename] = {}
		return {}

	# 验证JSON数据类型
	var data = json.data
	if not (data is Dictionary or data is Array):
		push_error("[ConfigManager] ❌ 配置文件JSON根节点必须是Dictionary或Array: %s" % path)
		_load_status[filename] = false
		_config_cache[filename] = {}
		return {}

	# 保存到缓存
	_config_cache[filename] = data
	_load_status[filename] = true

	# 记录文件修改时间
	_file_modified_times[filename] = FileAccess.get_modified_time(path)

	print("[ConfigManager] ✅ 加载配置成功: %s (数据项: %d)" % [filename, data.size() if data is Dictionary else len(data)])
	return data

## 获取配置数据
## @param config_name: 配置文件名(例如: "careers.json")
## @return: 配置数据Dictionary,不存在返回空字典
func get_config(config_name: String) -> Dictionary:
	if _config_cache.has(config_name):
		return _config_cache[config_name]
	else:
		push_warning("[ConfigManager] ⚠️ 请求的配置不存在: %s" % config_name)
		return {}

## 热重载配置文件
## @param config_name: 配置文件名
func reload_config(config_name: String) -> void:
	print("[ConfigManager] 🔄 重新加载配置: %s" % config_name)
	var data = _load_json_config(config_name)

	if _load_status.get(config_name, false):
		# 只有在EventBus已存在时才发送信号(避免启动时的循环依赖)
		if has_node("/root/EventBus"):
			EventBus.emit_signal("config_reloaded", config_name)
			print("[ConfigManager] 📢 已发送配置重载信号: %s" % config_name)

## 检查配置文件是否已修改(用于热重载)
## @param config_name: 配置文件名
## @return: 如果文件已修改返回true
func is_config_modified(config_name: String) -> bool:
	var path = CONFIG_DIR + config_name
	if not FileAccess.file_exists(path):
		return false

	var current_time = FileAccess.get_modified_time(path)
	var cached_time = _file_modified_times.get(config_name, 0)

	return current_time > cached_time

## 重载所有已修改的配置文件
func reload_modified_configs() -> void:
	print("[ConfigManager] 🔍 检查配置文件修改")
	var reloaded_count = 0

	for filename in _config_cache.keys():
		if is_config_modified(filename):
			reload_config(filename)
			reloaded_count += 1

	if reloaded_count > 0:
		print("[ConfigManager] 🔄 重载了 %d 个配置文件" % reloaded_count)
	else:
		print("[ConfigManager] ✅ 所有配置文件都是最新的")

# ==================== 便捷查询接口 ====================

## 获取职业数据
## @param career_id: 职业ID
## @return: 职业数据Dictionary
func get_career_data(career_id: String) -> Dictionary:
	var careers = get_config(CAREERS_CONFIG)
	if careers.has(career_id):
		return careers[career_id]
	else:
		push_warning("[ConfigManager] ⚠️ 职业数据不存在: %s" % career_id)
		return {}

## 获取所有职业列表
## @return: 职业ID数组
func get_all_career_ids() -> Array:
	var careers = get_config(CAREERS_CONFIG)
	return careers.keys()

## 获取性格模板
## @param template_name: 模板名称
## @return: 性格模板Dictionary
func get_personality_template(template_name: String) -> Dictionary:
	var personalities = get_config(PERSONALITIES_CONFIG)
	if personalities.has(template_name):
		return personalities[template_name]
	else:
		push_warning("[ConfigManager] ⚠️ 性格模板不存在: %s" % template_name)
		return {}

## 获取所有性格模板列表
## @return: 模板名称数组
func get_all_personality_templates() -> Array:
	var personalities = get_config(PERSONALITIES_CONFIG)
	return personalities.keys()

## 获取地点数据
## @param location_id: 地点ID
## @return: 地点数据Dictionary
func get_location_data(location_id: String) -> Dictionary:
	var locations = get_config(LOCATIONS_CONFIG)
	if locations.has(location_id):
		return locations[location_id]
	else:
		push_warning("[ConfigManager] ⚠️ 地点数据不存在: %s" % location_id)
		return {}

## 获取所有地点列表
## @return: 地点ID数组
func get_all_location_ids() -> Array:
	var locations = get_config(LOCATIONS_CONFIG)
	return locations.keys()

## 获取日程模板
## @param template_name: 模板名称
## @return: 日程模板Dictionary
func get_schedule_template(template_name: String) -> Dictionary:
	var schedules = get_config(SCHEDULES_CONFIG)
	if schedules.has(template_name):
		return schedules[template_name]
	else:
		push_warning("[ConfigManager] ⚠️ 日程模板不存在: %s" % template_name)
		return {}

## 获取所有日程模板列表
## @return: 模板名称数组
func get_all_schedule_templates() -> Array:
	var schedules = get_config(SCHEDULES_CONFIG)
	return schedules.keys()

## 获取Prompt模板
## @param template_name: 模板名称
## @return: Prompt字符串
func get_prompt_template(template_name: String) -> String:
	var prompts = get_config(PROMPTS_CONFIG)
	if prompts.has(template_name):
		var template = prompts[template_name]
		# 支持两种格式: 直接字符串 或 包含"content"字段的Dictionary
		if template is String:
			return template
		elif template is Dictionary and template.has("content"):
			return template["content"]
		else:
			push_warning("[ConfigManager] ⚠️ Prompt模板格式错误: %s" % template_name)
			return ""
	else:
		push_warning("[ConfigManager] ⚠️ Prompt模板不存在: %s" % template_name)
		return ""

## 获取所有Prompt模板列表
## @return: 模板名称数组
func get_all_prompt_templates() -> Array:
	var prompts = get_config(PROMPTS_CONFIG)
	return prompts.keys()

## 获取任务数据
## @param task_id: 任务ID
## @return: 任务数据Dictionary
func get_task_data(task_id: String) -> Dictionary:
	var tasks = get_config(TASKS_CONFIG)
	if tasks.has(task_id):
		return tasks[task_id]
	else:
		push_warning("[ConfigManager] ⚠️ 任务数据不存在: %s" % task_id)
		return {}

## 根据任务类型获取任务列表
## @param task_type: 任务类型("work", "daily", "social", "growth")
## @return: 任务ID数组
func get_tasks_by_type(task_type: String) -> Array:
	var tasks = get_config(TASKS_CONFIG)
	var result = []

	for task_id in tasks.keys():
		var task_data = tasks[task_id]
		if task_data.get("type", "") == task_type:
			result.append(task_id)

	return result

## 获取所有任务列表
## @return: 任务ID数组
func get_all_task_ids() -> Array:
	var tasks = get_config(TASKS_CONFIG)
	return tasks.keys()

# ==================== 调试接口 ====================

## 打印配置加载状态
func print_load_status() -> void:
	print("\n[ConfigManager] 📋 配置加载状态:")
	print("=" * 60)

	for filename in _load_status.keys():
		var status_icon = "✅" if _load_status[filename] else "❌"
		var data_count = 0

		if _config_cache.has(filename):
			var data = _config_cache[filename]
			data_count = data.size() if data is Dictionary else len(data)

		print("  %s %s (数据项: %d)" % [status_icon, filename, data_count])

	print("=" * 60)

## 获取配置统计信息
## @return: 统计信息Dictionary
func get_stats() -> Dictionary:
	var total_configs = _load_status.size()
	var loaded_configs = 0
	var total_items = 0

	for filename in _load_status:
		if _load_status[filename]:
			loaded_configs += 1

		if _config_cache.has(filename):
			var data = _config_cache[filename]
			total_items += data.size() if data is Dictionary else len(data)

	return {
		"total_configs": total_configs,
		"loaded_configs": loaded_configs,
		"failed_configs": total_configs - loaded_configs,
		"total_items": total_items,
		"is_initialized": _is_initialized
	}
