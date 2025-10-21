extends Node

func _ready():
	print("开始测试API连接...")
	
	# 获取APIManager实例
	var api_mgr = get_node_or_null("/root/APIManager")
	if not api_mgr:
		print("错误：无法获取APIManager实例")
		get_tree().quit()
		return
	
	# 获取当前设置
	var settings_mgr = get_node_or_null("/root/SettingsManager")
	if not settings_mgr:
		print("错误：无法获取SettingsManager实例")
		get_tree().quit()
		return
	
	var settings = settings_mgr.get_settings()
	print("当前API设置：")
	print("  API类型：", settings.api_type)
	print("  模型：", settings.model)
	print("  API密钥：", settings.api_key.substr(0, 10) + "...")
	
	# 测试API请求
	print("\n发送测试请求...")
	var test_prompt = "请回答：1+1等于几？"
	var http_request = api_mgr.generate_dialog(test_prompt)
	
	if not http_request:
		print("错误：无法创建HTTP请求")
		get_tree().quit()
		return
	
	print("HTTP请求已创建，等待响应...")
	
	# 等待响应
	http_request.request_completed.connect(_on_request_completed)
	
	# 设置超时
	var timer = get_tree().create_timer(30.0)
	timer.timeout.connect(func():
		print("请求超时")
		get_tree().quit()
	)

func _on_request_completed(result, response_code, headers, body):
	print("\n请求完成！")
	print("结果：", result)
	print("响应代码：", response_code)
	
	if result == HTTPRequest.RESULT_SUCCESS:
		var response_text = body.get_string_from_utf8()
		print("响应内容：", response_text)
		
		# 尝试解析JSON
		var json = JSON.new()
		var parse_result = json.parse(response_text)
		if parse_result == OK:
			var response_data = json.data
			print("\n解析后的JSON：")
			print(response_data)
			
			# 使用APIConfig解析响应
			var settings_mgr = get_node_or_null("/root/SettingsManager")
			if settings_mgr:
				var settings = settings_mgr.get_settings()
				var parsed_text = APIConfig.parse_response(settings.api_type, response_data)
				print("\n解析后的文本：", parsed_text)
		else:
			print("JSON解析失败：", parse_result)
	else:
		print("请求失败，错误代码：", response_code)
	
	get_tree().quit()