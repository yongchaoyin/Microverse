# ========================================
# PerceptionComponent.gd
# 感知组件 - 为AI提供空间、社交和环境感知能力
# ========================================
#
# 功能:
# 1. 空间感知: 检测附近的AI、地点
# 2. 社交感知: 识别社交机会,计算互动优先级
# 3. 环境感知: 感知时间、天气、活动
# 4. 感知过滤: 基于性格和关系的选择性感知
#
# 使用方式:
#   - 作为AICharacter的子节点 (Components/PerceptionComponent)
#   - 自动每5秒更新感知数据
#   - 通过get_perception()获取缓存数据
#   - 通过get_perception_summary_for_llm()获取LLM可用的文本摘要
#
# 作者: Claude (Sonnet 4.5)
# 日期: 2025-10-20
# 版本: 1.0
# ========================================

class_name PerceptionComponent extends Node

# ========================================
# 配置常量
# ========================================

const PERCEPTION_RADIUS: float = 300.0       # 感知半径 (像素)
const VISION_CONE_ANGLE: float = 180.0       # 视野角度 (度) - 预留,暂未使用
const UPDATE_INTERVAL: float = 5.0           # 更新间隔 (秒)
const MAX_PERCEIVED_CHARACTERS: int = 10     # 最多感知10个AI
const LOCATION_PROXIMITY_THRESHOLD: float = 100.0  # 判定"在地点内"的距离阈值

# ========================================
# 内部状态
# ========================================

var ai_character: Node = null                # 所属AI角色 (AICharacter节点)
var is_enabled: bool = true                  # 感知是否启用
var _last_update_time: float = 0.0           # 上次更新时间

# 缓存的感知数据
var cached_perception: Dictionary = {
	"nearby_characters": [],          # Array<Dictionary>: 附近的AI
	"current_location": {},           # Dictionary: 当前地点
	"nearby_locations": [],           # Array<Dictionary>: 附近地点
	"social_opportunities": [],       # Array<Dictionary>: 社交机会
	"current_activities": {},         # Dictionary: 正在进行的活动
	"time_period": "",                # String: 时间段 (morning/afternoon/evening/night)
	"weather": "",                    # String: 天气
	"perceived_threats": [],          # Array<Dictionary>: 感知到的威胁 (神经质AI)
	"last_update_timestamp": 0.0      # 上次更新的时间戳
}

# ========================================
# 信号定义
# ========================================

signal perception_updated(perception_data: Dictionary)        # 感知数据更新
signal character_entered_range(character_id: String)          # 有AI进入感知范围
signal character_left_range(character_id: String)             # 有AI离开感知范围
signal arrived_at_new_location(location_data: Dictionary)     # 到达新地点

# ========================================
# 生命周期
# ========================================

func _ready():
	# 获取父节点 (AICharacter)
	ai_character = get_parent().get_parent() if get_parent().name == "Components" else get_parent()

	if not ai_character:
		push_error("[PerceptionComponent] 无法找到AICharacter父节点!")
		return

	print("[PerceptionComponent] %s 的感知组件已初始化" % ai_character.name)

	# 立即进行一次感知更新
	update_perception()

func _process(delta: float):
	if not is_enabled or not ai_character:
		return

	_last_update_time += delta

	if _last_update_time >= UPDATE_INTERVAL:
		update_perception()
		_last_update_time = 0.0

# ========================================
# 核心感知方法
# ========================================

## 更新所有感知数据
func update_perception() -> Dictionary:
	if not ai_character:
		return cached_perception

	var new_perception = {}

	# 1. 空间感知
	var prev_nearby = cached_perception.get("nearby_characters", [])
	new_perception.nearby_characters = _perceive_nearby_characters()
	new_perception.current_location = _perceive_current_location()
	new_perception.nearby_locations = _perceive_nearby_locations()

	# 2. 社交感知
	new_perception.social_opportunities = _perceive_social_opportunities(new_perception.nearby_characters)

	# 3. 环境感知
	new_perception.current_activities = _perceive_current_activities(new_perception.nearby_characters)
	new_perception.time_period = _perceive_time_period()
	new_perception.weather = _perceive_weather()

	# 4. 感知过滤
	new_perception = _apply_perception_filters(new_perception)

	# 5. 检测变化并发送信号
	_detect_and_emit_changes(prev_nearby, new_perception.nearby_characters)
	_detect_location_change(cached_perception.get("current_location", {}), new_perception.current_location)

	# 更新缓存
	new_perception.last_update_timestamp = Time.get_ticks_msec() / 1000.0
	cached_perception = new_perception

	perception_updated.emit(cached_perception)

	return cached_perception

