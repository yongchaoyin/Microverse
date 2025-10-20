extends Node

# ========================================
# AI记忆管理系统 (Memory System)
# ========================================
#
# 功能概述:
# - 三层记忆架构: 短期(7天) / 长期(永久) / 核心(身份)
# - 28种细分记忆类型
# - 动态重要性计算(情感/关系/性格/时间)
# - 自动衰减与遗忘机制
# - LLM上下文优化(对话/决策/反思模式)
# - 性格和关系系统集成
#
# 设计文档: docs/design/11_AI记忆系统详细规范.md
# ========================================

# ========================================
# Memory类定义
# ========================================

class Memory:
	"""记忆对象 - 完整的记忆数据结构"""

	# 基础信息
	var memory_id: String           # 唯一ID
	var ai_id: String               # 所属AI
	var memory_type: String         # 记忆类型 (28种细分类型)
	var timestamp: int              # 游戏时间戳(天数)
	var game_time: Dictionary       # 具体游戏时间 {year, season, day, hour, minute}
	var importance: float = 0.5     # 重要性 0.0-1.0
	var emotional_intensity: float = 0.0  # 情感强度 0.0-1.0
	var emotional_valence: float = 0.0    # 情感正负 -1.0~1.0

	# 记忆内容
	var description: String = ""    # 人类可读描述
	var participants: Array = []    # 参与者AI ID列表
	var location: String = ""       # 发生地点
	var related_memories: Array = []  # 相关记忆ID

	# LLM使用字段
	var llm_summary: String = ""    # 简短摘要(供LLM上下文)
	var embedding_vector: Array = []  # 向量化嵌入(可选,用于语义检索)

	# 元数据
	var access_count: int = 0       # 被回忆的次数
	var last_accessed: int = 0      # 最后被访问的时间(天数)
	var decay_rate: float = 1.0     # 衰减速率
	var memory_layer: String = "short_term"  # 记忆层级: short_term/long_term/core

	func _init():
		memory_id = _generate_uuid()

	func to_dict() -> Dictionary:
		"""转换为字典(用于保存)"""
		return {
			"memory_id": memory_id,
			"ai_id": ai_id,
			"memory_type": memory_type,
			"timestamp": timestamp,
			"game_time": game_time,
			"importance": importance,
			"emotional_intensity": emotional_intensity,
			"emotional_valence": emotional_valence,
			"description": description,
			"participants": participants,
			"location": location,
			"related_memories": related_memories,
			"llm_summary": llm_summary,
			"access_count": access_count,
			"last_accessed": last_accessed,
			"decay_rate": decay_rate,
			"memory_layer": memory_layer
		}

	func from_dict(data: Dictionary) -> void:
		"""从字典加载"""
		memory_id = data.get("memory_id", _generate_uuid())
		ai_id = data.get("ai_id", "")
		memory_type = data.get("memory_type", "")
		timestamp = data.get("timestamp", 0)
		game_time = data.get("game_time", {})
		importance = data.get("importance", 0.5)
		emotional_intensity = data.get("emotional_intensity", 0.0)
		emotional_valence = data.get("emotional_valence", 0.0)
		description = data.get("description", "")
		participants = data.get("participants", [])
		location = data.get("location", "")
		related_memories = data.get("related_memories", [])
		llm_summary = data.get("llm_summary", "")
		access_count = data.get("access_count", 0)
		last_accessed = data.get("last_accessed", 0)
		decay_rate = data.get("decay_rate", 1.0)
		memory_layer = data.get("memory_layer", "short_term")

	func _generate_uuid() -> String:
		"""生成唯一ID"""
		return "%d_%d" % [Time.get_ticks_usec(), randi()]

# ========================================
# 记忆类型常量定义
# ========================================

# 28种细分记忆类型
const MEMORY_TYPES = {
	# 社交记忆 (7种)
	"conversation": {"base_importance": 0.4, "category": "social"},
	"gift_received": {"base_importance": 0.6, "category": "social"},
	"gift_given": {"base_importance": 0.5, "category": "social"},
	"conflict": {"base_importance": 0.85, "category": "social"},
	"reconciliation": {"base_importance": 0.8, "category": "social"},
	"confession": {"base_importance": 1.0, "category": "social"},
	"breakup": {"base_importance": 1.0, "category": "social"},

	# 工作记忆 (5种)
	"promotion": {"base_importance": 0.9, "category": "work"},
	"overtime": {"base_importance": 0.35, "category": "work"},
	"late_arrival": {"base_importance": 0.4, "category": "work"},
	"job_change": {"base_importance": 1.0, "category": "work"},
	"coworker_interaction": {"base_importance": 0.45, "category": "work"},

	# 生活记忆 (5种)
	"illness": {"base_importance": 0.7, "category": "life"},
	"financial_crisis": {"base_importance": 0.8, "category": "life"},
	"achievement": {"base_importance": 0.75, "category": "life"},
	"festival": {"base_importance": 0.6, "category": "life"},
	"move": {"base_importance": 0.8, "category": "life"},

	# 情感记忆 (4种)
	"peak_happiness": {"base_importance": 0.9, "category": "emotion"},
	"deep_sadness": {"base_importance": 0.9, "category": "emotion"},
	"trauma": {"base_importance": 1.0, "category": "emotion"},
	"nostalgia": {"base_importance": 0.7, "category": "emotion"},

	# 关系里程碑 (7种) - 与RelationshipManager集成
	"relationship_milestone": {"base_importance": 0.6, "category": "relationship"},
	"first_meeting": {"base_importance": 0.5, "category": "relationship"},
	"became_friends": {"base_importance": 0.7, "category": "relationship"},
	"became_close_friends": {"base_importance": 0.8, "category": "relationship"},
	"became_couple": {"base_importance": 1.0, "category": "relationship"},
	"marriage": {"base_importance": 1.0, "category": "relationship"},
	"became_enemies": {"base_importance": 0.85, "category": "relationship"}
}

# 旧版本兼容 - 枚举映射
enum MemoryType {
	PERSONAL = 0,
	INTERACTION = 1,
	TASK = 2,
	EMOTION = 3,
	EVENT = 4
}

enum MemoryImportance {
	LOW = 1,
	NORMAL = 3,
	HIGH = 5,
	CRITICAL = 10
}

# ========================================
# 内部状态
# ========================================

# 记忆存储 (按AI组织)
var _memories_by_ai: Dictionary = {}  # ai_id -> {short_term: [], long_term: [], core: []}

# 系统引用
var _time_system: Node = null
var _event_bus: Node = null
var _personality_engine: Node = null
var _relationship_manager: Node = null

# 配置参数
const SHORT_TERM_DAYS: int = 7        # 短期记忆保留天数
const SHORT_TERM_MAX: int = 50        # 短期记忆最大数量
const LONG_TERM_MAX: int = 200        # 长期记忆最大数量
const CORE_MEMORY_MAX: int = 10       # 核心记忆最大数量

# ========================================
# 初始化
# ========================================

