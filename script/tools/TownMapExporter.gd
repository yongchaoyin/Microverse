extends Node
class_name TownMapExporter

## Town地图导出器
## 用途：将当前场景渲染到离屏SubViewport，并导出为PNG
## 适合生成“全幅”地图图像（例如与map_bounds匹配的2400x1920）

@export var default_output_path: String = "user://TownMap_Full.png"
@export var default_resolution: Vector2i = Vector2i(2400, 1920)

func export_current_scene(output_path: String = "", resolution: Vector2i = Vector2i.ZERO) -> void:
	# 创建离屏视口
	var target_size: Vector2i = resolution if resolution != Vector2i.ZERO else default_resolution
	var subvp := SubViewport.new()
	subvp.size = target_size
	subvp.render_target_update_mode = SubViewport.UPDATE_ONCE
	subvp.disable_3d = true
	subvp.transparent_bg = false
	add_child(subvp)

	# 复制当前场景（避免直接操作运行中的场景）
	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_error("[TownMapExporter] 当前没有运行场景，无法导出")
		return
	var scene_copy := current_scene.duplicate()
	subvp.add_child(scene_copy)

	# 等待渲染帧更新
	await get_tree().process_frame
	await get_tree().process_frame

	# 获取渲染结果
	var tex := subvp.get_texture()
	if tex == null:
		push_error("[TownMapExporter] SubViewport未生成纹理，导出失败")
		scene_copy.queue_free()
		subvp.queue_free()
		return

	var img := tex.get_image()
	var save_path := output_path if output_path != "" else default_output_path
	var err := img.save_png(save_path)
	if err == OK:
		print("[TownMapExporter] ✓ 地图图片已导出 -> %s" % save_path)
	else:
		push_error("[TownMapExporter] 保存PNG失败: %s (code=%d)" % [save_path, err])

	# 清理
	scene_copy.queue_free()
	subvp.queue_free()