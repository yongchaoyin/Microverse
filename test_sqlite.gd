extends Node

## SQLite插件测试脚本
## 用于验证godot-sqlite插件是否正确安装和工作

func _ready():
	print("=== SQLite插件测试开始 ===")
	test_sqlite_installation()

func test_sqlite_installation():
	# 测试SQLite类是否可用
	var sqlite = SQLite.new()
	if sqlite == null:
		print("❌ SQLite类创建失败")
		return false
	
	print("✅ SQLite类创建成功")
	
	# 测试数据库连接
	var db_path = "user://test_database.db"
	var success = sqlite.open(db_path)
	if not success:
		print("❌ 数据库连接失败")
		return false
	
	print("✅ 数据库连接成功: ", db_path)
	
	# 测试创建表
	var table_created = sqlite.create_table("test_table", {
		"id": "INTEGER PRIMARY KEY AUTOINCREMENT",
		"name": "TEXT NOT NULL",
		"value": "INTEGER"
	})
	
	if table_created:
		print("✅ 测试表创建成功")
	else:
		print("❌ 测试表创建失败")
	
	# 测试插入数据
	var insert_success = sqlite.insert("test_table", {
		"name": "test_item",
		"value": 42
	})
	
	if insert_success:
		print("✅ 数据插入成功")
	else:
		print("❌ 数据插入失败")
	
	# 测试查询数据
	var results = sqlite.select("test_table", "name = 'test_item'")
	if results.size() > 0:
		print("✅ 数据查询成功，找到 ", results.size(), " 条记录")
	else:
		print("❌ 数据查询失败或无结果")
	
	# 关闭数据库
	sqlite.close()
	print("✅ 数据库连接已关闭")
	
	print("=== SQLite插件测试完成 ===")
	return true