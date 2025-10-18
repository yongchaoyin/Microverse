extends Node2D

# 地点标记创建工具
# 用途: 在Office场景中自动创建所有地点标记
# 使用方法:
#   1. 打开 scene/maps/Office.tscn
#   2. 将此脚本附加到Office根节点
#   3. 运行场景 (F5)
#   4. 地点标记自动创建
#   5. 保存场景 (Ctrl+S)
#   6. 移除此脚本

func _ready():
	print("\n=== 开始创建地点标记 ===\n")
	create_all_locations()
	print("\n=== 地点标记创建完成! ===")
	print("请保存场景 (Ctrl+S) 然后移除此脚本\n")

func create_all_locations():
	# 地点数据: [id, name_cn, position, type, capacity]
	# 坐标需要根据实际Office场景调整
	var locations_data = [
		# 办公区域
		["office_stephen", "CEO办公室", Vector2(1200, 800), "OFFICE", 3],
		["office_hr", "HR办公室", Vector2(900, 800), "OFFICE", 2],
		["desk_alice", "Alice的工位", Vector2(600, 600), "OFFICE", 1],
		["desk_tom", "Tom的工位", Vector2(700, 600), "OFFICE", 1],
		["desk_grace", "Grace的工位", Vector2(800, 600), "OFFICE", 1],
		["desk_jack", "Jack的工位", Vector2(600, 700), "OFFICE", 1],
		["desk_joe", "Joe的工位", Vector2(700, 700), "OFFICE", 1],
		["desk_lea", "Lea的工位", Vector2(800, 700), "OFFICE", 1],
		["desk_monica", "Monica的工位", Vector2(900, 700), "OFFICE", 1],

		# 会议室
		["meeting_room_01", "会议室1", Vector2(400, 300), "MEETING_ROOM", 10],
		["meeting_room_02", "会议室2", Vector2(400, 500), "MEETING_ROOM", 6],

		# 公共区域
		["cafeteria", "员工食堂", Vector2(2000, 1500), "CAFETERIA", 20],
		["coffee_shop", "休息咖啡区", Vector2(1600, 900), "COFFEE_SHOP", 8],
		["lounge", "休息室", Vector2(1400, 1100), "LOUNGE", 12],

		# 功能区域
		["bathroom_main", "洗手间", Vector2(500, 1200), "BATHROOM", 5],
		["gym", "健身房", Vector2(2200, 500), "GYM", 15],

		# 入口/走廊
		["entrance_main", "大门入口", Vector2(200, 200), "ENTRANCE", -1],
		["hallway_main", "主走廊", Vector2(800, 400), "HALLWAY", -1],
		["reception", "前台接待", Vector2(300, 300), "OTHER", 3],
	]

	# 检查是否已存在Locations容器
	var locations_container = get_node_or_null("Locations")

	if locations_container:
		print("⚠ 发现已存在Locations节点,将清空并重新创建")
		locations_container.queue_free()

	# 创建新的Locations容器
	locations_container = Node2D.new()
	locations_container.name = "Locations"
	add_child(locations_container)
	locations_container.owner = self  # 确保保存到场景

	# 创建所有地点标记
	for loc_data in locations_data:
		create_location_marker(
			locations_container,
			loc_data[0],  # id
			loc_data[1],  # name_cn
			loc_data[2],  # position
			loc_data[3],  # type
			loc_data[4]   # capacity
		)

	print("\n共创建 %d 个地点标记" % locations_data.size())

func create_location_marker(
	parent: Node,
	id: String,
	name_cn: String,
	position: Vector2,
	type: String,
	capacity: int
):
	var marker = Marker2D.new()
	marker.name = id  # 使用ID作为节点名称
	marker.global_position = position

	# 添加到location组 (LocationManager会自动加载)
	marker.add_to_group("location")

	# 设置元数据
	marker.set_meta("location_id", id)
	marker.set_meta("location_name_cn", name_cn)
	marker.set_meta("location_type", type)
	marker.set_meta("location_capacity", capacity)

	# 添加到父节点
	parent.add_child(marker)
	marker.owner = get_tree().edited_scene_root if get_tree().edited_scene_root else self

	print("✓ 创建地点: %s (%s) at %v" % [name_cn, id, position])

# 可选: 在编辑器中可视化地点标记
func _draw():
	if not has_node("Locations"):
		return

	var locations = get_node("Locations")
	for marker in locations.get_children():
		if marker is Marker2D:
			# 绘制地点标记圆圈
			draw_circle(marker.global_position, 20, Color(0, 1, 0, 0.5))

			# 绘制地点名称
			var name_cn = marker.get_meta("location_name_cn", "")
			if name_cn != "":
				draw_string(
					ThemeDB.fallback_font,
					marker.global_position + Vector2(-30, -30),
					name_cn,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					16,
					Color.WHITE
				)