## 获取当前感知数据 (缓存版本)
func get_perception() -> Dictionary:
	return cached_perception

## 为LLM生成感知摘要文本
func get_perception_summary_for_llm() -> String:
	var summary = ""

	# 1. 地点信息
	var current_loc = cached_perception.get("current_location", {})
	if not current_loc.is_empty():
		summary += "我现在在%s。\n" % current_loc.get("name_cn", "未知地点")
	else:
		summary += "我现在在室外空地上。\n"

	# 2. 周围的人
	var nearby_chars = cached_perception.get("nearby_characters", [])
	if nearby_chars.size() > 0:
		summary += "\n周围有以下的人:\n"
		for char_data in nearby_chars:
			var char_id = char_data.character_id
			var char_name = char_data.character_name
			var relationship_desc = _get_relationship_description(char_id)
			var activity = char_data.get("current_activity", "")
			var distance_desc = _get_distance_description(char_data.distance)

			summary += "  - %s (%s,%s)" % [char_name, relationship_desc, distance_desc]

			if activity:
				summary += ",正在%s" % activity

			summary += "\n"
	else:
		summary += "\n周围没有其他人,我独自一人。\n"

	# 3. 社交机会 (如果外向性高)
	var social_opps = cached_perception.get("social_opportunities", [])
	if social_opps.size() > 0 and _is_extraverted():
		summary += "\n我注意到:\n"
		var top_opp = social_opps[0]  # 只显示最高优先级的
		summary += "  - 可以和%s聊聊天 (%s)\n" % [
			top_opp.character_name,
			top_opp.suggested_action
		]

	# 4. 时间和天气
	var time_period_cn = _get_time_period_cn(cached_perception.get("time_period", ""))
	var weather_cn = _get_weather_cn(cached_perception.get("weather", ""))
	summary += "\n现在是%s" % time_period_cn
	if weather_cn:
		summary += ",%s" % weather_cn
	summary += "。\n"

	# 5. 威胁感知 (神经质AI)
	var threats = cached_perception.get("perceived_threats", [])
	if threats.size() > 0:
		summary += "\n⚠️ 我注意到%s在附近,感觉有点紧张...\n" % threats[0].character_name

	return summary

## 启用/禁用感知
func set_perception_enabled(enabled: bool):
	is_enabled = enabled
	set_process(enabled)

	if enabled:
		print("[PerceptionComponent] %s 的感知已启用" % ai_character.name)
	else:
		print("[PerceptionComponent] %s 的感知已禁用" % ai_character.name)

# ========================================
# 空间感知实现
# ========================================

func _perceive_nearby_characters() -> Array:
	"""感知附近的AI角色"""
	var nearby = []

	# 获取CharacterManager
	var char_manager = get_node_or_null("/root/CharacterManager")
	if not char_manager:
		push_warning("[PerceptionComponent] CharacterManager未找到")
		return nearby

	# 获取所有角色 (假设CharacterManager有get_all_characters方法)
	var all_characters = _get_all_characters(char_manager)

	for other_char in all_characters:
		if other_char == ai_character:
			continue

		var distance = ai_character.global_position.distance_to(other_char.global_position)

		# 距离过滤
		if distance > PERCEPTION_RADIUS:
			continue

		# 构建角色数据
		var char_data = {
			"character_id": other_char.name,
			"character_name": _get_character_display_name(other_char),
			"distance": distance,
			"position": other_char.global_position,
			"current_activity": _get_character_activity(other_char)
		}

		nearby.append(char_data)

	# 按距离排序 (近的优先)
	nearby.sort_custom(func(a, b): return a.distance < b.distance)

	# 限制数量
	if nearby.size() > MAX_PERCEIVED_CHARACTERS:
		nearby.resize(MAX_PERCEIVED_CHARACTERS)

	return nearby

