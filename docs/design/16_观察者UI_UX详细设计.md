# 观察者UI/UX详细设计规范

## 文档信息
- **版本**: v1.0
- **创建日期**: 2025-10-18
- **文档类型**: P0 - UI/UX设计
- **依赖文档**:
  - 01_项目愿景与核心设计.md
  - 02_观察者哲学与设计原则.md
  - 15_Godot项目技术架构.md

---

## 1. UI/UX设计哲学

### 1.1 核心原则

```
观察者UI设计五大原则:
1. 非侵入性 - UI不遮挡游戏主视野,自然融入场景
2. 信息丰富 - 提供足够信息让玩家理解AI行为
3. 直观导航 - 快速切换观察对象,无需复杂操作
4. 实时反馈 - AI思考、行动实时可视化
5. Stardew Valley风格 - 像素风/手绘风,温馨舒适
```

### 1.2 视觉风格参考

- **色彩**: 温暖的棕色、米色、绿色为主色调
- **字体**: 像素字体(主UI) + 手写体(对话/思考)
- **图标**: 简约像素图标
- **动画**: 轻微缓动动画,避免过度华丽
- **布局**: 不对称但平衡的自然布局

---

## 2. 整体UI布局

### 2.1 主界面布局图

```
┌─────────────────────────────────────────────────────────────────┐
│  [时间显示]        [游戏标题]           [速度控制] [菜单] [设置] │ ← 顶部栏(HUD)
├──────────┬──────────────────────────────────────────────┬────────┤
│          │                                              │        │
│  角色    │                                              │  观察  │
│  列表    │                                              │  面板  │
│          │                                              │        │
│  [头像1] │              游戏世界视野                    │ [信息] │
│  [头像2] │                                              │        │
│  [头像3] │           (主要观察区域)                     │ [思考] │
│  [头像4] │                                              │        │
│  [头像5] │                                              │ [状态] │
│  [头像6] │                                              │        │
│  [头像7] │                                              │ [关系] │
│  [头像8] │                                              │        │
│          │                                              │        │
│  [筛选]  │                                              │ [记忆] │
│          │                                              │        │
├──────────┴──────────────────────────────────────────────┴────────┤
│  [通知栏] 最近事件: AI完成工作 | AI开始对话 | 关系变化...        │ ← 底部通知栏
└─────────────────────────────────────────────────────────────────┘

屏幕分配:
- 顶部HUD: 5% 高度
- 左侧角色列表: 10% 宽度
- 右侧观察面板: 25% 宽度
- 中央游戏世界: 65% 宽度
- 底部通知栏: 5% 高度(可收起)
```

### 2.2 UI层级结构

```
UILayer (CanvasLayer)
├── HUD (顶部栏)
│   ├── TimeDisplay (时间显示)
│   ├── GameTitle (游戏标题)
│   ├── SpeedControl (速度控制)
│   ├── MenuButton (菜单按钮)
│   └── SettingsButton (设置按钮)
│
├── CharacterListPanel (左侧角色列表)
│   ├── CharacterList (角色列表)
│   ├── FilterButtons (筛选按钮)
│   └── SearchBox (搜索框)
│
├── ObservationPanel (右侧观察面板)
│   ├── CharacterInfo (角色信息卡片)
│   ├── ThoughtDisplay (思考显示)
│   ├── StatsDisplay (状态显示)
│   ├── RelationshipView (关系视图)
│   └── MemoryView (记忆视图)
│
├── NotificationBar (底部通知栏)
│   ├── EventLog (事件日志)
│   └── ToggleButton (收起/展开按钮)
│
├── Overlays (弹出层)
│   ├── SettingsMenu (设置菜单)
│   ├── SaveLoadMenu (存档菜单)
│   ├── CharacterDetailModal (角色详情模态框)
│   └── RelationshipGraphModal (关系图谱模态框)
│
└── TooltipLayer (工具提示层)
    └── Tooltip (动态提示框)
```

---

## 3. 核心UI组件详细设计

### 3.1 HUD (顶部栏)

#### 3.1.1 设计规格

```
高度: 60px
背景: 半透明深棕色(rgba(40, 30, 20, 0.9))
边框: 2px金色底边

组件布局:
[时间显示 120px] [空白 50px] [游戏标题 200px] [空白弹性] [速度控制 150px] [菜单 80px] [设置 80px]
```

#### 3.1.2 时间显示组件

```gdscript
# scene/ui/HUD/TimeDisplay.gd
extends HBoxContainer

@onready var date_label = $DateLabel
@onready var time_label = $TimeLabel
@onready var season_icon = $SeasonIcon

func _ready():
	EventBus.connect("time_tick", _on_time_tick)
	EventBus.connect("season_changed", _on_season_changed)
	_update_display()

func _update_display():
	# 日期: "第1年 春季 第3天"
	date_label.text = TimeSystem.get_date_string()
	date_label.add_theme_font_size_override("font_size", 14)
	date_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))

	# 时间: "08:30"
	time_label.text = TimeSystem.get_time_string()
	time_label.add_theme_font_size_override("font_size", 18)
	time_label.add_theme_color_override("font_color", Color(1, 1, 1))

	# 季节图标
	_update_season_icon()

func _update_season_icon():
	var season_textures = {
		TimeSystem.Season.SPRING: preload("res://assets/icons/season_spring.png"),
		TimeSystem.Season.SUMMER: preload("res://assets/icons/season_summer.png"),
		TimeSystem.Season.AUTUMN: preload("res://assets/icons/season_autumn.png"),
		TimeSystem.Season.WINTER: preload("res://assets/icons/season_winter.png")
	}
	season_icon.texture = season_textures[TimeSystem.current_season]

func _on_time_tick(minutes: int):
	_update_display()

func _on_season_changed(season: int):
	_update_season_icon()
	# 季节变化动画
	var tween = create_tween()
	tween.tween_property(season_icon, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(season_icon, "scale", Vector2(1.0, 1.0), 0.2)
```

**视觉示例**:
```
┌────────────────────────┐
│ 🌸 第1年 春季 第3天     │
│    08:30               │
└────────────────────────┘
```

#### 3.1.3 速度控制组件

```gdscript
# scene/ui/HUD/SpeedControl.gd
extends HBoxContainer

var speed_options = [0.5, 1.0, 2.0, 3.0]
var current_speed_index = 1

@onready var pause_button = $PauseButton
@onready var speed_button = $SpeedButton
@onready var speed_label = $SpeedLabel

func _ready():
	pause_button.pressed.connect(_on_pause_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	_update_display()

func _on_pause_pressed():
	TimeSystem.toggle_pause()
	_update_display()

func _on_speed_pressed():
	current_speed_index = (current_speed_index + 1) % speed_options.size()
	TimeSystem.set_time_multiplier(speed_options[current_speed_index])
	_update_display()

func _update_display():
	# 暂停按钮图标
	if TimeSystem.time_paused:
		pause_button.icon = preload("res://assets/icons/play.png")
		pause_button.tooltip_text = "继续(空格)"
	else:
		pause_button.icon = preload("res://assets/icons/pause.png")
		pause_button.tooltip_text = "暂停(空格)"

	# 速度标签
	if TimeSystem.time_paused:
		speed_label.text = "||"
	else:
		speed_label.text = "x%.1f" % speed_options[current_speed_index]

func _input(event):
	if event.is_action_pressed("ui_accept"):  # 空格键
		_on_pause_pressed()
```

**视觉示例**:
```
┌─────────────────┐
│ [⏸] [▶▶] x1.0  │
└─────────────────┘
```

---

### 3.2 CharacterListPanel (左侧角色列表)

#### 3.2.1 设计规格

```
宽度: 192px (10% of 1920px)
高度: 全屏高度 - HUD高度
背景: 半透明深棕色(rgba(30, 25, 20, 0.95))
边框: 2px右侧金色边框

组件结构:
- 搜索框: 40px高
- 筛选按钮: 35px高
- 角色列表: 剩余空间(可滚动)
```

#### 3.2.2 角色卡片设计

