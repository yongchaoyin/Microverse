extends Node

var test_input = "测试输入内容"

func _ready():
	print("[TestTerminalInput] 开始测试终端输入处理")
	
	# 模拟TerminalChat的_on_send方法
	_test_on_send(test_input)
	
	# 模拟MultiAgentOrchestrator的start方法
	_test_orchestrator_start("测试主题")

func _test_on_send(t: String):
	print("[TestTerminalInput] _on_send 被调用，输入内容: '%s'" % t)
	if t == "":
		print("[TestTerminalInput] 输入为空，忽略")
		return
	
	if t.begins_with("/"):
		print("[TestTerminalInput] 处理命令: %s" % t)
		# 这里应该处理命令，但我们跳过
	else:
		# 总是先显示用户消息
		print("[TestTerminalInput] 显示用户消息: %s" % t)
		# 模拟_append_line调用
		_test_append_line("user", "You", t, Color(0.85, 1.0, 0.85))
		
		# 模拟orchestrator调用
		print("[TestTerminalInput] 开始新的讨论")
		_test_orchestrator_start(t)

func _test_append_line(role: String, name: String, text: String, color: Color) -> void:
	print("[TestTerminalInput] _append_line 被调用 - role: %s, name: %s, text: %s" % [role, name, text])
	var prefix := ""
	match role:
		"system":
			prefix = "[System]"
		"user":
			prefix = "[你]"
		_:
			prefix = "[%s]" % name
	
	var final_text := "%s %s\n" % [prefix, text]
	print("[TestTerminalInput] 准备显示: %s" % final_text)

func _test_orchestrator_start(topic: String) -> void:
	print("[TestTerminalInput] orchestrator.start 被调用，主题: '%s'" % topic)
	
	# 模拟检查启用的代理
	var agents = ["苏格拉底", "批判者", "综合者"]  # 模拟启用的代理
	print("[TestTerminalInput] 启用的代理数量: %d" % agents.size())
	
	if agents.size() == 0:
		print("[TestTerminalInput] 没有启用的代理！")
		return
	
	print("[TestTerminalInput] 参与讨论的AI: %s" % ", ".join(agents))
	print("[TestTerminalInput] 开始讨论主题：「%s」" % topic)