func _perceive_current_location() -> Dictionary:
	"""感知当前所在地点"""

	# 尝试使用LocationManager
	var location_manager = get_node_or_null("/root/LocationManager")
	if location_manager and location_manager.has_method("get_nearest_location"):
		var nearest = location_manager.get_nearest_location(ai_character.global_position)
		if nearest and ai_character.global_position.distance_to(nearest.position) < LOCATION_PROXIMITY_THRESHOLD:
			return nearest.to_dict() if nearest.has_method("to_dict") else {}

	# 临时方案:通过场景节点查找
	var location_nodes = get_tree().get_nodes_in_group("location")
	var min_distance = INF
	var nearest_location = null

	for node in location_nodes:
		var distance = ai_character.global_position.distance_to(node.global_position)
		if distance < min_distance and distance < LOCATION_PROXIMITY_THRESHOLD:
			min_distance = distance
			nearest_location = node

	if nearest_location:
		return {
			"id": nearest_location.name,
			"name_cn": nearest_location.get_meta("location_name_cn", nearest_location.name),
			"name_en": nearest_location.get_meta("location_name_en", nearest_location.name),
			"type": nearest_location.get_meta("location_type", "OTHER"),
			"position": nearest_location.global_position
		}

	return {}

func _perceive_nearby_locations() -> Array:
	"""感知附近的地点 (不包括当前地点)"""
	var nearby_locs = []

	var current_loc = cached_perception.get("current_location", {})
	var current_loc_id = current_loc.get("id", "")

	# 尝试使用LocationManager
	var location_manager = get_node_or_null("/root/LocationManager")
	if location_manager and location_manager.has_method("get_all_locations"):
		for location in location_manager.get_all_locations():
			if location.id == current_loc_id:
				continue

			var distance = ai_character.global_position.distance_to(location.position)

			if distance < PERCEPTION_RADIUS and distance > LOCATION_PROXIMITY_THRESHOLD:
				nearby_locs.append({
					"location_id": location.id,
					"name": location.name_cn,
					"distance": distance,
					"type": location.type
				})

		# 按距离排序,最多返回5个
		nearby_locs.sort_custom(func(a, b): return a.distance < b.distance)
		if nearby_locs.size() > 5:
			nearby_locs.resize(5)

		return nearby_locs

	# 临时方案:通过场景节点
	var location_nodes = get_tree().get_nodes_in_group("location")
	for node in location_nodes:
		if node.name == current_loc_id:
			continue

		var distance = ai_character.global_position.distance_to(node.global_position)

		if distance < PERCEPTION_RADIUS and distance > LOCATION_PROXIMITY_THRESHOLD:
			nearby_locs.append({
				"location_id": node.name,
				"name": node.get_meta("location_name_cn", node.name),
				"distance": distance,
				"type": node.get_meta("location_type", "OTHER")
			})

	# 按距离排序
	nearby_locs.sort_custom(func(a, b): return a.distance < b.distance)
	if nearby_locs.size() > 5:
		nearby_locs.resize(5)

	return nearby_locs

# ========================================
# 社交感知实现
# ========================================

func _perceive_social_opportunities(nearby_characters: Array) -> Array:
	"""感知社交机会"""
	var opportunities = []

	var relationship_manager = get_node_or_null("/root/RelationshipManager")
	if not relationship_manager:
		return opportunities

	for char_data in nearby_characters:
		var char_id = char_data.character_id

		# 获取关系数据
		var relationship = {}
		if relationship_manager.has_method("get_relationship"):
			relationship = relationship_manager.get_relationship(ai_character.name, char_id)

		if relationship.is_empty():
			continue

		# 计算互动优先级
		var priority = _calculate_social_priority(char_id, char_data, relationship)

		# 只添加有一定优先级的机会
		if priority > 10.0:
			opportunities.append({
				"character_id": char_id,
				"character_name": char_data.character_name,
				"priority": priority,
				"relationship_level": relationship.get("relationship_level", "stranger"),
				"suggested_action": _suggest_social_action(relationship)
			})

	# 按优先级排序
	opportunities.sort_custom(func(a, b): return a.priority > b.priority)

	return opportunities

