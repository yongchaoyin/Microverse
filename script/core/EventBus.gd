# script/core/EventBus.gd
# 全局事件总线 - 负责系统间解耦通信
# 职责:
#   1. 提供预定义的系统级信号
#   2. 支持动态事件订阅/发布机制
#   3. 提供优先级和一次性监听器支持
#   4. 提供事件日志和调试功能
extends Node

# ==================== 时间系统事件 ====================
signal time_tick(game_minutes_passed: int)                                    # 每游戏分钟触发
signal hour_changed(hour: int)                                                 # 每小时触发
signal day_changed(year: int, season: int, day: int)                          # 每天触发
signal season_changed(season: int)                                             # 每季节触发
signal year_changed(year: int)                                                 # 每年触发
signal time_paused()                                                           # 时间暂停
signal time_resumed()                                                          # 时间恢复
signal time_speed_changed(multiplier: float)                                   # 时间倍速改变

# ==================== AI系统事件 ====================
signal ai_thought_generated(ai_id: String, thought: String)                   # AI产生思考
signal ai_action_taken(ai_id: String, action: Dictionary)                     # AI执行行动
signal ai_dialogue_started(ai_id: String, target_id: String)                  # AI开始对话
signal ai_dialogue_ended(ai_id: String)                                       # AI结束对话
signal ai_emotion_changed(ai_id: String, emotion: String)                     # AI情绪变化
signal ai_relationship_changed(ai_id: String, target_id: String, relationship: Dictionary) # 关系变化
signal ai_state_changed(ai_id: String, old_state: String, new_state: String) # AI状态变化
signal ai_goal_set(ai_id: String, goal: Dictionary)                           # AI设定目标
signal ai_goal_completed(ai_id: String, goal_id: String)                      # AI完成目标
signal ai_goal_failed(ai_id: String, goal_id: String, reason: String)        # AI目标失败

# ==================== 职业系统事件 ====================
signal work_started(ai_id: String)                                            # 开始工作
signal work_ended(ai_id: String)                                              # 结束工作
signal work_paused(ai_id: String, reason: String)                             # 工作暂停
signal work_resumed(ai_id: String)                                            # 工作恢复
signal overtime_started(ai_id: String, hours: float)                          # 开始加班
signal overtime_ended(ai_id: String)                                          # 结束加班
signal salary_paid(ai_id: String, amount: int)                                # 发放工资
signal career_promoted(ai_id: String, new_level: int)                         # 职业晋升
signal career_changed(ai_id: String, old_career: String, new_career: String) # 转职
signal performance_evaluated(ai_id: String, performance: int)                 # 绩效评估
signal task_assigned(ai_id: String, task: Dictionary)                         # 任务分配
signal task_completed(ai_id: String, task_id: String)                         # 任务完成
signal task_failed(ai_id: String, task_id: String, reason: String)           # 任务失败

# ==================== 记忆系统事件 ====================
signal memory_created(ai_id: String, memory: Dictionary)                      # 创建记忆
signal memory_forgotten(ai_id: String, memory_id: String)                     # 遗忘记忆
signal memory_consolidated(ai_id: String, memory_ids: Array)                  # 记忆整合
signal memory_layer_promoted(ai_id: String, memory_id: String, old_layer: String, new_layer: String) # 记忆层级提升
signal core_memory_updated(ai_id: String)                                     # 核心记忆更新
signal memory_decayed(ai_id: String, memory_id: String, new_strength: float) # 记忆衰减

# ==================== 关系系统事件 ====================
signal relationship_level_up(ai_id: String, target_id: String, dimension: String, old_value: float, new_value: float) # 关系升级
signal relationship_level_down(ai_id: String, target_id: String, dimension: String, old_value: float, new_value: float) # 关系降级
signal relationship_tag_added(ai_id: String, target_id: String, tag: String)  # 添加关系标签
signal relationship_tag_removed(ai_id: String, target_id: String, tag: String) # 移除关系标签
signal relationship_milestone(ai_id: String, target_id: String, milestone: String) # 关系里程碑

# ==================== 经济系统事件 ====================
signal money_changed(ai_id: String, old_amount: int, new_amount: int, reason: String) # 金钱变化
signal item_purchased(ai_id: String, item_id: String, quantity: int, total_cost: int) # 购买物品
signal item_sold(ai_id: String, item_id: String, quantity: int, total_income: int)    # 出售物品

