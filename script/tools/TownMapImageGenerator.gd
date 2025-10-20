extends Node
class_name TownMapImageGenerator

## 生成镇区PNG(不依赖Town.tscn)，通过SubViewport+TownMapPainter离屏渲染。

@export var default_output_path: String = "user://TownMap_Generated.png"
@export var default_resolution: Vector2i = Vector2i(2400, 1920)

func generate(output_path: String = "", resolution: Vector2i = Vector2i.ZERO) -> void:
	var target_size: Vector2i = resolution if resolution != Vector2i.ZERO else default_resolution
	var subvp := SubViewport.new()
	subvp.size = target_size
	subvp.render_target_update_mode = SubViewport.UPDATE_ONCE
	subvp.disable_3d = true
	subvp.transparent_bg = false
	add_child(subvp)

	# 添加绘制器
	var painter := TownMapPainter.new()
	painter.map_size = Vector2(target_size.x, target_size.y)
	subvp.add_child(painter)
	painter.queue_redraw()

	# 等待渲染
	await get_tree().process_frame
	await get_tree().process_frame

	# 导出
	var tex := subvp.get_texture()
	if tex == null:
		push_error("[TownMapImageGenerator] SubViewport未生成纹理")
		painter.queue_free()
		subvp.queue_free()
		return
	var img := tex.get_image()
	var save_path := output_path if output_path != "" else default_output_path
	var err := img.save_png(save_path)
	if err == OK:
		print("[TownMapImageGenerator] ✓ 已生成镇区地图 -> %s" % save_path)
	else:
		push_error("[TownMapImageGenerator] 保存PNG失败: %s (code=%d)" % [save_path, err])

	# 清理
	painter.queue_free()
	subvp.queue_free()