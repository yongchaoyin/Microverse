# ========================================
# AICharacterData.gd
# AI角色数据资源类 - 统一管理AI的所有数据
# ========================================
#
# 功能:
# 1. 继承自Resource,可在Godot编辑器中可视化编辑
# 2. 存储AI的所有属性:性格、状态、职业、经济、社交等
# 3. 提供序列化/反序列化方法,支持存档系统
# 4. 提供初始化方法:从配置加载、随机生成、使用模板
# 5. 作为Single Source of Truth,统一数据管理
#
# 使用方式:
#   - 在Godot编辑器中创建 .tres 资源文件
#   - 或通过代码动态创建: AICharacterData.new()
#   - 通过from_dict()从存档加载
#   - 通过from_config()从配置文件加载
#
# 作者: Claude (Sonnet 4.5)
# 日期: 2025-10-20
# 版本: 1.0
# ========================================

class_name AICharacterData extends Resource

# ========================================
# 基础信息
# ========================================

@export var id: String = ""                      # 唯一ID
@export var character_name: String = ""          # 角色名称
@export var age: int = 25                        # 年龄
@export var gender: String = "male"              # 性别 (male/female/other)
@export var birthday: Dictionary = {}           # 生日 {season: int, day: int}

# ========================================
# 性格特质 (Big Five)
# ========================================

@export var personality: Dictionary = {
	"extraversion": 50,           # 外向性 0-100
	"agreeableness": 50,          # 宜人性 0-100
	"conscientiousness": 50,      # 尽责性 0-100
	"neuroticism": 50,            # 神经质 0-100
	"openness": 50                # 开放性 0-100
}

# ========================================
# 当前状态
# ========================================

@export var stats: Dictionary = {
	"energy": 100,                # 精力 0-100
	"mood": 75,                   # 心情 0-100
	"stress": 30,                 # 压力 0-100
	"hunger": 20,                 # 饥饿 0-100
	"social_need": 50,            # 社交需求 0-100
	"health": 100                 # 健康 0-100
}

# ========================================
# 职业信息
# ========================================

@export var career: String = "frontend_engineer"  # 职业ID
@export var career_data: Dictionary = {
	"level": 1,                   # 职业等级
	"experience": 0,              # 经验值
	"years_worked": 0,            # 工作年限
	"performance": 75,            # 绩效评分 0-100
	"satisfaction": 60,           # 工作满意度 0-100
	"promotion_progress": 0       # 升职进度 0-100
}

# ========================================
# 工作状态
# ========================================

@export var work_data: Dictionary = {
	"is_working": false,          # 是否在工作
	"work_hours_today": 0.0,      # 今日工作时长
	"current_task": "",           # 当前任务
	"task_progress": 0,           # 任务进度 0-100
	"pressure": 50,               # 工作压力 0-100
	"absences_this_week": [],     # 本周缺勤记录
	"overtime_hours_this_week": 0.0 # 本周加班时长
}

# ========================================
# 经济状况
# ========================================

@export var money: int = 1000                    # 当前金钱
@export var financial_data: Dictionary = {
	"total_earned": 0,            # 总收入
	"total_spent": 0,             # 总支出
	"monthly_income": 0,          # 月收入
	"monthly_expense": 0,         # 月支出
	"savings_rate": 0.0,          # 储蓄率
	"debt": 0,                    # 债务
	"assets": []                  # 资产列表
}

# ========================================
# 位置和移动
# ========================================

@export var current_location: String = "Home"   # 当前位置
@export var current_room: String = ""           # 当前房间
@export var target_location: String = ""        # 目标位置
@export var is_moving: bool = false             # 是否在移动

# ========================================
# 行为状态
# ========================================

@export var current_activity: String = "idle"   # 当前活动
@export var activity_start_time: Dictionary = {} # 活动开始时间
@export var is_sleeping: bool = false           # 是否在睡眠
@export var sleep_start_time: Dictionary = {}   # 睡眠开始时间

# ========================================
# 社交状态
# ========================================

@export var is_in_conversation: bool = false    # 是否在对话中
@export var conversation_partner: String = ""   # 对话对象ID
@export var conversation_start_time: Dictionary = {}

