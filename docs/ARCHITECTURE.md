# 苏格拉底终端 - 技术架构文档

> 面向开发者的系统设计说明

---

## 📋 目录

1. [系统概述](#系统概述)
2. [核心架构](#核心架构)
3. [模块详解](#模块详解)
4. [数据流](#数据流)
5. [关键算法](#关键算法)
6. [扩展指南](#扩展指南)

---

## 🏗️ 系统概述

### 技术栈

- **引擎**: Godot 4.4+ (GDScript)
- **UI框架**: Godot Control节点 + RichTextLabel (BBCode渲染)
- **网络**: HTTPRequest (异步API调用)
- **数据存储**: JSON文件 (本地持久化)

### 设计理念

**苏格拉底终端**采用**事件驱动**和**信号解耦**的架构:

1. **Autoload单例**: 全局管理器通过Godot的autoload系统注册
2. **Signal通信**: 模块间通过信号(Signal)松耦合通信
3. **无状态API**: HTTP请求无状态,失败自动重试
4. **可配置AI**: 角色人格和API通过JSON配置,热更新

---

## 🎯 核心架构

### 系统层次图

```
┌─────────────────────────────────────────────────┐
│             UI Layer (用户交互层)                │
│  ┌───────────────────────────────────────────┐  │
│  │        TerminalChat.gd                    │  │
│  │  - 终端界面渲染                            │  │
│  │  - 命令解析                                │  │
│  │  - Markdown→BBCode转换                    │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                      ↓ signals
┌─────────────────────────────────────────────────┐
│       Orchestration Layer (编排层)              │
│  ┌────────────────┐  ┌────────────────────────┐ │
│  │ MultiAgent     │  │   DepthAnalyzer.gd    │ │
│  │ Orchestrator   │  │  - 深度检测算法        │ │
│  │ - 对话编排     │  │  - 概念层次识别        │ │
│  │ - 轮次控制     │  │  - 批判互动检测        │ │
│  │ - Prompt构建   │  └────────────────────────┘ │
│  └────────────────┘                             │
└─────────────────────────────────────────────────┘
          ↓ signals              ↓ data
┌─────────────────────────────────────────────────┐
│        Management Layer (管理层)                │
│  ┌────────────┐ ┌──────────┐ ┌───────────────┐ │
│  │ AgentMgr   │ │ APIMgr   │ │ SettingsMgr  │ │
│  │ - 角色管理  │ │ -API调用 │ │ - 配置持久化  │ │
│  │ - 配置加载  │ │ -请求构建│ │ - 环境变量   │ │
│  └────────────┘ └──────────┘ └───────────────┘ │
└─────────────────────────────────────────────────┘
          ↓                     ↓
┌─────────────────────────────────────────────────┐
│         Data/Config Layer (数据层)              │
│  ┌────────────┐          ┌───────────────────┐ │
│  │ APIConfig  │          │  JSON配置文件      │ │
│  │ - 厂商配置  │          │ - agents.json     │ │
│  │ - 请求格式  │          │ - settings.cfg    │ │
│  │ - 响应解析  │          └───────────────────┘ │
│  └────────────┘                                │
└─────────────────────────────────────────────────┘
```

### Autoload单例

项目通过[project.godot:18-23](../project.godot#L18-L23)注册了4个全局单例:

```gdscript
[autoload]
SettingsManager="*res://script/ui/SettingsManager.gd"
APIManager="*res://script/ai/APIManager.gd"
AgentManager="*res://script/ai/terminal/AgentManager.gd"
MultiAgentOrchestrator="*res://script/ai/terminal/MultiAgentOrchestrator.gd"
```

**访问方式**:
```gdscript
var api_mgr = get_node("/root/APIManager")
var agents = get_node("/root/AgentManager")
```

---

## 📦 模块详解

### 1. AgentManager (AI角色管理器)

**文件**: [script/ai/terminal/AgentManager.gd](../script/ai/terminal/AgentManager.gd)

**职责**:
- 加载/保存AI角色配置(`user://agents.json`)
- 提供8个预设角色模板
- 管理角色启用/禁用状态
- 同步角色配置到SettingsManager

**核心API**:
```gdscript
# 获取所有角色
func get_agents() -> Array

# 获取已启用的角色
func get_enabled_agents() -> Array

# 添加或更新角色
func upsert_agent(agent: Dictionary) -> void

# 设置API密钥
func set_agent_key(name: String, api_key: String) -> void

# 获取主持人角色
func get_moderator() -> Dictionary
```

**信号**:
```gdscript
signal agents_changed  # 角色配置改变时触发
```

**数据结构**:
```gdscript
{
  "name": "苏格拉底",
  "api_type": "OpenAI",
  "model": "gpt-4o-mini",
  "api_key": "sk-...",
  "system_prompt": "你是苏格拉底式引导者...",
  "color": Color(0.6, 0.9, 1.0),
  "enabled": true,
  "is_moderator": true
}
```

**环境变量支持**:
```gdscript
# 在_validate_and_fill中自动展开
if a.api_key.begins_with("${ENV:") and a.api_key.ends_with("}"):
    var varname := a.api_key.substr(6, a.api_key.length() - 7)
    a.api_key = OS.get_environment(varname)
```

---

### 2. MultiAgentOrchestrator (对话编排器)

**文件**: [script/ai/terminal/MultiAgentOrchestrator.gd](../script/ai/terminal/MultiAgentOrchestrator.gd)

**职责**:
- 管理对话轮次和历史
- 构建AI Prompt
- 协调多AI发言顺序
- 定期进行深度检测
- 识别用户"懂了"信号

**核心API**:
```gdscript
# 开始新话题
func start(topic: String) -> void

# 停止讨论
func stop() -> void

# 用户插话
func user_message(text: String) -> void

# 检查是否活跃
func is_active() -> bool

# 获取对话历史
func history() -> Array
```

**信号**:
```gdscript
signal line_emitted(role: String, name: String, text: String, color: Color)
signal discussion_started(topic: String)
signal discussion_stopped()
signal summary_available(text: String)
```

**关键常量**:
```gdscript
const MAX_TURNS := 50                  # 最大轮次
const MAX_PER_AGENT_TURNS := 12        # 单AI最大发言次数
const TURN_DELAY_SEC := 0.2            # 发言间隔
const DEPTH_CHECK_INTERVAL := 5        # 深度检测间隔
```

**Prompt构建** (见[_compose_agent_prompt](../script/ai/terminal/MultiAgentOrchestrator.gd#L142)):

```gdscript
func _compose_agent_prompt(agent: Dictionary) -> String:
    var header := "你是「%s」。%s\n请以严谨、友好且高信息密度风格参与深度讨论。" % [
        agent.name,
        agent.get("system_prompt", "")
    ]

    var topic_line := "当前讨论主题：%s" % _topic

    var rules := """深度讨论规范:
    1. **深入本质**: 不满足于表面解释...
    2. **批判性思维**: 积极指出他人论述的漏洞...
    ..."""

    var prior := _render_history_as_bullets(12)  # 最近12条消息

    var task := ""
    if _stop_requested:
        task = "用户表示理解。请简洁确认核心要点..."
    else:
        var depth := DepthAnalyzer.assess_depth(_history)
        if depth.score < 0.5:
            task = "当前讨论深度不足。请深入探讨:\n"
            for suggestion in depth.suggestions:
                task += "• %s\n" % suggestion
        else:
            task = "针对上文继续深入..."

    return "%s\n\n主题: %s\n\n%s\n\n讨论记录:\n%s\n\n任务:\n%s" % [
        header, topic_line, rules, prior, task
    ]
```

**深度检测集成**:
```gdscript
# 在_drive_debate_loop中每5轮执行
if turn % DEPTH_CHECK_INTERVAL == 0 and _history.size() > 5:
    var depth_result := DepthAnalyzer.assess_depth(_history)
    if not depth_result.is_deep_enough:
        var report := DepthAnalyzer.generate_report(depth_result)
        _emit_system("深度分析", report)
        _emit_system("System", "讨论深度不足,各位请从'本质原理'等角度继续深入。")
    elif turn >= DEPTH_CHECK_INTERVAL * 2:
        _emit_system("System", "讨论已有一定深度。您是否理解了?")
```

---

### 3. DepthAnalyzer (深度分析器)

**文件**: [script/ai/terminal/DepthAnalyzer.gd](../script/ai/terminal/DepthAnalyzer.gd)

**职责**:
- 评估对话深度
- 识别概念层次
- 检测批判性互动
- 生成改进建议

**核心API**:
```gdscript
# 评估深度
static func assess_depth(history: Array) -> Dictionary

# 生成报告
static func generate_report(depth_data: Dictionary) -> String
```

**深度评估算法** (见[assess_depth](../script/ai/terminal/DepthAnalyzer.gd#L57)):

```gdscript
func assess_depth(history: Array) -> Dictionary:
    var depth_score := 0.0
    var concept_layers := 0
    var critical_count := 0

    # 1. 关键词深度分析 (40%权重)
    var keyword_score := _analyze_keywords(history)
    depth_score += keyword_score * 0.4

    # 2. 概念层次检测 (30%权重)
    concept_layers = _detect_concept_layers(history)
    depth_score += (concept_layers / 4.0) * 0.3

    # 3. 批判性互动检测 (30%权重)
    critical_count = _detect_critical_interactions(history)
    depth_score += min(critical_count / 5.0, 1.0) * 0.3

    return {
        "score": clamp(depth_score, 0.0, 1.0),
        "concept_layers": concept_layers,
        "critical_interactions": critical_count,
        "is_deep_enough": depth_score >= 0.6 and concept_layers >= 2
    }
```

**关键词权重表**:
```gdscript
const DEPTH_KEYWORDS := {
    "本质": 1.5,      # 深层思考标志
    "原理": 1.5,
    "反例": 1.5,      # 批判性思维
    "矛盾": 1.4,
    "类比": 1.2,      # 例证能力
    "差不多": -0.8,   # 浅层标志(负分)
    "我觉得": -0.4,
}
```

**概念层次定义**:
```gdscript
const LAYER_KEYWORDS := [
    ["现象", "表面", "看起来"],        # 层次1: 表面现象
    ["原因", "机制", "如何"],          # 层次2: 机制过程
    ["本质", "原理", "为什么"],        # 层次3: 本质原理
    ["公理", "基础", "假设"]           # 层次4: 基础假设
]
```

**批判互动短语**:
```gdscript
const CRITICAL_PHRASES := [
    "你说的", "这里有问题", "不对", "不准确",
    "忽略了", "应该", "纠正", "事实上"
]
```

---

### 4. APIManager & APIConfig (API调用层)

**文件**:
- [script/ai/APIManager.gd](../script/ai/APIManager.gd)
- [script/ai/APIConfig.gd](../script/ai/APIConfig.gd)

**APIConfig职责**:
- 静态配置所有AI厂商信息
- 提供统一的请求构建接口
- 统一的响应解析接口

**支持的AI厂商**:
```gdscript
_providers["OpenAI"]  # gpt-4o-mini, gpt-4o
_providers["Claude"]  # claude-3-5-sonnet
_providers["DeepSeek"]  # deepseek-chat
_providers["Gemini"]  # gemini-2.0-flash-exp
_providers["Doubao"]  # doubao-lite/pro
_providers["KIMI"]  # moonshot-v1
_providers["Ollama"]  # 本地模型
_providers["OpenAI-Compatible"]  # 兼容接口
```

**请求格式枚举**:
```gdscript
enum RequestFormat {
    OLLAMA,     # Ollama专用格式
    OPENAI,     # OpenAI兼容格式(最通用)
    GEMINI,     # Gemini专用格式
    CLAUDE      # Claude专用格式
}
```

**核心API**:
```gdscript
# 构建请求体
static func build_request_data(api_type: String, model: String, prompt: String) -> Dictionary

# 构建请求头
static func build_headers(api_type: String, api_key: String) -> PackedStringArray

# 解析响应
static func parse_response(api_type: String, response: Variant, character_name: String) -> String

# 获取厂商信息
static func get_provider(api_type: String) -> APIProvider
```

**APIManager职责**:
- 创建HTTPRequest节点
- 异步发送API请求
- 请求完成后自动销毁节点

**关键代码**:
```gdscript
func generate_dialog(prompt: String, character_name: String) -> HTTPRequest:
    var settings = SettingsManager.get_character_ai_settings(character_name)
    var provider = APIConfig.get_provider(settings.api_type)

    # 创建HTTPRequest
    var request = HTTPRequest.new()
    add_child(request)

    # 构建请求
    var headers = APIConfig.build_headers(provider.name, settings.api_key)
    var body = APIConfig.build_request_data(provider.name, settings.model, prompt)

    # 发送请求
    var url = provider.url.replace("{model}", settings.model)
    request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

    # 自动清理
    request.request_completed.connect(func(_r, _rc, _h, _b):
        request.queue_free()
    )

    return request
```

---

### 5. TerminalChat (终端UI)

**文件**: [script/ai/terminal/TerminalChat.gd](../script/ai/terminal/TerminalChat.gd)

**职责**:
- 渲染终端界面
- 解析用户命令
- 处理Markdown→BBCode转换
- 滚动控制

**场景结构** (TerminalChat.tscn):
```
TerminalChat (Control)
├── ColorRect (背景)
├── VBox (VBoxContainer)
│   ├── Toolbar (HBoxContainer)
│   │   ├── FontSize (HSlider)
│   │   └── ThemeBtn (Button)
│   ├── Scroll (ScrollContainer)
│   │   └── Output (RichTextLabel) ← BBCode渲染
│   └── InputRow (HBoxContainer)
│       ├── Input (LineEdit)
│       └── Send (Button)
```

**Markdown转BBCode** (见[_markdown_to_bbcode](../script/ai/terminal/TerminalChat.gd#L252)):
```gdscript
static func _markdown_to_bbcode(md: String) -> String:
    var result := md

    # 1. 代码块 ```code``` → [code]code[/code]
    var code_block_regex := RegEx.new()
    code_block_regex.compile("```([\\s\\S]*?)```")
    result = code_block_regex.sub(result, "[code]$1[/code]", true)

    # 2. 行内代码 `code` → [code]code[/code]
    # 3. 粗体 **text** → [b]text[/b]
    # 4. 斜体 *text* → [i]text[/i]
    # 5. 引用 > text → [color=#888]▌ text[/color]

    # 6. 转义剩余BBCode字符
    result = result.replace("[", "\\[").replace("]", "\\]")
    # 然后恢复之前转换的BBCode标签...

    return result
```

**命令解析** (见[_handle_command](../script/ai/terminal/TerminalChat.gd#L74)):
```gdscript
func _handle_command(cmdline: String) -> void:
    var parts := cmdline.substr(1).split(" ", false, 2)
    var cmd := parts[0].to_lower()
    var arg := "" if parts.size() < 2 else parts[1]

    match cmd:
        "help": _show_help()
        "topic": orchestrator.start(arg.strip_edges())
        "stop", "understood": orchestrator.stop()
        "agents": _handle_agents_subcommand(arg)
        "export": _export_transcript(arg)
        "color": fg_color = Color(arg); _apply_theme()
        ...
```

---

## 🔄 数据流

### 完整对话流程

```
1. 用户输入话题
   ↓
   TerminalChat._on_send()
   ↓
2. 启动讨论
   ↓
   MultiAgentOrchestrator.start(topic)
   ├── 清空历史 clear_history()
   ├── 发出信号 discussion_started.emit(topic)
   └── 进入循环 _drive_debate_loop()

3. 对话循环
   ↓
   for each agent in get_enabled_agents():
       ├── 构建Prompt: _compose_agent_prompt(agent)
       │   ├── 角色设定 (system_prompt)
       │   ├── 话题 (topic)
       │   ├── 讨论规范 (rules)
       │   ├── 历史对话 (最近12条)
       │   └── 当前任务 (深度检测结果)
       │
       ├── 调用API: await _agent_turn(agent)
       │   ├── APIManager.generate_dialog(prompt, agent.name)
       │   ├── 等待HTTP响应
       │   └── 解析: APIConfig.parse_response()
       │
       ├── 更新历史: _append_history(role, name, text)
       │
       ├── 发出信号: line_emitted.emit(role, name, text, color)
       │
       └── 延迟: await get_tree().create_timer(0.2).timeout

   turn += 1

   if turn % 5 == 0:  # 深度检测
       ├── DepthAnalyzer.assess_depth(history)
       ├── 生成报告: generate_report(depth_data)
       └── 引导AI: _emit_system("讨论深度不足...")

4. 用户插话
   ↓
   TerminalChat: 用户输入 "我不太理解"
   ↓
   MultiAgentOrchestrator.user_message(text)
   ├── 追加到历史: _append_history("user", "You", text)
   ├── 检测"懂了"信号: _matches_understood(text)
   │   └── 如果匹配 → _stop_requested = true
   └── 继续AI发言循环

5. 讨论结束
   ↓
   用户说"懂了" OR 达到最大轮次
   ↓
   获取主持人: moderator = AgentManager.get_moderator()
   ↓
   生成总结: await _elicit_summary(moderator)
   ├── 构建总结Prompt
   ├── 调用主持人API
   └── 发出: summary_available.emit(summary)
   ↓
   发出信号: discussion_stopped.emit()
   ↓
   _active = false
```

---

## 🧮 关键算法

### 1. 深度分数计算

```
总分 = 关键词分数 * 0.4 + 层次分数 * 0.3 + 互动分数 * 0.3

关键词分数 = Σ(关键词权重) / (总字数/100) ∈ [0,1]

层次分数 = 检测到的层次数 / 4 ∈ [0,1]
  层次定义:
  - 0层: 无深度词汇
  - 1层: 表面现象("看起来","似乎")
  - 2层: 机制过程("原因","如何")
  - 3层: 本质原理("为什么","本质")
  - 4层: 基础假设("公理","前提")

互动分数 = min(批判短语出现次数 / 5, 1.0) ∈ [0,1]
```

### 2. 轮流发言调度

```gdscript
# 简单轮询策略
for turn in range(MAX_TURNS):
    for agent in get_enabled_agents():
        if _count_for(agent.name) >= MAX_PER_AGENT_TURNS:
            continue  # 跳过发言次数达上限的角色
        await _agent_turn(agent)
```

**未来可扩展为智能调度**:
```gdscript
func determine_next_speaker(topic, history) -> AIDebater:
    # 1. 分析话题关键词与AI专业领域匹配度
    # 2. 检测上一轮是否有人被质疑(被质疑者优先回应)
    # 3. 避免同一人连续发言超过2次
    # 4. 引入随机性(20%)避免固定模式
    pass
```

### 3. "懂了"信号识别

```gdscript
func _matches_understood(text: String) -> bool:
    var t := text.strip_edges().to_lower()
    var phrases := [
        "我懂了", "懂了", "明白了", "清楚了", "了解了",
        "i understand", "i got it", "got it", "makes sense"
    ]
    for p in phrases:
        if t.find(p.to_lower()) != -1:
            return true
    return false
```

---

## 🔧 扩展指南

### 添加新的AI厂商

**1. 在APIConfig中注册**:

编辑[script/ai/APIConfig.gd](../script/ai/APIConfig.gd):

```gdscript
# 在_initialize()中添加
_providers["NewProvider"] = APIProvider.new(
    "NewProvider",
    "新厂商显示名",
    "https://api.example.com/v1/chat/completions",
    ["model-a", "model-b"],  # 可用模型列表
    true,  # 是否需要API Key
    {"Content-Type": "application/json", "Authorization": "Bearer {api_key}"},
    "openai",  # 请求格式(复用现有或新增)
    "openai"   # 响应解析器
)
```

**2. 如果请求格式不兼容,添加新格式**:

```gdscript
func build_request_data(api_type: String, model: String, prompt: String) -> Dictionary:
    match provider.request_format:
        "newformat":
            return {
                "model": model,
                "input": prompt,
                "custom_field": "value"
            }
```

**3. 如果响应格式不兼容,添加解析器**:

```gdscript
func parse_response(api_type: String, response: Variant, character_name: String) -> String:
    match provider.response_parser:
        "newformat":
            return response["result"]["message"]
```

---

### 添加新的深度检测维度

编辑[script/ai/terminal/DepthAnalyzer.gd](../script/ai/terminal/DepthAnalyzer.gd):

```gdscript
# 1. 添加新的检测函数
static func _detect_novelty(history: Array) -> float:
    # 检测新观点引入率
    var unique_concepts := []
    for msg in history:
        # 提取关键词,去重...
    return unique_concepts.size() / float(history.size())

# 2. 在assess_depth中集成
func assess_depth(history: Array) -> Dictionary:
    # ...
    var novelty_score := _detect_novelty(history)
    depth_score += novelty_score * 0.1  # 新增10%权重
    # ...
```

---

### 自定义Prompt模板

编辑[script/ai/terminal/MultiAgentOrchestrator.gd](../script/ai/terminal/MultiAgentOrchestrator.gd):

```gdscript
func _compose_agent_prompt(agent: Dictionary) -> String:
    # 可以根据agent.name定制不同的Prompt结构
    if agent.name == "代码审查者":
        return _build_code_review_prompt(agent)
    elif agent.name == "数学证明者":
        return _build_math_proof_prompt(agent)
    else:
        return _build_default_prompt(agent)
```

---

### 添加新命令

编辑[script/ai/terminal/TerminalChat.gd](../script/ai/terminal/TerminalChat.gd):

```gdscript
func _handle_command(cmdline: String) -> void:
    var parts := cmdline.substr(1).split(" ", false, 2)
    var cmd := parts[0].to_lower()
    var arg := "" if parts.size() < 2 else parts[1]

    match cmd:
        # 添加新命令
        "summary":
            var summary := _generate_quick_summary()
            _append_system(summary)

        "translate":
            if arg == "":
                _append_system("用法: /translate [语言]")
            else:
                _set_translation_mode(arg)

        # ... 其他命令
```

---

## 📊 性能优化

### Token消耗优化

**当前策略**:
- 每次请求仅发送最近12条消息
- 总结时单独请求,不重复完整历史

**可优化点**:
1. **消息压缩**: 对历史消息进行摘要压缩
2. **关键信息提取**: 仅保留关键论点,删除冗余
3. **上下文窗口管理**: 根据模型上下文长度动态调整历史条数

```gdscript
func _render_history_smart(max_tokens: int) -> String:
    var history_text := ""
    var token_count := 0
    for i in range(_history.size() - 1, -1, -1):  # 倒序
        var msg_text := _history[i].text
        var msg_tokens := _estimate_tokens(msg_text)
        if token_count + msg_tokens > max_tokens:
            break
        history_text = "- %s: %s\n%s" % [_history[i].name, msg_text, history_text]
        token_count += msg_tokens
    return history_text
```

### HTTP请求并发

**当前**: 顺序发言,每个AI等待前一个完成

**可优化**: 并发请求,按完成顺序显示(适合快速头脑风暴)

```gdscript
func _parallel_agent_turns(agents: Array) -> void:
    var requests := []
    for agent in agents:
        var prompt := _compose_agent_prompt(agent)
        var req := await _api_mgr.generate_dialog(prompt, agent.name)
        requests.append({"agent": agent, "request": req})

    # 等待所有完成
    for r in requests:
        await r.request.request_completed
```

---

## 🧪 测试指南

### 单元测试示例

创建`tests/test_depth_analyzer.gd`:

```gdscript
extends GutTest

func test_shallow_discussion():
    var history := [
        {"role": "assistant", "name": "A", "text": "这个概念就是..."},
        {"role": "assistant", "name": "B", "text": "我觉得差不多就这样"},
    ]
    var result := DepthAnalyzer.assess_depth(history)
    assert_lt(result.score, 0.3, "浅层讨论应低于0.3分")
    assert_eq(result.concept_layers, 0, "应该没有概念层次")

func test_deep_discussion():
    var history := [
        {"role": "assistant", "name": "A", "text": "本质原理是...这里有反例..."},
        {"role": "assistant", "name": "B", "text": "你说的有问题,忽略了边界条件..."},
        {"role": "assistant", "name": "C", "text": "从公理出发推导..."},
    ]
    var result := DepthAnalyzer.assess_depth(history)
    assert_gt(result.score, 0.6, "深度讨论应高于0.6分")
    assert_gte(result.concept_layers, 2, "应至少2层概念")
```

---

## 📚 参考资料

- [Godot 4.4 文档](https://docs.godotengine.org/en/stable/)
- [GDScript 风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [OpenAI API 文档](https://platform.openai.com/docs/api-reference)
- [Anthropic Claude API](https://docs.anthropic.com/claude/reference)

---

**架构设计遵循**: 高内聚、低耦合、单一职责、开闭原则
