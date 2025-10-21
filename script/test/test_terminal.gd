extends Node

# 测试脚本：验证终端聊天的核心功能

func _ready() -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("开始测试终端聊天系统")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	await get_tree().process_frame

	test_agent_manager()
	test_settings_manager()
	test_orchestrator()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("测试完成")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

func test_agent_manager() -> void:
	print("\n[测试 1] AgentManager")
	var agent_mgr = get_node_or_null("/root/AgentManager")

	if not agent_mgr:
		print("  ❌ AgentManager 未找到!")
		return

	print("  ✅ AgentManager 已加载")

	var agents: Array = agent_mgr.get_agents()
	print("  总角色数: %d" % agents.size())

	if agents.size() == 0:
		print("  ⚠️  没有角色！检查 agents.json 是否存在或默认配置是否加载")
		return

	var enabled_agents: Array = agent_mgr.get_enabled_agents()
	print("  启用角色数: %d" % enabled_agents.size())

	if enabled_agents.size() == 0:
		print("  ❌ 没有启用的角色！")
		print("  提示：运行游戏后在终端输入 /reset 重置配置")
	else:
		print("  ✅ 有启用的角色")
		for agent in enabled_agents:
			print("    - %s (%s / %s)" % [agent.name, agent.api_type, agent.model])

func test_settings_manager() -> void:
	print("\n[测试 2] SettingsManager")
	var settings_mgr = get_node_or_null("/root/SettingsManager")

	if not settings_mgr:
		print("  ❌ SettingsManager 未找到!")
		return

	print("  ✅ SettingsManager 已加载")

	var settings: Dictionary = settings_mgr.get_settings()
	print("  默认 API 类型: %s" % settings.get("api_type", "未知"))
	print("  默认模型: %s" % settings.get("model", "未知"))

	var global_config: Dictionary = settings_mgr.global_ai_config
	print("  全局 API 类型: %s" % global_config.get("api_type", "未知"))
	print("  全局模型: %s" % global_config.get("model", "未知"))

func test_orchestrator() -> void:
	print("\n[测试 3] MultiAgentOrchestrator")
	var orchestrator = get_node_or_null("/root/MultiAgentOrchestrator")

	if not orchestrator:
		print("  ❌ MultiAgentOrchestrator 未找到!")
		return

	print("  ✅ MultiAgentOrchestrator 已加载")
	print("  是否活动: %s" % ("是" if orchestrator.is_active() else "否"))
