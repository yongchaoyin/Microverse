# script/project/ProjectDifficultyConfig.gd
extends Node

# Autoload单例: ProjectDifficultyConfig

# ========================================
# 难度模式配置
# ========================================

const DIFFICULTY_MODES = {
	"strict": {
		"name": "严格模式",
		"name_en": "Strict Mode",
		"description": "高风险高回报,项目失败惩罚严重,但成功奖励丰厚",
		"icon": "res://assets/icons/difficulty_strict.png",

		# 奖金系数 (根据完成度和质量)
		"bonus_multipliers": {
			# 完成度: 奖金系数
			1.0: 1.5,   # 完美完成: 150%奖金
			0.9: 1.2,   # 优秀完成: 120%奖金
			0.8: 1.0,   # 良好完成: 100%奖金
			0.7: 0.6,   # 勉强完成: 60%奖金
			0.6: 0.3,   # 不及格: 30%奖金
			0.5: 0.0    # <50%: 无奖金
		},

		# 延期惩罚
		"delay_penalties": {
			0: 1.0,     # 准时: 无惩罚
			7: 0.8,     # 延期1周: -20%
			14: 0.5,    # 延期2周: -50%
			30: 0.2     # 延期1个月: -80%
		},

		# 质量加成
		"quality_bonuses": {
			90: 1.3,    # 质量90+: +30%
			80: 1.1,    # 质量80+: +10%
			70: 1.0,    # 质量70+: 无加成
			60: 0.8     # 质量60-: -20%
		},

		# 关系影响
		"relationship_effects": {
			"perfect": {         # 完美完成
				"boss": 20,      # 与老板关系+20
				"team": 15       # 团队凝聚力+15
			},
			"good": {            # 良好完成
				"boss": 10,
				"team": 8
			},
			"barely": {          # 勉强完成
				"boss": -5,
				"team": -3
			},
			"failed": {          # 失败
				"boss": -30,     # 与老板关系-30
				"team": -20      # 团队凝聚力-20
			}
		},

		# 压力影响
		"stress_effects": {
			"perfect": -20,      # 完美完成: 压力-20
			"good": -10,
			"barely": 10,
			"failed": 40         # 失败: 压力+40
		},

		# 心情影响
		"mood_effects": {
			"perfect": 50,       # 完美完成: 心情+50
			"good": 30,
			"barely": -10,
			"failed": -50        # 失败: 心情-50
		},

		# 其他惩罚
		"extra_penalties": {
			"failed_can_fire": true,  # 失败可能有角色被"辞退"
			"health_impact": true     # 影响健康
		}
	},

	"balanced": {
		"name": "平衡模式",
		"name_en": "Balanced Mode",
		"description": "中等风险,完成有奖励,失败有小惩罚",
		"icon": "res://assets/icons/difficulty_balanced.png",

		"bonus_multipliers": {
			1.0: 1.2,   # 完美完成: 120%奖金
			0.9: 1.1,   # 优秀完成: 110%奖金
			0.8: 1.0,   # 良好完成: 100%奖金
			0.7: 0.7,   # 勉强完成: 70%奖金
			0.6: 0.5,   # 不及格: 50%奖金
			0.4: 0.3,   # 严重不及格: 30%奖金
			0.0: 0.2    # 完全失败: 20%奖金(基本工资补偿)
		},

		"delay_penalties": {
			0: 1.1,     # 准时: +10%
			7: 0.9,     # 延期1周: -10%
			14: 0.7,    # 延期2周: -30%
			30: 0.5     # 延期1个月: -50%
		},

		"quality_bonuses": {
			90: 1.2,    # 质量90+: +20%
			80: 1.1,    # 质量80+: +10%
			70: 1.0,    # 质量70+: 无加成
			60: 0.9     # 质量60-: -10%
		},

		"relationship_effects": {
			"perfect": {
				"boss": 15,
				"team": 12
			},
			"good": {
				"boss": 10,
				"team": 8
			},
			"barely": {
				"boss": -5,
				"team": -3
			},
			"failed": {
				"boss": -15,
				"team": -10
			}
		},

		"stress_effects": {
			"perfect": -15,
			"good": -8,
			"barely": 5,
			"failed": 25
		},

		"mood_effects": {
			"perfect": 40,
			"good": 25,
			"barely": -5,
			"failed": -30
		},

		"extra_penalties": {
			"failed_can_fire": false,
			"health_impact": false
		}
	},

	"relaxed": {
		"name": "轻松模式",
		"name_en": "Relaxed Mode",
		"description": "低风险,只要完成就有奖金,几乎无惩罚",
		"icon": "res://assets/icons/difficulty_relaxed.png",

		"bonus_multipliers": {
			1.0: 1.1,   # 完美完成: 110%奖金
			0.9: 1.05,  # 优秀完成: 105%奖金
			0.8: 1.0,   # 良好完成: 100%奖金
			0.7: 0.8,   # 勉强完成: 80%奖金
			0.6: 0.7,   # 不及格: 70%奖金
			0.5: 0.6,   # 严重不及格: 60%奖金
			0.0: 0.5    # 完全失败: 50%奖金
		},

		"delay_penalties": {
			0: 1.05,    # 准时: +5%
			7: 1.0,     # 延期1周: 无惩罚
			14: 0.95,   # 延期2周: -5%
			30: 0.9     # 延期1个月: -10%
		},

		"quality_bonuses": {
			90: 1.1,    # 质量90+: +10%
			80: 1.05,   # 质量80+: +5%
			70: 1.0,    # 质量70+: 无加成
			60: 0.95    # 质量60-: -5%
		},

		"relationship_effects": {
			"perfect": {
				"boss": 10,
				"team": 8
			},
			"good": {
				"boss": 8,
				"team": 6
			},
			"barely": {
				"boss": 0,
				"team": 0
			},
			"failed": {
				"boss": -5,
				"team": -3
			}
		},

		"stress_effects": {
			"perfect": -10,
			"good": -5,
			"barely": 0,
			"failed": 10
		},

		"mood_effects": {
			"perfect": 30,
			"good": 20,
			"barely": 0,
			"failed": -15
		},

		"extra_penalties": {
			"failed_can_fire": false,
			"health_impact": false
		}
	}
}