# ==================== 日程系统事件 ====================
signal schedule_item_started(ai_id: String, schedule_item: Dictionary)        # 日程项开始
signal schedule_item_completed(ai_id: String, schedule_item: Dictionary)      # 日程项完成
signal schedule_item_skipped(ai_id: String, schedule_item: Dictionary, reason: String) # 日程项跳过
signal schedule_changed(ai_id: String)                                         # 日程变更

# ==================== 导航系统事件 ====================
signal navigation_started(ai_id: String, destination: Vector2)                # 开始导航
signal navigation_completed(ai_id: String)                                    # 导航完成
signal navigation_failed(ai_id: String, reason: String)                       # 导航失败
signal location_arrived(ai_id: String, location_id: String)                   # 到达地点
signal location_left(ai_id: String, location_id: String)                      # 离开地点

# ==================== 存档系统事件 ====================
signal game_saved(slot_id: int, save_name: String)                            # 游戏保存
signal game_loaded(slot_id: int, save_name: String)                           # 游戏加载
signal autosave_triggered()                                                   # 自动存档触发
signal save_failed(slot_id: int, error: String)                               # 存档失败
signal load_failed(slot_id: int, error: String)                               # 读档失败

# ==================== UI系统事件 ====================
signal ui_focus_changed(ai_id: String)                                        # UI焦点切换
signal ui_panel_opened(panel_name: String)                                    # UI面板打开
signal ui_panel_closed(panel_name: String)                                    # UI面板关闭
signal ui_notification(title: String, message: String, type: String)          # UI通知

# ==================== 配置系统事件 ====================
signal config_reloaded(config_name: String)                                   # 配置重载

# ==================== 天气系统事件 ====================
signal weather_changed(old_weather: String, new_weather: String)              # 天气变化
signal temperature_changed(temperature: float)                                 # 温度变化

# ==================== 冲突系统事件 ====================
signal conflict_started(conflict_id: String, participants: Array)             # 冲突开始
signal conflict_escalated(conflict_id: String, intensity: int)                # 冲突升级
signal conflict_resolved(conflict_id: String, resolution: Dictionary)         # 冲突解决

# ==================== 动态事件订阅系统 ====================
# 用于运行时动态注册的事件监听器

class EventListener:
	var callable: Callable
	var one_shot: bool
	var priority: int

	func _init(c: Callable, one_shot_enabled: bool, listener_priority: int) -> void:
		callable = c
		self.one_shot = one_shot_enabled
		self.priority = listener_priority

# 事件监听器字典: {event_name: Array[EventListener]}
var _listeners: Dictionary = {}

# 正在发送的事件栈(用于检测循环事件)
var _emitting_stack: Array[String] = []

# 启用事件日志(调试用)
var enable_logging: bool = false

# 事件统计(调试用)
var _event_stats: Dictionary = {}  # {event_name: {emit_count: int, last_emit_time: float}}

# ==================== 生命周期方法 ====================
func _ready():
	print("[EventBus] 🚀 全局事件总线初始化完成")
	print("[EventBus] 📋 已注册 %d 个预定义信号" % get_signal_list().size())

# ==================== 动态订阅接口 ====================

## 订阅事件(通过对象和方法名)
## @param event_name: 事件名称
## @param target: 目标对象
## @param method: 方法名
## @param one_shot: 是否一次性监听
## @param priority: 优先级(数值越大优先级越高)
func subscribe(event_name: String, target: Object, method: String, one_shot: bool = false, priority: int = 0) -> void:
	if target == null:
		push_warning("[EventBus] ⚠️ 尝试订阅空对象到事件 '%s'" % event_name)
		return

	var callable := Callable(target, method)
	subscribe_callable(event_name, callable, one_shot, priority)