func _calculate_social_priority(char_id: String, char_data: Dictionary, relationship: Dictionary) -> float:
	"""计算社交优先级 (0-100)"""
	var priority = 0.0

	# 1. 关系因素 (40%)
	var affection = relationship.get("affection", 50)
	var familiarity = relationship.get("familiarity", 0)
	priority += (affection * 0.3 + familiarity * 0.1)

	# 2. 性格因素 (30%)
	var personality_engine = get_node_or_null("/root/PersonalityEngine")
	if personality_engine and personality_engine.has_method("get_personality"):
		var my_personality = personality_engine.get_personality(ai_character.name)
		if my_personality:
			# 外向性影响社交意愿
			priority += my_personality.get("extraversion", 50) * 0.3

			# 性格契合度
			if personality_engine.has_method("get_compatibility"):
				var compatibility = personality_engine.get_compatibility(ai_character.name, char_id)
				priority += compatibility * 0.1
	else:
		# 默认外向性为50
		priority += 50 * 0.3

	# 3. 距离因素 (20%)
	var distance = char_data.distance
	var distance_factor = max(0.0, 1.0 - distance / PERCEPTION_RADIUS)  # 越近优先级越高
	priority += distance_factor * 20.0

	# 4. 时间因素 (10%)
	# 上次互动时间越久,优先级略微提升
	var last_interaction = relationship.get("last_interaction_time", "")
	if last_interaction:
		var hours_since = _calculate_hours_since_interaction(last_interaction)
		priority += min(hours_since / 24.0 * 10.0, 10.0)  # 最多+10

	return clamp(priority, 0.0, 100.0)

func _suggest_social_action(relationship: Dictionary) -> String:
	"""建议社交行为"""
	var level = relationship.get("relationship_level", "stranger")

	match level:
		"stranger":
			return "打招呼,自我介绍"
		"acquaintance":
			return "聊聊天,增进了解"
		"friend":
			return "一起喝咖啡或聊工作"
		"close_friend":
			return "深度交流,分享心事"
		"best_friend":
			return "计划一起做点什么"
		"romantic":
			return "约会,增进感情"
		"enemy":
			return "保持距离,避免冲突"
		_:
			return "观察对方"

# ========================================
# 环境感知实现
# ========================================

func _perceive_current_activities(nearby_characters: Array) -> Dictionary:
	"""感知当前环境中的活动"""
	var activities = {}

	# 检测附近AI正在做什么
	for char_data in nearby_characters:
		var char_id = char_data.character_id
		var activity = char_data.get("current_activity", "")
		if activity:
			activities[char_id] = activity

	# 检测地点活动
	var current_loc = cached_perception.get("current_location", {})
	if not current_loc.is_empty():
		var location_manager = get_node_or_null("/root/LocationManager")
		if location_manager and location_manager.has_method("get_occupants"):
			var occupants = location_manager.get_occupants(current_loc.get("id", ""))
			activities["location_occupants_count"] = occupants.size()

	return activities

func _perceive_time_period() -> String:
	"""感知时间段"""
	var time_system = get_node_or_null("/root/TimeSystem")
	if time_system and time_system.has_method("get_time_period"):
		return time_system.get_time_period()
	return "unknown"

func _perceive_weather() -> String:
	"""感知天气"""
	var weather_system = get_node_or_null("/root/WeatherSystem")
	if weather_system and weather_system.has_method("get_current_weather"):
		return weather_system.get_current_weather()
	return "unknown"

# ========================================
# 感知过滤实现
# ========================================