func _ready():
	"""初始化记忆系统"""
	# 获取系统引用
	_time_system = get_node_or_null("/root/TimeSystem")
	_event_bus = get_node_or_null("/root/EventBus")
	_personality_engine = get_node_or_null("/root/PersonalityEngine")
	_relationship_manager = get_node_or_null("/root/RelationshipManager")

	# 连接时间系统信号
	if _time_system:
		if _time_system.has_signal("day_changed"):
			_time_system.day_changed.connect(_on_day_changed)

	# 连接关系系统信号
	if _event_bus:
		_event_bus.subscribe("relationship_milestone_unlocked", self, "_on_relationship_milestone")

	# 连接冲突系统信号
	var conflict_system = get_node_or_null("/root/ConflictSystem")
	if conflict_system:
		if conflict_system.has_signal("conflict_triggered"):
			conflict_system.conflict_triggered.connect(_on_conflict_triggered)
		if conflict_system.has_signal("conflict_resolved"):
			conflict_system.conflict_resolved.connect(_on_conflict_resolved)
		if conflict_system.has_signal("mediation_completed"):
			conflict_system.mediation_completed.connect(_on_mediation_completed)

	print("[MemoryManager] 记忆管理系统初始化完成")

# ========================================
# 创建记忆 (新API)
# ========================================

func create_memory(
	ai_id: String,
	memory_type: String,
	description: String,
	participants: Array = [],
	location: String = "",
	importance: float = -1.0,  # -1表示自动计算
	emotional_intensity: float = 0.0,
	emotional_valence: float = 0.0
) -> Memory:
	"""创建新记忆

	Args:
		ai_id: AI ID
		memory_type: 记忆类型(使用MEMORY_TYPES中的key)
		description: 记忆描述
		participants: 参与者AI ID列表
		location: 发生地点
		importance: 重要性(0.0-1.0, -1为自动计算)
		emotional_intensity: 情感强度(0.0-1.0)
		emotional_valence: 情感正负(-1.0~1.0)

	Returns:
		创建的Memory对象
	"""
	# 验证记忆类型
	if not MEMORY_TYPES.has(memory_type):
		push_warning("[MemoryManager] 未知的记忆类型: %s, 使用默认类型" % memory_type)
		memory_type = "conversation"

	# 创建记忆对象
	var memory = Memory.new()
	memory.ai_id = ai_id
	memory.memory_type = memory_type
	memory.timestamp = _get_current_day()
	memory.game_time = _get_time_snapshot()
	memory.description = description
	memory.participants = participants
	memory.location = location
	memory.emotional_intensity = clamp(emotional_intensity, 0.0, 1.0)
	memory.emotional_valence = clamp(emotional_valence, -1.0, 1.0)

	# 生成LLM摘要
	memory.llm_summary = _generate_llm_summary(memory)

	# 计算重要性
	if importance < 0:
		memory.importance = calculate_importance(memory)
	else:
		memory.importance = clamp(importance, 0.0, 1.0)

	# 添加到短期记忆
	_add_to_short_term(memory)

	# 检查是否需要创建情感记忆标签
	if emotional_intensity > 0.7 or abs(emotional_valence) > 0.8:
		_create_emotional_memory_tag(memory)

	# 发送事件
	if _event_bus:
		_event_bus.emit_event("memory_created", {
			"ai_id": ai_id,
			"memory_type": memory_type,
			"importance": memory.importance,
			"memory_id": memory.memory_id
		})

	print("[MemoryManager] %s 创建记忆: %s (重要性: %.2f)" % [ai_id, memory.llm_summary, memory.importance])

	return memory

# ========================================
# 记忆检索API
# ========================================

func get_recent_memories(ai_id: String, count: int = 10) -> Array:
	"""获取最近的记忆

	Args:
		ai_id: AI ID
		count: 返回数量

	Returns:
		Memory对象数组,按时间倒序
	"""
	var short_term = _get_short_term_memories(ai_id)
	var sorted_memories = short_term.duplicate()
	sorted_memories.sort_custom(func(a, b): return a.timestamp > b.timestamp)

	var result = []
	for i in range(min(count, sorted_memories.size())):
		result.append(sorted_memories[i])

	return result

func get_important_memories(ai_id: String, count: int = 20) -> Array:
	"""获取最重要的记忆

	Args:
		ai_id: AI ID
		count: 返回数量

	Returns:
		Memory对象数组,按重要性排序
	"""
	var long_term = _get_long_term_memories(ai_id)
	var sorted_memories = long_term.duplicate()
	sorted_memories.sort_custom(func(a, b): return a.importance > b.importance)

	var result = []
	for i in range(min(count, sorted_memories.size())):
		result.append(sorted_memories[i])

	return result

func get_memories_with_participant(ai_id: String, participant_id: String, count: int = 10) -> Array:
	"""获取与特定AI相关的记忆

	Args:
		ai_id: AI ID
		participant_id: 参与者AI ID
		count: 返回数量

	Returns:
		Memory对象数组
	"""
	var all_memories = _get_short_term_memories(ai_id) + _get_long_term_memories(ai_id)
	var filtered = []

	for m in all_memories:
		if participant_id in m.participants:
			filtered.append(m)

	# 按时间倒序
	filtered.sort_custom(func(a, b): return a.timestamp > b.timestamp)

	var result = []
	for i in range(min(count, filtered.size())):
		result.append(filtered[i])

	return result

func get_emotional_memories(ai_id: String, count: int = 5) -> Array:
	"""获取情感记忆

	Args:
		ai_id: AI ID
		count: 返回数量

	Returns:
		高情感强度的Memory对象数组
	"""
	var all_memories = _get_long_term_memories(ai_id)
	var emotional = []

	for m in all_memories:
		if m.emotional_intensity > 0.7:
			emotional.append(m)

	# 按情感强度排序
	emotional.sort_custom(func(a, b): return a.emotional_intensity > b.emotional_intensity)

	var result = []
	for i in range(min(count, emotional.size())):
		result.append(emotional[i])

	return result

func get_core_memories(ai_id: String) -> Array:
	"""获取核心记忆

	Args:
		ai_id: AI ID

	Returns:
		核心Memory对象数组
	"""
	_ensure_ai_memory_structure(ai_id)
	return _memories_by_ai[ai_id]["core"]

func get_memories_by_type(ai_id: String, memory_type: String, count: int = 10) -> Array:
	"""按类型获取记忆

	Args:
		ai_id: AI ID
		memory_type: 记忆类型
		count: 返回数量

	Returns:
		指定类型的Memory对象数组
	"""
	var all_memories = _get_short_term_memories(ai_id) + _get_long_term_memories(ai_id)
	var filtered = []

	for m in all_memories:
		if m.memory_type == memory_type:
			filtered.append(m)

	# 按时间倒序
	filtered.sort_custom(func(a, b): return a.timestamp > b.timestamp)

	var result = []
	for i in range(min(count, filtered.size())):
		result.append(filtered[i])

	return result

# ========================================
# LLM上下文构建
# ========================================

