class_name DepthAnalyzer
extends RefCounted

# 讨论深度分析器
# 评估对话是否真正深入,避免浅层重复

# 深度评估标准
const MIN_DEPTH_SCORE := 0.6  # 最低深度分数
const MIN_CONCEPT_LAYERS := 2  # 最少概念层次
const MIN_INTERACTIONS := 3  # 最少批判性互动次数

# 关键词权重表
const DEPTH_KEYWORDS := {
	# 深层思考标志
	"本质": 1.5,
	"原理": 1.5,
	"为什么": 1.3,
	"假设": 1.3,
	"前提": 1.3,
	"推导": 1.4,
	"证明": 1.4,
	"形式化": 1.5,
	"公理": 1.5,
	"数学": 1.3,
	"模型": 1.3,
	"抽象": 1.4,

	# 批判性思维
	"但是": 1.2,
	"然而": 1.2,
	"矛盾": 1.4,
	"反例": 1.5,
	"错误": 1.3,
	"漏洞": 1.3,
	"边界": 1.3,
	"局限": 1.3,
	"特例": 1.3,

	# 类比和例证
	"类比": 1.2,
	"比如": 1.1,
	"例子": 1.1,
	"实际": 1.2,
	"应用": 1.2,

	# 浅层标志(负分)
	"就是": -0.5,
	"差不多": -0.8,
	"大概": -0.6,
	"可能": -0.3,
	"我觉得": -0.4,
}

# 批判性互动短语
const CRITICAL_PHRASES := [
	"你说的", "这里有问题", "不对", "不准确", "不完全正确",
	"忽略了", "没考虑", "应该", "更准确", "补充一下",
	"纠正", "修正", "实际上", "事实上"
]

# 概念层次关键词
const LAYER_KEYWORDS := [
	["现象", "表面", "看起来", "似乎"],  # 层次1: 表面现象
	["原因", "机制", "过程", "如何"],     # 层次2: 机制过程
	["本质", "原理", "为什么", "根源"],   # 层次3: 本质原理
	["公理", "基础", "假设", "前提"]      # 层次4: 基础假设
]

# 评估对话历史的深度
static func assess_depth(history: Array) -> Dictionary:
	if history.size() < 3:
		return {
			"score": 0.0,
			"concept_layers": 0,
			"critical_interactions": 0,
			"suggestions": ["讨论刚开始,需要更多轮次"]
		}

	var depth_score := 0.0
	var concept_layers := 0
	var critical_count := 0
	var suggestions := []

	# 1. 关键词深度分析
	var keyword_score := _analyze_keywords(history)
	depth_score += keyword_score * 0.4

	# 2. 概念层次检测
	concept_layers = _detect_concept_layers(history)
	depth_score += (concept_layers / 4.0) * 0.3

	# 3. 批判性互动检测
	critical_count = _detect_critical_interactions(history)
	depth_score += min(critical_count / 5.0, 1.0) * 0.3

	# 4. 生成建议
	if concept_layers < MIN_CONCEPT_LAYERS:
		suggestions.append("讨论还停留在表面,需要深入探讨'为什么'和'本质原理'")

	if critical_count < MIN_INTERACTIONS:
		suggestions.append("缺少批判性互动,需要更多质疑、反例和纠正")

	if keyword_score < 0.5:
		suggestions.append("讨论过于模糊,需要更严格的定义和论证")

	var has_examples := _has_sufficient_examples(history)
	if not has_examples:
		suggestions.append("缺少具体例子和类比,建议增加实际应用场景")

	return {
		"score": clamp(depth_score, 0.0, 1.0),
		"concept_layers": concept_layers,
		"critical_interactions": critical_count,
		"suggestions": suggestions,
		"is_deep_enough": depth_score >= MIN_DEPTH_SCORE and concept_layers >= MIN_CONCEPT_LAYERS
	}

# 分析关键词深度
static func _analyze_keywords(history: Array) -> float:
	var total_score := 0.0
	var word_count := 0

	for msg in history:
		if msg.role != "assistant":
			continue
		var text: String = msg.text
		word_count += text.length()

		for keyword in DEPTH_KEYWORDS:
			if text.find(keyword) != -1:
				total_score += DEPTH_KEYWORDS[keyword]

	if word_count == 0:
		return 0.0

	# 归一化到0-1
	return clamp(total_score / (word_count / 100.0), 0.0, 1.0)

# 检测概念层次
static func _detect_concept_layers(history: Array) -> int:
	var layers_found := {}

	for msg in history:
		if msg.role != "assistant":
			continue
		var text: String = msg.text.to_lower()

		for layer_idx in range(LAYER_KEYWORDS.size()):
			for keyword in LAYER_KEYWORDS[layer_idx]:
				if text.find(keyword) != -1:
					layers_found[layer_idx] = true
					break

	return layers_found.size()

# 检测批判性互动
static func _detect_critical_interactions(history: Array) -> int:
	var count := 0

	for msg in history:
		if msg.role != "assistant":
			continue
		var text: String = msg.text

		for phrase in CRITICAL_PHRASES:
			if text.find(phrase) != -1:
				count += 1
				break

	return count

# 检测是否有足够的例子
static func _has_sufficient_examples(history: Array) -> bool:
	var example_count := 0

	for msg in history:
		if msg.role != "assistant":
			continue
		var text: String = msg.text

		if text.find("比如") != -1 or text.find("例如") != -1 or text.find("举例") != -1:
			example_count += 1
		if text.find("类比") != -1 or text.find("就像") != -1:
			example_count += 1

	return example_count >= 2

# 生成深度报告(用于终端显示)
static func generate_report(depth_data: Dictionary) -> String:
	var report := "[深度分析]\n"
	report += "深度分数: %.1f%% (>60%%为合格)\n" % (depth_data.score * 100)
	report += "概念层次: %d层 (需≥%d层)\n" % [depth_data.concept_layers, MIN_CONCEPT_LAYERS]
	report += "批判互动: %d次 (需≥%d次)\n" % [depth_data.critical_interactions, MIN_INTERACTIONS]

	if depth_data.is_deep_enough:
		report += "✓ 讨论深度充分\n"
	else:
		report += "✗ 讨论深度不足\n"
		if depth_data.suggestions.size() > 0:
			report += "\n改进建议:\n"
			for s in depth_data.suggestions:
				report += "• %s\n" % s

	return report
