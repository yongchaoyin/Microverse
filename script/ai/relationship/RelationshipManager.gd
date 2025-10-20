extends Node

class_name RelationshipManager

# ========================================
# 信号定义
# ========================================

signal relationship_changed(ai_id: String, target_id: String, relationship: Dictionary)
signal tags_changed(ai_id: String, target_id: String, tags: Array)
signal milestone_unlocked(ai_id: String, target_id: String, milestone_id: String)

# ========================================
# 常量定义
# ========================================

# 关系阈值配置
const RELATIONSHIP_THRESHOLDS = {
	"stranger": 0,      # 陌生人
	"acquaintance": 20, # 熟人
	"friend": 60,       # 朋友
	"close_friend": 80, # 好友
	"best_friend": 95,  # 挚友
	"romantic": 70,     # 恋爱(需要romance维度)
	"enemy": -50        # 敌人
}

# 信任度阈值配置
const TRUST_THRESHOLDS = {
	"can_loan": 60,     # 可以借钱
	"can_confide": 70,  # 可以倾诉
	"can_trust_secrets": 80  # 可以分享秘密
}

# 衰减配置
const DECAY_INTERVAL_HOURS = 24  # 每24小时检查一次衰减
const DECAY_IDLE_THRESHOLD_HOURS = 72  # 72小时无互动才开始衰减

const DECAY_RATES = {
	"familiarity": {"idle": -0.5, "max_loss": -20.0},    # 熟悉度衰减
	"affection": {"idle": -0.3, "max_loss": -30.0},       # 好感度衰减
	"trust": {"idle": -0.2, "max_loss": -25.0},          # 信任度衰减
	"romance": {"idle": -0.8, "max_loss": -40.0},        # 浪漫度衰减
}

# 事件权重配置
const EVENT_WEIGHTS = {
	"conversation_positive": {"affection": 2.0, "familiarity": 1.5, "trust": 1.0},
	"conversation_negative": {"affection": -3.0, "trust": -2.0},
	"gift_given": {"affection": 3.0, "trust": 1.5},
	"gift_received": {"affection": 4.0, "trust": 2.0},
	"help_provided": {"trust": 3.0, "affection": 2.0, "respect": 1.5},
	"help_received": {"trust": 4.0, "affection": 3.0, "respect": 2.0},
	"conflict_minor": {"affection": -2.0, "trust": -1.5},
	"conflict_major": {"affection": -5.0, "trust": -3.0},
	"betrayal": {"affection": -8.0, "trust": -10.0},
	"loan_given": {"trust": 2.0},
	"loan_repaid": {"trust": 3.0, "affection": 2.0},
	"loan_defaulted": {"trust": -5.0, "affection": -4.0},
	"romantic_advance": {"romance": 3.0, "affection": 2.0},
	"romantic_rejection": {"romance": -2.0, "affection": -1.5}
}

# 关系标签定义 (根据关系状态自动添加/移除)
const RELATIONSHIP_TAGS = {
	# 基础关系标签
	"strangers": {"name": "陌生人", "conditions": {"relationship_level": "stranger"}},
	"acquaintances": {"name": "熟人", "conditions": {"relationship_level": "acquaintance"}},
	"friends": {"name": "朋友", "conditions": {"relationship_level": "friend"}},
	"close_friends": {"name": "好友", "conditions": {"relationship_level": "close_friend"}},
	"best_friends": {"name": "挚友", "conditions": {"relationship_level": "best_friend"}},

	# 负面关系标签
	"enemies": {"name": "敌人", "conditions": {"affection_max": 20}},
	"rivals": {"name": "竞争对手", "conditions": {"affection_range": [20, 40], "respect_min": 40}},

	# 浪漫关系标签
	"crush": {"name": "暗恋", "conditions": {"romance_min": 30, "romance_max": 60, "not_mutual": true}},
	"dating": {"name": "恋爱中", "conditions": {"romance_min": 70, "affection_min": 70}},
	"married": {"name": "已婚", "conditions": {"romance_min": 80, "affection_min": 80, "trust_min": 80}},

	# 社交关系标签
	"coworkers": {"name": "同事", "conditions": {"manual_only": true}},  # 需要手动设置
	"neighbors": {"name": "邻居", "conditions": {"manual_only": true}},
	"roommates": {"name": "室友", "conditions": {"manual_only": true}},

	# 特殊关系标签
	"mentor": {"name": "导师", "conditions": {"respect_min": 70, "trust_min": 60}},
	"mentee": {"name": "学生", "conditions": {"respect_min": 70, "affection_min": 50}},
	"family": {"name": "家人", "conditions": {"manual_only": true}},

	# 债务关系标签
	"debtor": {"name": "债务人", "conditions": {"has_debt": true}},
	"creditor": {"name": "债权人", "conditions": {"is_creditor": true}}
}