func build_llm_context(ai_id: String, context_type: String = "conversation", max_tokens: int = 1000) -> String:
	"""为LLM构建记忆上下文

	Args:
		ai_id: AI ID
		context_type: 上下文类型 ("conversation" | "decision" | "reflection" | "daily_summary")
		max_tokens: 最大token数(估算: 1条记忆≈50 tokens)

	Returns:
		格式化的记忆上下文字符串
	"""
	var max_memories = max_tokens / 50
	var memories_to_format = []

	match context_type:
		"conversation":
			# 对话上下文: 最近记忆 + 核心记忆
			var recent = get_recent_memories(ai_id, 10)
			var core = get_core_memories(ai_id)
			memories_to_format = core + recent

		"decision":
			# 决策上下文: 重要记忆 + 情感记忆 + 核心记忆
			var important = get_important_memories(ai_id, 15)
			var emotional = get_emotional_memories(ai_id, 5)
			var core = get_core_memories(ai_id)
			memories_to_format = core + important + emotional

		"reflection":
			# 反思上下文: 所有重要记忆 + 核心记忆
			var important = get_important_memories(ai_id, 30)
			var core = get_core_memories(ai_id)
			memories_to_format = core + important

		"daily_summary":
			# 每日总结: 今天的所有记忆
			var today = get_recent_memories(ai_id, 50)
			var current_day = _get_current_day()
			var today_memories = []
			for m in today:
				if m.timestamp == current_day:
					today_memories.append(m)
			memories_to_format = today_memories

		_:
			# 默认: 最近记忆
			memories_to_format = get_recent_memories(ai_id, 20)

	return _format_memories_for_llm(memories_to_format, int(max_memories))

func _format_memories_for_llm(memories: Array, max_count: int) -> String:
	"""格式化记忆为LLM友好的文本

	Args:
		memories: Memory对象数组
		max_count: 最大数量

	Returns:
		格式化的文本
	"""
	# 去重
	var unique_memories = []
	var seen_ids = []
	for m in memories:
		if not m.memory_id in seen_ids:
			unique_memories.append(m)
			seen_ids.append(m.memory_id)

	# 按重要性×情感强度排序
	unique_memories.sort_custom(func(a, b):
		var score_a = a.importance * (1.0 + a.emotional_intensity)
		var score_b = b.importance * (1.0 + b.emotional_intensity)
		return score_a > score_b
	)

	if unique_memories.is_empty():
		return "\n\n### 相关记忆 ###\n暂无记忆"

	var context = "\n\n### 相关记忆 ###\n"
	var count = 0

	for memory in unique_memories:
		if count >= max_count:
			break

		# 格式化时间
		var time_str = _format_game_time(memory.game_time)

		# 格式化情感标签
		var emotion_str = _format_emotion(memory.emotional_valence, memory.emotional_intensity)

		# 构建记忆条目
		context += "[%s] %s %s\n" % [time_str, memory.llm_summary, emotion_str]
		count += 1

		# 标记被访问
		memory.access_count += 1
		memory.last_accessed = _get_current_day()

	if count < unique_memories.size():
		context += "...还有 %d 条其他记忆\n" % (unique_memories.size() - count)

	return context

func _format_game_time(game_time: Dictionary) -> String:
	"""格式化游戏时间

	Args:
		game_time: 时间字典

	Returns:
		格式化的时间字符串
	"""
	var season_name = game_time.get("season_name", "")
	var day = game_time.get("day", 0)
	var hour = game_time.get("hour", 0)

	if season_name != "":
		return "%s %d日 %d:00" % [season_name, day, hour]
	else:
		return "Day %d %d:00" % [day, hour]

func _format_emotion(valence: float, intensity: float) -> String:
	"""格式化情感标签

	Args:
		valence: 情感正负 -1.0~1.0
		intensity: 情感强度 0.0-1.0

	Returns:
		情感emoji字符串
	"""
	if intensity < 0.3:
		return ""

	var emotion = ""
	if valence > 0.6:
		emotion = "😊快乐"
	elif valence > 0.3:
		emotion = "🙂愉快"
	elif valence < -0.6:
		emotion = "😢悲伤"
	elif valence < -0.3:
		emotion = "😟难过"
	else:
		return ""

	if intensity > 0.7:
		emotion += "!!"

	return "(" + emotion + ")"

# ========================================
# 重要性计算
# ========================================

func calculate_importance(memory: Memory) -> float:
	"""计算记忆重要性

	综合考虑:
	- 基础重要性 (40%) - 由记忆类型决定
	- 情感强度 (25%) - 情感越强烈越重要
	- 关系亲密度 (20%) - 与重要人物的记忆更重要
	- 性格因素 (10%) - 性格影响重视的记忆类型
	- 新鲜度 (5%) - 近期记忆相对更重要

	Args:
		memory: Memory对象

	Returns:
		重要性值 0.0-1.0
	"""
	# 因素1: 基础重要性 (40%)
	var base_importance = _get_base_importance_by_type(memory.memory_type)

	# 因素2: 情感强度 (25%)
	var emotion_factor = memory.emotional_intensity

	# 因素3: 关系亲密度 (20%)
	var relationship_factor = _calculate_relationship_factor(memory)

	# 因素4: 性格因素 (10%)
	var personality_factor = _calculate_personality_factor(memory)

	# 因素5: 新鲜度 (5%)
	var recency_factor = _calculate_recency_factor(memory)

	# 综合计算
	var importance = base_importance * 0.4 + \
					emotion_factor * 0.25 + \
					relationship_factor * 0.2 + \
					personality_factor * 0.1 + \
					recency_factor * 0.05

	return clamp(importance, 0.0, 1.0)

func _get_base_importance_by_type(type: String) -> float:
	"""获取记忆类型的基础重要性

	Args:
		type: 记忆类型

	Returns:
		基础重要性 0.0-1.0
	"""
	if MEMORY_TYPES.has(type):
		return MEMORY_TYPES[type].base_importance
	return 0.5  # 默认值

func _calculate_relationship_factor(memory: Memory) -> float:
	"""计算关系因素

	与重要人物(好友或敌人)的记忆更重要

	Args:
		memory: Memory对象

	Returns:
		关系因素 0.0-1.0
	"""
	if not _relationship_manager:
		return 0.5  # 默认中等

	if memory.participants.is_empty():
		return 0.5

	var max_affection = 0.0
	for participant_id in memory.participants:
		var relationship = _relationship_manager.get_relationship(memory.ai_id, participant_id)
		if not relationship.is_empty():
			var affection = abs(relationship.get("affection", 50))  # 绝对值,敌人也重要
			max_affection = max(max_affection, affection)

	return max_affection / 100.0

