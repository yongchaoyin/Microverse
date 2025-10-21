extends Node

# 自动化测试脚本 - 模拟用户操作

var terminal_chat: Control
var test_results: Array = []
var current_test := 0

func _ready() -> void:
	print("\n")
	print("═════════════════════════════════════════════")
	print("   自动化测试开始 - 模拟用户操作")
	print("═════════════════════════════════════════════")
	print("")

	# 等待场景完全加载
	await get_tree().create_timer(1.0).timeout

	# 查找 TerminalChat 节点
	# 在测试场景中，TerminalChat 是 Root 的子节点
	var root_node = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	terminal_chat = root_node.get_node_or_null("TerminalChat")

	if not terminal_chat:
		print("❌ 错误: 找不到 TerminalChat 节点!")
		print("   场景树结构:")
		_print_tree(get_tree().root, 0)
		get_tree().quit()
		return

	print("✅ 找到 TerminalChat 节点")
	print("   节点路径: %s" % terminal_chat.get_path())

	# 运行测试序列
	await run_all_tests()

	# 显示测试结果
	show_results()

	# 等待3秒后退出
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()

func run_all_tests() -> void:
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("开始测试序列")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	await test_01_check_nodes()
	await get_tree().create_timer(0.5).timeout

	await test_02_check_managers()
	await get_tree().create_timer(0.5).timeout

	await test_03_simulate_send_button()
	await get_tree().create_timer(2.0).timeout

	await test_04_simulate_manual_input()
	await get_tree().create_timer(2.0).timeout

	await test_05_check_agent_count()
	await get_tree().create_timer(0.5).timeout

func test_01_check_nodes() -> void:
	current_test += 1
	print("[测试 %d] 检查UI节点" % current_test)

	var output = terminal_chat.get_node_or_null("VBox/Scroll/Output")
	var input = terminal_chat.get_node_or_null("VBox/InputRow/Input")
	var send_btn = terminal_chat.get_node_or_null("VBox/InputRow/Send")

	if output:
		print("  ✅ Output (RichTextLabel) 存在")
		test_results.append({"test": "Output节点", "result": true})
	else:
		print("  ❌ Output 节点不存在!")
		test_results.append({"test": "Output节点", "result": false})

	if input:
		print("  ✅ Input (TextEdit) 存在")
		print("     类型: %s" % input.get_class())
		test_results.append({"test": "Input节点", "result": true})
	else:
		print("  ❌ Input 节点不存在!")
		test_results.append({"test": "Input节点", "result": false})

	if send_btn:
		print("  ✅ Send Button 存在")
		test_results.append({"test": "Send按钮", "result": true})
	else:
		print("  ❌ Send 按钮不存在!")
		test_results.append({"test": "Send按钮", "result": false})

func test_02_check_managers() -> void:
	current_test += 1
	print("\n[测试 %d] 检查管理器单例" % current_test)

	var agent_mgr = get_node_or_null("/root/AgentManager")
	var orchestrator = get_node_or_null("/root/MultiAgentOrchestrator")
	var settings_mgr = get_node_or_null("/root/SettingsManager")

	if agent_mgr:
		var agents: Array = agent_mgr.get_agents()
		var enabled: Array = agent_mgr.get_enabled_agents()
		print("  ✅ AgentManager 存在")
		print("     总角色数: %d" % agents.size())
		print("     启用角色数: %d" % enabled.size())
		test_results.append({"test": "AgentManager", "result": true, "enabled": enabled.size()})
	else:
		print("  ❌ AgentManager 不存在!")
		test_results.append({"test": "AgentManager", "result": false})

	if orchestrator:
		print("  ✅ MultiAgentOrchestrator 存在")
		print("     是否活动: %s" % orchestrator.is_active())
		test_results.append({"test": "Orchestrator", "result": true})
	else:
		print("  ❌ Orchestrator 不存在!")
		test_results.append({"test": "Orchestrator", "result": false})

	if settings_mgr:
		var settings: Dictionary = settings_mgr.get_settings()
		print("  ✅ SettingsManager 存在")
		print("     默认API: %s" % settings.get("api_type", "未知"))
		print("     默认模型: %s" % settings.get("model", "未知"))
		test_results.append({"test": "SettingsManager", "result": true})
	else:
		print("  ❌ SettingsManager 不存在!")
		test_results.append({"test": "SettingsManager", "result": false})

