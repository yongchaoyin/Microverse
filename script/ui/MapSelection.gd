extends Control

func _ready():
	# 连接地图选择按钮信号
	$MarginContainer/ScrollContainer/GridContainer/PanelContainer/VBoxContainer/OfficeButton.pressed.connect(_on_office_selected)
	$MarginContainer/ScrollContainer/GridContainer/PanelContainer/VBoxContainer/ParkButton.pressed.connect(_on_park_selected)
	$MarginContainer/ScrollContainer/GridContainer/PanelContainer/VBoxContainer/TownButton.pressed.connect(_on_town_selected)
	$BackButton.pressed.connect(_on_back_pressed)

func _on_office_selected():
	# 设置办公室故事背景
	BackgroundStoryManager.set_background("Office")
	# 加载办公室场景
	get_tree().change_scene_to_file("res://scene/maps/Office.tscn")

func _on_park_selected():
	# 设置公园故事背景
	BackgroundStoryManager.set_background("Park")
	# 加载公园场景
	get_tree().change_scene_to_file("res://scene/maps/Park.tscn")

func _on_town_selected():
	# 设置小镇故事背景
	BackgroundStoryManager.set_background("Town")
	# 加载小镇场景
	get_tree().change_scene_to_file("res://scene/maps/Town.tscn")

func _on_back_pressed():
	# 返回主菜单
	get_tree().change_scene_to_file("res://scene/MainMenu.tscn")
