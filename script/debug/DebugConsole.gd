# script/debug/DebugConsole.gd
# 调试控制台 - 提供运行时调试命令和系统监控
# 职责:
#   1. 注册和执行调试命令
#   2. 提供系统状态监控
#   3. 支持命令别名和帮助系统
#   4. 提供命令历史记录
extends Node

# ==================== 信号定义 ====================
signal command_registered(name: String)
signal command_executed(name: String, args: Array, result: Variant)
signal command_failed(name: String, message: String)

# ==================== 命令类 ====================
class Command:
	var name: String
	var callable: Callable
	var help_text: String
	var aliases: Array[String]
	var category: String  # 命令分类

	func _init(command_name: String, command_callable: Callable, help := "", command_aliases: Array = [], command_category: String = "general") -> void:
		name = command_name
		callable = command_callable
		help_text = help
		aliases = command_aliases
		category = command_category

# ==================== 私有变量 ====================
# 命令字典: {command_name: Command}
var _commands: Dictionary = {}

# 别名映射: {alias: command_name}
var _alias_map: Dictionary = {}

# 命令历史
var _history: Array[String] = []
var _history_pointer: int = -1
const MAX_HISTORY_SIZE = 100

# 控制台状态
var is_console_active: bool = false
var echo_to_stdout: bool = true

# 命令分类
var _command_categories: Dictionary = {
	"general": "通用命令",
	"time": "时间系统",
	"ai": "AI系统",
	"relationship": "关系系统",
	"memory": "记忆系统",
	"economy": "经济系统",
	"save": "存档系统",
	"config": "配置系统",
	"debug": "调试工具"
}

# ==================== 生命周期方法 ====================
func _ready() -> void:
	_register_builtin_commands()
	print("[DebugConsole] 🚀 调试控制台初始化完成")
	print("[DebugConsole] 💡 使用 DebugConsole.execute_from_string(\"help\") 查看可用命令")

func _input(event: InputEvent) -> void:
	# 使用反引号(`)键切换控制台
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
		toggle_console()

# ==================== 公共接口 ====================

## 切换控制台显示状态
func toggle_console() -> void:
	is_console_active = not is_console_active
	if is_console_active:
		print("[DebugConsole] 🖥️ 控制台已激活 (无头模式)")
		print("[DebugConsole] 💡 输入 'help' 查看命令列表")
	else:
		print("[DebugConsole] 🔒 控制台已关闭")

## 注册命令
## @param name: 命令名称
## @param callable: 命令执行函数
## @param help_text: 帮助文本
## @param aliases: 命令别名列表
## @param category: 命令分类
func register_command(name: String, callable: Callable, help_text: String = "", aliases: Array = [], category: String = "general") -> void:
	if callable.is_null() or not callable.is_valid():
		push_warning("[DebugConsole] ⚠️ 命令 '%s' 注册失败 - callable无效" % name)
		return

	var normalized := name.to_lower()
	var command := Command.new(normalized, callable, help_text, aliases, category)
	_commands[normalized] = command

	# 注册别名
	for alias in aliases:
		_alias_map[alias.to_lower()] = normalized

	command_registered.emit(normalized)

	if echo_to_stdout:
		print("[DebugConsole] ✅ 注册命令: %s (分类: %s)" % [normalized, category])

## 注销命令
## @param name: 命令名称
func unregister_command(name: String) -> void:
	var normalized := name.to_lower()
	if not _commands.has(normalized):
		return

	var command: Command = _commands[normalized]

	# 移除别名
	for alias in command.aliases:
		if _alias_map.has(alias.to_lower()):
			_alias_map.erase(alias.to_lower())

	_commands.erase(normalized)

	if echo_to_stdout:
		print("[DebugConsole] ➖ 注销命令: %s" % normalized)