func _calculate_personality_factor(memory: Memory) -> float:
	"""计算性格因素

	不同性格的AI重视不同类型的记忆:
	- 外向性高: 更重视社交记忆
	- 尽责性高: 更重视工作成就
	- 神经质高: 更容易记住情感强烈的事件

	Args:
		memory: Memory对象

	Returns:
		性格因素 0.5-1.5 (倍数)
	"""
	if not _personality_engine:
		return 1.0  # 默认不影响

	var personality = _personality_engine.get_personality(memory.ai_id)
	if personality.is_empty():
		return 1.0

	var category = MEMORY_TYPES.get(memory.memory_type, {}).get("category", "")
	var factor = 1.0

	match category:
		"social":
			# 外向AI更重视社交记忆
			factor = personality.get("extraversion", 50) / 50.0

		"work":
			# 尽责AI更重视工作记忆
			factor = personality.get("conscientiousness", 50) / 50.0

		"emotion":
			# 神经质AI更容易记住情感记忆
			factor = personality.get("neuroticism", 50) / 50.0

		_:
			factor = 1.0

	# 情感强烈的事件,神经质AI更重视
	if memory.emotional_intensity > 0.7:
		factor *= personality.get("neuroticism", 50) / 50.0

	return clamp(factor, 0.5, 1.5)

func _calculate_recency_factor(memory: Memory) -> float:
	"""计算新鲜度因素

	近期记忆相对更重要,30天后降到最低

	Args:
		memory: Memory对象

	Returns:
		新鲜度因素 0.3-1.0
	"""
	var current_day = _get_current_day()
	var days_ago = current_day - memory.timestamp
	var recency = max(1.0 - (days_ago / 30.0), 0.3)
	return recency

# ========================================
# 记忆衰减与遗忘
# ========================================

func _on_day_changed(year: int, season: int, day: int):
	"""每天触发记忆巩固

	处理所有AI的记忆:
	- 短期记忆7天后转移或遗忘
	- 长期记忆满容量后遗忘最不重要的
	"""
	print("[MemoryManager] 第%d年 %s %d日 - 触发记忆巩固" % [year, _get_season_name(season), day])

	for ai_id in _memories_by_ai.keys():
		process_memory_consolidation(ai_id)

func process_memory_consolidation(ai_id: String):
	"""处理单个AI的记忆巩固

	Args:
		ai_id: AI ID
	"""
	var current_day = _get_current_day()
	var short_term = _get_short_term_memories(ai_id)

	# 检查需要转移或遗忘的短期记忆
	var to_consolidate = []
	for memory in short_term:
		var age_days = current_day - memory.timestamp

		if age_days >= SHORT_TERM_DAYS:
			to_consolidate.append(memory)

	# 处理每个过期的短期记忆
	for memory in to_consolidate:
		if _should_consolidate_to_long_term(memory, ai_id):
			_transfer_to_long_term(memory, ai_id)
		else:
			_forget_memory(memory, ai_id)

func _should_consolidate_to_long_term(memory: Memory, ai_id: String) -> bool:
	"""判断是否应该转移到长期记忆

	保留条件:
	- 重要性 > 0.6
	- 情感强度 > 0.7
	- 被频繁回忆 (access_count > 3)
	- 与重要人物相关 (好感度 > 60)
	- 性格特殊因素 (神经质AI记住负面,开放AI记住新奇)

	Args:
		memory: Memory对象
		ai_id: AI ID

	Returns:
		是否保留
	"""
	# 条件1: 高重要性
	if memory.importance > 0.6:
		return true

	# 条件2: 高情感强度
	if memory.emotional_intensity > 0.7:
		return true

	# 条件3: 被频繁回忆
	if memory.access_count > 3:
		return true

	# 条件4: 与重要人物相关
	if _relationship_manager and not memory.participants.is_empty():
		for participant_id in memory.participants:
			var rel = _relationship_manager.get_relationship(ai_id, participant_id)
			if not rel.is_empty():
				var affection = abs(rel.get("affection", 50))
				if affection > 60:  # 好友或敌人
					return true

	# 条件5: 性格特殊因素
	if _personality_engine:
		var personality = _personality_engine.get_personality(ai_id)
		if not personality.is_empty():
			# 神经质AI更容易记住负面记忆
			if personality.get("neuroticism", 50) > 70 and memory.emotional_valence < -0.5:
				return true

			# 开放AI更容易记住新奇经历
			if personality.get("openness", 50) > 70:
				if memory.memory_type in ["achievement", "festival", "move", "job_change"]:
					return true

	return false

func _transfer_to_long_term(memory: Memory, ai_id: String):
	"""转移到长期记忆

	Args:
		memory: Memory对象
		ai_id: AI ID
	"""
	var long_term = _get_long_term_memories(ai_id)

	# 检查容量 (最多200条)
	if long_term.size() >= LONG_TERM_MAX:
		# 找出最不重要的记忆并遗忘
		var sorted_long_term = long_term.duplicate()
		sorted_long_term.sort_custom(func(a, b): return a.importance < b.importance)
		var least_important = sorted_long_term[0]
		_forget_memory(least_important, ai_id)

	# 转移记忆
	memory.access_count = 0  # 重置访问计数
	memory.memory_layer = "long_term"
	_get_short_term_memories(ai_id).erase(memory)
	_get_long_term_memories(ai_id).append(memory)

	print("[MemoryManager] %s 记忆转移到长期: %s" % [ai_id, memory.llm_summary])

func _forget_memory(memory: Memory, ai_id: String):
	"""遗忘记忆

	Args:
		memory: Memory对象
		ai_id: AI ID
	"""
	_get_short_term_memories(ai_id).erase(memory)
	_get_long_term_memories(ai_id).erase(memory)

	print("[MemoryManager] %s 遗忘了: %s (重要性: %.2f)" % [ai_id, memory.llm_summary, memory.importance])

# ========================================
# 核心记忆管理
# ========================================

func create_core_memory(ai_id: String, description: String, reason: String = "") -> Memory:
	"""创建核心记忆

	核心记忆定义AI的身份,永不遗忘
	触发条件: 职业改变、重大创伤、确认恋爱关系等

	Args:
		ai_id: AI ID
		description: 核心记忆描述
		reason: 创建原因

	Returns:
		创建的Memory对象
	"""
	var core = get_core_memories(ai_id)

	if core.size() >= CORE_MEMORY_MAX:
		push_warning("[MemoryManager] %s 的核心记忆已满 (%d/%d)" % [ai_id, core.size(), CORE_MEMORY_MAX])
		return null

	var memory = Memory.new()
	memory.ai_id = ai_id
	memory.memory_type = "core_identity"
	memory.timestamp = _get_current_day()
	memory.game_time = _get_time_snapshot()
	memory.importance = 1.0  # 核心记忆永远最重要
	memory.description = description
	memory.llm_summary = description
	memory.memory_layer = "core"

	core.append(memory)

	print("[MemoryManager] %s 核心记忆创建: %s (原因: %s)" % [ai_id, description, reason])

	if _event_bus:
		_event_bus.emit_event("core_memory_created", {
			"ai_id": ai_id,
			"description": description,
			"reason": reason
		})

	return memory

# ========================================
# 辅助方法
# ========================================