```gdscript
# scene/ui/CharacterListPanel/CharacterCard.gd
extends PanelContainer

signal character_selected(character_id: String)

var character_data: AICharacterData

@onready var avatar = $HBoxContainer/Avatar
@onready var info_vbox = $HBoxContainer/InfoVBox
@onready var name_label = $HBoxContainer/InfoVBox/NameLabel
@onready var status_label = $HBoxContainer/InfoVBox/StatusLabel
@onready var emotion_icon = $HBoxContainer/EmotionIcon

func setup(data: AICharacterData):
	character_data = data
	_update_display()

	# 连接事件
	EventBus.connect("ai_emotion_changed", _on_emotion_changed)
	EventBus.connect("ai_action_taken", _on_action_taken)

func _update_display():
	# 头像
	avatar.texture = load("res://assets/avatars/%s.png" % character_data.id)

	# 名字
	name_label.text = character_data.character_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))

	# 状态文本
	status_label.text = _get_status_text()
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# 情绪图标
	_update_emotion_icon()

func _get_status_text() -> String:
	var current_action = character_data.current_data.get("current_action", "idle")
	var action_map = {
		"working": "工作中",
		"talking": "对话中",
		"walking": "移动中",
		"eating": "用餐",
		"sleeping": "睡眠",
		"idle": "空闲"
	}
	return action_map.get(current_action, "空闲")

func _update_emotion_icon():
	var emotion = character_data.current_data.get("emotion", "neutral")
	var emotion_textures = {
		"happy": preload("res://assets/icons/emotion_happy.png"),
		"sad": preload("res://assets/icons/emotion_sad.png"),
		"angry": preload("res://assets/icons/emotion_angry.png"),
		"neutral": preload("res://assets/icons/emotion_neutral.png"),
		"excited": preload("res://assets/icons/emotion_excited.png"),
		"tired": preload("res://assets/icons/emotion_tired.png")
	}
	emotion_icon.texture = emotion_textures.get(emotion, emotion_textures["neutral"])

func _on_emotion_changed(ai_id: String, emotion: String):
	if ai_id == character_data.id:
		_update_emotion_icon()

func _on_action_taken(ai_id: String, action: Dictionary):
	if ai_id == character_data.id:
		_update_display()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		character_selected.emit(character_data.id)
		# 高亮选中效果
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.0), 0.1)
		tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)
```

**角色卡片视觉示例**:
```
┌────────────────────────┐
│ [头像]  Alice          │
│  😊    前端工程师      │
│        工作中          │
└────────────────────────┘
```

#### 3.2.3 筛选功能

```gdscript
# scene/ui/CharacterListPanel/FilterButtons.gd
extends HBoxContainer

signal filter_changed(filter_type: String)

@onready var all_button = $AllButton
@onready var working_button = $WorkingButton
@onready var social_button = $SocialButton
@onready var idle_button = $IdleButton

var current_filter = "all"

func _ready():
	all_button.pressed.connect(func(): _set_filter("all"))
	working_button.pressed.connect(func(): _set_filter("working"))
	social_button.pressed.connect(func(): _set_filter("social"))
	idle_button.pressed.connect(func(): _set_filter("idle"))

	_set_filter("all")

func _set_filter(filter_type: String):
	current_filter = filter_type
	filter_changed.emit(filter_type)

	# 更新按钮状态
	all_button.button_pressed = (filter_type == "all")
	working_button.button_pressed = (filter_type == "working")
	social_button.button_pressed = (filter_type == "social")
	idle_button.button_pressed = (filter_type == "idle")
```

---

### 3.3 ObservationPanel (右侧观察面板)

#### 3.3.1 设计规格

```
宽度: 480px (25% of 1920px)
高度: 全屏高度 - HUD高度
背景: 半透明深棕色(rgba(30, 25, 20, 0.95))
边框: 2px左侧金色边框

组件分布:
- CharacterInfo: 150px高
- ThoughtDisplay: 200px高
- StatsDisplay: 180px高
- TabContainer(关系/记忆): 剩余空间
```

#### 3.3.2 角色信息卡片

```gdscript
# scene/ui/ObservationPanel/CharacterInfo.gd
extends VBoxContainer

var current_character: AICharacterData

@onready var avatar_large = $TopSection/AvatarLarge
@onready var name_label = $TopSection/NameLabel
@onready var age_gender_label = $TopSection/AgeGenderLabel
@onready var career_label = $MiddleSection/CareerLabel
@onready var personality_grid = $BottomSection/PersonalityGrid

func display_character(character: AICharacterData):
	current_character = character
	_update_display()

func _update_display():
	if not current_character:
		visible = false
		return

	visible = true

	# 头像(大)
	avatar_large.texture = load("res://assets/avatars/%s_large.png" % current_character.id)

	# 名字
	name_label.text = current_character.character_name
	name_label.add_theme_font_size_override("font_size", 24)

	# 年龄性别
	var gender_text = "男" if current_character.gender == "male" else "女"
	age_gender_label.text = "%d岁 · %s" % [current_character.age, gender_text]

	# 职业
	var career_data = ConfigManager.get_career_data(current_character.career)
	career_label.text = "%s (Lv%d)" % [career_data.get("display_name", "未知"), current_character.career_data.level]

	# 性格五维图
	_update_personality_display()

func _update_personality_display():
	# 清空旧的
	for child in personality_grid.get_children():
		child.queue_free()

	# Big Five性格维度
	var traits = [
		{"key": "extraversion", "name": "外向性", "color": Color(1, 0.3, 0.3)},
		{"key": "agreeableness", "name": "宜人性", "color": Color(0.3, 1, 0.3)},
		{"key": "conscientiousness", "name": "尽责性", "color": Color(0.3, 0.3, 1)},
		{"key": "neuroticism", "name": "神经质", "color": Color(1, 1, 0.3)},
		{"key": "openness", "name": "开放性", "color": Color(1, 0.3, 1)}
	]

	for trait in traits:
		var value = current_character.personality[trait.key]

		# 创建一行: [名字] [进度条] [数值]
		var hbox = HBoxContainer.new()

		var label = Label.new()
		label.text = trait.name
		label.custom_minimum_size = Vector2(60, 0)
		hbox.add_child(label)

		var progress = ProgressBar.new()
		progress.min_value = 0
		progress.max_value = 100
		progress.value = value
		progress.custom_minimum_size = Vector2(200, 20)
		progress.add_theme_color_override("color", trait.color)
		hbox.add_child(progress)

		var value_label = Label.new()
		value_label.text = str(value)
		value_label.custom_minimum_size = Vector2(30, 0)
		hbox.add_child(value_label)

		personality_grid.add_child(hbox)
```

**视觉示例**:
```
┌────────────────────────────────────┐
│         [大头像]                    │
│                                    │
│       Alice                        │
│       28岁 · 女                    │
│       前端工程师 (Lv3)             │
├────────────────────────────────────┤
│  外向性  ████████░░░░░░░░  75      │
│  宜人性  ██████████████░░  85      │
│  尽责性  ████████████░░░░  80      │
│  神经质  ████░░░░░░░░░░░░  35      │
│  开放性  ██████████████░░  90      │
└────────────────────────────────────┘
```

#### 3.3.3 思考显示组件