# ========================================
# 情绪状态
# ========================================

@export var current_emotion: String = "calm"    # 当前主要情绪
@export var emotion_intensity: int = 50         # 情绪强度 0-100
@export var emotion_history: Array = []         # 情绪历史 (最近50条)

# ========================================
# 长期目标
# ========================================

@export var long_term_goals: Array = []         # 长期目标列表
# 每个目标: {id: String, description: String, priority: int, progress: float, deadline: Dictionary}

# ========================================
# 短期计划
# ========================================

@export var daily_schedule: Array = []          # 每日日程
@export var weekly_routine: Array = []          # 每周惯例
@export var pending_tasks: Array = []           # 待办任务

# ========================================
# 记忆引用 (实际记忆存储在MemoryManager)
# ========================================

@export var memory_ids: Array = []              # 记忆ID列表
@export var core_memory_ids: Array = []         # 核心记忆ID列表

# ========================================
# 关系引用 (实际关系存储在RelationshipManager)
# ========================================

@export var relationship_ids: Dictionary = {}   # 关系ID字典 {ai_id: relationship_id}

# ========================================
# 思考历史引用
# ========================================

@export var thought_history_ids: Array = []     # 思考历史ID列表

# ========================================
# 元数据
# ========================================

@export var created_at: Dictionary = {}         # 创建时间
@export var last_updated: Dictionary = {}       # 最后更新时间
@export var total_game_days_lived: int = 0      # 已生活的游戏日数
@export var total_real_hours_played: float = 0.0 # 总游玩时长(现实小时)

# ========================================
# 统计数据
# ========================================

@export var statistics: Dictionary = {
	"total_conversations": 0,     # 总对话次数
	"total_friendships": 0,       # 总友谊数
	"total_romances": 0,          # 总恋爱次数
	"total_work_days": 0,         # 总工作天数
	"total_purchases": 0,         # 总购物次数
	"total_events_participated": 0, # 参与事件数
	"happiness_average": 75,      # 平均幸福度
	"stress_average": 30          # 平均压力
}

# ========================================
# 序列化方法
# ========================================

## 转换为字典 (用于存档)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"character_name": character_name,
		"age": age,
		"gender": gender,
		"birthday": birthday.duplicate(),
		"personality": personality.duplicate(),
		"stats": stats.duplicate(),
		"career": career,
		"career_data": career_data.duplicate(),
		"work_data": work_data.duplicate(),
		"money": money,
		"financial_data": financial_data.duplicate(),
		"current_location": current_location,
		"current_room": current_room,
		"target_location": target_location,
		"is_moving": is_moving,
		"current_activity": current_activity,
		"activity_start_time": activity_start_time.duplicate(),
		"is_sleeping": is_sleeping,
		"sleep_start_time": sleep_start_time.duplicate(),
		"is_in_conversation": is_in_conversation,
		"conversation_partner": conversation_partner,
		"conversation_start_time": conversation_start_time.duplicate(),
		"current_emotion": current_emotion,
		"emotion_intensity": emotion_intensity,
		"emotion_history": emotion_history.duplicate(),
		"long_term_goals": long_term_goals.duplicate(),
		"daily_schedule": daily_schedule.duplicate(),
		"weekly_routine": weekly_routine.duplicate(),
		"pending_tasks": pending_tasks.duplicate(),
		"memory_ids": memory_ids.duplicate(),
		"core_memory_ids": core_memory_ids.duplicate(),
		"relationship_ids": relationship_ids.duplicate(),
		"thought_history_ids": thought_history_ids.duplicate(),
		"created_at": created_at.duplicate(),
		"last_updated": last_updated.duplicate(),
		"total_game_days_lived": total_game_days_lived,
		"total_real_hours_played": total_real_hours_played,
		"statistics": statistics.duplicate()
	}

