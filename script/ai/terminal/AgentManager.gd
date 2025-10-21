extends Node

# Manages up to 10 AI agents with per-vendor API/model/key and display color.
# Persists configuration to user://agents.json and exposes signals for UI.

signal agents_changed

const AGENTS_FILE := "user://agents.json"
const MAX_AGENTS := 10

var _agents: Array = []  # Array of Dictionaries: {name, api_type, model, api_key, system_prompt, color, enabled, is_moderator}

func _ready() -> void:
	load_agents()

func get_agents() -> Array:
	return _agents.duplicate(true)

func get_enabled_agents() -> Array:
	var out := []
	for a in _agents:
		if a.get("enabled", true):
			out.append(a)
	return out

func get_agent_by_name(name: String) -> Dictionary:
	for a in _agents:
		if a.name == name:
			return a.duplicate(true)
	return {}

func upsert_agent(agent: Dictionary) -> void:
	assert(agent.has("name") and agent.name is String and agent.name.strip_edges() != "", "Agent must have a non-empty name")
	if _agents.size() >= MAX_AGENTS:
		var idx := _find_agent_index(agent.name)
		if idx == -1:
			push_error("Maximum of %d agents reached" % MAX_AGENTS)
			return
	var validated := _validate_and_fill(agent)
	var i := _find_agent_index(validated.name)
	if i == -1:
		_agents.append(validated)
	else:
		_agents[i] = validated
	save_agents()
	agents_changed.emit()

func remove_agent(name: String) -> void:
	var i := _find_agent_index(name)
	if i != -1:
		_agents.remove_at(i)
		save_agents()
		agents_changed.emit()

func set_agent_key(name: String, api_key: String) -> void:
	var i := _find_agent_index(name)
	if i == -1:
		push_error("Agent not found: %s" % name)
		return
	_agents[i].api_key = api_key
	save_agents()
	agents_changed.emit()

func set_agent_color(name: String, color: Color) -> void:
	var i := _find_agent_index(name)
	if i == -1:
		push_error("Agent not found: %s" % name)
		return
	_agents[i].color = color
	save_agents()
	agents_changed.emit()

func set_agent_enabled(name: String, enabled: bool) -> void:
	var i := _find_agent_index(name)
	if i == -1:
		push_error("Agent not found: %s" % name)
		return
	_agents[i].enabled = enabled
	save_agents()
	agents_changed.emit()

func set_agent_model(name: String, api_type: String, model: String) -> void:
	var i := _find_agent_index(name)
	if i == -1:
		push_error("Agent not found: %s" % name)
		return
	_agents[i].api_type = api_type
	_agents[i].model = model
	save_agents()
	agents_changed.emit()

func set_agent_moderator(name: String, is_moderator: bool) -> void:
	var i := _find_agent_index(name)
	if i == -1:
		push_error("Agent not found: %s" % name)
		return
	# Only one moderator allowed; unset others if setting true
	if is_moderator:
		for j in range(_agents.size()):
			_agents[j].is_moderator = false
	_agents[i].is_moderator = is_moderator
	save_agents()
	agents_changed.emit()

func set_agent_prompt(name: String, system_prompt: String) -> void:
	var i := _find_agent_index(name)
	if i == -1:
		push_error("Agent not found: %s" % name)
		return
	_agents[i].system_prompt = system_prompt
	save_agents()
	agents_changed.emit()

func set_agent_name(old_name: String, new_name: String) -> void:
	var i := _find_agent_index(old_name)
	if i == -1:
		push_error("Agent not found: %s" % old_name)
		return
	if _find_agent_index(new_name) != -1:
		push_error("Agent name already exists: %s" % new_name)
		return
	_agents[i].name = new_name
	save_agents()
	agents_changed.emit()

func get_moderator() -> Dictionary:
	for a in _agents:
		if a.get("is_moderator", false) and a.get("enabled", true):
			return a.duplicate(true)
	return {}

