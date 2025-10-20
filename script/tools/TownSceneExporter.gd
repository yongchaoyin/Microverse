extends Node
class_name TownSceneExporter

## 生成并保存镇区场景(Town_Auto.tscn)
## 不依赖现有Town场景，程序化构建基础节点与房屋、灯光系统

@export var map_size: Vector2 = Vector2(2400, 1920)
@export var output_scene_path: String = "res://scene/maps/Town_Auto.tscn"

func build_and_save(path: String = "") -> void:
	var save_path = path if path != "" else output_scene_path
	var root := _build_town_scene()
	var packed := PackedScene.new()
	var ok := packed.pack(root)
	if ok:
		var err := ResourceSaver.save(save_path, packed)
		if err == OK:
			print("[TownSceneExporter] ✓ 已保存镇区场景 -> %s" % save_path)
		else:
			push_error("[TownSceneExporter] 保存场景失败: code=%d" % err)
	else:
		push_error("[TownSceneExporter] 打包场景失败")

func _build_town_scene() -> Node2D:
	var town := Node2D.new()
	town.name = "Town_Auto"

	# 1) 昼夜系统
	var day_night := CanvasModulate.new()
	day_night.name = "DayNight"
	var day_script = load("res://script/world/DayNightCycle.gd")
	if day_script:
		day_night.set_script(day_script)
	else:
		push_warning("[TownSceneExporter] 缺少DayNightCycle脚本")
	town.add_child(day_night)

	# 2) 窗户灯光系统
	var window_lights := Node2D.new()
	window_lights.name = "WindowLights"
	var wl_script = load("res://script/world/WindowLights.gd")
	if wl_script:
		window_lights.set_script(wl_script)
		window_lights.auto_init_on_ready = true
	else:
		push_warning("[TownSceneExporter] 缺少WindowLights脚本")
	town.add_child(window_lights)

	# 3) 路灯系统
	var street_lights := Node2D.new()
	street_lights.name = "StreetLights"
	var sl_script = load("res://script/world/StreetLights.gd")
	if sl_script:
		street_lights.set_script(sl_script)
		street_lights.auto_init_on_ready = true
	else:
		push_warning("[TownSceneExporter] 缺少StreetLights脚本")
	town.add_child(street_lights)

	# 4) 房屋布局(上、下两排共8栋)
	var center := map_size * 0.5
	var top_y := center.y - 260
	var bottom_y := center.y + 140
	var xs = [800.0, 1000.0, 1400.0, 1600.0]
	var names_top = ["Tom", "Monica", "Stephen", "Lea"]
	var names_bottom = ["Alice", "Bob", "Eva", "Jack"]
	for i in range(xs.size()):
		var house_top = _create_house(names_top[i], Vector2(xs[i], top_y))
		town.add_child(house_top)
	for i in range(xs.size()):
		var house_bot = _create_house(names_bottom[i], Vector2(xs[i], bottom_y))
		town.add_child(house_bot)

	# 5) 相机（可选）
	var camera := load("res://script/CameraController.gd").new()
	camera.name = "Camera2D"
	camera.map_bounds = Rect2(Vector2.ZERO, map_size)
	camera.position = center
	camera.zoom = Vector2(1.0, 1.0)
	town.add_child(camera)

	# 6) 路灯简单分布（围绕镇中心）
	var light_scene: PackedScene = load("res://scene/world/StreetLight.tscn")
	if light_scene:
		var positions = [
			Vector2(center.x - 220, center.y - 220),
			Vector2(center.x + 220, center.y - 220),
			Vector2(center.x - 220, center.y + 220),
			Vector2(center.x + 220, center.y + 220),
			Vector2(center.x - 380, center.y),
			Vector2(center.x + 380, center.y),
			Vector2(center.x, center.y - 380),
			Vector2(center.x, center.y + 380),
		]
		for p in positions:
			var inst = light_scene.instantiate()
			inst.position = p
			inst.add_to_group("street_lights")
			street_lights.add_child(inst)
	else:
		push_warning("[TownSceneExporter] 缺少StreetLight.tscn，路灯不会生成")

	return town

func _create_house(hname: String, pos: Vector2) -> Node2D:
	var house := Building.new()
	house.name = "House_%s" % hname
	house.building_name = house.name
	house.building_type = "house"
	house.owner_id = hname
	house.position = pos

	# 外观占位(Sprite2D可选)
	var body := Sprite2D.new()
	body.name = "Sprite2D"
	body.modulate = Color(0.85, 0.75, 0.55)
	house.add_child(body)

	# 窗户容器与灯光
	var windows := Node2D.new()
	windows.name = "Windows"
	house.add_child(windows)

	var w1 := Light2D.new()
	w1.name = "WindowLight1"
	w1.position = Vector2(-40, -20)
	w1.enabled = false
	w1.energy = 0.0
	w1.add_to_group("window_lights")
	windows.add_child(w1)

	var w2 := Light2D.new()
	w2.name = "WindowLight2"
	w2.position = Vector2(40, -20)
	w2.enabled = false
	w2.energy = 0.0
	w2.add_to_group("window_lights")
	windows.add_child(w2)

	return house