extends Node

class_name EconomyManager

# ========================================
# 信号定义
# ========================================

signal salary_paid(ai_id: String, amount: int)
signal money_changed(ai_id: String, new_amount: int)
signal financial_crisis(ai_id: String, debt: int)
signal expense_settled(ai_id: String, amount: int)
signal economy_transaction(ai_id: String, transaction: Dictionary)
signal economy_debt_incurred(ai_id: String, debt: int)
signal economy_loan_created(ai_id: String, lender_id: String, amount: int, interest: float)

# ========================================
# 常量定义
# ========================================

const DAILY_EXPENSE_WEEKDAY_MIN = 70
const DAILY_EXPENSE_WEEKDAY_MAX = 90
const DAILY_EXPENSE_WEEKEND_MIN = 100
const DAILY_EXPENSE_WEEKEND_MAX = 150
const EXPENSE_SETTLEMENT_HOUR = 23  # 每天23:00结算当日开支

# 工资发放配置
const PAYROLL_WEEKDAY_INDEX = 0  # Monday
const PAYROLL_HOUR = 6

# 记忆模板
const SALARY_MEMORY_TEMPLATE = "[经济] 本周工资已到账：基础工资 %.0fG，绩效奖金 %.0fG，加班补贴 %.0fG"
const EXPENSE_MEMORY_TEMPLATE = "[经济] 今日支出 %.0fG，当前余额 %.0fG"
const CRISIS_MEMORY_TEMPLATE = "[经济] 我陷入了财务危机，存款已经为负"
const LOAN_MEMORY_TEMPLATE = "[经济] 向 %s 借了 %dG，利率 %.1f%%"

# ========================================
# 内部状态
# ========================================

var _accounts: Dictionary = {}  # ai_id -> {balance: int, transactions: Array, career_id: String, expenses: float}

var _time_system: Node = null
var _task_system: Node = null
var _career_system: Node = null
var _event_bus: Node = null
var _memory_manager: Node = null
var _relationship_manager: Node = null

# ========================================
# 初始化
# ========================================

func _ready():
	# 获取系统引用
	_time_system = get_node_or_null("/root/TimeSystem")
	_task_system = get_node_or_null("/root/TaskSystem")
	_career_system = get_node_or_null("/root/CareerSystem")
	_event_bus = get_node_or_null("/root/EventBus")
	_memory_manager = get_node_or_null("/root/MemoryManager")
	_relationship_manager = get_node_or_null("/root/RelationshipManager")

	# 连接时间系统信号
	if _time_system:
		_time_system.hour_changed.connect(_on_hour_changed)
		_time_system.day_changed.connect(_on_day_changed)

	print("[EconomyManager] 经济系统初始化完成")

# ========================================
# 角色管理
# ========================================

func register_character(ai_id: String, character_node: Node):
	"""注册AI角色到经济系统"""
	if not _accounts.has(ai_id):
		_accounts[ai_id] = {
			"balance": character_node.get_meta("money", 2000) if character_node else 2000,
			"transactions": [],
			"career_id": character_node.get_meta("career", "unemployed") if character_node else "unemployed",
			"expenses": 0.0,
			"last_expense_day": -1
		}
		print("[EconomyManager] 注册角色: %s，初始余额: %dG" % [ai_id, _accounts[ai_id].balance])

func get_balance(ai_id: String) -> int:
	"""获取角色余额"""
	if not _accounts.has(ai_id):
		return 0
	return int(_accounts[ai_id].balance)

func set_balance(ai_id: String, amount: int):
	"""设置角色余额"""
	if not _accounts.has(ai_id):
		register_character(ai_id, null)

	var old_balance = _accounts[ai_id].balance
	_accounts[ai_id].balance = amount
	money_changed.emit(ai_id, amount)

	# 更新角色节点
	var character = get_character_by_id(ai_id)
	if character:
		character.set_meta("money", amount)

# ========================================
# 工资系统
# ========================================

func _on_hour_changed(hour: int):
	"""小时变化时的处理"""
	# 周一早上6点发工资
	if _time_system and _time_system.is_workday() and _time_system.get_weekday_name() == "Monday" and hour == PAYROLL_HOUR:
		_pay_weekly_salaries()

func _on_day_changed(year: int, season: int, day: int):
	"""每日变化时的处理"""
	if _time_system and _time_system.get_current_hour() >= EXPENSE_SETTLEMENT_HOUR:
		_process_daily_expenses()

