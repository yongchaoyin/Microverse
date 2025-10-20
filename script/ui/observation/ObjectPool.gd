extends RefCounted

# ========================================
# ObjectPool - 对象池工具类
# ========================================
#
# 功能:
# - 复用UI节点,减少创建/销毁开销
# - 降低GC压力
# - 提升UI更新性能
#
# 使用方法:
# var pool = ObjectPool.new(ConflictItemScene, 20)
# var item = pool.acquire()
# # 使用item...
# pool.release(item)
#
# ========================================

# 对象工厂函数
var _factory: Callable

# 对象池
var _available_objects: Array = []
var _active_objects: Array = []

# 池参数
var _initial_size: int = 10
var _max_size: int = 50

func _init(factory: Callable, initial_size: int = 10, max_size: int = 50):
	"""初始化对象池

	Args:
		factory: 创建对象的工厂函数 (返回Node)
		initial_size: 初始池大小
		max_size: 最大池大小
	"""
	_factory = factory
	_initial_size = initial_size
	_max_size = max_size

	# 预创建对象
	_prewarm()

func _prewarm():
	"""预热对象池"""
	for i in range(_initial_size):
		var obj = _factory.call()
		if obj:
			obj.visible = false  # 隐藏未使用的对象
			_available_objects.append(obj)

func acquire() -> Node:
	"""获取对象

	Returns:
		可用的节点对象
	"""
	var obj = null

	# 从池中获取
	if not _available_objects.is_empty():
		obj = _available_objects.pop_back()
	else:
		# 池为空,创建新对象(如果未达上限)
		if _active_objects.size() < _max_size:
			obj = _factory.call()
		else:
			push_warning("[ObjectPool] 对象池已满,无法创建新对象")
			return null

	if obj:
		obj.visible = true
		_active_objects.append(obj)

	return obj

func release(obj: Node):
	"""释放对象回池

	Args:
		obj: 要释放的节点
	"""
	if not obj:
		return

	# 从活跃列表移除
	var index = _active_objects.find(obj)
	if index != -1:
		_active_objects.remove_at(index)

	# 重置对象状态
	obj.visible = false

	# 返回到可用池
	if not _available_objects.has(obj):
		_available_objects.append(obj)

func release_all():
	"""释放所有活跃对象"""
	for obj in _active_objects.duplicate():
		release(obj)

func clear():
	"""清空对象池"""
	# 释放所有对象
	release_all()

	# 清空池
	_available_objects.clear()
	_active_objects.clear()

func get_active_count() -> int:
	"""获取活跃对象数量

	Returns:
		活跃对象数
	"""
	return _active_objects.size()

func get_available_count() -> int:
	"""获取可用对象数量

	Returns:
		可用对象数
	"""
	return _available_objects.size()

func get_total_count() -> int:
	"""获取总对象数量

	Returns:
		总对象数
	"""
	return _active_objects.size() + _available_objects.size()
