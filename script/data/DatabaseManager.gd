extends Node

## ========================================
## DatabaseManager - 数据库管理器 (SQLite 版本)
## ========================================
##
## 功能:
## - 高频数据持久化 (交易日志、记忆、关系历史)
## - SQLite 数据库存储 (主要模式)
## - JSON 文件存储 (降级模式,SQLite 不可用时)
## - 自动数据迁移 (JSON → SQLite)
## - 自动备份和清理
## - SQL 查询接口
##
## 存储后端: SQLite (user://database/game.db) 或 JSON (降级)
##
## 依赖:
## - TimeSystem (获取时间戳)
## - EventBus (发送数据库事件)
## - godot-sqlite 插件 (可选,不可用时降级到 JSON)
##
## 作者: Claude (Sonnet 4.5)
## 创建日期: 2025-10-20
## 版本: 2.0.0 (SQLite 升级版)
## ========================================

## ========================================
## 信号定义
## ========================================

signal database_initialized()
signal transaction_logged(transaction_id: String)
signal memory_stored(memory_id: String)
signal database_backed_up(backup_path: String)
signal migration_completed(records_migrated: int)

## ========================================
## 常量定义
## ========================================

const DATABASE_DIR = "user://database"
const SQLITE_DB_PATH = "user://database/game.db"

## JSON 降级文件 (SQLite 不可用时使用)
const TRANSACTIONS_FILE = "user://database/transactions.json"
const MEMORIES_FILE = "user://database/memories.json"
const RELATIONSHIPS_FILE = "user://database/relationships.json"
const METADATA_FILE = "user://database/metadata.json"

## 自动清理配置 (仅JSON模式)
const MAX_TRANSACTIONS = 10000
const MAX_MEMORIES = 50000
const MAX_RELATIONSHIP_HISTORY = 5000
const BACKUP_INTERVAL_DAYS = 7

## ========================================
## 数据库引擎类型
## ========================================

enum EngineType {
	SQLITE,  # 使用 SQLite 数据库
	JSON     # 降级到 JSON 文件
}

## ========================================
## 核心数据
## ========================================

## 当前使用的引擎类型
var _engine_type: EngineType = EngineType.JSON

## SQLite 数据库实例
var _db: SQLite = null

## JSON 降级模式的数据 (仅在 JSON 模式使用)
var _transactions: Array = []
var _memories: Array = []
var _relationship_history: Array = []
var _metadata: Dictionary = {}

## 系统引用
var _time_system: Node = null
var _event_bus: Node = null
var _is_initialized: bool = false

## ========================================
## 生命周期
## ========================================

func _ready() -> void:
	_time_system = get_node_or_null("/root/TimeSystem")
	_event_bus = get_node_or_null("/root/EventBus")

	_initialize_database()

	print("[DatabaseManager] 数据库管理器初始化完成 (%s)" % ("SQLite" if _engine_type == EngineType.SQLITE else "JSON"))

## ========================================
## 数据库初始化
## ========================================

func _initialize_database() -> void:
	# 创建数据库目录
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("database"):
		dir.make_dir("database")

	# 检测 SQLite 插件是否可用
	if _check_sqlite_available():
		print("[DatabaseManager] 使用 SQLite 数据库引擎")
		_engine_type = EngineType.SQLITE
		_initialize_sqlite()
	else:
		push_warning("[DatabaseManager] SQLite 插件不可用,降级到 JSON 存储")
		print("[DatabaseManager] 请参考 docs/runing/14_SQLite_安装与升级指南.md 安装 SQLite 插件")
		_engine_type = EngineType.JSON
		_initialize_json()

	_is_initialized = true
	database_initialized.emit()

	if _event_bus:
		_event_bus.emit_signal("system_initialized", "DatabaseManager")

func _check_sqlite_available() -> bool:
	# 尝试创建 SQLite 实例
	var test_db = SQLite.new()
	return test_db != null

## ========================================
## SQLite 初始化
## ========================================

func _initialize_sqlite() -> void:
	_db = SQLite.new()
	_db.path = SQLITE_DB_PATH
	_db.open_db()

	# 创建表结构
	_create_sqlite_tables()

	# 创建索引
	_create_sqlite_indexes()

	# 检查是否需要从 JSON 迁移数据
	_check_and_migrate_from_json()

	print("[DatabaseManager] SQLite 数据库初始化完成")
	_print_sqlite_stats()