func _pay_weekly_salaries():
	"""发放周薪"""
	print("[经济系统] 周一发工资日")

	var all_ai_ids = _accounts.keys()
	for ai_id in all_ai_ids:
		var salary = _calculate_weekly_salary(ai_id)

		# 更新余额
		_accounts[ai_id].balance += salary
		money_changed.emit(ai_id, _accounts[ai_id].balance)
		salary_paid.emit(ai_id, salary)

		print("  %s 收到工资: %dG (总存款: %dG)" % [ai_id, salary, _accounts[ai_id].balance])

		# 创建记忆
		_create_salary_memory(ai_id, salary)

		# 通过EventBus发送事件
		if _event_bus:
			_event_bus.emit_event("salary_paid", {
				"ai_id": ai_id,
				"amount": salary,
				"total_balance": _accounts[ai_id].balance
			})

func _calculate_weekly_salary(ai_id: String) -> int:
	"""计算周薪"""
	if not _accounts.has(ai_id):
		return 0

	var career_data = get_career_data(ai_id)
	var daily_salary = career_data.get("daily_salary", 150)

	# 计算本周实际工作天数
	var work_days = 5  # 假设周一到周五工作

	# 基础周薪
	var base_salary = daily_salary * work_days

	# 绩效奖金
	var performance_bonus = _calculate_performance_bonus(ai_id)

	# 最终工资
	var final_salary = int(base_salary * (1.0 + performance_bonus))

	return final_salary

func _calculate_performance_bonus(ai_id: String) -> float:
	"""计算绩效奖金倍率 (-0.5 ~ 0.5)"""
	if not _task_system:
		return 0.0

	var performance = {}
	if _task_system.has_method("get_weekly_performance"):
		performance = _task_system.get_weekly_performance(ai_id)

	var score = 0.0

	# 完成率（40分）
	var completion_rate = performance.get("completion_rate", 0.8)
	score += completion_rate * 40.0

	# 工作质量（30分）- 基于尽责性
	var quality = performance.get("average_quality", 0.75)
	score += quality * 30.0

	# 加班时长（20分）
	var overtime_hours = performance.get("overtime_hours", 0.0)
	score += min(overtime_hours * 2.0, 20.0)

	# 同事关系（10分）
	var coworker_affection = _get_average_coworker_affection(ai_id)
	score += coworker_affection / 10.0

	# 转换为奖金倍率
	var bonus = (score - 50.0) / 100.0  # -0.5 ~ 0.5

	return clamp(bonus, -0.2, 0.5)  # 限制在合理范围内

func get_career_data(ai_id: String) -> Dictionary:
	"""获取职业数据"""
	if not _accounts.has(ai_id):
		return {}
	var career_id = _accounts[ai_id].career_id

	# 职业工资表
	var career_data = {
		"engineer": {"daily_salary": 180, "name": "工程师"},
		"designer": {"daily_salary": 160, "name": "设计师"},
		"manager": {"daily_salary": 220, "name": "经理"},
		"barista": {"daily_salary": 120, "name": "咖啡师"},
		"unemployed": {"daily_salary": 0, "name": "无业"}
	}

	return career_data.get(career_id, {"daily_salary": 100, "name": "未知"})

# ========================================
# 日常支出系统
# ========================================

func _process_daily_expenses():
	"""处理每日支出"""
	var all_ai_ids = _accounts.keys()
	var current_day = -1
	if _time_system:
		current_day = _time_system.get_total_days()

	for ai_id in all_ai_ids:
		var account = _accounts[ai_id]

		# 避免一天内重复结算
		if account.last_expense_day == current_day:
			continue

		var expense = _calculate_daily_expense(ai_id)
		account.balance -= expense
		account.last_expense_day = current_day
		account.expenses = expense

		money_changed.emit(ai_id, account.balance)
		expense_settled.emit(ai_id, expense)

		# 创建支出记忆
		_create_expense_memory(ai_id, expense)

		# 检查财务危机
		if account.balance < 0:
			financial_crisis.emit(ai_id, -account.balance)
			_handle_financial_crisis(ai_id)

		# 通过EventBus发送事件
		if _event_bus:
			_event_bus.emit_event("expense_settled", {
				"ai_id": ai_id,
				"amount": expense,
				"balance": account.balance
			})