# 关系里程碑定义 (重要关系事件)
const RELATIONSHIP_MILESTONES = {
	# 基础里程碑
	"first_meeting": {"name": "初次相识", "description": "第一次见面"},
	"became_acquaintance": {"name": "成为熟人", "description": "关系从陌生人升级为熟人"},
	"became_friends": {"name": "成为朋友", "description": "正式成为朋友"},
	"became_close_friends": {"name": "成为好友", "description": "友谊进一步加深"},
	"became_best_friends": {"name": "成为挚友", "description": "成为最好的朋友"},

	# 浪漫里程碑
	"romantic_interest": {"name": "产生好感", "description": "开始对对方产生浪漫好感"},
	"confession_accepted": {"name": "表白成功", "description": "表白被接受"},
	"confession_rejected": {"name": "表白失败", "description": "表白被拒绝"},
	"first_date": {"name": "第一次约会", "description": "正式的第一次约会"},
	"became_couple": {"name": "确立关系", "description": "正式成为恋人"},
	"first_kiss": {"name": "初吻", "description": "第一次亲吻"},
	"moved_in_together": {"name": "同居", "description": "开始同居生活"},
	"engagement": {"name": "订婚", "description": "决定结婚并订婚"},
	"marriage": {"name": "结婚", "description": "正式结为夫妻"},
	"breakup": {"name": "分手", "description": "结束恋爱关系"},
	"divorce": {"name": "离婚", "description": "结束婚姻关系"},

	# 负面里程碑
	"first_conflict": {"name": "第一次冲突", "description": "第一次发生争执"},
	"major_conflict": {"name": "重大冲突", "description": "发生严重的矛盾"},
	"betrayal": {"name": "背叛", "description": "遭受背叛"},
	"became_enemies": {"name": "成为敌人", "description": "关系恶化为敌对"},
	"reconciliation": {"name": "和解", "description": "矛盾得到解决,重归于好"},

	# 信任里程碑
	"first_secret_shared": {"name": "分享秘密", "description": "第一次分享个人秘密"},
	"deep_conversation": {"name": "深度交谈", "description": "进行了一次深入的交谈"},
	"helped_in_crisis": {"name": "危机援助", "description": "在困难时刻提供了帮助"},

	# 经济里程碑
	"first_loan": {"name": "第一次借贷", "description": "第一次发生金钱借贷"},
	"loan_repaid": {"name": "还清贷款", "description": "成功还清借款"},
	"loan_defaulted": {"name": "违约", "description": "未能按时还款"},

	# 其他里程碑
	"long_separation": {"name": "长期分离", "description": "长时间未见面"},
	"reunion": {"name": "重逢", "description": "经历分离后再次相见"}
}

# ========================================
# 内部状态
# ========================================

var _relationships: Dictionary = {}  # ai_id -> {target_id: RelationshipData}
var _time_system: Node = null
var _event_bus: Node = null
var _memory_manager: Node = null
var _personality_engine: Node = null  # 性格引擎

# ========================================
# 初始化
# ========================================

func _ready():
	_time_system = get_node_or_null("/root/TimeSystem")
	_event_bus = get_node_or_null("/root/EventBus")
	_memory_manager = get_node_or_null("/root/MemoryManager")
	_personality_engine = get_node_or_null("/root/PersonalityEngine")

	# 连接时间系统信号
	if _time_system:
		_time_system.hour_changed.connect(_on_hour_changed)

	# 连接经济系统信号
	if _event_bus:
		_event_bus.subscribe("economy_loan_created", self, "_on_loan_created")
		_event_bus.subscribe("salary_paid", self, "_on_salary_paid")

	print("[RelationshipManager] 关系管理器初始化完成")

# ========================================
# 角色管理
# ========================================

func initialize_character(ai_id: String, all_ai_ids: Array[String]):
	"""初始化AI的关系网络"""
	if not _relationships.has(ai_id):
		_relationships[ai_id] = {}

	for other_id in all_ai_ids:
		if other_id != ai_id and not _relationships[ai_id].has(other_id):
			_relationships[ai_id][other_id] = _create_initial_relationship(ai_id, other_id)

	print("[RelationshipManager] 初始化 %s 的关系网络(共%d个关系)" % [ai_id, all_ai_ids.size() - 1])

func _create_initial_relationship(ai_id: String, target_id: String) -> Dictionary:
	"""创建初始关系数据

	基于性格契合度计算初始好感度和信任度:
	- 契合度高(>50): 初始好感度60-70, 更容易建立友谊
	- 契合度中等(-50~50): 初始好感度45-55, 中性
	- 契合度低(<-50): 初始好感度30-40, 更容易产生矛盾
	"""
	var base_affection = 50
	var base_trust = 50
	var compatibility = 0.0

	# 如果性格引擎可用,计算性格契合度
	if _personality_engine and _personality_engine.has_method("calculate_compatibility"):
		compatibility = _personality_engine.calculate_compatibility(ai_id, target_id)

		# 根据契合度调整初始好感度 (契合度范围: -100到100)
		# 契合度每10点影响好感度±2点,最大影响±20点
		var affection_modifier = clamp(compatibility / 5.0, -20.0, 20.0)
		base_affection = clamp(50 + affection_modifier, 30, 70)

		# 根据契合度调整初始信任度(影响较小)
		# 契合度每20点影响信任度±1点,最大影响±5点
		var trust_modifier = clamp(compatibility / 20.0, -5.0, 5.0)
		base_trust = clamp(50 + trust_modifier, 45, 55)

		print("[RelationshipManager] %s ↔ %s 性格契合度: %.1f, 初始好感: %d, 初始信任: %d" %
			[ai_id, target_id, compatibility, base_affection, base_trust])

	return {
		"familiarity": 0,    # 熟悉度 0-100
		"affection": base_affection,     # 好感度 0-100 (基于性格契合度)
		"trust": base_trust,         # 信任度 0-100 (基于性格契合度)
		"romance": 0,        # 浪漫度 0-100
		"respect": 50,       # 尊重度 0-100
		"compatibility": compatibility,  # 性格契合度 -100到100
		"interaction_count": 0,
		"last_interaction_time": 0,
		"relationship_level": "stranger",
		"relationship_tags": [],  # 关系标签列表
		"interaction_history": [],  # 最近10次互动记录
		"milestones": [],  # 关系里程碑列表
		"last_decay_check": 0,
		"debts": []  # 债务记录 [debtor_id, amount, interest_rate, due_time]
	}