func _create_sqlite_tables() -> void:
	# 交易表
	_db.query("""
		CREATE TABLE IF NOT EXISTS transactions (
			id TEXT PRIMARY KEY,
			timestamp REAL NOT NULL,
			buyer_id TEXT NOT NULL,
			seller_id TEXT NOT NULL,
			item_id TEXT NOT NULL,
			amount INTEGER NOT NULL,
			channel TEXT NOT NULL
		);
	""")

	# 记忆表
	_db.query("""
		CREATE TABLE IF NOT EXISTS memories (
			id TEXT PRIMARY KEY,
			ai_id TEXT NOT NULL,
			timestamp REAL NOT NULL,
			type TEXT NOT NULL,
			content TEXT NOT NULL,
			importance REAL NOT NULL,
			valence REAL NOT NULL
		);
	""")

	# 关系历史表
	_db.query("""
		CREATE TABLE IF NOT EXISTS relationship_history (
			id TEXT PRIMARY KEY,
			timestamp REAL NOT NULL,
			source_id TEXT NOT NULL,
			target_id TEXT NOT NULL,
			channel TEXT NOT NULL,
			delta REAL NOT NULL,
			reason TEXT
		);
	""")

	# 元数据表
	_db.query("""
		CREATE TABLE IF NOT EXISTS metadata (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		);
	""")

func _create_sqlite_indexes() -> void:
	# 交易表索引
	_db.query("CREATE INDEX IF NOT EXISTS idx_transactions_buyer ON transactions(buyer_id);")
	_db.query("CREATE INDEX IF NOT EXISTS idx_transactions_seller ON transactions(seller_id);")
	_db.query("CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions(timestamp);")

	# 记忆表索引
	_db.query("CREATE INDEX IF NOT EXISTS idx_memories_ai_id ON memories(ai_id);")
	_db.query("CREATE INDEX IF NOT EXISTS idx_memories_timestamp ON memories(timestamp);")
	_db.query("CREATE INDEX IF NOT EXISTS idx_memories_importance ON memories(importance);")
	_db.query("CREATE INDEX IF NOT EXISTS idx_memories_type ON memories(ai_id, type);")

	# 关系历史表索引
	_db.query("CREATE INDEX IF NOT EXISTS idx_relationships_source_target ON relationship_history(source_id, target_id);")
	_db.query("CREATE INDEX IF NOT EXISTS idx_relationships_timestamp ON relationship_history(timestamp);")

func _check_and_migrate_from_json() -> void:
	# 检查是否已经迁移过
	_db.query("SELECT value FROM metadata WHERE key = 'migrated_from_json';")
	if _db.query_result.size() > 0:
		return  # 已经迁移过

	# 检查 JSON 文件是否存在
	if not FileAccess.file_exists(TRANSACTIONS_FILE) and not FileAccess.file_exists(MEMORIES_FILE):
		# 没有旧数据需要迁移
		_db.query("INSERT OR REPLACE INTO metadata (key, value) VALUES ('migrated_from_json', 'true');")
		return

	print("[DatabaseManager] 检测到 JSON 数据,开始迁移...")
	var migrated_count = 0

	# 迁移交易
	migrated_count += _migrate_transactions_from_json()

	# 迁移记忆
	migrated_count += _migrate_memories_from_json()

	# 迁移关系历史
	migrated_count += _migrate_relationships_from_json()

	# 标记迁移完成
	_db.query("INSERT OR REPLACE INTO metadata (key, value) VALUES ('migrated_from_json', 'true');")

	print("[DatabaseManager] 数据迁移完成,共迁移 %d 条记录" % migrated_count)
	migration_completed.emit(migrated_count)

