# AI导航系统设置指南 (AI Navigation System Setup Guide)

本指南帮助你快速配置AI导航系统,实现AI角色的自主移动功能。

---

## 快速开始

### 第一步: 检查Autoload配置

AI导航系统需要`LocationManager`作为全局单例运行。

✅ **已自动配置完成** - LocationManager已添加到 `project.godot` 的autoload列表中:

```ini
[autoload]
LocationManager="*res://script/navigation/LocationManager.gd"
```

如果需要手动检查,打开 [project.godot](../project.godot:27) 文件确认。

---

### 第二步: 添加地点标记到场景

有两种方法为Office场景添加地点标记:

#### 方法A: 使用自动化脚本 (推荐 ⭐)

1. 打开Godot编辑器
2. 打开场景: `scene/maps/Office.tscn`
3. 选中根节点 `Office`
4. 在Inspector面板中,点击 Script 旁的文件夹图标
5. 选择脚本: `script/tools/CreateLocationMarkers.gd`
6. 按 `F5` 运行场景
7. 查看控制台输出,确认地点标记创建成功
8. 按 `Ctrl+S` 保存场景
9. 移除临时脚本 (在Inspector中点击Script旁的X)

#### 方法B: 手动添加 (适合自定义地点)

1. 在Office场景中创建容器节点:
   ```
   Office (Node2D)
   └── Locations (Node2D)  ← 新建此节点
   ```

2. 在Locations下添加Marker2D节点,配置每个地点:
   - 节点名称: 地点ID (如 `office_alice`)
   - 位置: 在场景中拖动到合适坐标
   - 添加到组: `location` (Node → Groups → Add)
   - 设置元数据 (Node → Meta Properties):
     ```
     location_id: "office_alice"
     location_name_cn: "Alice的工位"
     location_type: "OFFICE"
     location_capacity: 2
     ```

---

### 第三步: 为角色添加AIMovementController

同样有两种方法:

#### 方法A: 使用编辑器脚本 (推荐 ⭐)

1. 在Godot编辑器中,点击菜单: `File` → `Run Script` (或按 `Ctrl+Shift+X`)
2. 选择脚本: `script/tools/AddAIMovementToCharacters.gd`
3. 点击 `Run` 按钮
4. 查看输出面板,确认所有角色都成功添加AIMovementController

#### 方法B: 手动添加到每个角色

对每个角色场景 (Alice.tscn, Tom.tscn 等):

1. 打开角色场景
2. 选中根节点 (CharacterBody2D)
3. 右键 → `Add Child Node` → 选择 `Node`
4. 命名为 `AIMovementController`
5. 在Inspector中,点击Script旁的文件夹,选择:
   `res://script/navigation/AIMovementController.gd`
6. 保存场景

---

## 验证安装

### 1. 检查LocationManager是否加载

在任意脚本中测试:

```gdscript
func _ready():
    # 等待一帧确保autoload加载完成
    await get_tree().process_frame

    # 打印所有地点
    LocationManager.print_locations()
```

**预期输出:**
```
=== 地点列表 ===
- CEO办公室 (office_stephen): (1200, 800), 类型: OFFICE, 占用: 0/3
- Alice的工位 (desk_alice): (600, 600), 类型: OFFICE, 占用: 0/1
...
================
```

---

### 2. 测试AI移动

在Office场景的脚本中添加测试代码:

```gdscript
func _ready():
    await get_tree().process_frame

    # 获取Alice
    var alice = get_node("Characters/Alice")
    var ai_movement = alice.get_node("AIMovementController")

    # 测试移动到CEO办公室
    print("测试: Alice移动到CEO办公室")
    ai_movement.move_to_location("office_stephen", func():
        print("✓ Alice到达CEO办公室!")
    )
```

---

## 使用示例

### 示例1: 基础地点移动

```gdscript
# 获取角色的AI移动控制器
var alice = get_node("Characters/Alice")
var ai_movement = alice.get_node("AIMovementController")

# 移动到会议室
ai_movement.move_to_location("meeting_room_01")

# 移动完成后的回调
ai_movement.move_to_location("cafeteria", func():
    print("Alice到达食堂,开始吃饭")
)
```

---

### 示例2: 根据类型查找最近地点

```gdscript
# Tom移动到最近的咖啡馆
var tom = get_node("Characters/Tom")
var tom_movement = tom.get_node("AIMovementController")

tom_movement.move_to_nearest_location(
    LocationManager.LocationType.COFFEE_SHOP
)
```

---

### 示例3: 日程驱动移动

```gdscript
# 在AIAgent中处理日程变化
func _on_schedule_changed(activity):
    var ai_movement = get_node("AIMovementController")

    # 根据活动类型自动移动
    ai_movement.execute_schedule_movement(activity.type)
```