## 订阅事件(通过Callable)
## @param event_name: 事件名称
## @param callable: 可调用对象
## @param one_shot: 是否一次性监听
## @param priority: 优先级(数值越大优先级越高)
func subscribe_callable(event_name: String, callable: Callable, one_shot: bool = false, priority: int = 0) -> void:
	if callable.is_null() or not callable.is_valid():
		push_warning("[EventBus] ⚠️ 无效的callable订阅到事件 '%s'" % event_name)
		return

	var listener := EventListener.new(callable, one_shot, priority)

	if not _listeners.has(event_name):
		_listeners[event_name] = []

	_listeners[event_name].append(listener)
	_sort_listeners(event_name)

	if enable_logging:
		print("[EventBus] ➕ 订阅: %s <- %s (one_shot=%s, priority=%d)" % [
			event_name,
			_describe_callable(callable),
			str(one_shot),
			priority
		])

## 取消订阅事件
## @param event_name: 事件名称
## @param target: 目标对象
## @param method: 方法名(空字符串表示取消该对象的所有订阅)
func unsubscribe(event_name: String, target: Object, method: String = "") -> void:
	if not _listeners.has(event_name):
		return

	var listeners: Array = _listeners[event_name]
	for i in range(listeners.size() - 1, -1, -1):
		var listener: EventListener = listeners[i]
		if listener.callable.is_null():
			listeners.remove_at(i)
			continue

		var obj := listener.callable.get_object()
		var method_name := listener.callable.get_method()
		if obj == target and (method == "" or method == method_name):
			listeners.remove_at(i)
			if enable_logging:
				print("[EventBus] ➖ 取消订阅: %s <- %s.%s" % [event_name, target.name if target is Node else str(target), method_name])

	if listeners.is_empty():
		_listeners.erase(event_name)

## 取消订阅Callable
## @param event_name: 事件名称
## @param callable: 可调用对象
func unsubscribe_callable(event_name: String, callable: Callable) -> void:
	if not _listeners.has(event_name):
		return

	var listeners: Array = _listeners[event_name]
	for i in range(listeners.size() - 1, -1, -1):
		var listener: EventListener = listeners[i]
		if listener.callable == callable:
			listeners.remove_at(i)
			if enable_logging:
				print("[EventBus] ➖ 取消订阅: %s <- %s" % [event_name, _describe_callable(callable)])

	if listeners.is_empty():
		_listeners.erase(event_name)

## 取消对象的所有订阅
## @param target: 目标对象
func unsubscribe_all(target: Object) -> void:
	var removed_count = 0
	for event_name in _listeners.keys():
		var old_size = _listeners[event_name].size()
		unsubscribe(event_name, target)
		var new_size = _listeners.get(event_name, []).size()
		removed_count += old_size - new_size

	if enable_logging and removed_count > 0:
		print("[EventBus] ➖ 取消了对象 %s 的 %d 个订阅" % [target.name if target is Node else str(target), removed_count])

## 发送动态事件
## @param event_name: 事件名称
## @param payload: 事件数据
func emit_event(event_name: String, payload: Variant = null) -> void:
	# 更新统计
	if not _event_stats.has(event_name):
		_event_stats[event_name] = {"emit_count": 0, "last_emit_time": 0.0}
	_event_stats[event_name]["emit_count"] += 1
	_event_stats[event_name]["last_emit_time"] = Time.get_ticks_msec() / 1000.0

	# 检测循环事件
	if _emitting_stack.has(event_name):
		push_error("[EventBus] ❌ 检测到循环事件: %s, 调用栈: %s" % [event_name, str(_emitting_stack)])
		return

	if not _listeners.has(event_name):
		if enable_logging:
			print("[EventBus] 📭 事件无订阅者: %s" % event_name)
		return

	var listeners: Array = _listeners[event_name]
	if listeners.is_empty():
		return

	_emitting_stack.push_back(event_name)

	if enable_logging:
		print("[EventBus] 📤 发送事件: %s (订阅者数: %d)" % [event_name, listeners.size()])

	# 复制监听器列表,允许在迭代过程中修改订阅
	var snapshot: Array = listeners.duplicate()
	for listener in snapshot:
		if listener.callable.is_null():
			continue

		var callable: Callable = listener.callable
		if not callable.is_valid():
			continue

		var obj := callable.get_object()
		if obj != null and not is_instance_valid(obj):
			# 对象已被释放,移除监听器
			unsubscribe_callable(event_name, callable)
			continue

		if enable_logging:
			print("[EventBus]   ➡️ 调用: %s" % _describe_callable(callable))

		# 调用监听器
		if payload == null:
			callable.call()
		else:
			callable.call(payload)

		# 一次性监听器在调用后移除
		if listener.one_shot:
			unsubscribe_callable(event_name, callable)

	_emitting_stack.pop_back()