```gdscript
# scene/ui/ObservationPanel/ThoughtDisplay.gd
extends VBoxContainer

var current_character_id: String = ""
var thought_history: Array = []
const MAX_HISTORY = 20

@onready var title_label = $TitleLabel
@onready var current_thought_text = $CurrentThoughtText
@onready var history_list = $HistoryScrollContainer/HistoryList

func _ready():
	EventBus.connect("ai_thought_generated", _on_ai_thought_generated)
	EventBus.connect("ui_focus_changed", _on_ui_focus_changed)

func _on_ui_focus_changed(ai_id: String):
	current_character_id = ai_id
	_load_thought_history()

func _on_ai_thought_generated(ai_id: String, thought: String):
	if ai_id == current_character_id:
		_display_new_thought(thought)

func _display_new_thought(thought: String):
	# 显示当前思考(带打字机效果)
	current_thought_text.text = ""
	_typewriter_effect(thought)

	# 添加到历史
	_add_to_history(thought)

func _typewriter_effect(text: String):
	var tween = create_tween()
	var duration = min(text.length() * 0.05, 2.0)  # 最多2秒

	for i in range(text.length()):
		tween.tween_callback(func():
			current_thought_text.text = text.substr(0, i + 1)
		)
		tween.tween_interval(duration / text.length())

func _add_to_history(thought: String):
	var history_entry = {
		"thought": thought,
		"time": TimeSystem.get_full_time_string()
	}

	thought_history.insert(0, history_entry)
	if thought_history.size() > MAX_HISTORY:
		thought_history.resize(MAX_HISTORY)

	_update_history_display()

func _update_history_display():
	# 清空旧的
	for child in history_list.get_children():
		child.queue_free()

	# 显示最近10条
	for i in range(min(10, thought_history.size())):
		var entry = thought_history[i]

		var entry_container = VBoxContainer.new()

		var time_label = Label.new()
		time_label.text = entry.time
		time_label.add_theme_font_size_override("font_size", 10)
		time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		entry_container.add_child(time_label)

		var thought_label = Label.new()
		thought_label.text = entry.thought
		thought_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		thought_label.add_theme_font_size_override("font_size", 12)
		entry_container.add_child(thought_label)

		var separator = HSeparator.new()
		entry_container.add_child(separator)

		history_list.add_child(entry_container)

func _load_thought_history():
	# 从MemoryManager加载思考历史
	var thoughts = MemoryManager.get_recent_thoughts(current_character_id, 20)
	thought_history = thoughts
	_update_history_display()
```

**视觉示例**:
```
┌────────────────────────────────────┐
│  💭 当前思考                        │
├────────────────────────────────────┤
│  今天的代码审查进展很顺利,我觉得  │
│  自己的技术能力得到了认可。也许   │
│  是时候考虑申请晋升了...          │
├────────────────────────────────────┤
│  📜 思考历史                        │
├────────────────────────────────────┤
│  第1年 春季 第3天 14:20            │
│  午休时间和Bob聊了会儿,他似乎对   │
│  我很友好...                       │
│  ─────────────────────────────────  │
│  第1年 春季 第3天 12:10            │
│  工作告一段落,该去吃午饭了         │
│  ─────────────────────────────────  │
└────────────────────────────────────┘
```

#### 3.3.4 状态显示组件

```gdscript
# scene/ui/ObservationPanel/StatsDisplay.gd
extends VBoxContainer

var current_character: AICharacterData

@onready var stats_grid = $StatsGrid
@onready var mood_icon = $MoodSection/MoodIcon
@onready var mood_text = $MoodSection/MoodText

func _ready():
	EventBus.connect("ui_focus_changed", _on_ui_focus_changed)
	EventBus.connect("time_tick", _on_time_tick)

func _on_ui_focus_changed(ai_id: String):
	current_character = CharacterManager.get_character_data(ai_id)
	_update_display()

func _on_time_tick(minutes: int):
	if current_character:
		_update_display()

func _update_display():
	if not current_character:
		return

	_update_stats_grid()
	_update_mood_display()

func _update_stats_grid():
	# 清空旧的
	for child in stats_grid.get_children():
		child.queue_free()

	# 状态列表
	var stats = [
		{"key": "energy", "name": "精力", "icon": "⚡", "color": Color(1, 1, 0)},
		{"key": "mood", "name": "心情", "icon": "😊", "color": Color(0, 1, 1)},
		{"key": "stress", "name": "压力", "icon": "😰", "color": Color(1, 0, 0)},
		{"key": "hunger", "name": "饥饿", "icon": "🍔", "color": Color(1, 0.5, 0)},
		{"key": "social_need", "name": "社交需求", "icon": "👥", "color": Color(0, 1, 0)},
		{"key": "health", "name": "健康", "icon": "❤️", "color": Color(1, 0, 0.5)}
	]

	for stat in stats:
		var value = current_character.stats[stat.key]

		var hbox = HBoxContainer.new()

		var icon_label = Label.new()
		icon_label.text = stat.icon
		icon_label.custom_minimum_size = Vector2(30, 0)
		hbox.add_child(icon_label)

		var name_label = Label.new()
		name_label.text = stat.name
		name_label.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(name_label)

		var progress = ProgressBar.new()
		progress.min_value = 0
		progress.max_value = 100
		progress.value = value
		progress.custom_minimum_size = Vector2(150, 20)

		# 根据值设置颜色
		var color = stat.color
		if stat.key == "stress":
			color = Color(1 - value/100.0, value/100.0, 0)  # 压力越高越红
		elif value < 30:
			color = Color(1, 0, 0)  # 低值警告

		progress.add_theme_color_override("color", color)
		hbox.add_child(progress)

		var value_label = Label.new()
		value_label.text = str(value)
		value_label.custom_minimum_size = Vector2(35, 0)
		hbox.add_child(value_label)

		stats_grid.add_child(hbox)

func _update_mood_display():
	var mood = current_character.stats.mood

	# 根据心情值显示不同的图标和文字
	if mood >= 80:
		mood_icon.text = "😄"
		mood_text.text = "心情极好"
		mood_text.add_theme_color_override("font_color", Color(0, 1, 0))
	elif mood >= 60:
		mood_icon.text = "😊"
		mood_text.text = "心情不错"
		mood_text.add_theme_color_override("font_color", Color(0.5, 1, 0))
	elif mood >= 40:
		mood_icon.text = "😐"
		mood_text.text = "心情一般"
		mood_text.add_theme_color_override("font_color", Color(1, 1, 0))
	elif mood >= 20:
		mood_icon.text = "😟"
		mood_text.text = "心情不佳"
		mood_text.add_theme_color_override("font_color", Color(1, 0.5, 0))
	else:
		mood_icon.text = "😢"
		mood_text.text = "心情很差"
		mood_text.add_theme_color_override("font_color", Color(1, 0, 0))
```

**视觉示例**:
```
┌────────────────────────────────────┐
│  📊 当前状态                        │
├────────────────────────────────────┤
│  ⚡ 精力    ████████████░░  85     │
│  😊 心情    ███████████░░░  75     │
│  😰 压力    ████░░░░░░░░░░  30     │
│  🍔 饥饿    ███░░░░░░░░░░░  25     │
│  👥 社交    ██████░░░░░░░░  50     │
│  ❤️ 健康    ████████████░░  95     │
├────────────────────────────────────┤
│      😊 心情不错                   │
└────────────────────────────────────┘
```

#### 3.3.5 关系视图(TabContainer)

