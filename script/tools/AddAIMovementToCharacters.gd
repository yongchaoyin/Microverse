@tool
extends EditorScript

# AI移动控制器批量添加工具
# 用途: 为所有角色场景添加AIMovementController组件
# 使用方法:
#   1. 在Godot编辑器中: File → Run Script (或者按 Ctrl+Shift+X)
#   2. 选择此脚本文件
#   3. 点击 Run

const AI_MOVEMENT_SCRIPT_PATH = "res://script/navigation/AIMovementController.gd"

func _run():
	print("\n=== 开始为角色添加AIMovementController ===\n")

	# 所有角色场景路径
	var character_scenes = [
		"res://scene/characters/Alice.tscn",
		"res://scene/characters/Tom.tscn",
		"res://scene/characters/Grace.tscn",
		"res://scene/characters/Jack.tscn",
		"res://scene/characters/Joe.tscn",
		"res://scene/characters/Lea.tscn",
		"res://scene/characters/Monica.tscn",
		"res://scene/characters/Stephen.tscn",
	]

	var success_count = 0
	var skip_count = 0
	var error_count = 0

	for scene_path in character_scenes:
		var result = add_ai_movement_to_character(scene_path)
		match result:
			"success":
				success_count += 1
			"skip":
				skip_count += 1
			"error":
				error_count += 1

	print("\n=== 处理完成 ===")
	print("✓ 成功添加: %d" % success_count)
	print("⊘ 已存在跳过: %d" % skip_count)
	print("✗ 错误: %d" % error_count)
	print("")

func add_ai_movement_to_character(scene_path: String) -> String:
	var character_name = scene_path.get_file().get_basename()

	# 检查场景文件是否存在
	if not FileAccess.file_exists(scene_path):
		print("✗ [%s] 场景文件不存在: %s" % [character_name, scene_path])
		return "error"

	# 加载场景
	var scene = load(scene_path) as PackedScene
	if not scene:
		print("✗ [%s] 无法加载场景" % character_name)
		return "error"

	var character = scene.instantiate()
	if not character:
		print("✗ [%s] 无法实例化场景" % character_name)
		return "error"

	# 检查是否已有AIMovementController
	if character.has_node("AIMovementController"):
		print("⊘ [%s] 已存在AIMovementController,跳过" % character_name)
		character.queue_free()
		return "skip"

	# 加载AIMovementController脚本
	var ai_movement_script = load(AI_MOVEMENT_SCRIPT_PATH)
	if not ai_movement_script:
		print("✗ [%s] 无法加载AIMovementController脚本" % character_name)
		character.queue_free()
		return "error"

	# 创建AIMovementController节点
	var ai_movement = Node.new()
	ai_movement.name = "AIMovementController"
	ai_movement.set_script(ai_movement_script)

	# 添加到角色
	character.add_child(ai_movement)
	ai_movement.owner = character  # 设置owner以便保存

	# 保存场景
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(character)

	if result != OK:
		print("✗ [%s] 打包场景失败" % character_name)
		character.queue_free()
		return "error"

	result = ResourceSaver.save(packed_scene, scene_path)

	if result != OK:
		print("✗ [%s] 保存场景失败" % character_name)
		character.queue_free()
		return "error"

	print("✓ [%s] AIMovementController添加成功" % character_name)
	character.queue_free()
	return "success"