# ========================================
# 关系查询API
# ========================================

func get_relationship(ai_id: String, target_id: String) -> Dictionary:
	"""获取关系数据"""
	if not _relationships.has(ai_id):
		return {}
	return _relationships[ai_id].get(target_id, {})

func get_relationship_level(ai_id: String, target_id: String) -> String:
	"""获取关系等级"""
	var relationship = get_relationship(ai_id, target_id)
	if relationship.is_empty():
		return "stranger"
	return relationship.get("relationship_level", "stranger")

func get_friends(ai_id: String, min_level: String = "friend") -> Array[String]:
	"""获取好友列表"""
	if not _relationships.has(ai_id):
		return []

	var friends: Array[String] = []
	var level_priority = {
		"stranger": 0,
		"acquaintance": 1,
		"friend": 2,
		"close_friend": 3,
		"best_friend": 4,
		"romantic": 5
	}

	var min_priority = level_priority.get(min_level, 2)

	for target_id in _relationships[ai_id]:
		var relationship = _relationships[ai_id][target_id]
		var target_priority = level_priority.get(relationship.relationship_level, 0)
		if target_priority >= min_priority:
			friends.append(target_id)

	return friends

func get_closest_people(ai_id: String, count: int = 5) -> Array[String]:
	"""获取最亲密的N个人"""
	if not _relationships.has(ai_id):
		return []

	# 按综合分数排序
	var scored_relationships = []
	for target_id in _relationships[ai_id]:
		var relationship = _relationships[ai_id][target_id]
		var score = (relationship.familiarity * 0.3 +
				   relationship.affection * 0.4 +
				   relationship.trust * 0.2 +
				   relationship.romance * 0.1)
		scored_relationships.append({"id": target_id, "score": score})

	# 排序
	scored_relationships.sort_custom(func(a, b): return a.score > b.score)

	# 返回前N个
	var result: Array[String] = []
	for i in range(min(count, scored_relationships.size())):
		result.append(scored_relationships[i].id)

	return result

func get_compatibility(ai_id: String, target_id: String) -> float:
	"""获取两个AI之间的性格契合度

	Returns:
		性格契合度 -100到100, 如果关系不存在返回0
	"""
	var relationship = get_relationship(ai_id, target_id)
	if relationship.is_empty():
		return 0.0
	return relationship.get("compatibility", 0.0)

func get_relationship_tags(ai_id: String, target_id: String) -> Array:
	"""获取关系标签列表

	Returns:
		关系标签数组, 例如: ["同事", "朋友", "室友"]
	"""
	var relationship = get_relationship(ai_id, target_id)
	if relationship.is_empty():
		return []
	return relationship.get("relationship_tags", [])

func get_milestones(ai_id: String, target_id: String) -> Array:
	"""获取关系里程碑列表

	Returns:
		里程碑数组, 每个元素包含: {milestone_id, timestamp, description}
	"""
	var relationship = get_relationship(ai_id, target_id)
	if relationship.is_empty():
		return []
	return relationship.get("milestones", [])

# ========================================
# 关系更新API
# ========================================

func update_relationship(ai_id: String, target_id: String, dimension: String, change: int):
	"""更新关系维度"""
	if not _relationships.has(ai_id) or not _relationships[ai_id].has(target_id):
		push_warning("[RelationshipManager] 关系不存在: %s -> %s" % [ai_id, target_id])
		return

	var relationship = _relationships[ai_id][target_id]

	# 更新维度值
	if dimension in ["familiarity", "affection", "trust", "romance", "respect"]:
		var old_value = relationship[dimension]
		relationship[dimension] = clamp(relationship[dimension] + change, 0, 100)

		print("[RelationshipManager] %s 对 %s 的%s: %d -> %d (变化:%+d)" % [
			ai_id, target_id, dimension, old_value, relationship[dimension], change])

	# 更新关系等级
	_update_relationship_level(ai_id, target_id)

	# 更新关系标签
	update_relationship_tags(ai_id, target_id)

	# 更新最后互动时间
	relationship.last_interaction_time = _current_timestamp()
	relationship.last_decay_check = _current_timestamp()

	# 发送事件
	relationship_changed.emit(ai_id, target_id, relationship)

	if _event_bus:
		_event_bus.emit_event("ai_relationship_changed", {
			"ai_id": ai_id,
			"target_id": target_id,
			"relationship": relationship,
			"dimension": dimension,
			"change": change
		})

func record_interaction(ai_id: String, target_id: String, interaction_type: String, sentiment: int):
	"""记录互动"""
	if not _relationships.has(ai_id) or not _relationships[ai_id].has(target_id):
		return

	var relationship = _relationships[ai_id][target_id]
	relationship.interaction_count += 1
	relationship.last_interaction_time = _current_timestamp()

	# 记录互动历史(保留最近10次)
	var history_entry = {
		"type": interaction_type,
		"sentiment": sentiment,
		"time": _current_timestamp()
	}
	relationship.interaction_history.append(history_entry)
	if relationship.interaction_history.size() > 10:
		relationship.interaction_history.pop_front()

	# 根据互动类型和情感值更新关系维度
	_apply_interaction_effects(ai_id, target_id, interaction_type, sentiment)