func _calculate_daily_expense(ai_id: String) -> int:
	"""计算每日支出"""
	if not _time_system or not _accounts.has(ai_id):
		return DAILY_EXPENSE_WEEKDAY_MIN

	var is_weekend = _time_system.is_weekend()
	var base_min = DAILY_EXPENSE_WEEKEND_MIN if is_weekend else DAILY_EXPENSE_WEEKDAY_MIN
	var base_max = DAILY_EXPENSE_WEEKEND_MAX if is_weekend else DAILY_EXPENSE_WEEKDAY_MAX

	var base_expense = randi_range(base_min, base_max)

	# 获取角色性格信息
	var character = get_character_by_id(ai_id)
	if not character:
		return base_expense

	# 性格修正 - 尽责性影响节俭程度
	var conscientiousness = character.get_meta("conscientiousness", 50) / 100.0
	var frugality_modifier = 1.0 - (conscientiousness - 0.5) * 0.5  # C=100时0.75倍，C=0时1.25倍

	# 外向性影响社交支出
	var extraversion = character.get_meta("extraversion", 50) / 100.0
	var social_modifier = 1.0 + (extraversion - 0.5) * 0.5  # E=100时1.25倍

	var final_expense = int(base_expense * frugality_modifier * social_modifier)

	return final_expense

# ========================================
# 借贷系统
# ========================================

func request_loan(requester_id: String, lender_id: String, amount: int) -> bool:
	"""发起借贷请求"""
	if not _relationship_manager or not _accounts.has(requester_id) or not _accounts.has(lender_id):
		return false

	# 检查贷款资格
	if not _relationship_manager.has_method("can_request_loan"):
		return false

	var loan_check = _relationship_manager.can_request_loan(requester_id, lender_id)
	if not loan_check.get("eligible", false):
		print("[经济系统] %s 向 %s 借钱失败: %s" % [requester_id, lender_id, loan_check.get("reason", "未知原因")])
		return false

	# 检查贷方余额
	if _accounts[lender_id].balance < amount:
		print("[经济系统] %s 余额不足，无法借钱给 %s" % [lender_id, requester_id])
		return false

	# 计算利率
	var trust_level = loan_check.get("trust_level", 60)
	var interest_rate = 0.10 - (trust_level - 60) / 40 * 0.08  # trust 60->10%, trust 100->2%
	interest_rate = clamp(interest_rate, 0.02, 0.10)

	# 执行转账
	_accounts[lender_id].balance -= amount
	_accounts[requester_id].balance += amount

	# 记录债务（简化实现，实际应该有更复杂的债务追踪）
	_add_debt_record(requester_id, lender_id, amount, interest_rate)

	# 发送事件
	if _event_bus:
		_event_bus.emit_event("economy_loan_created", {
			"requester_id": requester_id,
			"lender_id": lender_id,
			"amount": amount,
			"interest_rate": interest_rate
		})

	# 创建记忆
	_create_loan_memory(requester_id, lender_id, amount, interest_rate)

	print("[经济系统] %s 向 %s 借了 %dG，利率 %.1f%%" % [requester_id, lender_id, amount, interest_rate * 100])

	return true

func _add_debt_record(debtor_id: String, creditor_id: String, amount: int, interest: float):
	"""添加债务记录（简化实现）"""
	# 实际实现中应该有更完善的债务管理系统
	pass

# ========================================
# 财务危机处理
# ========================================

func _handle_financial_crisis(ai_id: String):
	"""处理财务危机"""
	if not _accounts.has(ai_id):
		return

	print("[经济危机] %s 存款为负: %dG" % [ai_id, _accounts[ai_id].balance])

	# 创建记忆
	_create_crisis_memory(ai_id)

	# 降低心情
	var character = get_character_by_id(ai_id)
	if character:
		var current_mood = character.get_meta("mood", 50)
		character.set_meta("mood", max(current_mood - 30, 0))

	# AI可能决定借钱
	_consider_borrowing_money(ai_id)