```gdscript
# scene/ui/ObservationPanel/RelationshipView.gd
extends VBoxContainer

var current_character_id: String = ""

@onready var relationship_list = $ScrollContainer/RelationshipList
@onready var view_graph_button = $ViewGraphButton

func _ready():
	EventBus.connect("ui_focus_changed", _on_ui_focus_changed)
	EventBus.connect("ai_relationship_changed", _on_relationship_changed)
	view_graph_button.pressed.connect(_on_view_graph_pressed)

func _on_ui_focus_changed(ai_id: String):
	current_character_id = ai_id
	_update_display()

func _on_relationship_changed(ai_id: String, target_id: String, relationship: Dictionary):
	if ai_id == current_character_id:
		_update_display()

func _update_display():
	# 清空旧的
	for child in relationship_list.get_children():
		child.queue_free()

	# 获取所有关系
	var relationships = RelationshipManager.get_all_relationships(current_character_id)

	# 按关系等级排序
	var sorted_relationships = []
	for target_id in relationships:
		var relationship = relationships[target_id]
		sorted_relationships.append({
			"target_id": target_id,
			"relationship": relationship
		})

	sorted_relationships.sort_custom(func(a, b):
		return _get_relationship_score(a.relationship) > _get_relationship_score(b.relationship)
	)

	# 显示前10个
	for i in range(min(10, sorted_relationships.size())):
		var entry = sorted_relationships[i]
		var card = _create_relationship_card(entry.target_id, entry.relationship)
		relationship_list.add_child(card)

func _get_relationship_score(relationship: Dictionary) -> int:
	return relationship.familiarity + relationship.affection + relationship.trust + relationship.romance

func _create_relationship_card(target_id: String, relationship: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 100)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	# 顶部: 头像 + 名字 + 关系等级
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var avatar = TextureRect.new()
	avatar.texture = load("res://assets/avatars/%s_small.png" % target_id)
	avatar.custom_minimum_size = Vector2(40, 40)
	top_hbox.add_child(avatar)

	var name_label = Label.new()
	name_label.text = CharacterManager.get_character_data(target_id).character_name
	name_label.add_theme_font_size_override("font_size", 14)
	top_hbox.add_child(name_label)

	var level_label = Label.new()
	level_label.text = _get_relationship_level_text(relationship.relationship_level)
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", _get_relationship_level_color(relationship.relationship_level))
	top_hbox.add_child(level_label)

	# 四维度进度条
	var dimensions = [
		{"key": "familiarity", "name": "熟悉", "color": Color(0, 1, 1)},
		{"key": "affection", "name": "好感", "color": Color(1, 0.5, 0.5)},
		{"key": "trust", "name": "信任", "color": Color(0, 1, 0)},
		{"key": "romance", "name": "浪漫", "color": Color(1, 0, 1)}
	]

	for dim in dimensions:
		var hbox = HBoxContainer.new()

		var label = Label.new()
		label.text = dim.name
		label.custom_minimum_size = Vector2(40, 0)
		label.add_theme_font_size_override("font_size", 10)
		hbox.add_child(label)

		var progress = ProgressBar.new()
		progress.min_value = 0
		progress.max_value = 100
		progress.value = relationship[dim.key]
		progress.custom_minimum_size = Vector2(200, 15)
		progress.add_theme_color_override("color", dim.color)
		hbox.add_child(progress)

		var value_label = Label.new()
		value_label.text = str(relationship[dim.key])
		value_label.custom_minimum_size = Vector2(30, 0)
		value_label.add_theme_font_size_override("font_size", 10)
		hbox.add_child(value_label)

		vbox.add_child(hbox)

	return card

func _get_relationship_level_text(level: String) -> String:
	var level_map = {
		"stranger": "陌生人",
		"acquaintance": "熟人",
		"friend": "朋友",
		"close_friend": "好友",
		"best_friend": "挚友",
		"romantic": "恋人"
	}
	return level_map.get(level, "未知")

func _get_relationship_level_color(level: String) -> Color:
	var color_map = {
		"stranger": Color(0.5, 0.5, 0.5),
		"acquaintance": Color(1, 1, 1),
		"friend": Color(0, 1, 1),
		"close_friend": Color(0, 1, 0),
		"best_friend": Color(1, 1, 0),
		"romantic": Color(1, 0, 1)
	}
	return color_map.get(level, Color(1, 1, 1))

func _on_view_graph_pressed():
	# 打开关系图谱模态框
	EventBus.emit_signal("ui_panel_opened", "relationship_graph")
```

**视觉示例**:
```
┌────────────────────────────────────┐
│  💞 关系                            │
├────────────────────────────────────┤
│ [头像] Bob      好友               │
│  熟悉  ████████████░░  85          │
│  好感  ████████████░░  80          │
│  信任  ███████████░░░  75          │
│  浪漫  ██░░░░░░░░░░░░  15          │
│ ───────────────────────────────────│
│ [头像] Carol    朋友               │
│  熟悉  ████████░░░░░░  70          │
│  好感  ███████░░░░░░░  65          │
│  信任  ██████░░░░░░░░  60          │
│  浪漫  ░░░░░░░░░░░░░░  0           │
│ ───────────────────────────────────│
│          [查看关系图谱]             │
└────────────────────────────────────┘
```

---

### 3.4 NotificationBar (底部通知栏)

```gdscript
# scene/ui/NotificationBar.gd
extends PanelContainer

var notification_queue: Array = []
var max_visible_notifications: int = 5

@onready var event_log = $HBoxContainer/EventLog
@onready var toggle_button = $HBoxContainer/ToggleButton

var is_expanded: bool = false

func _ready():
	# 连接所有重要事件
	EventBus.connect("ai_action_taken", _on_ai_action)
	EventBus.connect("ai_dialogue_started", _on_dialogue_started)
	EventBus.connect("career_promoted", _on_career_promoted)
	EventBus.connect("ai_relationship_changed", _on_relationship_changed)
	EventBus.connect("work_started", _on_work_started)
	EventBus.connect("work_ended", _on_work_ended)

	toggle_button.pressed.connect(_on_toggle_pressed)

func _on_ai_action(ai_id: String, action: Dictionary):
	var character_name = CharacterManager.get_character_data(ai_id).character_name
	var action_text = _get_action_text(action)
	_add_notification("%s %s" % [character_name, action_text], Color(1, 1, 1))

func _on_dialogue_started(ai_id: String, target_id: String):
	var char1_name = CharacterManager.get_character_data(ai_id).character_name
	var char2_name = CharacterManager.get_character_data(target_id).character_name
	_add_notification("💬 %s 和 %s 开始对话" % [char1_name, char2_name], Color(0, 1, 1))

func _on_career_promoted(ai_id: String, new_level: int):
	var character_name = CharacterManager.get_character_data(ai_id).character_name
	_add_notification("🎉 %s 晋升到 Lv%d!" % [character_name, new_level], Color(1, 1, 0))

func _on_relationship_changed(ai_id: String, target_id: String, relationship: Dictionary):
	# 只在关系等级变化时通知
	if relationship.has("level_changed") and relationship.level_changed:
		var char1_name = CharacterManager.get_character_data(ai_id).character_name
		var char2_name = CharacterManager.get_character_data(target_id).character_name
		var level = relationship.relationship_level
		_add_notification("💞 %s 和 %s 成为了%s" % [char1_name, char2_name, _get_relationship_text(level)], Color(1, 0, 1))

func _on_work_started(ai_id: String):
	var character_name = CharacterManager.get_character_data(ai_id).character_name
	_add_notification("💼 %s 开始工作" % character_name, Color(0.5, 0.5, 1))

func _on_work_ended(ai_id: String):
	var character_name = CharacterManager.get_character_data(ai_id).character_name
	_add_notification("🏠 %s 下班了" % character_name, Color(0.5, 1, 0.5))

func _add_notification(text: String, color: Color):
	var notification = {
		"text": text,
		"time": TimeSystem.get_time_string(),
		"color": color
	}

	notification_queue.insert(0, notification)
	if notification_queue.size() > 50:  # 保留最近50条
		notification_queue.resize(50)

	_update_display()

	# 如果收起状态,短暂显示
	if not is_expanded:
		_flash_notification(text, color)

func _update_display():
	event_log.text = ""

	var visible_count = max_visible_notifications if is_expanded else 1
	for i in range(min(visible_count, notification_queue.size())):
		var notif = notification_queue[i]
		event_log.text += "[color=#%s][%s] %s[/color]\n" % [notif.color.to_html(), notif.time, notif.text]

func _flash_notification(text: String, color: Color):
	# 临时显示通知
	var temp_label = Label.new()
	temp_label.text = text
	temp_label.add_theme_color_override("font_color", color)
	add_child(temp_label)

	var tween = create_tween()
	tween.tween_property(temp_label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(temp_label.queue_free)

func _on_toggle_pressed():
	is_expanded = !is_expanded
	_update_display()

	toggle_button.text = "▼" if is_expanded else "▲"

func _get_action_text(action: Dictionary) -> String:
	# 根据action类型返回文本
	return action.get("description", "做了某事")

func _get_relationship_text(level: String) -> String:
	var level_map = {
		"stranger": "陌生人",
		"acquaintance": "熟人",
		"friend": "朋友",
		"close_friend": "好友",
		"best_friend": "挚友",
		"romantic": "恋人"
	}
	return level_map.get(level, "")
```

**视觉示例(收起)**:
```
┌─────────────────────────────────────────────────────────────┐
│ [08:30] Alice 开始工作 | [08:25] Bob和Carol开始对话 | ... [▲]│
└─────────────────────────────────────────────────────────────┘
```

**视觉示例(展开)**:
```
┌─────────────────────────────────────────────────────────────┐
│ [08:30] Alice 开始工作                                       │
│ [08:25] 💬 Bob 和 Carol 开始对话                             │
│ [08:20] 🏠 Alice 下班了                                      │
│ [08:15] 💞 Bob 和 Alice 成为了朋友                           │
│ [08:10] 🎉 Carol 晋升到 Lv3!                          [▼]   │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. 摄像机控制系统

### 4.1 CameraController设计

```gdscript
# script/ui/CameraController.gd
extends Camera2D

