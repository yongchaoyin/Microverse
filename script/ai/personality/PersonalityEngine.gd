# script/ai/personality/PersonalityEngine.gd
# 性格引擎 - 基于Big Five人格模型的AI性格系统
# 职责:
#   1. 管理AI的Big Five性格数据
#   2. 计算性格对各系统的影响(社交/工作/经济/健康)
#   3. 计算两个AI之间的性格契合度
#   4. 生成性格标签和描述文本
#   5. 为LLM提供性格上下文
extends Node

# ==================== 常量定义 ====================

# Big Five维度名称
const BIG_FIVE_DIMENSIONS = ["extraversion", "agreeableness", "conscientiousness", "neuroticism", "openness"]
const BIG_FIVE_CN = {
	"extraversion": "外向性",
	"agreeableness": "宜人性",
	"conscientiousness": "尽责性",
	"neuroticism": "神经质",
	"openness": "开放性"
}

# 性格等级阈值
const PERSONALITY_LEVELS = {
	"very_low": {"min": 0, "max": 20},
	"low": {"min": 21, "max": 40},
	"moderate": {"min": 41, "max": 60},
	"high": {"min": 61, "max": 80},
	"very_high": {"min": 81, "max": 100}
}

# 性格标签模板
const PERSONALITY_TAGS = {
	"extraversion": {
		"very_low": ["极度内向", "独来独往", "避免社交"],
		"low": ["内向", "安静", "谨慎"],
		"moderate": ["适度社交", "灵活应对"],
		"high": ["外向", "健谈", "主动"],
		"very_high": ["极度外向", "社交达人", "聚会动物"]
	},
	"agreeableness": {
		"very_low": ["难以相处", "自我中心", "好斗"],
		"low": ["直率", "不随和", "竞争性强"],
		"moderate": ["有选择的友善", "实用主义"],
		"high": ["友善", "乐于助人", "合作"],
		"very_high": ["极度友善", "讨好他人", "牺牲自我"]
	},
	"conscientiousness": {
		"very_low": ["极度随性", "无计划", "冲动"],
		"low": ["随性", "灵活", "自发"],
		"moderate": ["基本规划", "平衡"],
		"high": ["尽责", "有序", "守时"],
		"very_high": ["完美主义", "过度自律", "工作狂"]
	},
	"neuroticism": {
		"very_low": ["极度稳定", "冷静", "压力不敏感"],
		"low": ["稳定", "淡定", "乐观"],
		"moderate": ["正常波动", "适应力强"],
		"high": ["敏感", "焦虑", "情绪化"],
		"very_high": ["极度焦虑", "脆弱", "神经质"]
	},
	"openness": {
		"very_low": ["极度保守", "固执", "拒绝改变"],
		"low": ["传统", "实际", "常规"],
		"moderate": ["开放与保守兼具", "务实"],
		"high": ["好奇", "创造性", "开放"],
		"very_high": ["极度创新", "理想主义", "先锋"]
	}
}

# 性格影响权重配置
const INFLUENCE_WEIGHTS = {
	# 社交系统影响
	"social_frequency": {
		"extraversion": 2.0,      # 外向性主导社交频率
		"agreeableness": 0.5,
		"openness": 0.3
	},
	# 冲突概率
	"conflict_probability": {
		"agreeableness": -1.5,    # 宜人性降低冲突(负权重)
		"neuroticism": 0.8,
		"extraversion": 0.2
	},
	# 加班概率
	"overtime_probability": {
		"conscientiousness": 1.8,  # 尽责性主导加班
		"neuroticism": -0.3,
		"agreeableness": 0.2
	},
	# 储蓄率
	"savings_rate": {
		"conscientiousness": 1.5,
		"neuroticism": 0.5,
		"openness": -0.3
	},
	# 生病概率
	"illness_probability": {
		"neuroticism": 1.5,        # 神经质增加生病
		"conscientiousness": -0.5,
		"extraversion": -0.2
	},
	# 送礼概率
	"gift_giving": {
		"agreeableness": 1.8,
		"extraversion": 0.5,
		"openness": 0.3
	},
	# 创新概率
	"innovation": {
		"openness": 2.0,
		"conscientiousness": -0.3,
		"neuroticism": -0.2
	}
}

# ==================== 私有变量 ====================

# 性格数据缓存: {ai_id: {dimension: value}}
var _personalities: Dictionary = {}

# 契合度缓存: {ai_id_1 + "_" + ai_id_2: compatibility_value}
var _compatibility_cache: Dictionary = {}

# ==================== 生命周期方法 ====================