## 从字典加载 (用于读档)
static func from_dict(data: Dictionary) -> AICharacterData:
	var ai_data = AICharacterData.new()

	ai_data.id = data.get("id", "")
	ai_data.character_name = data.get("character_name", "")
	ai_data.age = data.get("age", 25)
	ai_data.gender = data.get("gender", "male")
	ai_data.birthday = data.get("birthday", {})
	ai_data.personality = data.get("personality", ai_data.personality.duplicate())
	ai_data.stats = data.get("stats", ai_data.stats.duplicate())
	ai_data.career = data.get("career", "")
	ai_data.career_data = data.get("career_data", ai_data.career_data.duplicate())
	ai_data.work_data = data.get("work_data", ai_data.work_data.duplicate())
	ai_data.money = data.get("money", 0)
	ai_data.financial_data = data.get("financial_data", ai_data.financial_data.duplicate())
	ai_data.current_location = data.get("current_location", "Home")
	ai_data.current_room = data.get("current_room", "")
	ai_data.target_location = data.get("target_location", "")
	ai_data.is_moving = data.get("is_moving", false)
	ai_data.current_activity = data.get("current_activity", "idle")
	ai_data.activity_start_time = data.get("activity_start_time", {})
	ai_data.is_sleeping = data.get("is_sleeping", false)
	ai_data.sleep_start_time = data.get("sleep_start_time", {})
	ai_data.is_in_conversation = data.get("is_in_conversation", false)
	ai_data.conversation_partner = data.get("conversation_partner", "")
	ai_data.conversation_start_time = data.get("conversation_start_time", {})
	ai_data.current_emotion = data.get("current_emotion", "calm")
	ai_data.emotion_intensity = data.get("emotion_intensity", 50)
	ai_data.emotion_history = data.get("emotion_history", [])
	ai_data.long_term_goals = data.get("long_term_goals", [])
	ai_data.daily_schedule = data.get("daily_schedule", [])
	ai_data.weekly_routine = data.get("weekly_routine", [])
	ai_data.pending_tasks = data.get("pending_tasks", [])
	ai_data.memory_ids = data.get("memory_ids", [])
	ai_data.core_memory_ids = data.get("core_memory_ids", [])
	ai_data.relationship_ids = data.get("relationship_ids", {})
	ai_data.thought_history_ids = data.get("thought_history_ids", [])
	ai_data.created_at = data.get("created_at", {})
	ai_data.last_updated = data.get("last_updated", {})
	ai_data.total_game_days_lived = data.get("total_game_days_lived", 0)
	ai_data.total_real_hours_played = data.get("total_real_hours_played", 0.0)
	ai_data.statistics = data.get("statistics", ai_data.statistics.duplicate())

	return ai_data

# ========================================
# 初始化方法
# ========================================

## 从配置文件加载 (使用CharacterPersonality配置)
static func from_config(character_name: String, career_id: String = "") -> AICharacterData:
	var ai_data = AICharacterData.new()

	# 生成唯一ID
	ai_data.id = character_name.to_lower()
	ai_data.character_name = character_name

	# 设置职业
	if career_id:
		ai_data.career = career_id
	else:
		# 根据CharacterPersonality推断职业
		ai_data.career = _infer_career_from_personality(character_name)

	# 从PersonalityEngine获取性格数据
	var personality_engine = _get_personality_engine()
	if personality_engine and personality_engine.has_method("get_personality"):
		var personality_data = personality_engine.get_personality(character_name)
		if personality_data and not personality_data.is_empty():
			ai_data.personality = {
				"extraversion": personality_data.get("extraversion", 50),
				"agreeableness": personality_data.get("agreeableness", 50),
				"conscientiousness": personality_data.get("conscientiousness", 50),
				"neuroticism": personality_data.get("neuroticism", 50),
				"openness": personality_data.get("openness", 50)
			}

	# 设置创建时间
	var time_system = _get_time_system()
	if time_system:
		ai_data.created_at = _get_current_game_time(time_system)
		ai_data.last_updated = ai_data.created_at.duplicate()

	# 初始化年龄和性别 (基于预设)
	var preset = _get_character_preset(character_name)
	ai_data.age = preset.get("age", 25)
	ai_data.gender = preset.get("gender", "male")

	# 初始化生日 (随机)
	ai_data.birthday = {
		"season": randi() % 4,  # 0-3: Spring/Summer/Autumn/Winter
		"day": randi() % 28 + 1  # 1-28
	}

	# 初始金钱基于职业
	ai_data.money = _get_initial_money_by_career(ai_data.career)

	print("[AICharacterData] 从配置创建角色: %s (职业: %s)" % [character_name, ai_data.career])

	return ai_data