func _apply_interaction_effects(ai_id: String, target_id: String, interaction_type: String, sentiment: int):
	"""应用互动影响"""
	# 每次互动增加熟悉度
	update_relationship(ai_id, target_id, "familiarity", 1)

	# 根据情感值影响好感度
	var affection_change = sentiment / 10  # sentiment范围-100到100,转换为-10到10
	update_relationship(ai_id, target_id, "affection", affection_change)

	# 正面互动增加信任
	if sentiment > 50:
		update_relationship(ai_id, target_id, "trust", 1)
	elif sentiment < -50:
		update_relationship(ai_id, target_id, "trust", -2)

	# 特殊互动类型影响浪漫度
	if interaction_type in ["flirt", "date", "gift", "romantic_advance"]:
		update_relationship(ai_id, target_id, "romance", 2)

	# 根据 EVENT_WEIGHTS 应用更精确的影响
	var weights = EVENT_WEIGHTS.get(interaction_type, {})
	for dimension in weights:
		var change = weights[dimension]
		if sentiment < 0:
			change = abs(change) * (sentiment / 100.0)
		else:
			change = change * (sentiment / 100.0)
		update_relationship(ai_id, target_id, dimension, int(change))

# ========================================
# 关系标签管理
# ========================================

func add_relationship_tag(ai_id: String, target_id: String, tag_id: String) -> bool:
	"""添加关系标签

	Args:
		ai_id: AI ID
		target_id: 目标AI ID
		tag_id: 标签ID (在RELATIONSHIP_TAGS中定义)

	Returns:
		是否成功添加
	"""
	if not _relationships.has(ai_id) or not _relationships[ai_id].has(target_id):
		push_warning("[RelationshipManager] 关系不存在: %s -> %s" % [ai_id, target_id])
		return false

	if not RELATIONSHIP_TAGS.has(tag_id):
		push_warning("[RelationshipManager] 未知的标签ID: %s" % tag_id)
		return false

	var relationship = _relationships[ai_id][target_id]
	var tags = relationship.relationship_tags

	if tag_id in tags:
		return false  # 标签已存在

	tags.append(tag_id)
	print("[RelationshipManager] %s 和 %s 添加关系标签: %s" % [ai_id, target_id, RELATIONSHIP_TAGS[tag_id].name])

	# 发送标签变化信号
	tags_changed.emit(ai_id, target_id, tags)

	if _event_bus:
		_event_bus.emit_event("relationship_tag_added", {
			"ai_id": ai_id,
			"target_id": target_id,
			"tag_id": tag_id
		})

	return true

func remove_relationship_tag(ai_id: String, target_id: String, tag_id: String) -> bool:
	"""移除关系标签

	Args:
		ai_id: AI ID
		target_id: 目标AI ID
		tag_id: 标签ID

	Returns:
		是否成功移除
	"""
	if not _relationships.has(ai_id) or not _relationships[ai_id].has(target_id):
		return false

	var relationship = _relationships[ai_id][target_id]
	var tags = relationship.relationship_tags

	var index = tags.find(tag_id)
	if index == -1:
		return false  # 标签不存在

	tags.remove_at(index)
	print("[RelationshipManager] %s 和 %s 移除关系标签: %s" % [ai_id, target_id, RELATIONSHIP_TAGS[tag_id].name])

	# 发送标签变化信号
	tags_changed.emit(ai_id, target_id, tags)

	if _event_bus:
		_event_bus.emit_event("relationship_tag_removed", {
			"ai_id": ai_id,
			"target_id": target_id,
			"tag_id": tag_id
		})

	return true

func has_relationship_tag(ai_id: String, target_id: String, tag_id: String) -> bool:
	"""检查是否有特定关系标签

	Args:
		ai_id: AI ID
		target_id: 目标AI ID
		tag_id: 标签ID

	Returns:
		是否有该标签
	"""
	var relationship = get_relationship(ai_id, target_id)
	if relationship.is_empty():
		return false

	return tag_id in relationship.get("relationship_tags", [])

func update_relationship_tags(ai_id: String, target_id: String):
	"""更新关系标签 (根据关系状态自动添加/移除标签)

	这个方法会检查所有自动标签的条件,添加或移除相应的标签。
	在关系维度更新后自动调用。
	"""
	var relationship = get_relationship(ai_id, target_id)
	if relationship.is_empty():
		return

	for tag_id in RELATIONSHIP_TAGS:
		var tag_config = RELATIONSHIP_TAGS[tag_id]
		var conditions = tag_config.conditions

		# 跳过需要手动设置的标签
		if conditions.get("manual_only", false):
			continue

		var meets_conditions = _check_tag_conditions(relationship, conditions, ai_id, target_id)

		# 如果满足条件但没有标签,添加标签
		if meets_conditions and not has_relationship_tag(ai_id, target_id, tag_id):
			add_relationship_tag(ai_id, target_id, tag_id)
		# 如果不满足条件但有标签,移除标签
		elif not meets_conditions and has_relationship_tag(ai_id, target_id, tag_id):
			remove_relationship_tag(ai_id, target_id, tag_id)