func _generate_llm_summary(memory: Memory) -> String:
	"""生成LLM友好的简短摘要

	Args:
		memory: Memory对象

	Returns:
		摘要字符串
	"""
	var summary = ""
	var participant_name = ""
	if memory.participants.size() > 0:
		participant_name = memory.participants[0]

	match memory.memory_type:
		"conversation":
			if participant_name != "":
				summary = "和%s交谈" % participant_name
			else:
				summary = "进行了一次对话"

		"gift_received":
			if participant_name != "":
				summary = "收到%s的礼物" % participant_name
			else:
				summary = "收到了礼物"

		"gift_given":
			if participant_name != "":
				summary = "送礼物给%s" % participant_name
			else:
				summary = "送出了礼物"

		"conflict":
			if participant_name != "":
				summary = "和%s发生冲突" % participant_name
			else:
				summary = "发生了冲突"

		"reconciliation":
			if participant_name != "":
				summary = "和%s和解" % participant_name
			else:
				summary = "和解了"

		"confession":
			if "被表白" in memory.description or "向我表白" in memory.description:
				summary = "%s向我表白" % participant_name if participant_name != "" else "被表白"
			else:
				summary = "我向%s表白" % participant_name if participant_name != "" else "表白"

		"breakup":
			if participant_name != "":
				summary = "和%s分手" % participant_name
			else:
				summary = "分手了"

		"promotion":
			summary = "工资上涨"

		"overtime":
			summary = "加班"

		"late_arrival":
			summary = "迟到"

		"job_change":
			summary = "跳槽/转职"

		"illness":
			summary = "生病了"

		"financial_crisis":
			summary = "遇到财务危机"

		"achievement":
			summary = "达成成就"

		"festival":
			summary = "参加节日活动"

		"move":
			summary = "搬家"

		_:
			# 默认: 截取描述前50字符
			summary = memory.description.substr(0, 50)
			if memory.description.length() > 50:
				summary += "..."

	return summary

func _create_emotional_memory_tag(memory: Memory):
	"""基于强烈情感事件创建情感记忆标签

	Args:
		memory: Memory对象
	"""
	if not "emotional_peak" in memory.related_memories:
		memory.related_memories.append("emotional_peak")

	# 神经质AI更容易形成创伤记忆
	if _personality_engine:
		var personality = _personality_engine.get_personality(memory.ai_id)
		if not personality.is_empty():
			if personality.get("neuroticism", 50) > 70 and memory.emotional_valence < -0.8:
				if not "trauma" in memory.related_memories:
					memory.related_memories.append("trauma")
					print("[MemoryManager] %s 形成创伤记忆: %s" % [memory.ai_id, memory.llm_summary])

func _ensure_ai_memory_structure(ai_id: String):
	"""确保AI的记忆结构存在

	Args:
		ai_id: AI ID
	"""
	if not _memories_by_ai.has(ai_id):
		_memories_by_ai[ai_id] = {
			"short_term": [],
			"long_term": [],
			"core": []
		}

func _add_to_short_term(memory: Memory):
	"""添加到短期记忆

	Args:
		memory: Memory对象
	"""
	_ensure_ai_memory_structure(memory.ai_id)
	var short_term = _memories_by_ai[memory.ai_id]["short_term"]
	short_term.append(memory)

	# 检查是否超出容量
	if short_term.size() > SHORT_TERM_MAX:
		# 按重要性+时间排序,移除最不重要的
		var sorted_st = short_term.duplicate()
		sorted_st.sort_custom(func(a, b):
			if a.importance != b.importance:
				return a.importance > b.importance
			return a.timestamp > b.timestamp
		)

		# 保留前SHORT_TERM_MAX条
		_memories_by_ai[memory.ai_id]["short_term"] = sorted_st.slice(0, SHORT_TERM_MAX)

func _get_short_term_memories(ai_id: String) -> Array:
	"""获取短期记忆列表

	Args:
		ai_id: AI ID

	Returns:
		Memory对象数组
	"""
	_ensure_ai_memory_structure(ai_id)
	return _memories_by_ai[ai_id]["short_term"]

func _get_long_term_memories(ai_id: String) -> Array:
	"""获取长期记忆列表

	Args:
		ai_id: AI ID

	Returns:
		Memory对象数组
	"""
	_ensure_ai_memory_structure(ai_id)
	return _memories_by_ai[ai_id]["long_term"]

func _get_current_day() -> int:
	"""获取当前游戏天数

	Returns:
		天数
	"""
	if _time_system and _time_system.has_method("get_total_days"):
		return _time_system.get_total_days()
	return 0

func _get_time_snapshot() -> Dictionary:
	"""获取当前时间快照

	Returns:
		时间字典
	"""
	if _time_system and _time_system.has_method("get_current_time_dict"):
		return _time_system.get_current_time_dict()

	# Fallback
	var fallback = Time.get_datetime_dict_from_system()
	return {
		"year": fallback.year,
		"month": fallback.month,
		"day": fallback.day,
		"hour": fallback.hour,
		"minute": fallback.minute,
		"timestamp": Time.get_unix_time_from_system(),
		"time_string": "%02d:%02d" % [fallback.hour, fallback.minute],
		"date_string": "%04d-%02d-%02d" % [fallback.year, fallback.month, fallback.day],
		"season_name": "未知季节"
	}

func _get_season_name(season: int) -> String:
	"""获取季节名称

	Args:
		season: 季节索引

	Returns:
		季节名称
	"""
	var season_names = ["春季", "夏季", "秋季", "冬季"]
	if season >= 0 and season < season_names.size():
		return season_names[season]
	return "未知季节"

# ========================================
# 事件处理
# ========================================

func _on_relationship_milestone(payload: Dictionary):
	"""处理关系里程碑事件

	当RelationshipManager触发里程碑时,自动创建记忆

	Args:
		payload: 事件数据
	"""
	var ai_id = payload.get("ai_id", "")
	var target_id = payload.get("target_id", "")
	var milestone_id = payload.get("milestone_id", "")
	var milestone_data = payload.get("milestone_data", {})

	if ai_id == "" or milestone_id == "":
		return

	var description = milestone_data.get("description", "")
	if description == "":
		description = "与%s的关系里程碑: %s" % [target_id, milestone_data.get("name", milestone_id)]

	# 创建关系里程碑记忆
	create_memory(
		ai_id,
		"relationship_milestone",
		description,
		[target_id],
		"",
		-1.0,  # 自动计算重要性
		0.6,   # 中高情感强度
		0.5    # 正面情感
	)

func _on_conflict_triggered(conflict_id: String, conflict_data: Dictionary):
	"""处理冲突触发事件

	当ConflictSystem触发冲突时,自动创建冲突记忆

	Args:
		conflict_id: 冲突ID
		conflict_data: 冲突数据
	"""
	var source_id = conflict_data.get("source_id", "")
	var target_id = conflict_data.get("target_id", "")
	var conflict_type = conflict_data.get("conflict_type", "UNKNOWN")
	var severity = conflict_data.get("severity", 1)
	var trigger_event = conflict_data.get("trigger_event", {})
	var reason = trigger_event.get("reason", "未知原因")
	var location = trigger_event.get("location", "")

	if source_id == "" or target_id == "":
		return

	# 创建冲突记忆
	create_conflict_memory(
		source_id,
		target_id,
		conflict_type,
		severity,
		reason,
		location,
		conflict_id
	)

	print("[MemoryManager] 自动创建冲突记忆: %s (ID: %s)" % [conflict_id, conflict_id])