# ========================================
# API函数
# ========================================

func get_mode_config(mode: String) -> Dictionary:
	"""获取难度模式配置"""
	return DIFFICULTY_MODES.get(mode, DIFFICULTY_MODES["balanced"])

func get_mode_name(mode: String) -> String:
	"""获取难度模式名称"""
	var config = get_mode_config(mode)
	return config.get("name", "未知模式")

func get_all_modes() -> Array:
	"""获取所有难度模式(用于UI选择)"""
	var modes = []
	for mode_id in DIFFICULTY_MODES.keys():
		var config = DIFFICULTY_MODES[mode_id]
		modes.append({
			"id": mode_id,
			"name": config.get("name", ""),
			"name_en": config.get("name_en", ""),
			"description": config.get("description", ""),
			"icon": config.get("icon", "")
		})
	return modes

func calculate_bonus_multiplier(
	mode: String,
	completion_rate: float,
	quality_score: float,
	days_overdue: int
) -> float:
	"""计算奖金系数"""

	var config = get_mode_config(mode)

	# 1. 完成度系数
	var completion_multiplier = _get_tier_value(
		config.get("bonus_multipliers", {}),
		completion_rate
	)

	# 2. 延期惩罚
	var delay_multiplier = _get_tier_value(
		config.get("delay_penalties", {}),
		float(days_overdue),
		true  # 使用天数作为key
	)

	# 3. 质量加成
	var quality_multiplier = _get_tier_value(
		config.get("quality_bonuses", {}),
		quality_score
	)

	# 最终系数
	var final_multiplier = completion_multiplier * delay_multiplier * quality_multiplier

	return clamp(final_multiplier, 0.0, 2.0)

func _get_tier_value(tiers: Dictionary, value: float, use_exact_key: bool = false) -> float:
	"""根据阶梯配置获取值"""

	if use_exact_key:
		# 查找最接近的天数档位
		var keys = tiers.keys()
		keys.sort()
		for i in range(keys.size() - 1, -1, -1):
			if value >= keys[i]:
				return tiers[keys[i]]
		return 1.0
	else:
		# 查找最接近的百分比档位
		var keys = tiers.keys()
		keys.sort()
		keys.reverse()  # 从高到低
		for threshold in keys:
			if value >= threshold:
				return tiers[threshold]
		# 返回最低档
		if keys.size() > 0:
			return tiers[keys[keys.size() - 1]]
		return 1.0

func get_relationship_effect(mode: String, result: String) -> Dictionary:
	"""获取关系影响"""
	var config = get_mode_config(mode)
	return config.get("relationship_effects", {}).get(result, {})

func get_stress_effect(mode: String, result: String) -> int:
	"""获取压力影响"""
	var config = get_mode_config(mode)
	return config.get("stress_effects", {}).get(result, 0)

func get_mood_effect(mode: String, result: String) -> int:
	"""获取心情影响"""
	var config = get_mode_config(mode)
	return config.get("mood_effects", {}).get(result, 0)