func _check_tag_conditions(relationship: Dictionary, conditions: Dictionary, ai_id: String, target_id: String) -> bool:
	"""检查标签条件是否满足

	Args:
		relationship: 关系数据
		conditions: 条件字典
		ai_id: AI ID
		target_id: 目标AI ID

	Returns:
		是否满足所有条件
	"""
	# 检查关系等级条件
	if conditions.has("relationship_level"):
		if relationship.relationship_level != conditions.relationship_level:
			return false

	# 检查好感度最大值条件
	if conditions.has("affection_max"):
		if relationship.affection > conditions.affection_max:
			return false

	# 检查好感度范围条件
	if conditions.has("affection_range"):
		var range_val = conditions.affection_range
		if relationship.affection < range_val[0] or relationship.affection > range_val[1]:
			return false

	# 检查好感度最小值条件
	if conditions.has("affection_min"):
		if relationship.affection < conditions.affection_min:
			return false

	# 检查信任度最小值条件
	if conditions.has("trust_min"):
		if relationship.trust < conditions.trust_min:
			return false

	# 检查尊重度最小值条件
	if conditions.has("respect_min"):
		if relationship.respect < conditions.respect_min:
			return false

	# 检查浪漫度最小值条件
	if conditions.has("romance_min"):
		if relationship.romance < conditions.romance_min:
			return false

	# 检查浪漫度最大值条件
	if conditions.has("romance_max"):
		if relationship.romance > conditions.romance_max:
			return false

	# 检查是否有债务
	if conditions.has("has_debt"):
		var has_debt = relationship.debts.size() > 0
		if has_debt != conditions.has_debt:
			return false

	# 检查非互相条件 (例如暗恋)
	if conditions.has("not_mutual"):
		# 检查对方对自己的浪漫度是否低于自己对对方的
		var reverse_relationship = get_relationship(target_id, ai_id)
		if not reverse_relationship.is_empty():
			if reverse_relationship.romance >= relationship.romance:
				return false

	return true

# ========================================
# 关系里程碑管理
# ========================================

func add_milestone(ai_id: String, target_id: String, milestone_id: String, custom_description: String = "") -> bool:
	"""添加关系里程碑

	Args:
		ai_id: AI ID
		target_id: 目标AI ID
		milestone_id: 里程碑ID (在RELATIONSHIP_MILESTONES中定义)
		custom_description: 自定义描述 (可选,覆盖默认描述)

	Returns:
		是否成功添加
	"""
	if not _relationships.has(ai_id) or not _relationships[ai_id].has(target_id):
		push_warning("[RelationshipManager] 关系不存在: %s -> %s" % [ai_id, target_id])
		return false

	if not RELATIONSHIP_MILESTONES.has(milestone_id):
		push_warning("[RelationshipManager] 未知的里程碑ID: %s" % milestone_id)
		return false

	var relationship = _relationships[ai_id][target_id]
	var milestones = relationship.milestones

	# 检查是否已存在相同里程碑
	for milestone in milestones:
		if milestone.milestone_id == milestone_id:
			return false  # 里程碑已存在

	# 创建里程碑数据
	var milestone_config = RELATIONSHIP_MILESTONES[milestone_id]
	var description = custom_description if custom_description != "" else milestone_config.description
	var milestone_data = {
		"milestone_id": milestone_id,
		"name": milestone_config.name,
		"description": description,
		"timestamp": _current_timestamp(),
		"game_time": _get_game_time_string()
	}

	milestones.append(milestone_data)

	print("[RelationshipManager] %s 和 %s 解锁里程碑: %s - %s" %
		[ai_id, target_id, milestone_config.name, description])

	# 发送里程碑解锁信号
	milestone_unlocked.emit(ai_id, target_id, milestone_id)

	if _event_bus:
		_event_bus.emit_event("relationship_milestone_unlocked", {
			"ai_id": ai_id,
			"target_id": target_id,
			"milestone_id": milestone_id,
			"milestone_data": milestone_data
		})

	# 创建重要的记忆
	var memory_importance = _calculate_milestone_importance(milestone_id)
	var memory_text = "我和 %s %s: %s" % [target_id, milestone_config.name, description]
	_add_memory(ai_id, "relationship_milestone", memory_text, memory_importance, 0.5)

	return true

func has_milestone(ai_id: String, target_id: String, milestone_id: String) -> bool:
	"""检查是否有特定里程碑

	Args:
		ai_id: AI ID
		target_id: 目标AI ID
		milestone_id: 里程碑ID

	Returns:
		是否有该里程碑
	"""
	var relationship = get_relationship(ai_id, target_id)
	if relationship.is_empty():
		return false

	var milestones = relationship.get("milestones", [])
	for milestone in milestones:
		if milestone.milestone_id == milestone_id:
			return true

	return false

func _calculate_milestone_importance(milestone_id: String) -> float:
	"""计算里程碑的重要性 (用于记忆系统)

	Args:
		milestone_id: 里程碑ID

	Returns:
		重要性值 0.0-1.0
	"""
	# 婚姻和分手类里程碑最重要
	var critical_milestones = ["marriage", "divorce", "engagement", "became_couple", "breakup"]
	if milestone_id in critical_milestones:
		return 0.9

	# 浪漫相关里程碑较重要
	var romantic_milestones = ["confession_accepted", "confession_rejected", "first_kiss", "first_date"]
	if milestone_id in romantic_milestones:
		return 0.7

	# 友谊升级里程碑中等重要
	var friendship_milestones = ["became_friends", "became_close_friends", "became_best_friends"]
	if milestone_id in friendship_milestones:
		return 0.6

	# 负面里程碑较重要
	var negative_milestones = ["betrayal", "became_enemies", "major_conflict"]
	if milestone_id in negative_milestones:
		return 0.8

	# 其他里程碑普通重要
	return 0.5

func _get_game_time_string() -> String:
	"""获取游戏时间字符串 (用于里程碑记录)

	Returns:
		格式化的游戏时间字符串, 例如: "第1年 春季 第15天 14:30"
	"""
	if _time_system and _time_system.has_method("get_formatted_time"):
		return _time_system.get_formatted_time()
	return ""

# ========================================
# 便捷的里程碑触发方法
# ========================================

