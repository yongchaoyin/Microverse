extends Node

## JSON数据备份脚本
## 用于在SQLite迁移前备份现有的JSON数据

const BACKUP_DIR = "user://backup/"
const DATABASE_DIR = "user://database/"

func _ready():
	print("=== JSON数据备份开始 ===")
	backup_json_data()

func backup_json_data():
	# 创建备份目录
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("backup"):
		dir.make_dir("backup")
		print("✅ 创建备份目录: user://backup/")
	
	# 检查数据库目录是否存在
	if not dir.dir_exists("database"):
		print("ℹ️ 数据库目录不存在，无需备份")
		print("=== JSON数据备份完成 ===")
		return
	
	# 备份文件列表
	var files_to_backup = [
		"transactions.json",
		"memories.json", 
		"relationships.json",
		"metadata.json"
	]
	
	var backup_count = 0
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	
	for filename in files_to_backup:
		var source_path = DATABASE_DIR + filename
		var backup_path = BACKUP_DIR + timestamp + "_" + filename
		
		if FileAccess.file_exists(source_path):
			var success = copy_file(source_path, backup_path)
			if success:
				backup_count += 1
				print("✅ 备份文件: ", filename, " -> ", backup_path)
			else:
				print("❌ 备份失败: ", filename)
		else:
			print("ℹ️ 文件不存在，跳过: ", filename)
	
	if backup_count > 0:
		print("✅ 成功备份 ", backup_count, " 个JSON文件")
		
		# 创建备份信息文件
		var info_file = FileAccess.open(BACKUP_DIR + timestamp + "_backup_info.txt", FileAccess.WRITE)
		if info_file:
			info_file.store_line("JSON数据备份信息")
			info_file.store_line("备份时间: " + Time.get_datetime_string_from_system())
			info_file.store_line("备份文件数量: " + str(backup_count))
			info_file.store_line("备份文件:")
			for filename in files_to_backup:
				if FileAccess.file_exists(DATABASE_DIR + filename):
					info_file.store_line("- " + filename)
			info_file.close()
			print("✅ 创建备份信息文件")
	else:
		print("ℹ️ 没有找到需要备份的JSON文件")
	
	print("=== JSON数据备份完成 ===")

func copy_file(source: String, destination: String) -> bool:
	var source_file = FileAccess.open(source, FileAccess.READ)
	if not source_file:
		return false
	
	var dest_file = FileAccess.open(destination, FileAccess.WRITE)
	if not dest_file:
		source_file.close()
		return false
	
	dest_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	
	source_file.close()
	dest_file.close()
	
	return true