## 从字符串执行命令
## @param line: 命令行字符串
## @return: 命令执行结果
func execute_from_string(line: String) -> Variant:
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return null

	# 添加到历史
	_history.append(trimmed)
	if _history.size() > MAX_HISTORY_SIZE:
		_history.pop_front()
	_history_pointer = _history.size()

	# 分词
	var tokens := _tokenize(trimmed)
	if tokens.is_empty():
		return null

	var command_name := tokens[0].to_lower()
	var args := tokens.slice(1, tokens.size())

	return execute(command_name, args)

## 执行命令
## @param name: 命令名称
## @param args: 参数数组
## @return: 命令执行结果
func execute(name: String, args: Array = []) -> Variant:
	var normalized := _resolve_command_name(name)
	if normalized == "":
		var message := "未知命令: %s. 输入 'help' 查看命令列表" % name
		push_warning("[DebugConsole] ⚠️ %s" % message)
		command_failed.emit(name, message)
		return null

	var command: Command = _commands[normalized]
	var callable := command.callable

	var result: Variant = null

	# 执行命令
	if args.is_empty():
		result = callable.call()
	else:
		result = callable.callv(args)

	# 输出结果
	if echo_to_stdout:
		var args_text: Array = []
		for arg in args:
			args_text.append(str(arg))

		print("[DebugConsole] ➡️ %s(%s) -> %s" % [
			normalized,
			", ".join(PackedStringArray(args_text)),
			_to_string(result)
		])

	command_executed.emit(normalized, args, result)
	return result

## 列出所有命令
## @return: 命令名称数组
func list_commands() -> Array[String]:
	return _commands.keys()

## 获取命令帮助
## @param name: 命令名称
## @return: 帮助文本
func get_command_help(name: String) -> String:
	var normalized := _resolve_command_name(name)
	if normalized == "":
		return ""

	var command: Command = _commands[normalized]
	return command.help_text

## 获取命令历史
## @return: 历史记录数组
func get_history() -> Array[String]:
	return _history.duplicate()

## 清除命令历史
func clear_history() -> void:
	_history.clear()
	_history_pointer = -1
	print("[DebugConsole] 🧹 命令历史已清除")

# ==================== 内置命令注册 ====================

func _register_builtin_commands() -> void:
	# 通用命令
	register_command("help", Callable(self, "_cmd_help"), "列出所有命令或显示特定命令帮助. 用法: help [command]", ["?", "h"], "general")
	register_command("clear", Callable(self, "_cmd_clear"), "清除命令历史", ["cls"], "general")
	register_command("history", Callable(self, "_cmd_history"), "显示命令历史. 用法: history [count]", [], "general")
	register_command("commands", Callable(self, "_cmd_commands_by_category"), "按分类显示所有命令", [], "general")

	# 时间系统命令
	register_command("time", Callable(self, "_cmd_time_info"), "显示当前游戏时间", [], "time")
	register_command("time_set", Callable(self, "_cmd_time_set"), "设置游戏时间. 用法: time_set <hour> <minute>", [], "time")
	register_command("time_speed", Callable(self, "_cmd_time_speed"), "设置或查看时间倍速. 用法: time_speed [multiplier]", ["speed"], "time")
	register_command("time_pause", Callable(self, "_cmd_time_pause"), "暂停/恢复时间流动", ["pause"], "time")

	# AI系统命令
	register_command("ai_list", Callable(self, "_cmd_ai_list"), "列出所有AI角色", [], "ai")
	register_command("ai_stats", Callable(self, "_cmd_ai_stats"), "显示AI统计信息. 用法: ai_stats <ai_id>", [], "ai")
	register_command("ai_think", Callable(self, "_cmd_ai_think"), "强制AI思考. 用法: ai_think <ai_id>", [], "ai")

	# 关系系统命令
	register_command("rel_show", Callable(self, "_cmd_rel_show"), "显示关系状态. 用法: rel_show <ai_id> <target_id>", [], "relationship")
	register_command("rel_set", Callable(self, "_cmd_rel_set"), "设置关系维度. 用法: rel_set <ai_id> <target_id> <dimension> <value>", [], "relationship")

	# 记忆系统命令
	register_command("mem_list", Callable(self, "_cmd_mem_list"), "列出AI记忆. 用法: mem_list <ai_id> [layer]", [], "memory")
	register_command("mem_add", Callable(self, "_cmd_mem_add"), "添加记忆. 用法: mem_add <ai_id> <content>", [], "memory")

	# 经济系统命令
	register_command("money_set", Callable(self, "_cmd_money_set"), "设置金钱. 用法: money_set <ai_id> <amount>", [], "economy")
	register_command("money_add", Callable(self, "_cmd_money_add"), "增加金钱. 用法: money_add <ai_id> <amount>", [], "economy")

	# 存档系统命令
	register_command("save", Callable(self, "_cmd_save"), "快速保存. 用法: save <slot_id>", [], "save")
	register_command("load", Callable(self, "_cmd_load"), "快速加载. 用法: load <slot_id>", [], "save")

	# 配置系统命令
	register_command("config_reload", Callable(self, "_cmd_config_reload"), "重载配置文件. 用法: config_reload <config_name>", [], "config")
	register_command("config_list", Callable(self, "_cmd_config_list"), "列出所有配置文件", [], "config")

	# 调试工具命令
	register_command("debug_mode", Callable(self, "_cmd_debug_mode"), "切换调试模式", [], "debug")
	register_command("stats", Callable(self, "_cmd_stats"), "显示系统统计信息", [], "debug")
	register_command("eventbus_stats", Callable(self, "_cmd_eventbus_stats"), "显示事件总线统计", [], "debug")