# 摄像机配置
var zoom_min: float = 0.5
var zoom_max: float = 2.0
var zoom_step: float = 0.1
var pan_speed: float = 500.0
var smooth_speed: float = 5.0

# 当前状态
var current_follow_target: Node2D = null
var is_dragging: bool = false
var drag_start_position: Vector2

# UI提示
@onready var camera_ui = $CameraUI
@onready var follow_label = $CameraUI/FollowLabel

func _ready():
	# 设置摄像机初始状态
	zoom = Vector2(1.0, 1.0)
	position_smoothing_enabled = true
	position_smoothing_speed = smooth_speed

	# 连接UI事件
	EventBus.connect("ui_focus_changed", _on_ui_focus_changed)

func _process(delta):
	# 如果有跟随目标,平滑跟随
	if current_follow_target and not is_dragging:
		var target_position = current_follow_target.global_position
		global_position = global_position.lerp(target_position, smooth_speed * delta)

func _input(event):
	# 鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()

		# 中键拖拽
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start_position = get_global_mouse_position()
			else:
				is_dragging = false

	# 鼠标拖拽移动
	if event is InputEventMouseMotion and is_dragging:
		var drag_offset = drag_start_position - get_global_mouse_position()
		global_position += drag_offset
		current_follow_target = null  # 取消跟随
		_update_follow_label()

	# 键盘快捷键
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_in()
	if event.is_action_pressed("camera_zoom_out"):
		_zoom_out()
	if event.is_action_pressed("camera_reset"):
		_reset_camera()

func _zoom_in():
	var new_zoom = zoom + Vector2(zoom_step, zoom_step)
	zoom = new_zoom.clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

func _zoom_out():
	var new_zoom = zoom - Vector2(zoom_step, zoom_step)
	zoom = new_zoom.clamp(Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))

func _reset_camera():
	zoom = Vector2(1.0, 1.0)
	if current_follow_target:
		global_position = current_follow_target.global_position

# 跟随目标
func follow_target(target: Node2D):
	current_follow_target = target
	_update_follow_label()

func unfollow_target():
	current_follow_target = null
	_update_follow_label()

func _update_follow_label():
	if current_follow_target:
		var character = current_follow_target as AICharacter
		if character:
			follow_label.text = "跟随: %s (按ESC取消)" % character.character_data.character_name
			follow_label.visible = true
	else:
		follow_label.visible = false

func _on_ui_focus_changed(ai_id: String):
	# 当UI焦点切换时,自动跟随该角色
	var character = CharacterManager.get_character_by_id(ai_id)
	if character:
		follow_target(character)
```

### 4.2 摄像机交互快捷键

```ini
# project.godot [input] section

camera_zoom_in={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode": KEY_EQUAL)]
}

camera_zoom_out={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode": KEY_MINUS)]
}

camera_reset={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode": KEY_R)]
}

camera_free_mode={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode": KEY_ESCAPE)]
}
```

---

## 5. 模态框和弹出层设计

### 5.1 关系图谱模态框

```gdscript
# scene/ui/Modals/RelationshipGraphModal.gd
extends Panel

var current_character_id: String = ""
var graph_nodes: Dictionary = {}  # {ai_id: Node2D}

@onready var graph_container = $GraphContainer
@onready var close_button = $CloseButton
@onready var title_label = $TitleLabel

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	EventBus.connect("ui_panel_opened", _on_panel_opened)

func _on_panel_opened(panel_name: String):
	if panel_name == "relationship_graph":
		visible = true
		_generate_graph()

func _on_close_pressed():
	visible = false

func _generate_graph():
	# 清空旧的
	for child in graph_container.get_children():
		child.queue_free()

	graph_nodes.clear()

	# 获取所有角色
	var all_characters = CharacterManager.get_all_character_ids()

	# 创建节点
	var center = graph_container.size / 2
	var radius = min(graph_container.size.x, graph_container.size.y) * 0.4
	var angle_step = TAU / all_characters.size()

	for i in range(all_characters.size()):
		var ai_id = all_characters[i]
		var angle = i * angle_step

		var node_position = center + Vector2(cos(angle), sin(angle)) * radius

		# 创建角色节点
		var node = _create_character_node(ai_id)
		node.position = node_position
		graph_container.add_child(node)
		graph_nodes[ai_id] = node

	# 绘制连接线(关系)
	_draw_relationships()

func _create_character_node(ai_id: String) -> Control:
	var node = VBoxContainer.new()

	var avatar = TextureRect.new()
	avatar.texture = load("res://assets/avatars/%s_small.png" % ai_id)
	avatar.custom_minimum_size = Vector2(60, 60)
	node.add_child(avatar)

	var name_label = Label.new()
	name_label.text = CharacterManager.get_character_data(ai_id).character_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(name_label)

	# 点击节点聚焦该角色
	avatar.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			EventBus.emit_signal("ui_focus_changed", ai_id)
	)

	return node

func _draw_relationships():
	# 使用Line2D绘制关系连接线
	for ai_id in graph_nodes:
		var relationships = RelationshipManager.get_all_relationships(ai_id)

		for target_id in relationships:
			if not graph_nodes.has(target_id):
				continue

			var relationship = relationships[target_id]

			# 只绘制关系等级>=朋友的连接
			if relationship.relationship_level in ["friend", "close_friend", "best_friend", "romantic"]:
				var line = Line2D.new()
				line.add_point(graph_nodes[ai_id].position)
				line.add_point(graph_nodes[target_id].position)

				# 根据关系等级设置线条颜色和宽度
				var color = _get_relationship_color(relationship.relationship_level)
				var width = _get_relationship_width(relationship.relationship_level)

				line.default_color = color
				line.width = width
				line.z_index = -1  # 线条在节点下方

				graph_container.add_child(line)

func _get_relationship_color(level: String) -> Color:
	var color_map = {
		"friend": Color(0, 1, 1, 0.3),
		"close_friend": Color(0, 1, 0, 0.5),
		"best_friend": Color(1, 1, 0, 0.7),
		"romantic": Color(1, 0, 1, 0.9)
	}
	return color_map.get(level, Color(0.5, 0.5, 0.5, 0.2))

func _get_relationship_width(level: String) -> float:
	var width_map = {
		"friend": 2.0,
		"close_friend": 3.0,
		"best_friend": 4.0,
		"romantic": 5.0
	}
	return width_map.get(level, 1.0)
```

**视觉示例**:
```
┌────────────────────────────────────────┐
│  关系图谱                       [X]    │
├────────────────────────────────────────┤
│                [Bob]                   │
│                  │                     │
│          ┌───────┼───────┐             │
│          │       │       │             │
│      [Alice]  [Carol]  [Dave]          │
│          │               │             │
│          └───────────────┘             │
│                                        │
│  图例:                                  │
│  ─── 朋友  ══ 好友  ≡≡≡ 挚友  ♥♥ 恋人 │
└────────────────────────────────────────┘
```

---

## 6. 动画与过渡效果

### 6.1 UI动画规范

```gdscript
# 标准UI动画时长
const ANIM_FAST = 0.1      # 快速动画(按钮点击)
const ANIM_NORMAL = 0.2    # 常规动画(面板打开)
const ANIM_SLOW = 0.5      # 慢速动画(场景切换)

# 缓动函数
const EASE_IN_OUT = Tween.EASE_IN_OUT
const EASE_OUT = Tween.EASE_OUT

# 常用动画模板

# 1. 淡入淡出
func fade_in(node: CanvasItem, duration: float = ANIM_NORMAL):
	node.modulate.a = 0.0
	node.visible = true
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration).set_ease(EASE_OUT)

func fade_out(node: CanvasItem, duration: float = ANIM_NORMAL):
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration).set_ease(EASE_OUT)
	tween.tween_callback(func(): node.visible = false)