func _ready():
	print("[PersonalityEngine] 🧠 性格引擎初始化完成")
	print("[PersonalityEngine] 📊 支持Big Five人格模型")

# ==================== 性格数据管理 ====================

## 注册AI的性格数据
## @param ai_id: AI唯一ID
## @param personality: Big Five性格字典 {extraversion, agreeableness, conscientiousness, neuroticism, openness}
func register_personality(ai_id: String, personality: Dictionary) -> void:
	# 验证性格数据
	if not _validate_personality(personality):
		push_error("[PersonalityEngine] ❌ 无效的性格数据: %s" % ai_id)
		return

	_personalities[ai_id] = personality.duplicate()
	_clear_compatibility_cache(ai_id)

	if ConfigManager.get_node("/root/DebugConsole"):
		print("[PersonalityEngine] ✅ 注册性格: %s - %s" % [ai_id, _get_personality_summary(personality)])

## 获取AI的性格数据
## @param ai_id: AI唯一ID
## @return: 性格数据字典
func get_personality(ai_id: String) -> Dictionary:
	return _personalities.get(ai_id, {})

## 获取性格维度值
## @param ai_id: AI唯一ID
## @param dimension: 维度名称
## @return: 维度值(0-100), 不存在返回50(中性)
func get_dimension(ai_id: String, dimension: String) -> int:
	var personality = get_personality(ai_id)
	return personality.get(dimension, 50)

## 验证性格数据
func _validate_personality(personality: Dictionary) -> bool:
	for dimension in BIG_FIVE_DIMENSIONS:
		if not personality.has(dimension):
			return false
		var value = personality[dimension]
		if not (value >= 0 and value <= 100):
			return false
	return true

## 生成随机性格
## @return: 随机生成的Big Five性格字典
func generate_random_personality() -> Dictionary:
	var personality = {}
	for dimension in BIG_FIVE_DIMENSIONS:
		# 使用正态分布,均值50,标准差20
		personality[dimension] = int(clamp(randfn(50, 20), 0, 100))
	return personality

## 从模板创建性格
## @param template_name: 模板名称
## @return: 性格字典
func create_from_template(template_name: String) -> Dictionary:
	var template = ConfigManager.get_personality_template(template_name)
	if template.has("big_five"):
		return template["big_five"].duplicate()
	return generate_random_personality()

# ==================== 性格影响计算 ====================

## 计算社交频率倍率
## @param ai_id: AI唯一ID
## @return: 倍率值(0.0-3.0)
func calculate_social_frequency_multiplier(ai_id: String) -> float:
	return _calculate_influence(ai_id, "social_frequency", 1.0)

## 计算冲突概率
## @param ai_id: AI唯一ID
## @return: 概率值(0.0-1.0)
func calculate_conflict_probability(ai_id: String) -> float:
	var base_prob = 0.2  # 基础冲突概率20%
	var multiplier = _calculate_influence(ai_id, "conflict_probability", 1.0)
	return clamp(base_prob * multiplier, 0.0, 1.0)

## 计算加班概率
## @param ai_id: AI唯一ID
## @return: 概率值(0.0-1.0)
func calculate_overtime_probability(ai_id: String) -> float:
	var base_prob = 0.3  # 基础加班概率30%
	var multiplier = _calculate_influence(ai_id, "overtime_probability", 1.0)
	return clamp(base_prob * multiplier, 0.0, 1.0)

## 计算储蓄率
## @param ai_id: AI唯一ID
## @return: 储蓄率(0.0-0.7)
func calculate_savings_rate(ai_id: String) -> float:
	var base_rate = 0.2  # 基础储蓄率20%
	var multiplier = _calculate_influence(ai_id, "savings_rate", 1.0)
	return clamp(base_rate * multiplier, 0.0, 0.7)

## 计算生病概率
## @param ai_id: AI唯一ID
## @return: 周生病概率(0.0-0.15)
func calculate_illness_probability(ai_id: String) -> float:
	var base_prob = 0.02  # 基础生病概率2%/周
	var multiplier = _calculate_influence(ai_id, "illness_probability", 1.0)
	return clamp(base_prob * multiplier, 0.0, 0.15)

## 计算送礼概率
## @param ai_id: AI唯一ID
## @return: 概率值(0.0-1.0)
func calculate_gift_giving_probability(ai_id: String) -> float:
	var base_prob = 0.1  # 基础送礼概率10%
	var multiplier = _calculate_influence(ai_id, "gift_giving", 1.0)
	return clamp(base_prob * multiplier, 0.0, 1.0)

## 计算创新倾向
## @param ai_id: AI唯一ID
## @return: 倍率值(0.0-3.0)
func calculate_innovation_tendency(ai_id: String) -> float:
	return _calculate_influence(ai_id, "innovation", 1.0)