func _apply_perception_filters(perception: Dictionary) -> Dictionary:
	"""应用感知过滤器 - 基于性格和关系"""
	var personality_engine = get_node_or_null("/root/PersonalityEngine")
	if not personality_engine or not personality_engine.has_method("get_personality"):
		return perception

	var personality = personality_engine.get_personality(ai_character.name)
	if not personality:
		return perception

	var extraversion = personality.get("extraversion", 50)
	var neuroticism = personality.get("neuroticism", 50)
	var openness = personality.get("openness", 50)

	# 1. 外向性过滤社交感知
	if extraversion < 30:
		# 内向AI只关注最亲密的人
		var filtered_chars = _filter_by_relationship(
			perception.nearby_characters,
			["close_friend", "best_friend", "romantic"]
		)
		perception.nearby_characters = filtered_chars

		# 清空社交机会 (内向AI不主动寻找社交)
		perception.social_opportunities = []

	# 2. 神经质过滤威胁
	if neuroticism > 70:
		# 神经质高的AI会注意到敌人或关系差的人
		var threats = _filter_by_relationship(perception.nearby_characters, ["enemy"])
		if threats.size() > 0:
			perception.perceived_threats = threats

		# 也会注意到affection < 30的人
		var low_affection_chars = _filter_by_low_affection(perception.nearby_characters, 30)
		for char in low_affection_chars:
			if not char in perception.get("perceived_threats", []):
				perception.perceived_threats.append(char)

	# 3. 开放性影响新地点感知
	if openness < 30:
		# 开放性低的AI不太关注新地点
		perception.nearby_locations = []

	return perception

func _filter_by_relationship(characters: Array, allowed_levels: Array) -> Array:
	"""按关系等级过滤角色"""
	var filtered = []
	var relationship_manager = get_node_or_null("/root/RelationshipManager")

	if not relationship_manager:
		return filtered

	for char_data in characters:
		var char_id = char_data.character_id
		var relationship = {}

		if relationship_manager.has_method("get_relationship"):
			relationship = relationship_manager.get_relationship(ai_character.name, char_id)

		if relationship and relationship.get("relationship_level", "") in allowed_levels:
			filtered.append(char_data)

	return filtered

func _filter_by_low_affection(characters: Array, threshold: int) -> Array:
	"""过滤出好感度低于阈值的角色"""
	var filtered = []
	var relationship_manager = get_node_or_null("/root/RelationshipManager")

	if not relationship_manager:
		return filtered

	for char_data in characters:
		var char_id = char_data.character_id
		var relationship = {}

		if relationship_manager.has_method("get_relationship"):
			relationship = relationship_manager.get_relationship(ai_character.name, char_id)

		if relationship and relationship.get("affection", 50) < threshold:
			filtered.append(char_data)

	return filtered

# ========================================
# 变化检测
# ========================================

func _detect_and_emit_changes(prev_nearby: Array, current_nearby: Array):
	"""检测附近角色变化并发送信号"""
	var prev_ids = []
	for char_data in prev_nearby:
		prev_ids.append(char_data.character_id)

	var current_ids = []
	for char_data in current_nearby:
		current_ids.append(char_data.character_id)

	# 检测新进入的角色
	for char_id in current_ids:
		if not char_id in prev_ids:
			character_entered_range.emit(char_id)
			print("[PerceptionComponent] %s 感知到 %s 进入范围" % [ai_character.name, char_id])

	# 检测离开的角色
	for char_id in prev_ids:
		if not char_id in current_ids:
			character_left_range.emit(char_id)
			print("[PerceptionComponent] %s 感知到 %s 离开范围" % [ai_character.name, char_id])

func _detect_location_change(prev_location: Dictionary, current_location: Dictionary):
	"""检测地点变化"""
	var prev_id = prev_location.get("id", "")
	var current_id = current_location.get("id", "")

	if current_id != "" and current_id != prev_id:
		arrived_at_new_location.emit(current_location)
		print("[PerceptionComponent] %s 到达新地点: %s" % [ai_character.name, current_location.get("name_cn", current_id)])

# ========================================
# 辅助方法
# ========================================

func _get_all_characters(char_manager: Node) -> Array:
	"""获取所有角色 - 兼容不同的CharacterManager实现"""
	if char_manager.has_method("get_all_characters"):
		return char_manager.get_all_characters()

	# 备选方案:通过场景树查找
	return get_tree().get_nodes_in_group("ai_characters")

func _get_character_display_name(character: Node) -> String:
	"""获取角色显示名称"""
	if character.has_meta("character_data"):
		var char_data = character.get_meta("character_data")
		if char_data.has("character_name"):
			return char_data.character_name

	if character.has("character_data") and character.character_data:
		if character.character_data.has("character_name"):
			return character.character_data.character_name

	return character.name