# ==================== 内置命令实现 ====================

# 通用命令
func _cmd_help(args: Array = []) -> String:
	if args.is_empty():
		var output = "\n" + "=" * 60 + "\n"
		output += "🎮 Microverse 调试控制台 - 命令列表\n"
		output += "=" * 60 + "\n\n"
		output += "💡 使用 'help <command>' 查看特定命令的详细帮助\n"
		output += "💡 使用 'commands' 按分类查看所有命令\n\n"

		var names := _commands.keys()
		names.sort()

		for name in names:
			var command: Command = _commands[name]
			output += "  • %s - %s\n" % [name, command.help_text]

		output += "\n" + "=" * 60
		return output

	var normalized := _resolve_command_name(args[0])
	if normalized == "":
		return "❌ 命令不存在: %s" % args[0]

	var command: Command = _commands[normalized]
	var output = "\n" + "=" * 40 + "\n"
	output += "📖 命令: %s\n" % normalized
	output += "=" * 40 + "\n"
	output += "分类: %s\n" % _command_categories.get(command.category, command.category)
	output += "说明: %s\n" % command.help_text

	if not command.aliases.is_empty():
		output += "别名: %s\n" % ", ".join(command.aliases)

	output += "=" * 40
	return output

func _cmd_clear(args: Array = []) -> String:
	clear_history()
	return "✅ 命令历史已清除"

func _cmd_history(args: Array = []) -> String:
	var count := 10
	if args.size() > 0:
		count = maxi(1, int(args[0]))

	var slice := _history.slice(maxi(0, _history.size() - count), _history.size())

	if slice.is_empty():
		return "📭 命令历史为空"

	var output = "\n📜 命令历史 (最近 %d 条):\n" % slice.size()
	output += "=" * 40 + "\n"

	for i in range(slice.size()):
		output += "%d. %s\n" % [i + 1, slice[i]]

	return output

func _cmd_commands_by_category(args: Array = []) -> String:
	var output = "\n" + "=" * 60 + "\n"
	output += "📚 命令分类列表\n"
	output += "=" * 60 + "\n\n"

	for category in _command_categories.keys():
		var category_commands = []

		for cmd_name in _commands.keys():
			var command: Command = _commands[cmd_name]
			if command.category == category:
				category_commands.append(cmd_name)

		if category_commands.is_empty():
			continue

		category_commands.sort()

		output += "📁 %s\n" % _command_categories[category]
		output += "-" * 40 + "\n"

		for cmd_name in category_commands:
			var command: Command = _commands[cmd_name]
			output += "  • %s - %s\n" % [cmd_name, command.help_text]

		output += "\n"

	output += "=" * 60
	return output