func _migrate_transactions_from_json() -> int:
	if not FileAccess.file_exists(TRANSACTIONS_FILE):
		return 0

	var file = FileAccess.open(TRANSACTIONS_FILE, FileAccess.READ)
	if not file:
		return 0

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK:
		return 0

	var transactions = json.data
	if not transactions is Array:
		return 0

	_db.query("BEGIN TRANSACTION;")
	for transaction in transactions:
		_db.query("INSERT INTO transactions (id, timestamp, buyer_id, seller_id, item_id, amount, channel) VALUES (?, ?, ?, ?, ?, ?, ?);", [
			transaction.get("id", ""),
			transaction.get("timestamp", 0.0),
			transaction.get("buyer_id", ""),
			transaction.get("seller_id", ""),
			transaction.get("item_id", ""),
			transaction.get("amount", 0),
			transaction.get("channel", "")
		])
	_db.query("COMMIT;")

	print("[DatabaseManager] 从 JSON 迁移了 %d 条交易记录" % transactions.size())
	return transactions.size()

func _migrate_memories_from_json() -> int:
	if not FileAccess.file_exists(MEMORIES_FILE):
		return 0

	var file = FileAccess.open(MEMORIES_FILE, FileAccess.READ)
	if not file:
		return 0

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK:
		return 0

	var memories = json.data
	if not memories is Array:
		return 0

	_db.query("BEGIN TRANSACTION;")
	for memory in memories:
		_db.query("INSERT INTO memories (id, ai_id, timestamp, type, content, importance, valence) VALUES (?, ?, ?, ?, ?, ?, ?);", [
			memory.get("id", ""),
			memory.get("ai_id", ""),
			memory.get("timestamp", 0.0),
			memory.get("type", ""),
			memory.get("content", ""),
			memory.get("importance", 0.0),
			memory.get("valence", 0.0)
		])
	_db.query("COMMIT;")

	print("[DatabaseManager] 从 JSON 迁移了 %d 条记忆数据" % memories.size())
	return memories.size()

func _migrate_relationships_from_json() -> int:
	if not FileAccess.file_exists(RELATIONSHIPS_FILE):
		return 0

	var file = FileAccess.open(RELATIONSHIPS_FILE, FileAccess.READ)
	if not file:
		return 0

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) != OK:
		return 0

	var relationships = json.data
	if not relationships is Array:
		return 0

	_db.query("BEGIN TRANSACTION;")
	for record in relationships:
		_db.query("INSERT INTO relationship_history (id, timestamp, source_id, target_id, channel, delta, reason) VALUES (?, ?, ?, ?, ?, ?, ?);", [
			record.get("id", ""),
			record.get("timestamp", 0.0),
			record.get("source_id", ""),
			record.get("target_id", ""),
			record.get("channel", ""),
			record.get("delta", 0.0),
			record.get("reason", "")
		])
	_db.query("COMMIT;")

	print("[DatabaseManager] 从 JSON 迁移了 %d 条关系历史" % relationships.size())
	return relationships.size()

func _print_sqlite_stats() -> void:
	_db.query("SELECT COUNT(*) as count FROM transactions;")
	var tx_count = _db.query_result[0]["count"] if _db.query_result.size() > 0 else 0

	_db.query("SELECT COUNT(*) as count FROM memories;")
	var mem_count = _db.query_result[0]["count"] if _db.query_result.size() > 0 else 0

	_db.query("SELECT COUNT(*) as count FROM relationship_history;")
	var rel_count = _db.query_result[0]["count"] if _db.query_result.size() > 0 else 0

	print("  - 交易记录: %d 条" % tx_count)
	print("  - 记忆数据: %d 条" % mem_count)
	print("  - 关系历史: %d 条" % rel_count)

## ========================================
## JSON 初始化 (降级模式)
## ========================================

func _initialize_json() -> void:
	_load_transactions()
	_load_memories()
	_load_relationship_history()
	_load_metadata()

	print("[DatabaseManager] JSON 数据库初始化完成")
	print("  - 交易记录: %d 条" % _transactions.size())
	print("  - 记忆数据: %d 条" % _memories.size())
	print("  - 关系历史: %d 条" % _relationship_history.size())

## ========================================
## 交易日志 API
## ========================================

