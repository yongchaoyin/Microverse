extends Control

# UI 元素引用
var output: RichTextLabel
var input: LineEdit
var send_button: Button
var background: ColorRect

# 初始化
func _ready():
	# 创建UI布局
	output = RichTextLabel.new()
	output.name = "Output"
	output.custom_minimum_size = Vector2(400, 300)
	output.bbcode_enabled = true
	output.text = "窗口模式输入测试\n"
		
	input = LineEdit.new()
	input.name = "Input"
	input.placeholder_text = "在此输入..."
		
	send_button = Button.new()
	send_button.name = "SendButton"
	send_button.text = "发送"
		
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color.BLACK
		
	# 设置布局
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	add_child(vbox)
	
	vbox.add_child(output)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	vbox.add_child(hbox)
	
	hbox.add_child(input)
	hbox.add_child(send_button)
	
	add_child(background)
	background.move_to_front()
	
	# 连接信号
	if not input.gui_input.is_connected(_on_input_gui_input):
		input.gui_input.connect(_on_input_gui_input)
	if not send_button.pressed.is_connected(_on_send_button_pressed):
		send_button.pressed.connect(_on_send_button_pressed)
	
	# 设置焦点
	input.grab_focus()
	print("[WindowInputTest] 输入框焦点已设置")
	
	# 延迟一帧后测试输入
	await get_tree().process_frame
	_test_input_methods()
	
	# 强制刷新输出
	await get_tree().process_frame
	print("[WindowInputTest] 场景初始化完成")

func _test_input_methods():
	print("[WindowInputTest] 开始测试窗口模式下的输入处理")
	
	# 测试1: 直接调用_on_send
	print("[WindowInputTest] 测试1: 直接调用_on_send")
	input.text = "测试1: 直接调用"
	_on_send()
	
	# 等待一帧
	await get_tree().process_frame
	print("[WindowInputTest] 测试1完成")
	
	# 测试2: 模拟按键事件
	print("[WindowInputTest] 测试2: 模拟按键事件")
	input.text = "测试2: 按键事件"
	_simulate_key_event(KEY_ENTER)
	
	# 等待一帧
	await get_tree().process_frame
	print("[WindowInputTest] 测试2完成")
	
	# 测试3: 模拟按钮点击
	print("[WindowInputTest] 测试3: 模拟按钮点击")
	input.text = "测试3: 按钮点击"
	send_button.emit_signal("pressed")
	
	# 等待一帧
	await get_tree().process_frame
	print("[WindowInputTest] 测试3完成")
	
	# 测试4: 测试空格键
	print("[WindowInputTest] 测试4: 模拟空格键")
	input.text = "测试4: 空格键"
	_simulate_key_event(KEY_SPACE)
	
	# 等待一帧
	await get_tree().process_frame
	print("[WindowInputTest] 测试4完成")
	
	# 测试5: 测试其他按键
	print("[WindowInputTest] 测试5: 模拟其他按键")
	input.text = "测试5: 其他按键"
	_simulate_key_event(KEY_A)
	
	# 等待一帧
	await get_tree().process_frame
	print("[WindowInputTest] 测试5完成")
	
	# 测试6: 测试焦点状态
	print("[WindowInputTest] 测试6: 检查焦点状态")
	print("[WindowInputTest] 输入框是否有焦点: ", input.has_focus())
	print("[WindowInputTest] 当前场景是否有焦点: ", has_focus())
	
	# 等待一帧
	await get_tree().process_frame
	print("[WindowInputTest] 测试6完成")
	
	print("[WindowInputTest] 所有测试完成")

func _simulate_key_event(key_code):
	# 创建按键事件
	var event = InputEventKey.new()
	event.keycode = key_code
	event.pressed = true
	
	# 打印事件信息
	print("[WindowInputTest] 模拟按键事件 - 按键码: ", event.keycode, ", 按下状态: ", event.pressed, ", 窗口ID: ", event.window_id)
	
	# 尝试多种方式发送事件
	print("[WindowInputTest] 尝试方法1: Input.parse_input_event")
	Input.parse_input_event(event)
	
	# 等待一帧
	await get_tree().process_frame
	
	print("[WindowInputTest] 尝试方法2: input._gui_input")
	input._gui_input(event)
	
	# 等待一帧
	await get_tree().process_frame
	
	print("[WindowInputTest] 尝试方法3: 直接调用_on_send")
	_on_send()
	
	# 等待一帧
	await get_tree().process_frame
	
	print("[WindowInputTest] 尝试方法4: 设置窗口ID并发送事件")
	var event_with_window = InputEventKey.new()
	event_with_window.keycode = key_code
	event_with_window.pressed = true
	# 尝试设置窗口ID
	if get_window():
		print("[WindowInputTest] 当前窗口ID: ", get_window().get_id())
		# 注意：在Godot 4中，窗口ID可能不可设置或只读
		# 我们尝试发送事件到输入控件
		input.accept_event()
		input._gui_input(event_with_window)
	else:
		print("[WindowInputTest] 无法获取窗口")
	
	# 等待一帧
	await get_tree().process_frame
	
	print("[WindowInputTest] 尝试方法5: 使用InputEventAction")
	var action_event = InputEventAction.new()
	action_event.action = "ui_accept"
	action_event.pressed = true
	Input.parse_input_event(action_event)

func _on_input_gui_input(event: InputEvent) -> void:
	# 打印所有输入事件
	print("[WindowInputTest] 收到输入事件: ", event)
	
	if event is InputEventKey:
		print("[WindowInputTest] 键盘事件 - 按键码: ", event.keycode, ", 按下状态: ", event.pressed, ", 窗口ID: ", event.window_id)
		
		if event.pressed and event.keycode == KEY_ENTER:
			print("[WindowInputTest] 检测到Enter键，调用_on_send")
			_on_send()

func _on_send_button_pressed():
	print("[WindowInputTest] 发送按钮被点击")
	_on_send()

func _on_send():
	var text = input.text.strip_edges()
	if text.is_empty():
		print("[WindowInputTest] 输入为空，忽略")
		return
		
	print("[WindowInputTest] 处理输入: ", text)
	output.text += "\n> " + text
	input.text = ""