func _consider_borrowing_money(ai_id: String):
	"""考虑向朋友借钱"""
	if not _relationship_manager or not _accounts.has(ai_id):
		return

	var friends = []
	if _relationship_manager.has_method("get_friends"):
		friends = _relationship_manager.get_friends(ai_id, "friend")

	if friends.size() == 0:
		print("  %s 没有可以借钱的朋友" % ai_id)
		return

	# 按信任度排序
	if _relationship_manager.has_method("get_closest_people"):
		friends = _relationship_manager.get_closest_people(ai_id, friends.size())

	var needed_amount = -_accounts[ai_id].balance + 500  # 借到能撑2周的钱

	for friend_id in friends:
		if request_loan(ai_id, friend_id, needed_amount):
			print("  %s 向 %s 借了 %dG" % [ai_id, friend_id, needed_amount])
			return

	print("  %s 借钱失败" % ai_id)

# ========================================
# 记忆系统
# ========================================

func _create_salary_memory(ai_id: String, salary: int):
	"""创建工资收入记忆"""
	var career_data = get_career_data(ai_id)
	var career_name = career_data.get("name", "未知")
	var memory_text = "本周作为%s，收到了工资 %dG" % [career_name, salary]

	_add_memory(ai_id, "salary_received", memory_text, 0.4, 0.5)

func _create_expense_memory(ai_id: String, expense: int):
	"""创建支出记忆"""
	var memory_text = "今日支出 %dG，当前余额 %dG" % [expense, _accounts[ai_id].balance]

	var importance = 0.3
	var valence = -0.3
	if _accounts[ai_id].balance < 100:
		importance = 0.7
		valence = -0.7

	_add_memory(ai_id, "daily_expense", memory_text, importance, valence)

func _create_crisis_memory(ai_id: String):
	"""创建财务危机记忆"""
	var memory_text = "我陷入了财务危机，存款已经为负"
	_add_memory(ai_id, "financial_crisis", memory_text, 0.8, -0.8)

func _create_loan_memory(borrower_id: String, lender_id: String, amount: int, interest: float):
	"""创建借贷记忆"""
	var memory_text = "向 %s 借了 %dG，利率 %.1f%%" % [lender_id, amount, interest * 100]
	_add_memory(borrower_id, "loan_taken", memory_text, 0.6, -0.2)

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

# ========================================
# 工具函数
# ========================================

func get_character_by_id(ai_id: String) -> Node:
	"""通过ID获取AI角色节点"""
	# 简化实现，实际应该通过CharacterManager获取
	# 这里假设角色节点名为ai_id
	return get_node_or_null("/root/CharacterManager/" + ai_id)

func _get_average_coworker_affection(ai_id: String) -> float:
	"""获取与同事的平均好感度"""
	if not _relationship_manager:
		return 50.0

	var career_id = _accounts[ai_id].career_id if _accounts.has(ai_id) else "unemployed"
	var coworkers = []

	# 找到同职业的同事
	for other_id in _accounts.keys():
		if other_id != ai_id and _accounts[other_id].career_id == career_id:
			coworkers.append(other_id)

	if coworkers.size() == 0:
		return 50.0

	var total_affection = 0.0
	if _relationship_manager.has_method("get_relationship"):
		for coworker_id in coworkers:
			var relationship = _relationship_manager.get_relationship(ai_id, coworker_id)
			if relationship.has("affection"):
				total_affection += relationship.affection

	return total_affection / coworkers.size() if coworkers.size() > 0 else 50.0

# ========================================
# 查询API
# ========================================

func get_financial_status(ai_id: String) -> Dictionary:
	"""获取财务状况摘要"""
	if not _accounts.has(ai_id):
		return {}

	var account = _accounts[ai_id]
	var career_data = get_career_data(ai_id)
	var monthly_income = career_data.daily_salary * 5 * 4  # 周薪*4周

	var savings_ratio = account.balance / float(monthly_income)

	var status = ""
	if savings_ratio > 3.0:
		status = "富裕"
	elif savings_ratio > 1.5:
		status = "稳定"
	elif savings_ratio > 0.5:
		status = "紧张"
	else:
		status = "危机"

	return {
		"current_money": account.balance,
		"monthly_income": monthly_income,
		"savings_ratio": savings_ratio,
		"status": status,
		"career": career_data.get("name", "未知"),
		"daily_expense": account.expenses
	}

func get_all_financial_status() -> Dictionary:
	"""获取所有人的财务状况"""
	var result = {}
	for ai_id in _accounts.keys():
		result[ai_id] = get_financial_status(ai_id)
	return result

# ========================================
# 保存/加载
# ========================================