func trigger_first_meeting(ai_id: String, target_id: String):
	"""触发初次相识里程碑

	在两个AI第一次互动时调用
	"""
	if not has_milestone(ai_id, target_id, "first_meeting"):
		add_milestone(ai_id, target_id, "first_meeting")
		add_milestone(target_id, ai_id, "first_meeting")

func trigger_romantic_confession(confessor_id: String, target_id: String, accepted: bool):
	"""触发表白事件

	Args:
		confessor_id: 表白者ID
		target_id: 被表白者ID
		accepted: 是否接受表白
	"""
	if accepted:
		add_milestone(confessor_id, target_id, "confession_accepted", "向%s表白成功" % target_id)
		add_milestone(target_id, confessor_id, "confession_accepted", "接受了%s的表白" % confessor_id)

		# 大幅提升浪漫度和好感度
		update_relationship(confessor_id, target_id, "romance", 15)
		update_relationship(confessor_id, target_id, "affection", 10)
		update_relationship(target_id, confessor_id, "romance", 15)
		update_relationship(target_id, confessor_id, "affection", 10)
	else:
		add_milestone(confessor_id, target_id, "confession_rejected", "向%s表白被拒绝" % target_id)
		add_milestone(target_id, confessor_id, "confession_rejected", "拒绝了%s的表白" % confessor_id)

		# 降低浪漫度
		update_relationship(confessor_id, target_id, "romance", -10)
		update_relationship(confessor_id, target_id, "affection", -5)

func trigger_date(ai_id: String, target_id: String, is_first_date: bool = false):
	"""触发约会事件

	Args:
		ai_id: AI ID
		target_id: 约会对象ID
		is_first_date: 是否是第一次约会
	"""
	if is_first_date and not has_milestone(ai_id, target_id, "first_date"):
		add_milestone(ai_id, target_id, "first_date")
		add_milestone(target_id, ai_id, "first_date")

	# 增加浪漫度和好感度
	update_relationship(ai_id, target_id, "romance", 5)
	update_relationship(ai_id, target_id, "affection", 3)
	update_relationship(target_id, ai_id, "romance", 5)
	update_relationship(target_id, ai_id, "affection", 3)

func trigger_conflict(ai_id_1: String, ai_id_2: String, is_major: bool = false):
	"""触发冲突事件

	Args:
		ai_id_1: AI 1 ID
		ai_id_2: AI 2 ID
		is_major: 是否是重大冲突
	"""
	var milestone_id = "major_conflict" if is_major else "first_conflict"

	# 只有首次冲突才记录first_conflict
	if not is_major and has_milestone(ai_id_1, ai_id_2, "first_conflict"):
		return

	add_milestone(ai_id_1, ai_id_2, milestone_id, "与%s发生了%s" % [ai_id_2, "重大冲突" if is_major else "冲突"])
	add_milestone(ai_id_2, ai_id_1, milestone_id, "与%s发生了%s" % [ai_id_1, "重大冲突" if is_major else "冲突"])

	# 降低好感度和信任度
	var affection_change = -10 if is_major else -5
	var trust_change = -8 if is_major else -3

	update_relationship(ai_id_1, ai_id_2, "affection", affection_change)
	update_relationship(ai_id_1, ai_id_2, "trust", trust_change)
	update_relationship(ai_id_2, ai_id_1, "affection", affection_change)
	update_relationship(ai_id_2, ai_id_1, "trust", trust_change)

func trigger_betrayal(betrayer_id: String, victim_id: String):
	"""触发背叛事件

	Args:
		betrayer_id: 背叛者ID
		victim_id: 受害者ID
	"""
	add_milestone(victim_id, betrayer_id, "betrayal", "遭到了%s的背叛" % betrayer_id)

	# 严重降低信任度和好感度
	update_relationship(victim_id, betrayer_id, "trust", -20)
	update_relationship(victim_id, betrayer_id, "affection", -15)

func trigger_reconciliation(ai_id_1: String, ai_id_2: String):
	"""触发和解事件

	在之前有过冲突的两个AI和好时调用
	"""
	add_milestone(ai_id_1, ai_id_2, "reconciliation", "与%s重归于好" % ai_id_2)
	add_milestone(ai_id_2, ai_id_1, "reconciliation", "与%s重归于好" % ai_id_1)

	# 恢复部分好感度和信任度
	update_relationship(ai_id_1, ai_id_2, "affection", 10)
	update_relationship(ai_id_1, ai_id_2, "trust", 8)
	update_relationship(ai_id_2, ai_id_1, "affection", 10)
	update_relationship(ai_id_2, ai_id_1, "trust", 8)

func trigger_breakup(ai_id_1: String, ai_id_2: String):
	"""触发分手事件

	Args:
		ai_id_1: AI 1 ID
		ai_id_2: AI 2 ID
	"""
	add_milestone(ai_id_1, ai_id_2, "breakup", "与%s分手" % ai_id_2)
	add_milestone(ai_id_2, ai_id_1, "breakup", "与%s分手" % ai_id_1)

	# 大幅降低浪漫度,适度降低好感度
	update_relationship(ai_id_1, ai_id_2, "romance", -30)
	update_relationship(ai_id_1, ai_id_2, "affection", -15)
	update_relationship(ai_id_2, ai_id_1, "romance", -30)
	update_relationship(ai_id_2, ai_id_1, "affection", -15)

	# 移除恋爱相关标签
	remove_relationship_tag(ai_id_1, ai_id_2, "dating")
	remove_relationship_tag(ai_id_2, ai_id_1, "dating")