func _get_character_activity(character: Node) -> String:
	"""获取角色当前活动"""
	var ai_brain = character.get_node_or_null("Components/AIBrain")
	if ai_brain:
		if ai_brain.has_method("get_current_state"):
			return ai_brain.get_current_state()

		if ai_brain.has("current_state"):
			return str(ai_brain.current_state)

	return ""

func _get_relationship_description(char_id: String) -> String:
	"""获取关系描述"""
	var relationship_manager = get_node_or_null("/root/RelationshipManager")
	if not relationship_manager or not relationship_manager.has_method("get_relationship"):
		return "陌生人"

	var relationship = relationship_manager.get_relationship(ai_character.name, char_id)
	if relationship.is_empty():
		return "陌生人"

	var level = relationship.get("relationship_level", "stranger")

	match level:
		"stranger":
			return "陌生人"
		"acquaintance":
			return "认识的人"
		"friend":
			return "朋友"
		"close_friend":
			return "好友"
		"best_friend":
			return "挚友"
		"romantic":
			return "恋人"
		"enemy":
			return "敌人"
		_:
			return "认识的人"

func _get_distance_description(distance: float) -> String:
	"""获取距离描述"""
	if distance < 50:
		return "很近"
	elif distance < 150:
		return "较近"
	else:
		return "有点远"

func _get_time_period_cn(time_period: String) -> String:
	"""时间段中文转换"""
	match time_period:
		"morning":
			return "早晨"
		"afternoon":
			return "下午"
		"evening":
			return "傍晚"
		"night":
			return "夜晚"
		_:
			return "现在"

func _get_weather_cn(weather: String) -> String:
	"""天气中文转换"""
	match weather:
		"sunny":
			return "天气晴朗"
		"cloudy":
			return "多云"
		"light_rain":
			return "小雨"
		"heavy_rain":
			return "大雨"
		"thunderstorm":
			return "雷暴"
		"snowy":
			return "下雪"
		"foggy":
			return "有雾"
		"windy":
			return "大风"
		"unknown", "":
			return ""
		_:
			return weather

func _is_extraverted() -> bool:
	"""判断AI是否外向"""
	var personality_engine = get_node_or_null("/root/PersonalityEngine")
	if not personality_engine or not personality_engine.has_method("get_personality"):
		return false

	var personality = personality_engine.get_personality(ai_character.name)
	if not personality:
		return false

	return personality.get("extraversion", 50) > 60

func _calculate_hours_since_interaction(last_interaction_time: String) -> float:
	"""计算距离上次互动的小时数"""
	# 简化实现:假设last_interaction_time是TimeSystem的时间字符串
	# 实际应该解析时间字符串并计算差值

	var time_system = get_node_or_null("/root/TimeSystem")
	if not time_system:
		return 0.0

	# 临时实现:随机返回0-48小时
	# TODO: 实现真正的时间差计算
	return randf() * 48.0

# ========================================
# 调试方法
# ========================================

func debug_print_perception():
	"""打印当前感知数据 (调试用)"""
	print("\n========== %s 的感知数据 ==========" % ai_character.name)
	print("附近角色数量: %d" % cached_perception.nearby_characters.size())
	for char_data in cached_perception.nearby_characters:
		print("  - %s (距离: %.1f)" % [char_data.character_name, char_data.distance])

	print("\n当前地点: %s" % cached_perception.get("current_location", {}).get("name_cn", "无"))
	print("附近地点数量: %d" % cached_perception.nearby_locations.size())

	print("\n社交机会数量: %d" % cached_perception.social_opportunities.size())
	if cached_perception.social_opportunities.size() > 0:
		var top_opp = cached_perception.social_opportunities[0]
		print("  最高优先级: %s (优先级: %.1f)" % [top_opp.character_name, top_opp.priority])

	print("\n时间段: %s" % _get_time_period_cn(cached_perception.time_period))
	print("天气: %s" % _get_weather_cn(cached_perception.weather))
	print("=====================================\n")
