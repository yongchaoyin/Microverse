@tool
extends EditorPlugin

func _enter_tree():
	print("[Godot-SQLite] Plugin enabled")

func _exit_tree():
	print("[Godot-SQLite] Plugin disabled")