func _on_conflict_resolved(conflict_id: String, conflict_data: Dictionary):
	"""处理冲突解决事件

	当ConflictSystem解决冲突时,自动创建和解记忆

	Args:
		conflict_id: 冲突ID
		conflict_data: 冲突数据
	"""
	var source_id = conflict_data.get("source_id", "")
	var target_id = conflict_data.get("target_id", "")
	var resolution = conflict_data.get("resolution", {})
	var resolution_type = resolution.get("type", "NONE")
	var resolution_reason = resolution.get("reason", "冲突已解决")
	var location = conflict_data.get("trigger_event", {}).get("location", "")

	if source_id == "" or target_id == "":
		return

	# 只有成功和解才创建和解记忆(排除强制解决)
	if resolution_type != "NONE" and resolution_type != "FORCED":
		create_reconciliation_memory(
			source_id,
			target_id,
			resolution_type,
			resolution_reason,
			location,
			conflict_id
		)

		print("[MemoryManager] 自动创建和解记忆: %s (方式: %s)" % [conflict_id, resolution_type])

func _on_mediation_completed(conflict_id: String, mediator_id: String, success: bool):
	"""处理调解完成事件

	当调解完成时,为调解者创建调解记忆

	Args:
		conflict_id: 冲突ID
		mediator_id: 调解者ID
		success: 是否调解成功
	"""
	if mediator_id == "":
		return

	# 获取冲突系统引用
	var conflict_system = get_node_or_null("/root/ConflictSystem")
	if not conflict_system:
		return

	# 获取冲突详情
	var conflict = conflict_system.get_conflict(conflict_id)
	if conflict.is_empty():
		return

	var source_id = conflict.get("source_id", "")
	var target_id = conflict.get("target_id", "")
	var conflict_type = conflict.get("conflict_type", "UNKNOWN")

	# 构建调解记忆描述
	var description = ""
	if success:
		description = "成功调解了%s和%s之间的%s冲突 (ID: %s)" % [source_id, target_id, conflict_type, conflict_id]
	else:
		description = "尝试调解%s和%s之间的%s冲突,但未成功 (ID: %s)" % [source_id, target_id, conflict_type, conflict_id]

	# 为调解者创建工作记忆
	create_memory(
		mediator_id,
		"work_achievement",  # 使用工作成就类型
		description,
		[source_id, target_id],  # 参与者包括冲突双方
		"",
		-1.0,  # 自动计算重要性
		0.6 if success else 0.4,  # 成功调解情感强度更高
		0.7 if success else -0.2   # 成功是正面情感,失败略负面
	)

	print("[MemoryManager] 创建调解记忆: %s (调解者: %s, 成功: %s)" % [conflict_id, mediator_id, success])

# ========================================
# 向后兼容API (旧版本)
# ========================================

func get_character_memories(character: Node) -> Array:
	"""获取角色的所有记忆 (旧API,兼容)

	Args:
		character: 角色节点

	Returns:
		字典数组(旧格式)
	"""
	if not character:
		return []

	var ai_id = character.get_meta("ai_id", character.name)
	var short_term = _get_short_term_memories(ai_id)
	var long_term = _get_long_term_memories(ai_id)
	var all_memories = short_term + long_term

	# 转换为旧格式
	var old_format = []
	for memory in all_memories:
		old_format.append({
			"content": memory.description,
			"timestamp": _format_game_time(memory.game_time),
			"type": _convert_type_to_old_enum(memory.memory_type),
			"importance": _convert_importance_to_old_enum(memory.importance),
			"created_at": memory.timestamp
		})

	return old_format

func add_memory(
	character: Node,
	memory_content: String,
	memory_type: MemoryType = MemoryType.PERSONAL,
	importance: MemoryImportance = MemoryImportance.NORMAL
) -> void:
	"""添加记忆到角色 (旧API,兼容)

	Args:
		character: 角色节点
		memory_content: 记忆内容
		memory_type: 记忆类型(旧枚举)
		importance: 重要性(旧枚举)
	"""
	if not character or memory_content.strip_edges().is_empty():
		return

	var ai_id = character.get_meta("ai_id", character.name)
	var new_type = _convert_old_enum_to_type(memory_type)
	var new_importance = _convert_old_enum_to_importance(importance)

	# 调用新API
	create_memory(
		ai_id,
		new_type,
		memory_content,
		[],  # 默认无参与者
		"",  # 默认无地点
		new_importance,
		0.0,  # 默认无情感
		0.0
	)

func get_formatted_memories_for_prompt(character: Node, max_count: int = -1) -> String:
	"""获取格式化的记忆文本 (旧API,兼容)

	Args:
		character: 角色节点
		max_count: 最大数量(-1为不限制)

	Returns:
		格式化的记忆字符串
	"""
	if not character:
		return "\n\n记忆信息:\n- 暂无重要记忆"

	var ai_id = character.get_meta("ai_id", character.name)
	var context = build_llm_context(ai_id, "conversation", 1000 if max_count == -1 else max_count * 50)

	if context.strip_edges() == "### 相关记忆 ###\n暂无记忆":
		return "\n\n记忆信息:\n- 暂无重要记忆"

	return context.replace("### 相关记忆 ###", "记忆信息:")

func get_recent_memories(character: Node, hours: int = 24) -> Array:
	"""获取最近的记忆 (旧API,兼容,参数不同)

	Args:
		character: 角色节点
		hours: 小时数(新版本使用天数,这里转换)

	Returns:
		字典数组(旧格式)
	"""
	if not character:
		return []

	var ai_id = character.get_meta("ai_id", character.name)
	var days = max(1, hours / 24)
	var memories = get_recent_memories(ai_id, days * 10)  # 每天约10条记忆

	# 转换为旧格式
	var old_format = []
	for memory in memories:
		old_format.append({
			"content": memory.description,
			"timestamp": _format_game_time(memory.game_time),
			"type": _convert_type_to_old_enum(memory.memory_type),
			"importance": _convert_importance_to_old_enum(memory.importance),
			"created_at": memory.timestamp
		})

	return old_format

func search_memories(character: Node, keywords: Array) -> Array:
	"""搜索相关记忆 (旧API,兼容)

	Args:
		character: 角色节点
		keywords: 关键词列表

	Returns:
		字典数组(旧格式)
	"""
	if not character:
		return []

	var ai_id = character.get_meta("ai_id", character.name)
	var all_memories = _get_short_term_memories(ai_id) + _get_long_term_memories(ai_id)
	var relevant = []

	for memory in all_memories:
		var text = (memory.description + " " + memory.llm_summary).to_lower()
		for keyword in keywords:
			if text.contains(keyword.to_lower()):
				relevant.append({
					"content": memory.description,
					"timestamp": _format_game_time(memory.game_time),
					"type": _convert_type_to_old_enum(memory.memory_type),
					"importance": _convert_importance_to_old_enum(memory.importance),
					"created_at": memory.timestamp
				})
				break

	return relevant