# 2. 缩放弹出
func scale_popup(node: Control, duration: float = ANIM_NORMAL):
	node.scale = Vector2(0.8, 0.8)
	node.modulate.a = 0.0
	node.visible = true

	var tween = create_tween()
	tween.parallel().tween_property(node, "scale", Vector2(1.0, 1.0), duration).set_ease(EASE_OUT)
	tween.parallel().tween_property(node, "modulate:a", 1.0, duration).set_ease(EASE_OUT)

# 3. 滑入滑出
func slide_in_from_right(node: Control, duration: float = ANIM_NORMAL):
	var original_position = node.position
	node.position.x += node.size.x
	node.visible = true

	var tween = create_tween()
	tween.tween_property(node, "position", original_position, duration).set_ease(EASE_OUT)

func slide_out_to_right(node: Control, duration: float = ANIM_NORMAL):
	var target_position = node.position + Vector2(node.size.x, 0)
	var tween = create_tween()
	tween.tween_property(node, "position", target_position, duration).set_ease(EASE_OUT)
	tween.tween_callback(func(): node.visible = false)

# 4. 打字机效果(已在ThoughtDisplay中使用)

# 5. 通知弹出效果
func notification_popup(text: String, position: Vector2, duration: float = 2.0):
	var label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)

	# 向上漂浮淡出
	var tween = create_tween()
	tween.parallel().tween_property(label, "position:y", position.y - 50, duration).set_ease(EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration).set_ease(EASE_OUT)
	tween.tween_callback(label.queue_free)
```

### 6.2 实时反馈动画

```gdscript
# AI思考时的气泡动画
func animate_thought_bubble(bubble: Node2D):
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(bubble, "scale", Vector2(1.05, 1.05), 0.5).set_ease(EASE_IN_OUT)
	tween.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.5).set_ease(EASE_IN_OUT)