func trigger_marriage(ai_id_1: String, ai_id_2: String):
	"""触发结婚事件

	Args:
		ai_id_1: AI 1 ID
		ai_id_2: AI 2 ID
	"""
	# 先订婚
	if not has_milestone(ai_id_1, ai_id_2, "engagement"):
		add_milestone(ai_id_1, ai_id_2, "engagement", "与%s订婚" % ai_id_2)
		add_milestone(ai_id_2, ai_id_1, "engagement", "与%s订婚" % ai_id_1)

	# 再结婚
	add_milestone(ai_id_1, ai_id_2, "marriage", "与%s结婚" % ai_id_2)
	add_milestone(ai_id_2, ai_id_1, "marriage", "与%s结婚" % ai_id_1)

	# 添加已婚标签
	add_relationship_tag(ai_id_1, ai_id_2, "married")
	add_relationship_tag(ai_id_2, ai_id_1, "married")

	# 移除恋爱中标签
	remove_relationship_tag(ai_id_1, ai_id_2, "dating")
	remove_relationship_tag(ai_id_2, ai_id_1, "dating")

	# 最大化浪漫度和信任度
	update_relationship(ai_id_1, ai_id_2, "romance", 20)
	update_relationship(ai_id_1, ai_id_2, "trust", 15)
	update_relationship(ai_id_1, ai_id_2, "affection", 15)
	update_relationship(ai_id_2, ai_id_1, "romance", 20)
	update_relationship(ai_id_2, ai_id_1, "trust", 15)
	update_relationship(ai_id_2, ai_id_1, "affection", 15)

# ========================================
# 借贷系统API
# ========================================

func can_request_loan(requester_id: String, lender_id: String) -> Dictionary:
	"""检查是否可以借钱"""
	if not _relationships.has(requester_id) or not _relationships.has(lender_id):
		return {"eligible": false, "reason": "关系不存在"}

	var relationship = _relationships[lender_id][requester_id]
	var trust_level = relationship.trust

	# 检查信任度是否足够
	if trust_level < TRUST_THRESHOLDS.can_loan:
		return {
			"eligible": false,
			"reason": "信任度不足",
			"trust_level": trust_level,
			"required_trust": TRUST_THRESHOLDS.can_loan
		}

	# 检查是否有未还清的债务
	if _has_outstanding_debt(requester_id, lender_id):
		return {
			"eligible": false,
			"reason": "有未还清的债务",
			"trust_level": trust_level
		}

	return {
		"eligible": true,
		"trust_level": trust_level,
		"required_trust": TRUST_THRESHOLDS.can_loan
	}

func calculate_loan_multiplier(trust: float) -> float:
	"""计算贷款倍数"""
	return 1.0 + (trust - TRUST_THRESHOLDS.can_loan) / 40.0 * 2.0  # trust 60->1.0, trust 100->3.0

func add_debt(debtor_id: String, creditor_id: String, amount: int, interest_rate: float, due_days: int = 30):
	"""添加债务记录"""
	if not _relationships.has(creditor_id) or not _relationships[creditor_id].has(debtor_id):
		return

	var relationship = _relationships[creditor_id][debtor_id]
	var debt = {
		"amount": amount,
		"interest_rate": interest_rate,
		"due_time": _current_timestamp() + due_days * 24 * 3600,
		"created_time": _current_timestamp()
	}
	relationship.debts.append(debt)

func _has_outstanding_debt(debtor_id: String, creditor_id: String) -> bool:
	"""检查是否有未还清的债务"""
	if not _relationships.has(creditor_id):
		return false

	var relationship = _relationships[creditor_id][debtor_id]
	var current_time = _current_timestamp()

	for debt in relationship.debts:
		if debt.due_time > current_time:  # 还未到期
			return true

	return false

# ========================================
# 关系等级管理
# ========================================

func _update_relationship_level(ai_id: String, target_id: String):
	"""更新关系等级"""
	var relationship = _relationships[ai_id][target_id]
	var familiarity = relationship.familiarity
	var affection = relationship.affection

	# 判断关系等级
	var level = "stranger"
	if familiarity >= RELATIONSHIP_THRESHOLDS.best_friend and affection >= RELATIONSHIP_THRESHOLDS.best_friend:
		level = "best_friend"
	elif familiarity >= RELATIONSHIP_THRESHOLDS.close_friend and affection >= RELATIONSHIP_THRESHOLDS.close_friend:
		level = "close_friend"
	elif familiarity >= RELATIONSHIP_THRESHOLDS.friend and affection >= RELATIONSHIP_THRESHOLDS.friend:
		level = "friend"
	elif familiarity >= RELATIONSHIP_THRESHOLDS.acquaintance:
		level = "acquaintance"

	# 检查是否有浪漫关系
	if relationship.romance >= RELATIONSHIP_THRESHOLDS.romantic and affection >= RELATIONSHIP_THRESHOLDS.romantic:
		level = "romantic"

	# 检查是否为敌人
	if affection < RELATIONSHIP_THRESHOLDS.enemy:
		level = "enemy"

	if relationship.relationship_level != level:
		var old_level = relationship.relationship_level
		relationship.relationship_level = level
		print("[RelationshipManager] %s 和 %s 的关系等级变化: %s -> %s" % [ai_id, target_id, old_level, level])

		# 添加关系等级变化的里程碑
		_add_level_change_milestone(ai_id, target_id, old_level, level)

		# 创建里程碑记忆 (旧方法保留兼容)
		_create_relationship_milestone(ai_id, target_id, old_level, level)