func ensure_defaults_if_empty() -> void:
	if _agents.size() == 0:
		# 提供8种专业预设角色模板,用户需设置API Key才能启用
		var defaults := [
			{
				"name": "苏格拉底",
				"api_type": "SiliconFlow",
				"model": "zai-org/GLM-4.6",
				"api_key": "",
				"system_prompt": "你是苏格拉底式引导者。不直接给答案,而是通过精准提问引导对方深入思考。擅长揭示概念背后的假设、矛盾和盲点。语气谦逊但犀利,常问'为什么'、'如何定义'、'是否总是如此'。",
				"color": Color(0.6, 0.9, 1.0),
				"enabled": true,
				"is_moderator": true
			},
			{
				"name": "批判者",
				"api_type": "SiliconFlow",
				"model": "zai-org/GLM-4.6",
				"api_key": "",
				"system_prompt": "你是建设性批评专家。专门挑战论点、找漏洞、揭示隐含假设。但你的批评是为了帮助完善理解,而非攻击。善用反例、边界情况、逻辑谬误检测。语气严谨但不刻薄。",
				"color": Color(1.0, 0.7, 0.6),
				"enabled": true,
				"is_moderator": false
			},
			{
				"name": "综合者",
				"api_type": "SiliconFlow",
				"model": "zai-org/GLM-4.6",
				"api_key": "",
				"system_prompt": "你是观点整合大师。擅长从多个角度提炼共识、发现不同观点的内在联系、构建知识框架。在讨论陷入对立时,你能找到更高维度的统一视角。语气包容、系统化。",
				"color": Color(0.7, 1.0, 0.7),
				"enabled": true,
				"is_moderator": false
			},
			{
				"name": "实践者",
				"api_type": "SiliconFlow",
				"model": "zai-org/GLM-4.6",
				"api_key": "",
				"system_prompt": "你是务实派专家。关注理论如何应用到真实场景,常问'实际怎么用'、'有什么限制条件'、'工程上如何实现'。擅长工程权衡、性能分析、可行性评估。语气直接、重实效。",
				"color": Color(1.0, 0.9, 0.5),
				"enabled": true,
				"is_moderator": false
			},
			{
				"name": "理论家",
				"api_type": "SiliconFlow",
				"model": "zai-org/GLM-4.6",
				"api_key": "",
				"system_prompt": "你是深度理论专家。深入探讨概念本质、数学原理、底层逻辑。擅长形式化定义、公理推导、抽象建模。不满足于表面解释,追求严格性和完备性。语气学术、精确。",
				"color": Color(0.8, 0.7, 1.0),
				"enabled": true,
				"is_moderator": false
			},
			{
				"name": "类比大师",
				"api_type": "SiliconFlow",
				"model": "zai-org/GLM-4.6",
				"api_key": "",
				"system_prompt": "你是比喻和类比专家。善用日常生活例子、跨领域类比解释复杂概念。能把抽象的理论具象化,让人'一听就懂'。但你知道类比的局限,会明确指出'类比在哪里失效'。语气生动、启发性强。",
				"color": Color(1.0, 0.8, 1.0),
				"enabled": true,
				"is_moderator": false
			},
			{
				"name": "魔鬼代言人",
				"api_type": "SiliconFlow",
				"model": "zai-org/GLM-4.6",
				"api_key": "",
				"system_prompt": "你是故意唱反调的辩手。即使大家都赞同,你也要找出被忽视的对立观点、潜在风险、特殊情况。目的是确保讨论全面,避免群体思维。语气挑衅但基于理性。",
				"color": Color(1.0, 0.6, 0.6),
				"enabled": true,
				"is_moderator": false
			},
			{
				"name": "学术派",
				"api_type": "SiliconFlow",
				"model": "zai-org/GLM-4.6",
				"api_key": "",
				"system_prompt": "你是引经据典的学者。熟悉相关领域的经典论文、权威教材、历史发展。擅长引用可靠来源、对比不同学派观点、指出学术争议点。但你也会警告'这个领域还在发展中'。语气严谨、博学。",
				"color": Color(0.9, 0.9, 0.7),
				"enabled": true,
				"is_moderator": false
			}
		]
		for d in defaults:
			upsert_agent(d)

func load_agents() -> void:
	_agents.clear()
	if FileAccess.file_exists(AGENTS_FILE):
		var f := FileAccess.open(AGENTS_FILE, FileAccess.READ)
		if f:
			var raw := f.get_as_text()
			f.close()
			var data = JSON.parse_string(raw)
			if data is Array:
				for item in data:
					# Convert HTML color strings back to Color objects
					if item.has("color") and item.color is String:
						item.color = Color.from_string(item.color, Color.WHITE)
					var v := _validate_and_fill(item)
					_agents.append(v)
	ensure_defaults_if_empty()
	# mirror agent AI settings to SettingsManager for per-agent API usage in APIManager
	_sync_settings_manager()
	agents_changed.emit()

func save_agents() -> void:
	var f := FileAccess.open(AGENTS_FILE, FileAccess.WRITE)
	if not f:
		push_error("Failed to open %s for write" % AGENTS_FILE)
		return
	
	# Convert Color objects to strings for JSON serialization
	var agents_data := []
	for agent in _agents:
		var agent_copy: Dictionary = agent.duplicate(true)
		if agent_copy.color is Color:
			agent_copy.color = agent_copy.color.to_html()
		agents_data.append(agent_copy)
	
	f.store_string(JSON.stringify(agents_data, "\t"))
	f.close()
	_sync_settings_manager()

func _validate_and_fill(agent: Dictionary) -> Dictionary:
	var a := {
		"name": agent.get("name", "").strip_edges(),
		"api_type": agent.get("api_type", "SiliconFlow"),
		"model": agent.get("model", "zai-org/GLM-4.6"),
		"api_key": agent.get("api_key", ""),
		"system_prompt": agent.get("system_prompt", ""),
		"color": agent.get("color", Color(0.8, 0.9, 1.0)),
		"enabled": agent.get("enabled", true),
		"is_moderator": agent.get("is_moderator", false)
	}
	
	# Ensure color is a Color object, not a string
	if a.color is String:
		a.color = Color.from_string(a.color, Color(0.8, 0.9, 1.0))
	elif not (a.color is Color):
		a.color = Color(0.8, 0.9, 1.0)
	
	# Allow env var expansion for api_key like ${ENV:OPENAI_API_KEY}
	if a.api_key is String and a.api_key.begins_with("${ENV:") and a.api_key.ends_with("}"):
		var varname: String = a.api_key.substr(6, a.api_key.length() - 7)
		var env_val: String = OS.get_environment(varname)
		if env_val != "":
			a.api_key = env_val
	return a

func _find_agent_index(name: String) -> int:
	for i in range(_agents.size()):
		if _agents[i].name == name:
			return i
	return -1

func _sync_settings_manager() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	if not sm:
		return
	
	# 设置全局默认AI配置
	var global_config := {
		"api_type": "SiliconFlow",
		"model": "zai-org/GLM-4.6",
		"api_key": ""
	}
	sm.set_global_ai_config(global_config)
	
	# For each agent, set a per-character AI setting so APIManager can route per-agent
	for a in _agents:
		var s := {
			"api_type": a.api_type,
			"model": a.model,
			"api_key": a.api_key,
			"show_ai_model_label": false
		}
		sm.set_character_ai_settings(a.name, s)