# ========================================
# 类型转换 (新旧兼容)
# ========================================

func _convert_old_enum_to_type(old_type: MemoryType) -> String:
	"""旧枚举转新类型字符串

	Args:
		old_type: 旧枚举值

	Returns:
		新类型字符串
	"""
	match old_type:
		MemoryType.PERSONAL:
			return "conversation"
		MemoryType.INTERACTION:
			return "conversation"
		MemoryType.TASK:
			return "coworker_interaction"
		MemoryType.EMOTION:
			return "peak_happiness"
		MemoryType.EVENT:
			return "achievement"
		_:
			return "conversation"

func _convert_type_to_old_enum(new_type: String) -> int:
	"""新类型字符串转旧枚举

	Args:
		new_type: 新类型字符串

	Returns:
		旧枚举值
	"""
	var category = MEMORY_TYPES.get(new_type, {}).get("category", "")
	match category:
		"social":
			return MemoryType.INTERACTION
		"work":
			return MemoryType.TASK
		"emotion":
			return MemoryType.EMOTION
		"life":
			return MemoryType.EVENT
		_:
			return MemoryType.PERSONAL

func _convert_old_enum_to_importance(old_importance: MemoryImportance) -> float:
	"""旧重要性枚举转新float值

	Args:
		old_importance: 旧枚举值

	Returns:
		新重要性值 0.0-1.0
	"""
	match old_importance:
		MemoryImportance.LOW:
			return 0.3
		MemoryImportance.NORMAL:
			return 0.5
		MemoryImportance.HIGH:
			return 0.7
		MemoryImportance.CRITICAL:
			return 1.0
		_:
			return 0.5

func _convert_importance_to_old_enum(new_importance: float) -> int:
	"""新重要性float值转旧枚举

	Args:
		new_importance: 新重要性值 0.0-1.0

	Returns:
		旧枚举值
	"""
	if new_importance >= 0.9:
		return MemoryImportance.CRITICAL
	elif new_importance >= 0.6:
		return MemoryImportance.HIGH
	elif new_importance >= 0.4:
		return MemoryImportance.NORMAL
	else:
		return MemoryImportance.LOW

# ========================================
# 保存/加载
# ========================================

func save_state() -> Dictionary:
	"""保存记忆系统状态

	Returns:
		状态字典
	"""
	var state = {
		"version": 2.0,  # 版本号
		"memories_by_ai": {}
	}

	# 转换所有Memory对象为字典
	for ai_id in _memories_by_ai.keys():
		state.memories_by_ai[ai_id] = {
			"short_term": [],
			"long_term": [],
			"core": []
		}

		for memory in _memories_by_ai[ai_id]["short_term"]:
			state.memories_by_ai[ai_id]["short_term"].append(memory.to_dict())

		for memory in _memories_by_ai[ai_id]["long_term"]:
			state.memories_by_ai[ai_id]["long_term"].append(memory.to_dict())

		for memory in _memories_by_ai[ai_id]["core"]:
			state.memories_by_ai[ai_id]["core"].append(memory.to_dict())

	print("[MemoryManager] 保存状态: %d个AI的记忆数据" % _memories_by_ai.size())
	return state

func load_state(state: Dictionary):
	"""加载记忆系统状态

	Args:
		state: 状态字典
	"""
	var version = state.get("version", 1.0)

	if version < 2.0:
		push_warning("[MemoryManager] 加载旧版本数据(v%.1f),可能需要迁移" % version)

	_memories_by_ai.clear()

	var memories_data = state.get("memories_by_ai", {})
	for ai_id in memories_data.keys():
		_ensure_ai_memory_structure(ai_id)

		# 加载短期记忆
		for mem_dict in memories_data[ai_id].get("short_term", []):
			var memory = Memory.new()
			memory.from_dict(mem_dict)
			_memories_by_ai[ai_id]["short_term"].append(memory)

		# 加载长期记忆
		for mem_dict in memories_data[ai_id].get("long_term", []):
			var memory = Memory.new()
			memory.from_dict(mem_dict)
			_memories_by_ai[ai_id]["long_term"].append(memory)

		# 加载核心记忆
		for mem_dict in memories_data[ai_id].get("core", []):
			var memory = Memory.new()
			memory.from_dict(mem_dict)
			_memories_by_ai[ai_id]["core"].append(memory)

	print("[MemoryManager] 加载状态完成: %d个AI的记忆数据" % _memories_by_ai.size())

# ========================================
# ConflictSystem集成API
# ========================================

func create_conflict_memory(
	ai_id: String,
	other_ai_id: String,
	conflict_type: String,
	severity: int,
	reason: String,
	location: String = "",
	conflict_id: String = ""
) -> Memory:
	"""创建冲突记忆

	Args:
		ai_id: 发起者AI ID
		other_ai_id: 冲突对象AI ID
		conflict_type: 冲突类型(INTEREST/VALUES/PERSONALITY等)
		severity: 严重程度(1-9)
		reason: 冲突原因
		location: 发生地点
		conflict_id: 冲突ID(可选)

	Returns:
		创建的Memory对象
	"""
	# 构建描述
	var description = "与%s发生了%s冲突: %s" % [other_ai_id, conflict_type, reason]
	if conflict_id:
		description += " (ID: %s)" % conflict_id

	# 计算情感参数
	var emotional_intensity = clamp(severity / 9.0, 0.3, 1.0)  # 严重程度越高,情感强度越大
	var emotional_valence = -clamp(severity / 9.0, 0.5, 1.0)   # 冲突总是负面情感

	# 创建记忆
	var memory = create_memory(
		ai_id,
		"conflict",
		description,
		[other_ai_id],  # 参与者
		location,
		-1.0,  # 自动计算重要性
		emotional_intensity,
		emotional_valence
	)

	# 同时为对方创建记忆(从对方视角)
	var other_description = "与%s发生了%s冲突: %s" % [ai_id, conflict_type, reason]
	if conflict_id:
		other_description += " (ID: %s)" % conflict_id

	create_memory(
		other_ai_id,
		"conflict",
		other_description,
		[ai_id],
		location,
		-1.0,
		emotional_intensity,
		emotional_valence
	)

	print("[MemoryManager] 创建冲突记忆: %s <-> %s (严重程度: %d)" % [ai_id, other_ai_id, severity])

	return memory

