extends Node2D
class_name TownMapPainter

## 纯绘制的镇区地图(不依赖现有场景)。
## 使用draw_*原语绘制道路、房屋、湖泊、绿地等元素。

@export var map_size: Vector2 = Vector2(2400, 1920)
@export var road_width: float = 64.0
@export var house_size: Vector2 = Vector2(160, 120)

# 调色板
@export var color_grass := Color(0.36, 0.65, 0.36)
@export var color_road := Color(0.25, 0.25, 0.25)
@export var color_pavement := Color(0.70, 0.70, 0.70)
@export var color_house := Color(0.85, 0.75, 0.55)
@export var color_roof := Color(0.60, 0.30, 0.25)
@export var color_door := Color(0.40, 0.25, 0.10)
@export var color_window := Color(0.90, 0.90, 0.60)
@export var color_water := Color(0.20, 0.45, 0.90)
@export var color_park := Color(0.22, 0.50, 0.22)
@export var color_tree := Color(0.15, 0.40, 0.15)

func _draw():
	# 背景草地
	draw_rect(Rect2(Vector2.ZERO, map_size), color_grass, true)

	var center := map_size * 0.5
	var half_road := road_width * 0.5

	# 横向主路
	draw_rect(Rect2(Vector2(0, center.y - half_road), Vector2(map_size.x, road_width)), color_road, true)
	# 纵向主路
	draw_rect(Rect2(Vector2(center.x - half_road, 0), Vector2(road_width, map_size.y)), color_road, true)

	# 镇中心铺装圆区
	draw_circle(center, 160.0, color_pavement)

	# 湖泊(左上)
	draw_rect(Rect2(Vector2(280, 280), Vector2(420, 320)), color_water, true)
	# 公园(右上)
	draw_rect(Rect2(Vector2(map_size.x - 980, 300), Vector2(600, 480)), color_park, true)
	# 公园树点缀
	for i in range(12):
		var tx := map_size.x - 980 + 50 + (i % 4) * 140
		var ty := 340 + int(i / 4) * 140
		draw_circle(Vector2(tx, ty), 30.0, color_tree)

	# 房屋位置布局(上下两排共8栋)
	var top_y := center.y - 260
	var bottom_y := center.y + 140
	var xs := [800.0, 1000.0, 1400.0, 1600.0]
	for x in xs:
		_draw_house(Vector2(x, top_y))
	for x in xs:
		_draw_house(Vector2(x, bottom_y))

func _draw_house(pos: Vector2):
	# 房屋主体
	var body_rect := Rect2(pos - house_size * 0.5, house_size)
	draw_rect(body_rect, color_house, true)
	# 屋顶(三角形)
	var top := body_rect.position
	var roof_h := 50.0
	var roof_points := PackedVector2Array([
		Vector2(top.x, top.y),
		Vector2(top.x + house_size.x, top.y),
		Vector2(top.x + house_size.x * 0.5, top.y - roof_h)
	])
	draw_polygon(roof_points, [color_roof])
	# 门
	var door_size := Vector2(24, 44)
	var door_pos := Vector2(body_rect.position.x + house_size.x * 0.5 - door_size.x * 0.5,
		body_rect.position.y + house_size.y - door_size.y - 8)
	draw_rect(Rect2(door_pos, door_size), color_door, true)
	# 窗户
	var win := Vector2(20, 20)
	var wpad := 18
	draw_rect(Rect2(body_rect.position + Vector2(wpad, wpad + 20), win), color_window, true)
	draw_rect(Rect2(body_rect.position + Vector2(house_size.x - wpad - win.x, wpad + 20), win), color_window, true)
	draw_rect(Rect2(body_rect.position + Vector2(wpad, house_size.y * 0.5), win), color_window, true)
	draw_rect(Rect2(body_rect.position + Vector2(house_size.x - wpad - win.x, house_size.y * 0.5), win), color_window, true)