func log_transaction(buyer_id: String, seller_id: String, item_id: String, amount: int, channel: String = "purchase") -> String:
	var transaction_id = _generate_id("txn")
	var timestamp = _get_current_timestamp()

	if _engine_type == EngineType.SQLITE:
		_db.query("INSERT INTO transactions (id, timestamp, buyer_id, seller_id, item_id, amount, channel) VALUES (?, ?, ?, ?, ?, ?, ?);", [
			transaction_id, timestamp, buyer_id, seller_id, item_id, amount, channel
		])
	else:
		var transaction = {
			"id": transaction_id,
			"timestamp": timestamp,
			"buyer_id": buyer_id,
			"seller_id": seller_id,
			"item_id": item_id,
			"amount": amount,
			"channel": channel
		}
		_transactions.append(transaction)

		if _transactions.size() > MAX_TRANSACTIONS:
			_transactions = _transactions.slice(-MAX_TRANSACTIONS)

		_save_transactions_async()

	transaction_logged.emit(transaction_id)
	return transaction_id

func get_transactions_by_ai(ai_id: String, limit: int = 100) -> Array:
	if _engine_type == EngineType.SQLITE:
		_db.query("SELECT * FROM transactions WHERE buyer_id = ? OR seller_id = ? ORDER BY timestamp DESC LIMIT ?;", [ai_id, ai_id, limit])
		return _db.query_result
	else:
		var results: Array = []
		for i in range(_transactions.size() - 1, -1, -1):
			var transaction = _transactions[i]
			if transaction.buyer_id == ai_id or transaction.seller_id == ai_id:
				results.append(transaction)
				if results.size() >= limit:
					break
		return results

func get_transactions_by_time_range(start_timestamp: float, end_timestamp: float) -> Array:
	if _engine_type == EngineType.SQLITE:
		_db.query("SELECT * FROM transactions WHERE timestamp BETWEEN ? AND ? ORDER BY timestamp DESC;", [start_timestamp, end_timestamp])
		return _db.query_result
	else:
		var results: Array = []
		for transaction in _transactions:
			var ts = transaction.get("timestamp", 0)
			if ts >= start_timestamp and ts <= end_timestamp:
				results.append(transaction)
		return results

func get_transaction_stats(ai_id: String) -> Dictionary:
	if _engine_type == EngineType.SQLITE:
		_db.query("SELECT SUM(amount) as total_spent, COUNT(*) as count FROM transactions WHERE buyer_id = ?;", [ai_id])
		var spent_result = _db.query_result[0] if _db.query_result.size() > 0 else {"total_spent": 0, "count": 0}

		_db.query("SELECT SUM(amount) as total_earned, COUNT(*) as count FROM transactions WHERE seller_id = ?;", [ai_id])
		var earned_result = _db.query_result[0] if _db.query_result.size() > 0 else {"total_earned": 0, "count": 0}

		var total_spent = spent_result.get("total_spent", 0) if spent_result.get("total_spent") != null else 0
		var total_earned = earned_result.get("total_earned", 0) if earned_result.get("total_earned") != null else 0

		return {
			"total_spent": total_spent,
			"total_earned": total_earned,
			"net_balance": total_earned - total_spent,
			"transaction_count": spent_result.get("count", 0) + earned_result.get("count", 0)
		}
	else:
		var total_spent = 0
		var total_earned = 0
		var transaction_count = 0

		for transaction in _transactions:
			if transaction.buyer_id == ai_id:
				total_spent += transaction.amount
				transaction_count += 1
			elif transaction.seller_id == ai_id:
				total_earned += transaction.amount
				transaction_count += 1

		return {
			"total_spent": total_spent,
			"total_earned": total_earned,
			"net_balance": total_earned - total_spent,
			"transaction_count": transaction_count
		}

## ========================================
## 记忆数据 API
## ========================================

func store_memory(ai_id: String, memory_type: String, content: String, importance: float, valence: float) -> String:
	var memory_id = _generate_id("mem")
	var timestamp = _get_current_timestamp()

	if _engine_type == EngineType.SQLITE:
		_db.query("INSERT INTO memories (id, ai_id, timestamp, type, content, importance, valence) VALUES (?, ?, ?, ?, ?, ?, ?);", [
			memory_id, ai_id, timestamp, memory_type, content, importance, valence
		])
	else:
		var memory = {
			"id": memory_id,
			"ai_id": ai_id,
			"timestamp": timestamp,
			"type": memory_type,
			"content": content,
			"importance": importance,
			"valence": valence
		}
		_memories.append(memory)

		if _memories.size() > MAX_MEMORIES:
			_memories = _memories.slice(-MAX_MEMORIES)

		_save_memories_async()

	memory_stored.emit(memory_id)
	return memory_id

