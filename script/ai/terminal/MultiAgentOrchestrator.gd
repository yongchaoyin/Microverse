extends Node

# Drives multi-agent deep discussion until the user confirms understanding.
# Works with AgentManager and APIManager. Emits events for TerminalChat UI.

# 引入深度分析器
const DepthAnalyzer := preload("res://script/ai/terminal/DepthAnalyzer.gd")

signal line_emitted(role: String, name: String, text: String, color: Color)
signal discussion_started(topic: String)
signal discussion_stopped()
signal summary_available(text: String)

const MAX_TURNS := 50
const MAX_PER_AGENT_TURNS := 12
const TURN_DELAY_SEC := 0.2
const DEPTH_CHECK_INTERVAL := 5  # 每5轮检查一次深度

var _topic: String = ""
var _active: bool = false
var _history: Array = []   # Array of {role, name, text}
var _per_agent_counts := {}
var _stop_requested := false
var _last_user_ack: String = ""

@onready var _agent_mgr: AgentManager = get_node("/root/AgentManager")
@onready var _api_mgr = get_node("/root/APIManager")

func is_active() -> bool:
	return _active

func history() -> Array:
	return _history.duplicate(true)

func clear_history() -> void:
	_history.clear()
	_per_agent_counts.clear()
	_last_user_ack = ""

func start(topic: String) -> void:
	if _active:
		stop()
		await get_tree().process_frame
	_active = true
	_topic = topic.strip_edges()
	_stop_requested = false
	clear_history()
	discussion_started.emit(_topic)
	_emit_system("System", "开始讨论主题：「%s」。欢迎在任意时刻插话、提问或反驳。" % _topic)
	# round robin loop
	await _drive_debate_loop()

func stop() -> void:
	_stop_requested = true

func user_message(text: String) -> void:
	if not _active:
		return
	text = text.strip_edges()
	if text == "":
		return
	_append_history("user", "You", text)
	_emit_line("user", "You", text, Color(0.85, 1.0, 0.85))
	# Check stop phrases
	if _matches_understood(text):
		_last_user_ack = text
		_stop_requested = true