## 通用影响计算
## @param ai_id: AI唯一ID
## @param influence_type: 影响类型
## @param base_value: 基础值
## @return: 影响后的值
func _calculate_influence(ai_id: String, influence_type: String, base_value: float) -> float:
	var personality = get_personality(ai_id)
	if personality.is_empty():
		return base_value

	var weights = INFLUENCE_WEIGHTS.get(influence_type, {})
	var influence = 0.0

	for dimension in weights.keys():
		var weight = weights[dimension]
		var value = personality.get(dimension, 50)
		# 将0-100映射到-1到1,然后应用权重
		var normalized = (value - 50) / 50.0
		influence += normalized * weight

	# 将影响值转换为倍率
	var multiplier = 1.0 + influence
	return max(0.0, multiplier)

# ==================== 性格契合度计算 ====================

## 计算两个AI的性格契合度
## @param ai_id_1: 第一个AI的ID
## @param ai_id_2: 第二个AI的ID
## @return: 契合度值(-100到100), 0为中性,正值为契合,负值为不契合
func calculate_compatibility(ai_id_1: String, ai_id_2: String) -> float:
	# 检查缓存
	var cache_key = _get_cache_key(ai_id_1, ai_id_2)
	if _compatibility_cache.has(cache_key):
		return _compatibility_cache[cache_key]

	var personality_1 = get_personality(ai_id_1)
	var personality_2 = get_personality(ai_id_2)

	if personality_1.is_empty() or personality_2.is_empty():
		return 0.0

	# Big Five契合度算法(基于心理学研究)
	var compatibility = 0.0

	# 1. 外向性: 相似性原则(相似的人更契合)
	var e_diff = abs(personality_1.extraversion - personality_2.extraversion)
	compatibility += (100 - e_diff) * 0.15

	# 2. 宜人性: 互补原则(一方高即可)
	var a_sum = personality_1.agreeableness + personality_2.agreeableness
	compatibility += (a_sum / 2.0) * 0.35  # 权重最高

	# 3. 尽责性: 相似性原则
	var c_diff = abs(personality_1.conscientiousness - personality_2.conscientiousness)
	compatibility += (100 - c_diff) * 0.20

	# 4. 神经质: 互补原则(都低最好)
	var n_avg = (personality_1.neuroticism + personality_2.neuroticism) / 2.0
	compatibility += (100 - n_avg) * 0.15

	# 5. 开放性: 相似性原则
	var o_diff = abs(personality_1.openness - personality_2.openness)
	compatibility += (100 - o_diff) * 0.15

	# 归一化到-100到100
	var normalized_compatibility = (compatibility - 50) * 2

	# 缓存结果
	_compatibility_cache[cache_key] = normalized_compatibility

	return normalized_compatibility

## 获取契合度等级描述
## @param compatibility: 契合度值
## @return: 描述字符串
func get_compatibility_level(compatibility: float) -> String:
	if compatibility >= 60:
		return "极度契合"
	elif compatibility >= 30:
		return "很契合"
	elif compatibility >= 10:
		return "较契合"
	elif compatibility >= -10:
		return "中性"
	elif compatibility >= -30:
		return "不太契合"
	elif compatibility >= -60:
		return "不契合"
	else:
		return "极度不契合"

## 获取缓存键
func _get_cache_key(ai_id_1: String, ai_id_2: String) -> String:
	# 确保顺序一致
	if ai_id_1 < ai_id_2:
		return ai_id_1 + "_" + ai_id_2
	else:
		return ai_id_2 + "_" + ai_id_1

## 清除契合度缓存
func _clear_compatibility_cache(ai_id: String) -> void:
	var keys_to_remove = []
	for key in _compatibility_cache.keys():
		if key.contains(ai_id):
			keys_to_remove.append(key)

	for key in keys_to_remove:
		_compatibility_cache.erase(key)

# ==================== 性格标签生成 ====================

## 获取性格标签列表
## @param ai_id: AI唯一ID
## @return: 标签数组
func get_personality_tags(ai_id: String) -> Array:
	var personality = get_personality(ai_id)
	if personality.is_empty():
		return []

	var tags = []

	for dimension in BIG_FIVE_DIMENSIONS:
		var value = personality[dimension]
		var level = _get_level_from_value(value)
		var dimension_tags = PERSONALITY_TAGS[dimension][level]
		tags.append_array(dimension_tags)

	return tags