func get_memories_by_ai(ai_id: String, limit: int = 50) -> Array:
	if _engine_type == EngineType.SQLITE:
		_db.query("SELECT * FROM memories WHERE ai_id = ? ORDER BY timestamp DESC LIMIT ?;", [ai_id, limit])
		return _db.query_result
	else:
		var results: Array = []
		for i in range(_memories.size() - 1, -1, -1):
			var memory = _memories[i]
			if memory.ai_id == ai_id:
				results.append(memory)
				if results.size() >= limit:
					break
		return results

func get_memories_by_type(ai_id: String, memory_type: String, limit: int = 20) -> Array:
	if _engine_type == EngineType.SQLITE:
		_db.query("SELECT * FROM memories WHERE ai_id = ? AND type = ? ORDER BY timestamp DESC LIMIT ?;", [ai_id, memory_type, limit])
		return _db.query_result
	else:
		var results: Array = []
		for i in range(_memories.size() - 1, -1, -1):
			var memory = _memories[i]
			if memory.ai_id == ai_id and memory.type == memory_type:
				results.append(memory)
				if results.size() >= limit:
					break
		return results

func get_important_memories(ai_id: String, min_importance: float = 0.7, limit: int = 20) -> Array:
	if _engine_type == EngineType.SQLITE:
		_db.query("SELECT * FROM memories WHERE ai_id = ? AND importance >= ? ORDER BY importance DESC, timestamp DESC LIMIT ?;", [ai_id, min_importance, limit])
		return _db.query_result
	else:
		var results: Array = []
		for i in range(_memories.size() - 1, -1, -1):
			var memory = _memories[i]
			if memory.ai_id == ai_id and memory.importance >= min_importance:
				results.append(memory)
				if results.size() >= limit:
					break
		return results

## ========================================
## 关系历史 API
## ========================================

func log_relationship_change(source_id: String, target_id: String, channel: String, delta: float, reason: String = "") -> String:
	var record_id = _generate_id("rel")
	var timestamp = _get_current_timestamp()

	if _engine_type == EngineType.SQLITE:
		_db.query("INSERT INTO relationship_history (id, timestamp, source_id, target_id, channel, delta, reason) VALUES (?, ?, ?, ?, ?, ?, ?);", [
			record_id, timestamp, source_id, target_id, channel, delta, reason
		])
	else:
		var record = {
			"id": record_id,
			"timestamp": timestamp,
			"source_id": source_id,
			"target_id": target_id,
			"channel": channel,
			"delta": delta,
			"reason": reason
		}
		_relationship_history.append(record)

		if _relationship_history.size() > MAX_RELATIONSHIP_HISTORY:
			_relationship_history = _relationship_history.slice(-MAX_RELATIONSHIP_HISTORY)

		_save_relationship_history_async()

	return record_id

func get_relationship_history(source_id: String, target_id: String, limit: int = 50) -> Array:
	if _engine_type == EngineType.SQLITE:
		_db.query("SELECT * FROM relationship_history WHERE source_id = ? AND target_id = ? ORDER BY timestamp DESC LIMIT ?;", [source_id, target_id, limit])
		return _db.query_result
	else:
		var results: Array = []
		for i in range(_relationship_history.size() - 1, -1, -1):
			var record = _relationship_history[i]
			if record.source_id == source_id and record.target_id == target_id:
				results.append(record)
				if results.size() >= limit:
					break
		return results