## 随机生成AI数据
static func random_generate(character_name: String = "") -> AICharacterData:
	var ai_data = AICharacterData.new()

	# 生成随机ID
	if character_name:
		ai_data.id = character_name.to_lower()
		ai_data.character_name = character_name
	else:
		ai_data.id = "ai_" + str(Time.get_ticks_msec())
		ai_data.character_name = "AI_" + str(randi() % 10000)

	# 随机年龄和性别
	ai_data.age = randi() % 40 + 20  # 20-59岁
	ai_data.gender = ["male", "female"].pick_random()

	# 随机性格 (Big Five)
	ai_data.personality = {
		"extraversion": randi() % 100,
		"agreeableness": randi() % 100,
		"conscientiousness": randi() % 100,
		"neuroticism": randi() % 100,
		"openness": randi() % 100
	}

	# 随机职业
	var careers = ["frontend_engineer", "backend_engineer", "product_manager",
	               "designer", "hr", "tester", "admin", "receptionist"]
	ai_data.career = careers.pick_random()

	# 随机初始金钱
	ai_data.money = randi() % 5000 + 500  # 500-5500

	# 随机生日
	ai_data.birthday = {
		"season": randi() % 4,
		"day": randi() % 28 + 1
	}

	# 设置创建时间
	var time_system = _get_time_system()
	if time_system:
		ai_data.created_at = _get_current_game_time(time_system)
		ai_data.last_updated = ai_data.created_at.duplicate()

	print("[AICharacterData] 随机生成角色: %s" % ai_data.character_name)

	return ai_data

## 使用预设模板创建
static func from_template(template_name: String) -> AICharacterData:
	# 预设模板数据
	var templates = {
		"default_employee": {
			"age": 28,
			"gender": "male",
			"career": "frontend_engineer",
			"money": 2000,
			"personality": {
				"extraversion": 50,
				"agreeableness": 60,
				"conscientiousness": 70,
				"neuroticism": 40,
				"openness": 55
			}
		},
		"intern": {
			"age": 22,
			"gender": "female",
			"career": "frontend_engineer",
			"money": 500,
			"personality": {
				"extraversion": 60,
				"agreeableness": 70,
				"conscientiousness": 50,
				"neuroticism": 55,
				"openness": 75
			},
			"career_data": {
				"level": 0,
				"experience": 0,
				"years_worked": 0
			}
		},
		"senior_engineer": {
			"age": 35,
			"gender": "male",
			"career": "backend_engineer",
			"money": 8000,
			"personality": {
				"extraversion": 40,
				"agreeableness": 50,
				"conscientiousness": 85,
				"neuroticism": 35,
				"openness": 60
			},
			"career_data": {
				"level": 3,
				"experience": 5000,
				"years_worked": 10
			}
		}
	}

	var template = templates.get(template_name, templates["default_employee"])

	var ai_data = AICharacterData.new()
	ai_data.id = "template_" + template_name + "_" + str(Time.get_ticks_msec())
	ai_data.character_name = template_name.capitalize()
	ai_data.age = template.get("age", 25)
	ai_data.gender = template.get("gender", "male")
	ai_data.career = template.get("career", "frontend_engineer")
	ai_data.money = template.get("money", 1000)
	ai_data.personality = template.get("personality", ai_data.personality.duplicate())

	if template.has("career_data"):
		for key in template.career_data:
			ai_data.career_data[key] = template.career_data[key]

	# 随机生日
	ai_data.birthday = {
		"season": randi() % 4,
		"day": randi() % 28 + 1
	}

	# 设置创建时间
	var time_system = _get_time_system()
	if time_system:
		ai_data.created_at = _get_current_game_time(time_system)
		ai_data.last_updated = ai_data.created_at.duplicate()

	print("[AICharacterData] 使用模板创建角色: %s (模板: %s)" % [ai_data.character_name, template_name])

	return ai_data