支持的活动类型:
- `"work"` → 移动到办公室
- `"meeting"` → 移动到会议室
- `"lunch"` / `"dinner"` → 移动到食堂
- `"coffee_break"` → 移动到咖啡馆
- `"gym"` → 移动到健身房
- `"rest"` → 移动到休息室
- `"bathroom"` → 移动到洗手间
- `"home"` → 移动到家

---

### 示例4: 角色社交移动

```gdscript
# Grace想和Alice交谈
var grace = get_node("Characters/Grace")
var alice = get_node("Characters/Alice")
var grace_movement = grace.get_node("AIMovementController")

# Grace移动到Alice附近 (距离80像素)
grace_movement.move_to_ai(alice, 80.0, func():
    # 到达后开始对话
    DialogManager.start_conversation(grace, alice)
)
```

---

## 自定义地点配置

### 调整地点坐标

如果自动创建的地点坐标不合适,可以编辑 [CreateLocationMarkers.gd:25-45](../script/tools/CreateLocationMarkers.gd#L25-L45):

```gdscript
var locations_data = [
    # [id, name_cn, position, type, capacity]
    ["office_stephen", "CEO办公室", Vector2(1200, 800), "OFFICE", 3],
    # ↑ 修改这里的坐标
]
```

---

### 添加新地点类型

如需添加新的地点类型,编辑 [LocationManager.gd:49-63](../script/navigation/LocationManager.gd#L49-L63):

```gdscript
enum LocationType {
    OFFICE,
    COFFEE_SHOP,
    # ...
    MY_CUSTOM_TYPE,  # ← 添加新类型
}
```

并在 [AIMovementController.gd:271-301](../script/navigation/AIMovementController.gd#L271-L301) 的 `execute_schedule_movement()` 中添加映射:

```gdscript
match activity_type:
    "my_activity":
        move_to_nearest_location(LocationManager.LocationType.MY_CUSTOM_TYPE)
```

---

## 调试技巧

### 启用调试输出

在 `AIMovementController.gd` 顶部添加:

```gdscript
const DEBUG = true
```

这会输出详细的移动日志:
```
[AIMovementController] Alice 开始移动到: CEO办公室 (1200, 800)
[AIMovementController] Alice 导航完成
[AIMovementController] Alice 到达地点: office_stephen
```

---

### 可视化地点标记

在Office场景中添加调试绘制脚本:

```gdscript
extends Node2D

func _draw():
    await get_tree().process_frame

    for location in LocationManager.get_all_locations():
        # 绘制地点圆圈
        draw_circle(location.position, 30, Color(0, 1, 0, 0.3))

        # 绘制地点名称
        draw_string(
            ThemeDB.fallback_font,
            location.position + Vector2(-50, -40),
            location.name_cn,
            HORIZONTAL_ALIGNMENT_LEFT,
            -1, 14, Color.YELLOW
        )
```

---

## 常见问题

### Q: LocationManager找不到地点?

**A:** 检查以下几点:
1. 地点标记节点是否添加到了 `location` 组
2. 元数据是否正确设置 (`location_id`, `location_name_cn`, `location_type`)
3. LocationManager是否在autoload中正确注册

---

### Q: AI角色不移动?

**A:** 检查:
1. 角色是否有 `AIMovementController` 子节点
2. 角色是否有 `CharacterController` 脚本 (父类必须是CharacterBody2D)
3. 场景中是否有 `NavigationRegion2D` 节点并配置了导航网格

---

### Q: 如何更改移动速度?

**A:** 移动速度由 `CharacterController.gd` 控制,修改:

```gdscript
# CharacterController.gd
var movement_speed: float = 200.0  # 调整此值
```

AIMovementController也支持速度倍率:

```gdscript
# AIMovementController.gd
var movement_speed_multiplier: float = 1.5  # 1.5倍速度
```

---

## 相关文档

- 📖 [AI导航系统详细规范](design/21_AI导航系统详细规范.md) - 完整系统设计文档
- 📁 [LocationManager.gd](../script/navigation/LocationManager.gd) - 地点管理器源码
- 📁 [AIMovementController.gd](../script/navigation/AIMovementController.gd) - AI移动控制器源码
- 🛠 [CreateLocationMarkers.gd](../script/tools/CreateLocationMarkers.gd) - 地点标记创建工具
- 🛠 [AddAIMovementToCharacters.gd](../script/tools/AddAIMovementToCharacters.gd) - 角色组件添加工具

---

## 下一步

设置完成后,你可以:

1. ✅ 连接日程系统,实现AI自动按日程移动
2. ✅ 在LLM提示词中添加地点信息,让AI决策更智能
3. ✅ 创建地点预约系统,避免会议室冲突
4. ✅ 添加地点事件系统 (如: 进入咖啡馆触发对话)

---

**需要帮助?** 查看 [完整设计文档](design/21_AI导航系统详细规范.md) 或在项目Issue中提问。