func _drive_debate_loop() -> void:
	var agents := _agent_mgr.get_enabled_agents()
	print("[MultiAgentOrchestrator] 启用的代理数量: %d" % agents.size())
	if agents.size() == 0:
		_emit_system("System", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		_emit_system("System", "⚠️ 没有启用的AI角色！")
		_emit_system("System", "")
		_emit_system("System", "解决方法：")
		_emit_system("System", "1. 如果是首次使用或配置有误，请输入：/reset")
		_emit_system("System", "2. 或者点击左上角⚙设置按钮，在'AI角色'标签中启用角色")
		_emit_system("System", "3. 也可以使用命令：/agents enable 角色名")
		_emit_system("System", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		_active = false
		discussion_stopped.emit()
		return

	# 显示参与讨论的AI列表
	var agent_names := []
	for a in agents:
		agent_names.append(a.name)
	_emit_system("System", "参与讨论的AI: %s" % ", ".join(agent_names))
	var turn := 0
	while _active and not _stop_requested and turn < MAX_TURNS:
		for agent in agents:
			if not _active or _stop_requested:
				break
			if _count_for(agent.name) >= MAX_PER_AGENT_TURNS:
				continue
			await _agent_turn(agent)
			await get_tree().create_timer(TURN_DELAY_SEC).timeout
		turn += 1

		# 深度检测(每DEPTH_CHECK_INTERVAL轮)
		if turn % DEPTH_CHECK_INTERVAL == 0 and _history.size() > 5:
			var depth_result: Dictionary = DepthAnalyzer.assess_depth(_history)
			if not depth_result.is_deep_enough:
				var report: String = DepthAnalyzer.generate_report(depth_result)
				_emit_system("深度分析", report)
				# 引导AI深入
				_emit_system("System", "讨论深度不足,各位请从'本质原理'、'反例边界'、'实际应用'等角度继续深入。")
			elif turn >= DEPTH_CHECK_INTERVAL * 2:
				# 深度足够,询问用户是否理解
				_emit_system("System", "讨论已有一定深度。您是否理解了?可输入'懂了'结束,或继续提问。")
	# Optional moderator summary on stop
	var moderator := _agent_mgr.get_moderator()
	if moderator and _history.size() > 0:
		var summary := await _elicit_summary(moderator)
		if summary.strip_edges() != "":
			_append_history("assistant", moderator.name, summary)
			_emit_line("assistant", moderator.name, summary, moderator.color)
			summary_available.emit(summary)
	_active = false
	discussion_stopped.emit()

func _agent_turn(agent: Dictionary) -> void:
	var prompt := _compose_agent_prompt(agent)
	var http_request: HTTPRequest = await _api_mgr.generate_dialog(prompt, agent.name)
	if not http_request:
		_emit_system("System", "%s：请求创建失败。" % agent.name)
		return
	
	var completed := false
	var err_text := ""
	http_request.request_completed.connect(func(result, response_code, _h, body):
		completed = true
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			err_text = "HTTP错误 %s" % response_code
			return
		var response_text = body.get_string_from_utf8()
		print("[MultiAgentOrchestrator] 原始响应: ", response_text)
		var response = JSON.parse_string(response_text)
		if response == null:
			err_text = "JSON解析失败"
			return
		var provider_name = APIConfig.get_provider(agent.api_type).name
		var text := APIConfig.parse_response(provider_name, response, agent.name)
		if text == null:
			text = ""
		text = text.strip_edges()
		if text == "":
			err_text = "空响应"
			return
		_per_agent_counts[agent.name] = _count_for(agent.name) + 1
		_append_history("assistant", agent.name, text)
		_emit_line("assistant", agent.name, text, agent.color)
	)
	
	# wait for completion (HTTPRequest frees itself via APIManager; we rely on flag)
	var waited := 0.0
	while not completed and waited < 60.0 and _active and not _stop_requested:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	if not completed and _active:
		_emit_system("System", "%s：请求超时。" % agent.name)
	elif err_text != "":
		_emit_system("System", "%s：%s" % [agent.name, err_text])

func _compose_agent_prompt(agent: Dictionary) -> String:
	var header := "你是「%s」。%s\n请以严谨、友好且高信息密度风格参与深度讨论。" % [
		agent.name,
		agent.get("system_prompt", "")
	]

	var topic_line := "当前讨论主题：%s" % _topic

	var rules := """深度讨论规范:
1. **深入本质**: 不满足于表面解释,追问'为什么'、'本质是什么'、'底层原理'
2. **批判性思维**: 积极指出他人论述的漏洞、隐含假设、边界条件、反例
3. **多层次论证**: 从现象→机制→原理→基础假设,逐层递进
4. **具体例证**: 用实际例子、类比、代码/公式(适用时)使抽象概念具象化
5. **避免空话**: 每句话都要有实质信息,不重复已说内容
6. **相互纠正**: 发现错误立即指出并给出正确解释,这不是攻击而是帮助
7. **保持焦点**: 紧扣主题,深挖而非发散

输出格式:
- 核心观点(1-2句)
- 详细论证(包含原理/例子/反例)
- 对其他人的回应或质疑(如适用)
- 末尾一行【要点】小结"""

	var prior := _render_history_as_bullets(12)
	var user_ack := _last_user_ack if _last_user_ack != "" else ""

	var task := ""
	if _stop_requested:
		task = "用户表示理解（%s）。请用最简洁的方式再次确认核心要点与常见误区，并结束。" % user_ack
	else:
		# 检查当前深度
		var depth: Dictionary = DepthAnalyzer.assess_depth(_history)
		if depth.score < 0.5:
			task = "当前讨论深度不足。请深入探讨:\n"
			for suggestion in depth.suggestions:
				task += "• %s\n" % suggestion
			task += "\n针对上文,给出更深层次的分析或批判。"
		else:
			task = "针对上文继续深入,或回应其他人的观点。若用户提出新问题,优先回答。"

	return "%s\n\n主题: %s\n\n%s\n\n讨论记录:\n%s\n\n任务:\n%s" % [
		header, topic_line, rules, prior, task
	]

func _render_history_as_bullets(max_items: int) -> String:
	var start: int = max(0, _history.size() - max_items)
	var lines: String = ""
	for i in range(start, _history.size()):
		var m: Dictionary = _history[i]
		lines += "- %s: %s\n" % [m.name, m.text]
	return lines.strip_edges()

func _count_for(name: String) -> int:
	return int(_per_agent_counts.get(name, 0))

func _matches_understood(text: String) -> bool:
	var t := text.strip_edges().to_lower()
	var phrases := [
		"我懂了", "懂了", "明白了", "清楚了", "了解了",
		"i understand", "i got it", "got it", "makes sense", "understood"
	]
	for p in phrases:
		if t.find(p.to_lower()) != -1:
			return true
	return false

func _elicit_summary(moderator: Dictionary) -> String:
	var prompt := "你是本次讨论的主持人「%s」。请用分点形式总结主题『%s』的核心概念、关键要点、常见误区、进一步延伸，并给出1个生活类比与1个公式/伪代码（若适用）。限制在200字内。" % [
		moderator.name, _topic
	]
	var req: HTTPRequest = await _api_mgr.generate_dialog(prompt, moderator.name)
	if not req:
		return ""
	var done := false
	var out := ""
	req.request_completed.connect(func(result, response_code, _h, body):
		done = true
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			return
		var response = JSON.parse_string(body.get_string_from_utf8())
		var text := APIConfig.parse_response(APIConfig.get_provider(moderator.api_type).name, response, moderator.name)
		if text:
			out = text.strip_edges()
	)
	var waited := 0.0
	while not done and waited < 30.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	return out

func _emit_system(name: String, text: String) -> void:
	_append_history("system", name, text)
	_emit_line("system", name, text, Color(0.8, 0.8, 0.8))

func _emit_line(role: String, name: String, text: String, color: Color) -> void:
	line_emitted.emit(role, name, text, color)

func _append_history(role: String, name: String, text: String) -> void:
	_history.append({"role": role, "name": name, "text": text})