# 时间系统命令
func _cmd_time_info(args: Array = []) -> String:
	var time_system := get_node_or_null("/root/TimeSystem")
	if not time_system:
		return "❌ TimeSystem 未加载"

	return "🕐 当前游戏时间: %s" % time_system.get_full_time_string()

func _cmd_time_set(args: Array = []) -> String:
	if args.size() < 2:
		return "❌ 用法: time_set <hour> <minute>"

	var time_system := get_node_or_null("/root/TimeSystem")
	if not time_system:
		return "❌ TimeSystem 未加载"

	time_system.current_hour = int(args[0])
	time_system.current_minute = int(args[1])

	return "✅ 时间已设置为: %s" % time_system.get_full_time_string()

func _cmd_time_speed(args: Array = []) -> String:
	var time_system := get_node_or_null("/root/TimeSystem")
	if not time_system:
		return "❌ TimeSystem 未加载"

	if args.is_empty():
		return "⚡ 当前时间倍速: %.2fx" % time_system.time_multiplier

	var value := float(args[0])
	time_system.set_time_multiplier(value)

	return "✅ 时间倍速已设置为: %.2fx" % time_system.time_multiplier

func _cmd_time_pause(args: Array = []) -> String:
	var time_system := get_node_or_null("/root/TimeSystem")
	if not time_system:
		return "❌ TimeSystem 未加载"

	time_system.toggle_pause()

	if time_system.time_paused:
		return "⏸️ 时间已暂停"
	else:
		return "▶️ 时间已恢复"

# AI系统命令
func _cmd_ai_list(args: Array = []) -> String:
	var character_manager := get_node_or_null("/root/CharacterManager")
	if not character_manager:
		return "❌ CharacterManager 未加载"

	# 这里需要CharacterManager提供get_all_characters()方法
	return "🤖 AI列表功能需要CharacterManager实现"

func _cmd_ai_stats(args: Array = []) -> String:
	if args.is_empty():
		return "❌ 用法: ai_stats <ai_id>"

	return "📊 AI统计功能待实现 (AI ID: %s)" % args[0]

func _cmd_ai_think(args: Array = []) -> String:
	if args.is_empty():
		return "❌ 用法: ai_think <ai_id>"

	return "💭 强制思考功能待实现 (AI ID: %s)" % args[0]

# 关系系统命令
func _cmd_rel_show(args: Array = []) -> String:
	if args.size() < 2:
		return "❌ 用法: rel_show <ai_id> <target_id>"

	return "💕 关系查看功能待实现 (AI: %s, Target: %s)" % [args[0], args[1]]

func _cmd_rel_set(args: Array = []) -> String:
	if args.size() < 4:
		return "❌ 用法: rel_set <ai_id> <target_id> <dimension> <value>"

	return "💕 关系设置功能待实现"

# 记忆系统命令
func _cmd_mem_list(args: Array = []) -> String:
	if args.is_empty():
		return "❌ 用法: mem_list <ai_id> [layer]"

	return "🧠 记忆列表功能待实现 (AI ID: %s)" % args[0]

func _cmd_mem_add(args: Array = []) -> String:
	if args.size() < 2:
		return "❌ 用法: mem_add <ai_id> <content>"

	return "🧠 添加记忆功能待实现"

# 经济系统命令
func _cmd_money_set(args: Array = []) -> String:
	if args.size() < 2:
		return "❌ 用法: money_set <ai_id> <amount>"

	return "💰 设置金钱功能待实现 (AI: %s, Amount: %s)" % [args[0], args[1]]

func _cmd_money_add(args: Array = []) -> String:
	if args.size() < 2:
		return "❌ 用法: money_add <ai_id> <amount>"

	return "💰 增加金钱功能待实现 (AI: %s, Amount: %s)" % [args[0], args[1]]

# 存档系统命令
func _cmd_save(args: Array = []) -> String:
	if args.is_empty():
		return "❌ 用法: save <slot_id>"

	return "💾 保存功能待实现 (Slot: %s)" % args[0]