# AI情绪变化时的图标动画
func animate_emotion_change(emotion_icon: Sprite2D):
	var tween = create_tween()
	tween.tween_property(emotion_icon, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(emotion_icon, "scale", Vector2(1.0, 1.0), 0.2).set_ease(EASE_OUT)
	tween.tween_property(emotion_icon, "rotation", TAU, 0.3).set_ease(EASE_OUT)

# 关系变化时的连接线闪烁
func animate_relationship_line(line: Line2D):
	var original_width = line.width
	var tween = create_tween()
	tween.tween_property(line, "width", original_width * 2, 0.2)
	tween.tween_property(line, "width", original_width, 0.2)
```

---

## 7. 响应式布局与适配

### 7.1 多分辨率适配

```gdscript
# script/ui/ResponsiveLayout.gd
extends Node

# 预设分辨率
const RESOLUTIONS = {
	"1920x1080": Vector2(1920, 1080),
	"1280x720": Vector2(1280, 720),
	"2560x1440": Vector2(2560, 1440),
	"3840x2160": Vector2(3840, 2160)
}

# UI缩放比例(基于1920x1080)
var ui_scale: float = 1.0

func _ready():
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_ui_scale()

func _on_viewport_size_changed():
	_update_ui_scale()

func _update_ui_scale():
	var viewport_size = get_viewport().size
	var base_width = 1920.0

	# 根据宽度计算缩放比例
	ui_scale = viewport_size.x / base_width

	# 调整UI根节点的缩放
	var ui_layer = get_node("/root/Main/UILayer")
	if ui_layer:
		ui_layer.scale = Vector2(ui_scale, ui_scale)

	print("[ResponsiveLayout] UI缩放比例: %.2f" % ui_scale)
```

### 7.2 字体大小适配

```gdscript
# 根据UI缩放动态调整字体大小
func set_adaptive_font_size(label: Label, base_size: int):
	label.add_theme_font_size_override("font_size", int(base_size * ui_scale))
```

---

## 8. 无障碍功能

### 8.1 键盘导航

```gdscript
# scene/ui/KeyboardNavigation.gd
extends Node

var focusable_elements: Array = []
var current_focus_index: int = 0

func _ready():
	_register_focusable_elements()

func _input(event):
	if event.is_action_pressed("ui_focus_next"):  # Tab键
		_focus_next()
	elif event.is_action_pressed("ui_focus_prev"):  # Shift+Tab
		_focus_previous()
	elif event.is_action_pressed("ui_accept"):  # Enter键
		_activate_focused()

func _register_focusable_elements():
	# 自动查找所有可聚焦的UI元素
	focusable_elements = get_tree().get_nodes_in_group("focusable")

func _focus_next():
	if focusable_elements.size() == 0:
		return

	current_focus_index = (current_focus_index + 1) % focusable_elements.size()
	focusable_elements[current_focus_index].grab_focus()

func _focus_previous():
	if focusable_elements.size() == 0:
		return

	current_focus_index = (current_focus_index - 1 + focusable_elements.size()) % focusable_elements.size()
	focusable_elements[current_focus_index].grab_focus()

func _activate_focused():
	if focusable_elements.size() > 0 and current_focus_index < focusable_elements.size():
		var focused = focusable_elements[current_focus_index]
		if focused is Button:
			focused.emit_signal("pressed")
```

### 8.2 屏幕阅读器支持(未来扩展)

```gdscript
# 为UI元素添加无障碍描述
func set_accessibility_label(node: Control, label: String):
	node.set_meta("accessibility_label", label)

# 为屏幕阅读器提供文本描述
func get_accessibility_description(node: Control) -> String:
	if node.has_meta("accessibility_label"):
		return node.get_meta("accessibility_label")
	elif node is Label:
		return node.text
	elif node is Button:
		return node.text
	else:
		return node.name
```

---

## 9. 主题与样式系统

### 9.1 主题配置文件

```gdscript
# res://themes/main_theme.tres
# (Godot Theme资源)

# 配置:
- 默认字体: res://assets/fonts/pixel_font.ttf
- 标题字体: res://assets/fonts/handwriting_font.ttf
- 主色调: #8B7355 (深棕色)
- 次色调: #D4A373 (浅棕色)
- 高亮色: #FFCC33 (金色)
- 背景色: #1E1914 (深黑褐)
- 文字颜色: #FFFFFF (白色)
- 次要文字颜色: #CCCCCC (灰白)

# 按钮样式:
- Normal: 深棕色背景,白色文字
- Hover: 浅棕色背景,金色边框
- Pressed: 金色背景,深棕色文字

# 面板样式:
- 背景: 半透明深棕色
- 边框: 2px金色边框
- 圆角: 5px

# 进度条样式:
- 背景: 深灰色
- 填充: 根据上下文动态变化(能量=黄色,健康=红色等)
```

### 9.2 动态主题切换(未来扩展)

```gdscript
# script/ui/ThemeManager.gd
extends Node

var themes: Dictionary = {
	"default": preload("res://themes/main_theme.tres"),
	"dark": preload("res://themes/dark_theme.tres"),
	"light": preload("res://themes/light_theme.tres")
}

var current_theme: String = "default"

func set_theme(theme_name: String):
	if not themes.has(theme_name):
		push_warning("[ThemeManager] 主题不存在: " + theme_name)
		return

	current_theme = theme_name
	var theme = themes[theme_name]

	# 应用到所有UI节点
	var ui_root = get_node("/root/Main/UILayer")
	_apply_theme_recursive(ui_root, theme)

	print("[ThemeManager] 切换到主题: " + theme_name)

func _apply_theme_recursive(node: Node, theme: Theme):
	if node is Control:
		node.theme = theme

	for child in node.get_children():
		_apply_theme_recursive(child, theme)
```

---

## 10. 性能优化

### 10.1 UI更新优化

```gdscript
# 1. UI更新节流(已在ObservationPanel中实现)

# 2. 虚拟列表(大量角色时使用)
class_name VirtualList extends ScrollContainer

var item_height: float = 50.0
var visible_item_count: int = 10
var total_item_count: int = 0
var item_pool: Array = []

func _process(delta):
	# 只渲染可见范围内的项目
	var scroll_offset = scroll_vertical
	var first_visible_index = int(scroll_offset / item_height)
	var last_visible_index = first_visible_index + visible_item_count

	_update_visible_items(first_visible_index, last_visible_index)

# 3. UI元素池化
# (已在ObjectPool中实现,见15_Godot项目技术架构.md)
```

### 10.2 渲染优化

```gdscript
# 1. 不在视野内的UI元素不更新
func _on_visibility_changed():
	if not visible:
		set_process(false)
		set_physics_process(false)
	else:
		set_process(true)
		set_physics_process(true)

# 2. 使用CanvasLayer分层渲染
# (已在UI层级结构中实现)

# 3. 减少Draw Calls
# - 使用TextureAtlas合并小图标
# - 尽量使用主题而不是单独设置样式
```

---

## 11. UI测试与调试

### 11.1 UI自动化测试(未来扩展)

```gdscript
# tests/ui/test_observation_panel.gd
extends GutTest

var observation_panel: ObservationPanel

func before_each():
	observation_panel = preload("res://scene/ui/ObservationPanel.tscn").instantiate()
	add_child_autofree(observation_panel)

func test_display_character():
	var test_character = AICharacterData.new()
	test_character.character_name = "Test Alice"
	test_character.age = 25

	observation_panel.display_character(test_character)

	assert_eq(observation_panel.current_character, test_character)
	assert_true(observation_panel.visible)

func test_thought_display():
	var test_thought = "这是一个测试思考"
	observation_panel._display_new_thought(test_thought)

	assert_eq(observation_panel.current_thought_text.text, test_thought)
```

### 11.2 UI调试覆盖层

```gdscript
# scene/ui/UIDebugOverlay.gd
extends CanvasLayer

var show_bounds: bool = false
var show_anchors: bool = false

func _input(event):
	if event.is_action_pressed("debug_toggle_ui_bounds"):  # F3
		show_bounds = !show_bounds
		queue_redraw()

	if event.is_action_pressed("debug_toggle_ui_anchors"):  # F4
		show_anchors = !show_anchors
		queue_redraw()

func _draw():
	if show_bounds:
		_draw_ui_bounds()

	if show_anchors:
		_draw_ui_anchors()

func _draw_ui_bounds():
	# 绘制所有Control节点的边界框
	var controls = get_tree().get_nodes_in_group("ui")
	for control in controls:
		if control is Control and control.visible:
			var rect = control.get_global_rect()
			draw_rect(rect, Color(1, 0, 0, 0.3), false, 2.0)

func _draw_ui_anchors():
	# 绘制锚点位置
	pass  # 实现细节...
```

---

## 12. 总结与实现清单

### 12.1 核心UI组件完成度

- [x] HUD顶部栏设计
- [x] CharacterListPanel角色列表设计
- [x] ObservationPanel观察面板设计
  - [x] CharacterInfo角色信息
  - [x] ThoughtDisplay思考显示
  - [x] StatsDisplay状态显示
  - [x] RelationshipView关系视图
  - [x] MemoryView记忆视图
- [x] NotificationBar通知栏设计
- [x] CameraController摄像机控制
- [x] 模态框设计(关系图谱)

### 12.2 交互功能完成度

- [x] 角色选择与焦点切换
- [x] 摄像机跟随与自由移动
- [x] 时间控制(暂停/速度)
- [x] 实时事件通知
- [x] 筛选与搜索功能
- [x] 键盘快捷键
- [x] 工具提示系统

### 12.3 视觉效果完成度

- [x] UI动画系统
- [x] 打字机效果
- [x] 过渡动画
- [x] 实时反馈动画
- [x] 主题系统
- [x] 响应式布局

#### 3.3.6 记忆视图 (MemoryView)

```gdscript
# scene/ui/ObservationPanel/MemoryView.gd
extends VBoxContainer

var current_character_id: String = ""

@onready var memory_list = $ScrollContainer/MemoryList
@onready var filter_buttons = $FilterButtons
@onready var memory_timeline = $Timeline

func _ready():
	EventBus.connect("ui_focus_changed", _on_ui_focus_changed)
	EventBus.connect("memory_added", _on_memory_added)

	_setup_filter_buttons()

func _setup_filter_buttons():
	filter_buttons.add_button("全部", "all")
	filter_buttons.add_button("重要", "important")
	filter_buttons.add_button("工作", "work")
	filter_buttons.add_button("社交", "social")
	filter_buttons.add_button("情感", "emotional")

	filter_buttons.filter_changed.connect(_on_filter_changed)

func _on_ui_focus_changed(ai_id: String):
	current_character_id = ai_id
	_update_display("all")

func _on_memory_added(ai_id: String, memory: Dictionary):
	if ai_id == current_character_id:
		_update_display(filter_buttons.current_filter)

func _on_filter_changed(filter_type: String):
	_update_display(filter_type)

func _update_display(filter_type: String):
	# 清空旧的
	for child in memory_list.get_children():
		child.queue_free()

	# 获取记忆
	var memories = MemoryManager.get_memories(current_character_id, 50)

	# 筛选
	var filtered_memories = _filter_memories(memories, filter_type)

	# 按时间排序 (最新的在前)
	filtered_memories.sort_custom(func(a, b):
		return a.timestamp > b.timestamp
	)

	# 显示记忆卡片
	for memory in filtered_memories.slice(0, 20):  # 最多显示20条
		var card = _create_memory_card(memory)
		memory_list.add_child(card)

func _filter_memories(memories: Array, filter_type: String) -> Array:
	if filter_type == "all":
		return memories

	var filtered = []
	for memory in memories:
		match filter_type:
			"important":
				if memory.importance >= 70:
					filtered.append(memory)
			"work":
				if memory.type == MemoryManager.MemoryType.TASK:
					filtered.append(memory)
			"social":
				if memory.type == MemoryManager.MemoryType.INTERACTION:
					filtered.append(memory)
			"emotional":
				if memory.type == MemoryManager.MemoryType.EMOTION:
					filtered.append(memory)

	return filtered

func _create_memory_card(memory: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)

	var vbox = VBoxContainer.new()
	card.add_child(vbox)

	# 顶部: 时间 + 重要性星级
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var time_label = Label.new()
	time_label.text = _format_memory_timestamp(memory.timestamp)
	time_label.add_theme_font_size_override("font_size", 10)
	time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	top_hbox.add_child(time_label)

	var importance_label = Label.new()
	importance_label.text = _get_importance_stars(memory.importance)
	importance_label.add_theme_font_size_override("font_size", 12)
	top_hbox.add_child(importance_label)

	# 记忆内容
	var content_label = Label.new()
	content_label.text = memory.content
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(content_label)

	# 记忆类型标签
	var type_label = Label.new()
	type_label.text = _get_memory_type_text(memory.type)
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", _get_memory_type_color(memory.type))
	vbox.add_child(type_label)

	return card

func _format_memory_timestamp(timestamp: Dictionary) -> String:
	return "%s %d日 %02d:%02d" % [
		TimeSystem.SEASONS[timestamp.season],
		timestamp.day,
		timestamp.hour,
		timestamp.minute
	]

func _get_importance_stars(importance: int) -> String:
	var stars = ""
	var star_count = int(importance / 20.0)  # 0-5星
	for i in range(star_count):
		stars += "⭐"
	return stars

func _get_memory_type_text(type: int) -> String:
	match type:
		MemoryManager.MemoryType.PERSONAL:
			return "个人"
		MemoryManager.MemoryType.INTERACTION:
			return "社交"
		MemoryManager.MemoryType.TASK:
			return "工作"
		MemoryManager.MemoryType.EMOTION:
			return "情感"
		MemoryManager.MemoryType.EVENT:
			return "事件"
		_:
			return "其他"

func _get_memory_type_color(type: int) -> Color:
	match type:
		MemoryManager.MemoryType.PERSONAL:
			return Color(0, 1, 1)
		MemoryManager.MemoryType.INTERACTION:
			return Color(0, 1, 0)
		MemoryManager.MemoryType.TASK:
			return Color(1, 0.5, 0)
		MemoryManager.MemoryType.EMOTION:
			return Color(1, 0, 1)
		MemoryManager.MemoryType.EVENT:
			return Color(1, 1, 0)
		_:
			return Color(0.5, 0.5, 0.5)
```

**记忆视图视觉示例**:
```
┌────────────────────────────────────┐
│  📚 记忆                            │
├────────────────────────────────────┤
│  [全部] [重要] [工作] [社交] [情感] │
├────────────────────────────────────┤
│  春季 第3天 14:20  ⭐⭐⭐⭐         │
│  和Bob发生了激烈冲突,说了很多气话 │
│  #社交                             │
│  ─────────────────────────────────  │
│  春季 第3天 12:30  ⭐⭐⭐           │
│  完成了重要的项目,老板很满意       │
│  #工作                             │
│  ─────────────────────────────────  │
│  春季 第2天 18:00  ⭐⭐⭐⭐⭐       │
│  和Alice成为了恋人,感觉很幸福      │
│  #情感                             │
└────────────────────────────────────┘
```

---

### 3.4 事件通知UI (补充EventSystem集成)

#### 3.4.1 事件通知分级显示

```gdscript
# scene/ui/EventNotificationManager.gd
extends CanvasLayer

# 通知层级
enum NotificationLevel {
	MINOR = 1,    # 小气泡,右上角
	NORMAL = 2,   # 右侧面板
	MAJOR = 3,    # 中央卡片
	EPIC = 4      # 全屏覆盖
}

@onready var minor_container = $MinorContainer
@onready var normal_container = $NormalContainer
@onready var major_modal = $MajorModal
@onready var epic_modal = $EpicModal

func _ready():
	EventBus.connect("event_created", _on_event_created)

func _on_event_created(event: EventData):
	if not event.is_observable:
		return

	match event.ui_notification_level:
		NotificationLevel.MINOR:
			_show_minor_notification(event)
		NotificationLevel.NORMAL:
			_show_normal_notification(event)
		NotificationLevel.MAJOR:
			_show_major_notification(event)
		NotificationLevel.EPIC:
			_show_epic_notification(event)

# Level 1: 小气泡通知
func _show_minor_notification(event: EventData):
	var bubble = preload("res://scene/ui/Notifications/MinorBubble.tscn").instantiate()
	bubble.setup(event)
	minor_container.add_child(bubble)

	# 3秒后自动消失
	await get_tree().create_timer(3.0).timeout
	bubble.queue_free()

# Level 2: 右侧通知面板
func _show_normal_notification(event: EventData):
	var panel = preload("res://scene/ui/Notifications/NormalPanel.tscn").instantiate()
	panel.setup(event)
	normal_container.add_child(panel)

	# 10秒后自动消失(或手动关闭)
	panel.auto_dismiss_timer = 10.0

# Level 3: 中央重要卡片
func _show_major_notification(event: EventData):
	major_modal.setup(event)
	major_modal.visible = true

	# 暂停游戏时间(可选)
	if event.importance >= EventData.Importance.MAJOR:
		TimeSystem.pause()

# Level 4: 全屏史诗事件
func _show_epic_notification(event: EventData):
	epic_modal.setup(event)
	epic_modal.visible = true

	# 强制暂停游戏
	TimeSystem.pause()
```

#### 3.4.2 重要事件卡片设计

```gdscript
# scene/ui/Notifications/MajorEventCard.gd
extends PanelContainer

var event_data: EventData

@onready var title_label = $VBox/TitleLabel
@onready var icon = $VBox/Icon
@onready var description_label = $VBox/DescriptionLabel
@onready var participants_container = $VBox/ParticipantsContainer
@onready var view_details_button = $VBox/ButtonsHBox/ViewDetailsButton
@onready var focus_button = $VBox/ButtonsHBox/FocusButton
@onready var dismiss_button = $VBox/ButtonsHBox/DismissButton

func setup(event: EventData):
	event_data = event

	# 设置标题
	title_label.text = event.event_name
	title_label.add_theme_color_override("font_color", event.ui_color)

	# 设置图标
	if event.ui_icon != "":
		icon.texture = load(event.ui_icon)

	# 设置描述
	description_label.text = event.observer_description

	# 显示参与者头像
	_display_participants()

	# 连接按钮
	view_details_button.pressed.connect(_on_view_details)
	focus_button.pressed.connect(_on_focus)
	dismiss_button.pressed.connect(_on_dismiss)

	# 入场动画
	_animate_in()

func _display_participants():
	for child in participants_container.get_children():
		child.queue_free()

	for ai_id in event_data.participants:
		var avatar = TextureRect.new()
		avatar.texture = load("res://assets/avatars/%s_small.png" % ai_id)
		avatar.custom_minimum_size = Vector2(40, 40)
		participants_container.add_child(avatar)

func _animate_in():
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)