## 广播事件(emit_event的别名)
## @param event_name: 事件名称
## @param payload: 事件数据
func broadcast(event_name: String, payload: Variant = null) -> void:
	emit_event(event_name, payload)

## 检查事件是否有订阅者
## @param event_name: 事件名称
## @return: 如果有订阅者返回true
func has_subscribers(event_name: String) -> bool:
	return _listeners.has(event_name) and not (_listeners[event_name] as Array).is_empty()

# ==================== 调试接口 ====================

## 打印事件总线状态
func debug_print_status() -> void:
	print("\n[EventBus] 📊 事件总线状态:")
	print("=" * 80)
	print("动态事件订阅数: %d" % _listeners.size())
	print("事件统计记录数: %d" % _event_stats.size())
	print("=" * 80)

	if _listeners.size() > 0:
		print("\n动态事件订阅:")
		for event_name in _listeners.keys():
			var listeners: Array = _listeners[event_name]
			print("  📌 %s (%d 个订阅者)" % [event_name, listeners.size()])
			for listener in listeners:
				print("    - %s (priority: %d, one_shot: %s)" % [
					_describe_callable(listener.callable),
					listener.priority,
					str(listener.one_shot)
				])

	if _event_stats.size() > 0:
		print("\n事件发送统计 (Top 10):")
		var sorted_events = _event_stats.keys()
		sorted_events.sort_custom(func(a, b): return _event_stats[a]["emit_count"] > _event_stats[b]["emit_count"])

		for i in range(min(10, sorted_events.size())):
			var event_name = sorted_events[i]
			var stats = _event_stats[event_name]
			print("  📈 %s: %d 次发送 (最后: %.2f秒前)" % [
				event_name,
				stats["emit_count"],
				Time.get_ticks_msec() / 1000.0 - stats["last_emit_time"]
			])

	print("=" * 80 + "\n")

## 打印信号连接情况(预定义信号)
## @param signal_name: 信号名称
func debug_print_signal_connections(signal_name: String) -> void:
	var connections = get_signal_connection_list(signal_name)
	print("[EventBus] 📡 信号 '%s' 连接数: %d" % [signal_name, connections.size()])
	for connection in connections:
		print("  - Target: %s, Method: %s" % [
			connection["callable"].get_object(),
			connection["callable"].get_method()
		])

## 获取调试信息字典
## @return: 调试信息Dictionary
func debug_dump() -> Dictionary:
	var dump := {}

	# 动态监听器
	for event_name in _listeners.keys():
		var listeners: Array = _listeners[event_name]
		var entries: Array = []
		for listener in listeners:
			entries.append({
				"callable": _describe_callable(listener.callable),
				"one_shot": listener.one_shot,
				"priority": listener.priority
			})
		dump[event_name] = entries

	return dump

## 获取事件统计信息
## @return: 统计信息Dictionary
func get_stats() -> Dictionary:
	return {
		"dynamic_events_count": _listeners.size(),
		"total_subscriptions": _get_total_subscription_count(),
		"event_stats": _event_stats.duplicate(),
		"predefined_signals_count": get_signal_list().size()
	}

## 清除事件统计
func clear_stats() -> void:
	_event_stats.clear()
	print("[EventBus] 🧹 事件统计已清除")

# ==================== 私有辅助方法 ====================

## 描述Callable(用于日志)
func _describe_callable(callable: Callable) -> String:
	if callable.is_null():
		return "null"

	var obj := callable.get_object()
	var method := callable.get_method()
	var object_name := obj.name if obj and obj is Node else str(obj)
	return "%s.%s" % [object_name, method]

## 按优先级排序监听器
func _sort_listeners(event_name: String) -> void:
	var listeners: Array = _listeners[event_name]
	listeners.sort_custom(func(a, b):
		# 优先级高的在前
		return a.priority > b.priority
	)

## 获取总订阅数
func _get_total_subscription_count() -> int:
	var total = 0
	for event_name in _listeners.keys():
		total += _listeners[event_name].size()
	return total