func _cmd_load(args: Array = []) -> String:
	if args.is_empty():
		return "❌ 用法: load <slot_id>"

	return "💾 加载功能待实现 (Slot: %s)" % args[0]

# 配置系统命令
func _cmd_config_reload(args: Array = []) -> String:
	if args.is_empty():
		return "❌ 用法: config_reload <config_name>"

	var config_manager := get_node_or_null("/root/ConfigManager")
	if not config_manager:
		return "❌ ConfigManager 未加载"

	var config_name = args[0]
	if not config_name.ends_with(".json"):
		config_name += ".json"

	config_manager.reload_config(config_name)

	return "✅ 配置已重载: %s" % config_name

func _cmd_config_list(args: Array = []) -> String:
	var config_manager := get_node_or_null("/root/ConfigManager")
	if not config_manager:
		return "❌ ConfigManager 未加载"

	var stats = config_manager.get_stats()

	var output = "\n📁 配置文件列表\n"
	output += "=" * 40 + "\n"
	output += "总配置文件数: %d\n" % stats["total_configs"]
	output += "已加载: %d\n" % stats["loaded_configs"]
	output += "失败: %d\n" % stats["failed_configs"]
	output += "总数据项: %d\n" % stats["total_items"]
	output += "=" * 40

	return output

# 调试工具命令
func _cmd_debug_mode(args: Array = []) -> String:
	# 这里可以切换全局调试标志
	echo_to_stdout = not echo_to_stdout

	if echo_to_stdout:
		return "🔧 调试模式已启用"
	else:
		return "🔒 调试模式已禁用"

func _cmd_stats(args: Array = []) -> String:
	var output = "\n📊 系统统计信息\n"
	output += "=" * 60 + "\n\n"

	# FPS
	output += "🎮 FPS: %d\n" % Engine.get_frames_per_second()

	# 时间系统
	var time_system := get_node_or_null("/root/TimeSystem")
	if time_system:
		output += "🕐 游戏时间: %s\n" % time_system.get_full_time_string()
		output += "⚡ 时间倍速: %.2fx\n" % time_system.time_multiplier

	# 配置管理器
	var config_manager := get_node_or_null("/root/ConfigManager")
	if config_manager:
		var stats = config_manager.get_stats()
		output += "📁 配置文件: %d/%d 已加载\n" % [stats["loaded_configs"], stats["total_configs"]]

	# 事件总线
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		var stats = event_bus.get_stats()
		output += "📡 事件订阅数: %d\n" % stats["total_subscriptions"]
		output += "📋 预定义信号数: %d\n" % stats["predefined_signals_count"]

	# 内存使用
	output += "💾 内存使用: %.2f MB\n" % (OS.get_static_memory_usage() / 1024.0 / 1024.0)

	output += "\n" + "=" * 60

	return output

func _cmd_eventbus_stats(args: Array = []) -> String:
	var event_bus := get_node_or_null("/root/EventBus")
	if not event_bus:
		return "❌ EventBus 未加载"

	event_bus.debug_print_status()
	return "✅ 事件总线统计已打印到控制台"

# ==================== 私有辅助方法 ====================

## 解析命令名称(包括别名)
func _resolve_command_name(name: String) -> String:
	var normalized := name.to_lower()

	if _commands.has(normalized):
		return normalized

	if _alias_map.has(normalized):
		return _alias_map[normalized]

	return ""

## 分词解析器
func _tokenize(line: String) -> Array[String]:
	var tokens: Array[String] = []
	var current := ""
	var in_quotes := false

	for i in range(line.length()):
		var char := line[i]

		if char == "\"":
			in_quotes = not in_quotes
			continue

		if char == " " and not in_quotes:
			if current != "":
				tokens.append(current)
				current = ""
		else:
			current += char

	if current != "":
		tokens.append(current)

	return tokens

## 转换为字符串(用于输出)
func _to_string(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_DICTIONARY, TYPE_ARRAY:
			return JSON.stringify(value, "  ")
		_:
			return str(value)