func _add_level_change_milestone(ai_id: String, target_id: String, old_level: String, new_level: String):
	"""添加关系等级变化的里程碑

	根据等级变化自动添加相应的里程碑
	"""
	# 映射关系等级到里程碑ID
	var level_to_milestone = {
		"acquaintance": "became_acquaintance",
		"friend": "became_friends",
		"close_friend": "became_close_friends",
		"best_friend": "became_best_friends",
		"romantic": "became_couple",
		"enemy": "became_enemies"
	}

	# 如果新等级有对应的里程碑,添加它
	if level_to_milestone.has(new_level):
		var milestone_id = level_to_milestone[new_level]
		var description = "关系从%s变为%s" % [_translate_level(old_level), _translate_level(new_level)]
		add_milestone(ai_id, target_id, milestone_id, description)

func _translate_level(level: String) -> String:
	"""翻译关系等级为中文

	Args:
		level: 英文关系等级

	Returns:
		中文关系等级
	"""
	var translations = {
		"stranger": "陌生人",
		"acquaintance": "熟人",
		"friend": "朋友",
		"close_friend": "好友",
		"best_friend": "挚友",
		"romantic": "恋人",
		"enemy": "敌人"
	}
	return translations.get(level, level)

# ========================================
# 衰减系统
# ========================================

func _on_hour_changed(hour: int):
	"""每小时检查衰减"""
	if hour % DECAY_INTERVAL_HOURS != 0:  # 每24小时检查一次
		return

	_apply_decay()

func _apply_decay():
	"""应用关系衰减"""
	var current_time = _current_timestamp()

	for ai_id in _relationships.keys():
		for target_id in _relationships[ai_id].keys():
			var relationship = _relationships[ai_id][target_id]
			var last_check = relationship.last_decay_check
			var idle_time = current_time - relationship.last_interaction_time

			# 如果最近有互动，不衰减
			if idle_time < DECAY_IDLE_THRESHOLD_HOURS * 3600:
				continue

			# 应用各维度的衰减
			for dimension in DECAY_RATES.keys():
				if dimension in relationship:
					var decay_config = DECAY_RATES[dimension]
					var decay_rate = decay_config.idle
					var max_loss = decay_config.max_loss

					if decay_rate < 0 and relationship[dimension] > 0:
						var new_value = relationship[dimension] + decay_rate
						relationship[dimension] = max(new_value, max(abs(max_loss), 0))

			relationship.last_decay_check = current_time

			# 更新关系等级
			_update_relationship_level(ai_id, target_id)

# ========================================
# 记忆系统
# ========================================

func _create_relationship_milestone(ai_id: String, target_id: String, old_level: String, new_level: String):
	"""创建关系里程碑记忆"""
	var memory_text = "我和 %s 的关系从%s变成了%s" % [target_id, old_level, new_level]

	_add_memory(ai_id, "relationship_milestone", memory_text, 0.6, 0.4)

func _add_memory(ai_id: String, memory_type: String, text: String, importance: float, valence: float):
	"""添加记忆到MemoryManager"""
	if not _memory_manager:
		return

	var character = get_character_by_id(ai_id)
	if not character:
		return

	if _memory_manager.has_method("create_memory"):
		_memory_manager.create_memory(
			character,
			memory_type,
			text,
			[],
			"",
			importance,
			valence
		)

func get_character_by_id(ai_id: String) -> Node:
	"""通过ID获取AI角色节点"""
	return get_node_or_null("/root/CharacterManager/" + ai_id)

# ========================================
# 事件处理
# ========================================

func _on_loan_created(payload: Dictionary):
	"""处理借贷事件"""
	var requester_id = payload.get("requester_id", "")
	var lender_id = payload.get("lender_id", "")
	var amount = payload.get("amount", 0)
	var interest_rate = payload.get("interest_rate", 0.0)

	if requester_id != "" and lender_id != "":
		# 贷方增加信任
		update_relationship(lender_id, requester_id, "trust", 2)
		# 借方增加好感
		update_relationship(requester_id, lender_id, "affection", 2)

		# 添加债务记录
		add_debt(requester_id, lender_id, amount, interest_rate)

		# 检查是否是第一次借贷
		var relationship = get_relationship(requester_id, lender_id)
		if not has_milestone(requester_id, lender_id, "first_loan"):
			add_milestone(requester_id, lender_id, "first_loan", "向%s借了%dG" % [lender_id, amount])
			# 对方也添加里程碑
			add_milestone(lender_id, requester_id, "first_loan", "借给%s %dG" % [requester_id, amount])

		# 添加债务人/债权人标签
		add_relationship_tag(requester_id, lender_id, "creditor")  # 贷方是债权人(对借方而言)
		add_relationship_tag(lender_id, requester_id, "debtor")    # 借方是债务人(对贷方而言)

		# 创建记忆
		var loan_text = "我向 %s 借了 %dG，利率 %.1f%%" % [lender_id, amount, interest_rate * 100]
		_add_memory(requester_id, "loan_taken", loan_text, 0.6, -0.2)

func _on_salary_paid(payload: Dictionary):
	"""处理工资发放事件"""
	pass  # 关系系统不需要直接处理工资事件

# ========================================
# 查询API
# ========================================

func _current_timestamp() -> int:
	"""获取当前时间戳"""
	if _time_system and _time_system.has_method("get_current_timestamp"):
		return _time_system.get_current_timestamp()
	return Time.get_unix_time_from_system()

# ========================================
# 保存/加载
# ========================================

func save_state() -> Dictionary:
	"""保存关系系统状态"""
	return {
		"relationships": _relationships,
		"timestamp": _current_timestamp()
	}

func load_state(state: Dictionary):
	"""加载关系系统状态"""
	_relationships = state.get("relationships", {})
	print("[RelationshipManager] 关系数据已加载，共%d个AI的关系网络" % _relationships.size())