func _on_view_details():
	# 打开事件详情模态框
	EventBus.emit_signal("ui_show_event_details", event_data.event_id)
	_on_dismiss()

func _on_focus():
	# 聚焦到主要参与者
	if event_data.primary_participant != "":
		EventBus.emit_signal("ui_focus_changed", event_data.primary_participant)
	_on_dismiss()

func _on_dismiss():
	# 淡出动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

	# 恢复游戏时间
	if TimeSystem.time_paused:
		TimeSystem.resume()
```

**重要事件卡片视觉示例**:
```
┌─────────────────────────────────────────┐
│             🎉 重要事件                  │
├─────────────────────────────────────────┤
│           [事件图标]                     │
│                                         │
│     Alice和Bob开始恋爱了!                │
│                                         │
│  在夕阳下,Alice和Bob终于向对方表白,      │
│  两人正式成为恋人!这是他们关系的重要      │
│  里程碑。                                │
│                                         │
│  参与者: [Alice头像] [Bob头像]           │
│                                         │
│  [查看详情] [聚焦] [知道了]              │
└─────────────────────────────────────────┘
```

---

### 12.4 补充完善功能

- ✅ MemoryView记忆视图 (已补充完整实现)
- ✅ 事件通知UI分级系统 (已补充)
- ⏳ 存档菜单UI(SaveLoadUIManager已存在,需优化)
- ⏳ 设置菜单UI(SettingsManager已存在,需设计UI)
- ⏳ 关系图谱模态框的完整交互
- ⏳ 屏幕阅读器支持
- ⏳ UI自动化测试

### 12.5 开发优先级

**P0 (立即开始)**:
1. ✅ 创建HUD场景和脚本
2. ✅ 创建CharacterListPanel场景和脚本
3. ✅ 创建ObservationPanel场景和脚本(CharacterInfo, ThoughtDisplay, StatsDisplay)
4. ✅ 创建NotificationBar场景和脚本
5. ✅ 实现CameraController
6. ✅ 应用主题样式

**P1 (后续迭代)**:
1. ⏳ RelationshipView完整实现
2. ⏳ MemoryView实现
3. ⏳ 关系图谱模态框
4. ⏳ UI动画抛光
5. ⏳ 响应式布局优化

**P2 (未来扩展)**:
1. ⏳ 动态主题切换
2. ⏳ 无障碍功能完善
3. ⏳ UI自动化测试
4. ⏳ 更多模态框(角色详情、记忆详情等)

---

## 附录: UI资源清单

### A.1 图标资源需求

```
res://assets/icons/
├── season_spring.png      # 春季图标
├── season_summer.png      # 夏季图标
├── season_autumn.png      # 秋季图标
├── season_winter.png      # 冬季图标
├── emotion_happy.png      # 高兴表情
├── emotion_sad.png        # 悲伤表情
├── emotion_angry.png      # 愤怒表情
├── emotion_neutral.png    # 中性表情
├── emotion_excited.png    # 兴奋表情
├── emotion_tired.png      # 疲惫表情
├── play.png               # 播放按钮
├── pause.png              # 暂停按钮
├── speed_1x.png           # 1倍速图标
├── speed_2x.png           # 2倍速图标
├── speed_3x.png           # 3倍速图标
└── ...
```

### A.2 字体资源需求

```
res://assets/fonts/
├── pixel_font.ttf         # 像素字体(主UI)
└── handwriting_font.ttf   # 手写体(对话/思考)
```

### A.3 头像资源需求

```
res://assets/avatars/
├── alice.png              # 小头像(40x40)
├── alice_small.png        # 超小头像(30x30)
├── alice_large.png        # 大头像(100x100)
├── bob.png
├── bob_small.png
├── bob_large.png
└── ... (其他角色)
```

---

**文档结束**

**所有P0文档已完成!** 现在可以开始正式开发Microverse项目了!