# ========================================
# 工具方法
# ========================================

## 更新统计数据
func update_statistics():
	statistics["happiness_average"] = int((stats.mood + (100 - stats.stress)) / 2.0)
	statistics["stress_average"] = stats.stress

## 添加情绪历史
func add_emotion(emotion: String, intensity: int, reason: String = ""):
	var time_system = _get_time_system()
	var timestamp = _get_current_game_time(time_system) if time_system else {}

	var emotion_entry = {
		"emotion": emotion,
		"intensity": intensity,
		"reason": reason,
		"timestamp": timestamp
	}
	emotion_history.append(emotion_entry)

	# 只保留最近50条
	if emotion_history.size() > 50:
		emotion_history.remove_at(0)

	current_emotion = emotion
	emotion_intensity = intensity

## 更新最后修改时间
func update_last_modified():
	var time_system = _get_time_system()
	if time_system:
		last_updated = _get_current_game_time(time_system)

## 增加游戏日计数
func increment_game_days():
	total_game_days_lived += 1

## 增加游玩时长
func add_playtime(hours: float):
	total_real_hours_played += hours

## 获取简要信息 (用于调试)
func get_summary() -> String:
	return "%s (%s岁, %s, %s) - 金钱:%d, 心情:%d, 压力:%d" % [
		character_name,
		age,
		gender,
		career,
		money,
		stats.mood,
		stats.stress
	]

# ========================================
# 私有辅助方法
# ========================================

static func _get_personality_engine() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("PersonalityEngine")

static func _get_time_system() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("TimeSystem")

static func _get_current_game_time(time_system: Node) -> Dictionary:
	if time_system and time_system.has_method("get_current_time_dict"):
		return time_system.get_current_time_dict()
	elif time_system:
		return {
			"year": time_system.get("current_year") if time_system.has("current_year") else 1,
			"season": time_system.get("current_season") if time_system.has("current_season") else 0,
			"day": time_system.get("current_day") if time_system.has("current_day") else 1,
			"hour": time_system.get("current_hour") if time_system.has("current_hour") else 6,
			"minute": time_system.get("current_minute") if time_system.has("current_minute") else 0
		}
	return {}

static func _infer_career_from_personality(character_name: String) -> String:
	# 根据CharacterPersonality中的position推断职业ID
	var position_map = {
		"老板": "ceo",
		"秘书": "admin",
		"前台": "receptionist",
		"前端工程师": "frontend_engineer",
		"UI设计师": "designer",
		"HR": "hr",
		"后端开发工程师": "backend_engineer",
		"测试工程师": "tester",
		"产品经理": "product_manager"
	}

	var personality_config = CharacterPersonality.get_personality(character_name)
	var position = personality_config.get("position", "")

	for keyword in position_map.keys():
		if keyword in position:
			return position_map[keyword]

	return "frontend_engineer"  # 默认

static func _get_character_preset(character_name: String) -> Dictionary:
	# 预设角色的年龄和性别
	var presets = {
		"Stephen": {"age": 45, "gender": "male"},
		"Tom": {"age": 28, "gender": "male"},
		"Lea": {"age": 24, "gender": "female"},
		"Alice": {"age": 27, "gender": "female"},
		"Grace": {"age": 30, "gender": "female"},
		"Jack": {"age": 32, "gender": "male"},
		"Joe": {"age": 29, "gender": "male"},
		"Monica": {"age": 33, "gender": "female"}
	}

	return presets.get(character_name, {"age": 25, "gender": "male"})

static func _get_initial_money_by_career(career_id: String) -> int:
	# 根据职业设置初始金钱
	var career_money_map = {
		"ceo": 50000,
		"product_manager": 8000,
		"backend_engineer": 6000,
		"frontend_engineer": 5000,
		"designer": 5000,
		"tester": 4500,
		"hr": 4000,
		"admin": 3500,
		"receptionist": 3000
	}

	return career_money_map.get(career_id, 2000)