func create_reconciliation_memory(
	ai_id: String,
	other_ai_id: String,
	resolution_type: String,
	reason: String,
	location: String = "",
	conflict_id: String = ""
) -> Memory:
	"""创建和解记忆

	Args:
		ai_id: AI ID
		other_ai_id: 和解对象AI ID
		resolution_type: 和解方式(MEDIATION/COMPROMISE/APOLOGY等)
		reason: 和解原因/方式描述
		location: 发生地点
		conflict_id: 相关冲突ID(可选)

	Returns:
		创建的Memory对象
	"""
	# 构建描述
	var description = "与%s通过%s方式和解: %s" % [other_ai_id, resolution_type, reason]
	if conflict_id:
		description += " (冲突ID: %s)" % conflict_id

	# 和解是正面情感
	var emotional_intensity = 0.7
	var emotional_valence = 0.8

	# 创建记忆
	var memory = create_memory(
		ai_id,
		"reconciliation",
		description,
		[other_ai_id],
		location,
		-1.0,  # 自动计算重要性
		emotional_intensity,
		emotional_valence
	)

	# 同时为对方创建记忆
	var other_description = "与%s通过%s方式和解: %s" % [ai_id, resolution_type, reason]
	if conflict_id:
		other_description += " (冲突ID: %s)" % conflict_id

	create_memory(
		other_ai_id,
		"reconciliation",
		other_description,
		[ai_id],
		location,
		-1.0,
		emotional_intensity,
		emotional_valence
	)

	print("[MemoryManager] 创建和解记忆: %s <-> %s (方式: %s)" % [ai_id, other_ai_id, resolution_type])

	return memory

func create_relationship_milestone_memory(
	ai_id: String,
	other_ai_id: String,
	milestone_type: String,
	description: String,
	location: String = ""
) -> Memory:
	"""创建关系里程碑记忆

	Args:
		ai_id: AI ID
		other_ai_id: 关系对象AI ID
		milestone_type: 里程碑类型(first_meeting/became_friends/became_enemies等)
		description: 里程碑描述
		location: 发生地点

	Returns:
		创建的Memory对象
	"""
	# 根据里程碑类型确定情感参数
	var emotional_params = _get_milestone_emotional_params(milestone_type)

	# 创建记忆
	var memory = create_memory(
		ai_id,
		milestone_type,
		description,
		[other_ai_id],
		location,
		-1.0,  # 自动计算重要性
		emotional_params.intensity,
		emotional_params.valence
	)

	# 同时为对方创建记忆
	create_memory(
		other_ai_id,
		milestone_type,
		description.replace(other_ai_id, ai_id).replace(ai_id, other_ai_id),  # 简单替换视角
		[ai_id],
		location,
		-1.0,
		emotional_params.intensity,
		emotional_params.valence
	)

	print("[MemoryManager] 创建关系里程碑记忆: %s <-> %s (%s)" % [ai_id, other_ai_id, milestone_type])

	return memory

func get_conflict_memories(ai_id: String, other_ai_id: String = "", limit: int = 10) -> Array:
	"""获取冲突相关记忆

	Args:
		ai_id: AI ID
		other_ai_id: 可选,指定对象AI ID则只返回与该AI的冲突
		limit: 返回数量限制

	Returns:
		Memory对象数组,按时间倒序
	"""
	var all_memories = []
	all_memories.append_array(_get_short_term_memories(ai_id))
	all_memories.append_array(_get_long_term_memories(ai_id))

	# 筛选冲突记忆
	var conflict_memories = []
	for memory in all_memories:
		if memory.memory_type == "conflict":
			# 如果指定了对象,只返回与该对象的冲突
			if other_ai_id.is_empty() or other_ai_id in memory.participants:
				conflict_memories.append(memory)

	# 按时间倒序排序
	conflict_memories.sort_custom(func(a, b): return a.timestamp > b.timestamp)

	# 限制数量
	if conflict_memories.size() > limit:
		conflict_memories.resize(limit)

	return conflict_memories

func get_reconciliation_memories(ai_id: String, other_ai_id: String = "", limit: int = 10) -> Array:
	"""获取和解相关记忆

	Args:
		ai_id: AI ID
		other_ai_id: 可选,指定对象AI ID
		limit: 返回数量限制

	Returns:
		Memory对象数组,按时间倒序
	"""
	var all_memories = []
	all_memories.append_array(_get_short_term_memories(ai_id))
	all_memories.append_array(_get_long_term_memories(ai_id))

	# 筛选和解记忆
	var reconciliation_memories = []
	for memory in all_memories:
		if memory.memory_type == "reconciliation":
			if other_ai_id.is_empty() or other_ai_id in memory.participants:
				reconciliation_memories.append(memory)

	# 按时间倒序排序
	reconciliation_memories.sort_custom(func(a, b): return a.timestamp > b.timestamp)

	# 限制数量
	if reconciliation_memories.size() > limit:
		reconciliation_memories.resize(limit)

	return reconciliation_memories

func get_relationship_history(ai_id: String, other_ai_id: String, limit: int = 20) -> Array:
	"""获取与特定AI的完整关系历史

	包括: 初次见面/成为朋友/冲突/和解/成为敌人等所有社交记忆

	Args:
		ai_id: AI ID
		other_ai_id: 关系对象AI ID
		limit: 返回数量限制

	Returns:
		Memory对象数组,按时间正序(最早到最新)
	"""
	var all_memories = []
	all_memories.append_array(_get_short_term_memories(ai_id))
	all_memories.append_array(_get_long_term_memories(ai_id))
	all_memories.append_array(_get_core_memories(ai_id))

	# 筛选与该AI相关的社交记忆
	var relationship_memories = []
	var social_types = ["conversation", "gift_received", "gift_given", "conflict",
	                     "reconciliation", "confession", "breakup",
	                     "first_meeting", "became_friends", "became_close_friends",
	                     "became_couple", "marriage", "became_enemies"]

	for memory in all_memories:
		if memory.memory_type in social_types and other_ai_id in memory.participants:
			relationship_memories.append(memory)

	# 按时间正序排序(最早到最新)
	relationship_memories.sort_custom(func(a, b): return a.timestamp < b.timestamp)

	# 限制数量(保留最新的)
	if relationship_memories.size() > limit:
		var start_index = relationship_memories.size() - limit
		relationship_memories = relationship_memories.slice(start_index)

	return relationship_memories

func _get_milestone_emotional_params(milestone_type: String) -> Dictionary:
	"""获取里程碑类型对应的情感参数

	Args:
		milestone_type: 里程碑类型

	Returns:
		{intensity: float, valence: float}
	"""
	var params_map = {
		"first_meeting": {"intensity": 0.5, "valence": 0.3},
		"became_friends": {"intensity": 0.7, "valence": 0.7},
		"became_close_friends": {"intensity": 0.8, "valence": 0.8},
		"became_couple": {"intensity": 1.0, "valence": 1.0},
		"marriage": {"intensity": 1.0, "valence": 1.0},
		"became_enemies": {"intensity": 0.9, "valence": -0.9},
		"relationship_milestone": {"intensity": 0.6, "valence": 0.5}
	}

	return params_map.get(milestone_type, {"intensity": 0.5, "valence": 0.0})