func save_state() -> Dictionary:
	"""保存经济系统状态"""
	return {
		"accounts": _accounts,
		"timestamp": _time_system.get_current_timestamp() if _time_system else Time.get_unix_time_from_system()
	}

func load_state(state: Dictionary):
	"""加载经济系统状态"""
	_accounts = state.get("accounts", {})
	print("[EconomyManager] 经济数据已加载，共%d个账户" % _accounts.size())

# ========================================
# Phase D: 关系系统增强集成
# ========================================

func check_loan_with_trust(requester_id: String, lender_id: String, amount: int) -> Dictionary:
	"""检查借贷请求的信任阈值

	Args:
		requester_id: 借款人ID
		lender_id: 贷方ID
		amount: 借款金额

	Returns:
		检查结果 {approved: bool, trust_level: float, reason: String}
	"""
	if not _relationship_manager:
		return {"approved": false, "trust_level": 0.0, "reason": "关系系统未加载"}

	var relationship = _relationship_manager.get_relationship(requester_id, lender_id)
	if relationship.is_empty():
		return {"approved": false, "trust_level": 0.0, "reason": "双方没有关系记录"}

	var trust = relationship.get("trust", 0.0)

	# 信任阈值检查
	var min_trust_required = 30.0 + (amount / 1000.0) * 20.0  # 金额越大,所需信任度越高
	min_trust_required = clamp(min_trust_required, 30.0, 80.0)

	if trust < min_trust_required:
		return {
			"approved": false,
			"trust_level": trust,
			"reason": "信任度不足(需要: %.0f, 当前: %.0f)" % [min_trust_required, trust]
		}

	return {
		"approved": true,
		"trust_level": trust,
		"reason": "信任度充足"
	}

func trigger_debt_conflict(debtor_id: String, creditor_id: String, overdue_amount: int):
	"""触发债务纠纷冲突

	当债务逾期时,可能触发冲突

	Args:
		debtor_id: 债务人ID
		creditor_id: 债权人ID
		overdue_amount: 逾期金额
	"""
	var conflict_system = get_node_or_null("/root/ConflictSystem")
	if not conflict_system:
		return

	# 计算严重程度(基于逾期金额)
	var severity = 1
	if overdue_amount > 10000:
		severity = 9  # CRITICAL
	elif overdue_amount > 5000:
		severity = 6  # MAJOR
	elif overdue_amount > 2000:
		severity = 3  # MODERATE
	else:
		severity = 1  # MINOR

	# 触发冲突
	var conflict_id = conflict_system.trigger_conflict(
		creditor_id,  # 债权人是发起者
		debtor_id,    # 债务人是目标
		conflict_system.ConflictType.INTEREST,  # 利益冲突
		severity,
		"债务逾期未还: %dG" % overdue_amount,
		{"location": "办公室", "amount": overdue_amount}
	)

	print("[EconomyManager] 债务纠纷冲突触发: %s (ID: %s, 金额: %dG)" % [
		"%s vs %s" % [creditor_id, debtor_id],
		conflict_id,
		overdue_amount
	])

func update_relationship_after_transaction(from_id: String, to_id: String, amount: int, transaction_type: String):
	"""交易后更新关系

	Args:
		from_id: 转出方ID
		to_id: 接收方ID
		amount: 金额
		transaction_type: 交易类型 (gift/loan/salary/trade)
	"""
	if not _relationship_manager:
		return

	var changes = {}
	var reason = ""

	match transaction_type:
		"gift":
			# 赠送礼物增加好感和信任
			var impact = clamp(amount / 1000.0, 1.0, 10.0)  # 金额越多影响越大
			changes = {
				"affection": impact * 2,
				"trust": impact
			}
			reason = "赠送了%dG的礼物" % amount
		"loan":
			# 借款增加信任(借款方对贷方)
			changes = {
				"trust": 5.0
			}
			reason = "借了%dG" % amount
		"repayment":
			# 还款增加信任和尊重
			changes = {
				"trust": 3.0,
				"respect": 2.0
			}
			reason = "按时归还了%dG借款" % amount
		"trade":
			# 公平交易略微增加信任
			changes = {
				"trust": 1.0,
				"familiarity": 1.0
			}
			reason = "进行了%dG的交易" % amount

	if not changes.is_empty():
		_relationship_manager.modify_relationship(from_id, to_id, changes, reason)
		print("[EconomyManager] 交易后关系更新: %s -> %s (%s)" % [from_id, to_id, reason])