func get_relationship_stats(source_id: String, target_id: String) -> Dictionary:
	if _engine_type == EngineType.SQLITE:
		_db.query("""
			SELECT
				SUM(CASE WHEN delta > 0 THEN 1 ELSE 0 END) as positive_changes,
				SUM(CASE WHEN delta < 0 THEN 1 ELSE 0 END) as negative_changes,
				SUM(delta) as total_delta,
				COUNT(*) as change_count
			FROM relationship_history
			WHERE source_id = ? AND target_id = ?;
		""", [source_id, target_id])

		var result = _db.query_result[0] if _db.query_result.size() > 0 else {}
		var total_delta = result.get("total_delta", 0.0) if result.get("total_delta") != null else 0.0
		var change_count = result.get("change_count", 0)

		return {
			"positive_changes": result.get("positive_changes", 0),
			"negative_changes": result.get("negative_changes", 0),
			"total_delta": total_delta,
			"change_count": change_count,
			"average_delta": total_delta / change_count if change_count > 0 else 0.0
		}
	else:
		var positive_changes = 0
		var negative_changes = 0
		var total_delta = 0.0
		var change_count = 0

		for record in _relationship_history:
			if record.source_id == source_id and record.target_id == target_id:
				var delta = record.delta
				total_delta += delta
				change_count += 1

				if delta > 0:
					positive_changes += 1
				elif delta < 0:
					negative_changes += 1

		return {
			"positive_changes": positive_changes,
			"negative_changes": negative_changes,
			"total_delta": total_delta,
			"change_count": change_count,
			"average_delta": total_delta / change_count if change_count > 0 else 0.0
		}

## ========================================
## 高级查询 API (仅 SQLite)
## ========================================

func query_custom(sql: String, params: Array = []) -> Array:
	"""执行自定义 SQL 查询 (仅 SQLite 模式可用)"""
	if _engine_type != EngineType.SQLITE:
		push_warning("[DatabaseManager] query_custom() 仅在 SQLite 模式可用")
		return []

	_db.query(sql, params)
	return _db.query_result

## ========================================
## JSON 数据持久化 (降级模式)
## ========================================