func test_03_simulate_send_button() -> void:
	current_test += 1
	print("\n[测试 %d] 模拟点击发送按钮" % current_test)

	var input = terminal_chat.get_node_or_null("VBox/InputRow/Input")
	var send_btn = terminal_chat.get_node_or_null("VBox/InputRow/Send")
	var output = terminal_chat.get_node_or_null("VBox/Scroll/Output")

	if not input or not send_btn or not output:
		print("  ❌ 缺少必要节点，跳过测试")
		test_results.append({"test": "发送按钮测试", "result": false})
		return

	# 记录点击前的输出内容
	var output_before: String = output.text
	var output_before_length: int = output_before.length()
	print("  📝 点击前输出长度: %d" % output_before_length)

	# 设置输入内容
	input.text = "测试消息：你好"
	print("  📝 设置输入内容: '%s'" % input.text)

	# 模拟点击发送按钮
	print("  🖱️  模拟点击发送按钮...")
	send_btn.emit_signal("pressed")

	# 等待处理
	await get_tree().process_frame
	await get_tree().process_frame

	# 检查输出是否变化
	var output_after: String = output.text
	var output_after_length: int = output_after.length()
	print("  📝 点击后输出长度: %d" % output_after_length)

	if output_after_length > output_before_length:
		print("  ✅ 输出内容增加了 %d 字符" % (output_after_length - output_before_length))
		print("  ✅ 发送按钮功能正常")
		test_results.append({"test": "发送按钮功能", "result": true})

		# 显示新增的内容（最后200个字符）
		var new_content := output_after.substr(max(0, output_after_length - 200))
		print("  📄 新增内容（最后200字符）:\n%s" % new_content)
	else:
		print("  ❌ 输出内容没有变化!")
		print("  ❌ 发送按钮可能没有工作")
		test_results.append({"test": "发送按钮功能", "result": false})

func test_04_simulate_manual_input() -> void:
	current_test += 1
	print("\n[测试 %d] 模拟手动输入和Enter键" % current_test)

	var input = terminal_chat.get_node_or_null("VBox/InputRow/Input")
	var output = terminal_chat.get_node_or_null("VBox/Scroll/Output")

	if not input or not output:
		print("  ❌ 缺少必要节点，跳过测试")
		test_results.append({"test": "Enter键测试", "result": false})
		return

	var output_before_length: int = output.text.length()

	# 设置输入内容
	input.text = "测试Enter键：你好世界"
	print("  📝 设置输入内容: '%s'" % input.text)

	# 模拟 Enter 键按下
	print("  ⌨️  模拟按下 Enter 键...")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	input.emit_signal("gui_input", event)

	# 等待处理
	await get_tree().process_frame
	await get_tree().process_frame

	var output_after_length: int = output.text.length()

	if output_after_length > output_before_length:
		print("  ✅ Enter键触发成功，输出增加了 %d 字符" % (output_after_length - output_before_length))
		test_results.append({"test": "Enter键功能", "result": true})
	else:
		print("  ❌ Enter键没有触发任何操作")
		print("  💡 提示: TextEdit 的 gui_input 信号可能需要特殊处理")
		test_results.append({"test": "Enter键功能", "result": false})

func test_05_check_agent_count() -> void:
	current_test += 1
	print("\n[测试 %d] 检查AI代理启用状态" % current_test)

	var agent_mgr = get_node_or_null("/root/AgentManager")
	if not agent_mgr:
		print("  ❌ AgentManager 不存在")
		test_results.append({"test": "代理启用检查", "result": false})
		return

	var enabled_agents: Array = agent_mgr.get_enabled_agents()
	print("  📊 启用的代理数量: %d" % enabled_agents.size())

	if enabled_agents.size() == 0:
		print("  ❌ 没有启用的代理!")
		print("  💡 建议: 运行 /reset 命令重置配置")
		test_results.append({"test": "代理启用检查", "result": false})
	else:
		print("  ✅ 有 %d 个代理已启用" % enabled_agents.size())
		for agent in enabled_agents:
			print("     - %s (%s)" % [agent.name, agent.api_type])
		test_results.append({"test": "代理启用检查", "result": true})

func _print_tree(node: Node, indent: int) -> void:
	var prefix := "  ".repeat(indent)
	print("%s- %s (%s)" % [prefix, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, indent + 1)

func show_results() -> void:
	print("\n")
	print("═════════════════════════════════════════════")
	print("   测试结果汇总")
	print("═════════════════════════════════════════════")

	var total := test_results.size()
	var passed := 0

	for result in test_results:
		var status := "✅" if result.result else "❌"
		print("%s %s" % [status, result.test])
		if result.result:
			passed += 1

		# 显示额外信息
		if result.has("enabled"):
			print("   └─ 启用代理: %d" % result.enabled)

	print("")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("总计: %d/%d 测试通过 (%.1f%%)" % [passed, total, (float(passed) / total * 100.0)])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	if passed == total:
		print("🎉 所有测试通过！系统运行正常。")
	elif passed >= total * 0.7:
		print("⚠️  大部分测试通过，但有一些问题需要解决。")
	else:
		print("❌ 多个测试失败，系统可能存在严重问题。")

	print("")