## 获取性格描述文本(供LLM使用)
## @param ai_id: AI唯一ID
## @return: 描述文本
func get_personality_description(ai_id: String) -> String:
	var personality = get_personality(ai_id)
	if personality.is_empty():
		return "性格数据未定义"

	var descriptions = []

	for dimension in BIG_FIVE_DIMENSIONS:
		var value = personality[dimension]
		var level = _get_level_from_value(value)
		var cn_name = BIG_FIVE_CN[dimension]
		var level_cn = _get_level_description_cn(level)

		descriptions.append("%s: %s (%d)" % [cn_name, level_cn, value])

	return "\n".join(descriptions)

## 获取性格摘要
func _get_personality_summary(personality: Dictionary) -> String:
	var tags = []
	for dimension in BIG_FIVE_DIMENSIONS:
		var value = personality[dimension]
		if value >= 70:
			tags.append("高" + BIG_FIVE_CN[dimension])
		elif value <= 30:
			tags.append("低" + BIG_FIVE_CN[dimension])

	if tags.is_empty():
		return "平衡型性格"
	return ", ".join(tags)

## 从数值获取等级
func _get_level_from_value(value: int) -> String:
	for level in PERSONALITY_LEVELS.keys():
		var range_dict = PERSONALITY_LEVELS[level]
		if value >= range_dict["min"] and value <= range_dict["max"]:
			return level
	return "moderate"

## 获取等级中文描述
func _get_level_description_cn(level: String) -> String:
	match level:
		"very_low": return "极低"
		"low": return "偏低"
		"moderate": return "中等"
		"high": return "偏高"
		"very_high": return "极高"
		_: return "中等"

# ==================== LLM上下文生成 ====================

## 生成性格上下文文本(供LLM Prompt使用)
## @param ai_id: AI唯一ID
## @return: 格式化的性格上下文
func generate_llm_context(ai_id: String) -> String:
	var personality = get_personality(ai_id)
	if personality.is_empty():
		return ""

	var context = "## 性格特征\n"
	context += get_personality_description(ai_id) + "\n\n"

	context += "## 性格标签\n"
	var tags = get_personality_tags(ai_id)
	context += ", ".join(tags) + "\n\n"

	context += "## 行为倾向\n"
	context += "- 社交倾向: %.0f%%\n" % (calculate_social_frequency_multiplier(ai_id) * 100)
	context += "- 冲突倾向: %.0f%%\n" % (calculate_conflict_probability(ai_id) * 100)
	context += "- 加班倾向: %.0f%%\n" % (calculate_overtime_probability(ai_id) * 100)
	context += "- 储蓄倾向: %.0f%%\n" % (calculate_savings_rate(ai_id) * 100)

	return context

## 生成两个AI的关系上下文(供LLM使用)
## @param ai_id_1: 第一个AI的ID
## @param ai_id_2: 第二个AI的ID
## @return: 关系上下文文本
func generate_relationship_context(ai_id_1: String, ai_id_2: String) -> String:
	var compatibility = calculate_compatibility(ai_id_1, ai_id_2)
	var level = get_compatibility_level(compatibility)

	var context = "## 性格契合度\n"
	context += "%s 和 %s: %s (%.1f)\n" % [ai_id_1, ai_id_2, level, compatibility]

	# 详细分析
	var p1 = get_personality(ai_id_1)
	var p2 = get_personality(ai_id_2)

	if not p1.is_empty() and not p2.is_empty():
		context += "\n### 详细对比\n"
		for dimension in BIG_FIVE_DIMENSIONS:
			var diff = abs(p1[dimension] - p2[dimension])
			var similarity = "相似" if diff < 30 else ("有差异" if diff < 60 else "差异很大")
			context += "- %s: %d vs %d (%s)\n" % [BIG_FIVE_CN[dimension], p1[dimension], p2[dimension], similarity]

	return context

# ==================== 调试接口 ====================

## 打印性格统计
func print_personality_stats() -> void:
	print("\n[PersonalityEngine] 📊 性格统计:")
	print("=" * 60)
	print("已注册AI数量: %d" % _personalities.size())
	print("契合度缓存数量: %d" % _compatibility_cache.size())
	print("=" * 60)

## 获取统计信息
func get_stats() -> Dictionary:
	return {
		"registered_personalities": _personalities.size(),
		"compatibility_cache_size": _compatibility_cache.size()
	}

# ==================== 保存/加载 ====================

## 保存性格数据
func save_state() -> Dictionary:
	return {
		"personalities": _personalities.duplicate(true),
		"version": "1.0"
	}

## 加载性格数据
func load_state(state: Dictionary) -> void:
	_personalities = state.get("personalities", {})
	_compatibility_cache.clear()
	print("[PersonalityEngine] ✅ 性格数据已加载: %d个AI" % _personalities.size())