func _load_transactions() -> void:
	if not FileAccess.file_exists(TRANSACTIONS_FILE):
		return
	var file = FileAccess.open(TRANSACTIONS_FILE, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and json.data is Array:
		_transactions = json.data

func _load_memories() -> void:
	if not FileAccess.file_exists(MEMORIES_FILE):
		return
	var file = FileAccess.open(MEMORIES_FILE, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and json.data is Array:
		_memories = json.data

func _load_relationship_history() -> void:
	if not FileAccess.file_exists(RELATIONSHIPS_FILE):
		return
	var file = FileAccess.open(RELATIONSHIPS_FILE, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and json.data is Array:
		_relationship_history = json.data

func _load_metadata() -> void:
	if not FileAccess.file_exists(METADATA_FILE):
		_metadata = {"version": "1.0.0", "created_at": _get_current_timestamp()}
		return
	var file = FileAccess.open(METADATA_FILE, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		_metadata = json.data

func _save_transactions_async() -> void:
	call_deferred("_save_transactions")

func _save_memories_async() -> void:
	call_deferred("_save_memories")

func _save_relationship_history_async() -> void:
	call_deferred("_save_relationship_history")

func _save_transactions() -> void:
	var file = FileAccess.open(TRANSACTIONS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_transactions, "\t"))
		file.close()

func _save_memories() -> void:
	var file = FileAccess.open(MEMORIES_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_memories, "\t"))
		file.close()

func _save_relationship_history() -> void:
	var file = FileAccess.open(RELATIONSHIPS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_relationship_history, "\t"))
		file.close()

## ========================================
## 备份系统
## ========================================

func create_backup() -> String:
	var backup_dir = "user://database/backups"
	var dir = DirAccess.open("user://database")
	if not dir.dir_exists("backups"):
		dir.make_dir("backups")

	var timestamp = _get_current_timestamp()
	var backup_name = "backup_%d" % int(timestamp)
	var backup_path = backup_dir + "/" + backup_name

	dir = DirAccess.open("user://database/backups")
	if not dir.dir_exists(backup_name):
		dir.make_dir(backup_name)

	if _engine_type == EngineType.SQLITE:
		# 备份 SQLite 数据库
		_copy_file(SQLITE_DB_PATH, backup_path + "/game.db")
	else:
		# 备份 JSON 文件
		_copy_file(TRANSACTIONS_FILE, backup_path + "/transactions.json")
		_copy_file(MEMORIES_FILE, backup_path + "/memories.json")
		_copy_file(RELATIONSHIPS_FILE, backup_path + "/relationships.json")
		_copy_file(METADATA_FILE, backup_path + "/metadata.json")

	print("[DatabaseManager] 数据库备份完成: %s" % backup_path)
	database_backed_up.emit(backup_path)

	_cleanup_old_backups()
	return backup_path

func _copy_file(source: String, dest: String) -> bool:
	if not FileAccess.file_exists(source):
		return false
	var source_file = FileAccess.open(source, FileAccess.READ)
	if not source_file:
		return false
	var content = source_file.get_as_text()
	source_file.close()
	var dest_file = FileAccess.open(dest, FileAccess.WRITE)
	if not dest_file:
		return false
	dest_file.store_string(content)
	dest_file.close()
	return true

func _cleanup_old_backups() -> void:
	var backup_dir = DirAccess.open("user://database/backups")
	if not backup_dir:
		return
	var backups: Array = []
	backup_dir.list_dir_begin()
	var file_name = backup_dir.get_next()
	while file_name != "":
		if backup_dir.current_is_dir() and file_name.begins_with("backup_"):
			backups.append(file_name)
		file_name = backup_dir.get_next()
	backup_dir.list_dir_end()
	backups.sort()
	if backups.size() > 5:
		for i in range(backups.size() - 5):
			var old_backup = backups[i]
			_remove_directory_recursive("user://database/backups/" + old_backup)
			print("[DatabaseManager] 清理旧备份: %s" % old_backup)

func _remove_directory_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path + "/" + file_name
		if dir.current_is_dir():
			_remove_directory_recursive(file_path)
		else:
			dir.remove(file_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	dir.remove(path)

## ========================================
## 统计信息 API
## ========================================

func get_database_stats() -> Dictionary:
	if _engine_type == EngineType.SQLITE:
		_db.query("SELECT COUNT(*) as count FROM transactions;")
		var tx_count = _db.query_result[0]["count"] if _db.query_result.size() > 0 else 0

		_db.query("SELECT COUNT(*) as count FROM memories;")
		var mem_count = _db.query_result[0]["count"] if _db.query_result.size() > 0 else 0

		_db.query("SELECT COUNT(*) as count FROM relationship_history;")
		var rel_count = _db.query_result[0]["count"] if _db.query_result.size() > 0 else 0

		return {
			"engine_type": "SQLite",
			"transactions_count": tx_count,
			"memories_count": mem_count,
			"relationship_records_count": rel_count,
			"database_path": SQLITE_DB_PATH
		}
	else:
		return {
			"engine_type": "JSON",
			"transactions_count": _transactions.size(),
			"memories_count": _memories.size(),
			"relationship_records_count": _relationship_history.size()
		}

func get_ai_summary(ai_id: String) -> Dictionary:
	return {
		"transaction_stats": get_transaction_stats(ai_id),
		"memory_count": get_memories_by_ai(ai_id, 999999).size(),
		"recent_memories": get_memories_by_ai(ai_id, 5),
		"recent_transactions": get_transactions_by_ai(ai_id, 5)
	}

## ========================================
## 工具函数
## ========================================

func _generate_id(prefix: String) -> String:
	var timestamp = _get_current_timestamp()
	var random = randi() % 10000
	return "%s_%d_%d" % [prefix, int(timestamp), random]

func _get_current_timestamp() -> float:
	if _time_system and _time_system.has_method("get_current_timestamp"):
		return _time_system.get_current_timestamp()
	return Time.get_unix_time_from_system()

func is_initialized() -> bool:
	return _is_initialized

func get_engine_type() -> String:
	return "SQLite" if _engine_type == EngineType.SQLITE else "JSON"

func flush_all() -> void:
	"""强制保存所有数据"""
	if _engine_type == EngineType.SQLITE:
		# SQLite 自动提交,无需手动 flush
		pass
	else:
		_save_transactions()
		_save_memories()
		_save_relationship_history()
	print("[DatabaseManager] 所有数据已强制保存")

func clear_all_data() -> void:
	"""清除所有数据 (用于测试)"""
	if _engine_type == EngineType.SQLITE:
		_db.query("DELETE FROM transactions;")
		_db.query("DELETE FROM memories;")
		_db.query("DELETE FROM relationship_history;")
	else:
		_transactions.clear()
		_memories.clear()
		_relationship_history.clear()
		_save_transactions()
		_save_memories()
		_save_relationship_history()
	print("[DatabaseManager] 所有数据已清除")
