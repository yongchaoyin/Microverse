# LLM集成架构详细规范

> **文档类型**: 技术实现规范
> **关联文档**: [02_核心系统设计.md](../02_核心系统设计.md)
> **目标**: 定义AI决策的LLM调用架构、Prompt工程和成本优化策略
> **设计哲学**: AI完全自主决策,观察者只能观察和有限影响

---

## 📋 目录

1. [系统概述](#系统概述)
2. [LLM调用架构](#llm调用架构)
3. [Prompt工程策略](#prompt工程策略)
4. [AI决策场景分类](#ai决策场景分类)
5. [上下文构建系统](#上下文构建系统)
6. [响应解析与验证](#响应解析与验证)
7. [错误处理与降级](#错误处理与降级)
8. [成本优化策略](#成本优化策略)
9. [完整代码实现](#完整代码实现)

---

## 🎯 系统概述

### 设计原则

**核心哲学**:
- ✅ **AI完全自主**: LLM生成的决策不受玩家直接控制
- ✅ **记忆驱动**: AI决策基于其记忆、性格、关系
- ✅ **涌现叙事**: 故事从AI互动中自然产生,而非脚本化
- ✅ **真实智能**: AI应该"思考"而非"执行指令"

**不考虑token消耗的设计**:
- ✅ 为每次AI决策提供丰富的上下文信息
- ✅ 包含完整的记忆、关系、性格数据
- ✅ 详细的场景描述和社交网络信息
- ✅ 历史事件和长期目标

### LLM调用场景 (预算充足版)

**核心理念**: AI应该**持续思考**,而不是定期决策。

在Microverse中,AI在以下场景**实时调用LLM**:

| 场景类型 | 调用频率 | Token估算(input+output) | 说明 |
|---------|---------|----------------------|------|
| **持续思考流** | 每10分钟游戏时间 | 2000-3000 | AI的内心独白、观察、反思 |
| **社交对话** | 每句话 | 1500-2500 | 每次对话回合都调用LLM |
| **环境感知** | 每5分钟游戏时间 | 1000-1500 | AI观察周围环境和人物 |
| **情绪波动** | 每次事件触发 | 800-1200 | 实时情绪反应 |
| **工作思考** | 工作时每15分钟 | 1500-2000 | 工作中的思考和决策 |
| **关系评估** | 每次互动后 | 1000-1500 | 评估关系变化 |
| **记忆整合** | 每小时游戏时间 | 2000-3000 | 整理和反思记忆 |
| **目标规划** | 每天早晨 | 3000-5000 | 规划当天和长期目标 |
| **睡前反思** | 每天睡前 | 2000-3000 | 回顾一天,整合记忆 |
| **梦境生成** | 睡眠时 | 1500-2000 | 生成基于记忆的梦境内容 |

**每个AI每游戏日的详细估算** (20小时游戏时间):

1. **持续思考流**: 20小时 / 10分钟 = 120次 × 2500 tokens = **300,000 tokens**
2. **环境感知**: 20小时 / 5分钟 = 240次 × 1250 tokens = **300,000 tokens**
3. **社交对话**: 10-15次对话 × 5轮 × 2000 tokens = **100,000-150,000 tokens**
4. **工作思考**: 8小时工作 / 15分钟 = 32次 × 1750 tokens = **56,000 tokens**
5. **情绪波动**: 5-10次 × 1000 tokens = **5,000-10,000 tokens**
6. **关系评估**: 10-15次 × 1250 tokens = **12,500-18,750 tokens**
7. **记忆整合**: 20次 × 2500 tokens = **50,000 tokens**
8. **目标规划**: 1次 × 4000 tokens = **4,000 tokens**
9. **睡前反思**: 1次 × 2500 tokens = **2,500 tokens**
10. **梦境生成**: 1次 × 1750 tokens = **1,750 tokens**

**每个AI每游戏日总计**: ~**831,750 - 881,000 tokens**

**8个AI的总成本** (按游戏日):
- Total tokens: ~7,000,000 tokens/游戏日
- 使用GPT-4o-mini: $0.15/1M input + $0.60/1M output
- 假设 input:output = 2:1
  - Input: 4.7M × $0.15 = **$0.70**
  - Output: 2.3M × $0.60 = **$1.38**
- **每游戏日成本**: ~**$2.08**
- **每现实小时成本** (游戏日=2小时现实): ~**$1.04/小时**
- **每月成本** (每天玩4小时): ~**$125/月**

**预算充足策略**:
- ✅ AI真正"活着",持续思考
- ✅ 每个思考都有完整上下文
- ✅ 真实的内心世界和情感波动
- ✅ 深度的社交互动
- ✅ 涌现的叙事和故事

---

## 🏗️ LLM调用架构

### 现有架构解析

项目已经实现了灵活的多LLM支持架构:

```gdscript
# 现有的APIConfig.gd支持的LLM提供商
- Ollama (本地)
- OpenAI (GPT系列)
- DeepSeek
- Doubao (豆包)
- Gemini (Google)
- Claude (Anthropic)
- KIMI (月之暗面)
- OpenAI Compatible (兼容API)
```

### AI决策调用流程 (预算充足版)

**多层次思考系统**:

```
┌─────────────────────────────────────────────────────────────────┐
│  AI代理 (AIAgent.gd) - 多定时器系统                              │
│                                                                  │
│  1. 持续思考流 (10分钟游戏时间)                                 │
│     continuous_thought_timer → generate_inner_monologue()       │
│                                                                  │
│  2. 环境感知 (5分钟游戏时间)                                    │
│     perception_timer → perceive_environment()                   │
│                                                                  │
│  3. 工作思考 (15分钟游戏时间,工作时)                            │
│     work_thought_timer → think_about_work()                     │
│                                                                  │
│  4. 社交对话 (实时触发)                                         │
│     on_conversation_event → generate_dialogue_response()        │
│                                                                  │
│  5. 情绪反应 (事件触发)                                         │
│     on_emotion_trigger → process_emotional_response()           │
│                                                                  │
│  6. 记忆整合 (1小时游戏时间)                                    │
│     memory_integration_timer → integrate_memories()             │
│                                                                  │
│  7. 每日规划 (每天早晨6:00)                                     │
│     on_morning_started → plan_daily_goals()                     │
│                                                                  │
│  8. 睡前反思 (每天22:00)                                        │
│     on_bedtime → reflect_on_day()                               │
│                                                                  │
│  9. 梦境生成 (睡眠时)                                           │
│     during_sleep → generate_dreams()                            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  上下文构建器 (AIContextBuilder.gd) [新建]              │
│                                                          │
│  1. 获取AI当前状态 (精力、心情、位置)                   │
│  2. 加载相关记忆 (MemoryManager)                        │
│  3. 获取关系网络 (RelationshipManager)                  │
│  4. 读取性格特质 (CharacterPersonality)                 │
│  5. 获取职业和日程 (CareerSystem, ScheduleSystem)       │
│  6. 构建场景描述                                        │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Prompt生成器 (AIPromptGenerator.gd) [新建]             │
│                                                          │
│  根据决策类型选择Prompt模板:                            │
│  - daily_decision_template                              │
│  - social_interaction_template                          │
│  - work_decision_template                               │
│  - relationship_event_template                          │
│  - major_decision_template                              │
│                                                          │
│  填充上下文数据到模板                                   │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  APIManager (现有)                                       │
│                                                          │
│  generate_decision(prompt, character_name)              │
│  → 调用配置的LLM API                                    │
│  → 返回HTTPRequest                                      │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  响应解析器 (AIResponseParser.gd) [新建]                │
│                                                          │
│  1. 解析LLM返回的JSON响应                               │
│  2. 验证决策的合法性                                    │
│  3. 提取行动、情绪、思考                                │
│  4. 创建记忆条目                                        │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│  行动执行器 (AIActionExecutor.gd) [新建]                │
│                                                          │
│  根据LLM决策执行具体行动:                               │
│  - move_to(location)                                    │
│  - start_conversation(target_ai)                        │
│  - start_work()                                         │
│  - make_purchase(item)                                  │
│  - express_emotion(emotion)                             │
└─────────────────────────────────────────────────────────┘
```

---

## 🎨 Prompt工程策略

### Prompt设计原则

**1. 角色定位清晰**
```
你是{name},一个拥有真实情感和记忆的虚拟生命。
你完全自主地生活在Microverse小镇,没有人能控制你的思想和决策。
你的行为基于你的性格、记忆、情感和当前环境。
```

**2. 丰富的上下文信息**
- 完整的性格特质 (Big Five)
- 最近的记忆 (最近7天,按重要性排序)
- 关系网络 (好友、恋人、同事)
- 当前状态 (精力、心情、位置、时间)
- 职业信息 (工作内容、压力、薪资)
- 长期目标

**3. 结构化输出**
要求LLM返回JSON格式,便于解析:
```json
{
  "thought": "我在想什么",
  "action": "我决定做什么",
  "emotion": "我的情绪",
  "target": "行动对象(如果有)",
  "reason": "为什么这样决定"
}
```

### Prompt模板库

#### 模板1: 日常决策 (Daily Decision)

```markdown
# 你是谁
你是**{name}**,{age}岁,职业是{career}。

# 你的性格 (Big Five人格)
- 外向性 (Extraversion): {extraversion}/100
- 友善性 (Agreeableness): {agreeableness}/100
- 尽责性 (Conscientiousness): {conscientiousness}/100
- 神经质 (Neuroticism): {neuroticism}/100
- 开放性 (Openness): {openness}/100

{personality_description}

# 当前状态
- 时间: {current_time}
- 位置: {current_location}
- 精力: {energy}/100
- 心情: {mood}/100
- 压力: {stress}/100
- 金钱: {money}G

# 你的记忆 (最近7天)
{recent_memories}

# 你的人际关系
{relationships}

# 你的职业生活
- 职位: {career}
- 工作日: {work_days}
- 工作时间: {work_hours}
- 薪资: {salary}G/天
- 工作压力: {work_pressure}/100

# 你的日程安排
今天的计划:
{daily_schedule}

# 当前场景
{scene_description}

# 可选行动
你现在可以选择:
{available_actions}

# 决策任务
请根据你的性格、记忆、情感和当前状况,自主决定接下来要做什么。

**重要提醒**:
- 你是一个真实的虚拟生命,拥有自己的意志
- 你的决策应该符合你的性格特质
- 你应该考虑你的记忆和人际关系
- 你的行为应该对你的长期目标有帮助
- 你可以改变计划,不必严格遵守日程

请以JSON格式返回你的决策:
```json
{
  "thought": "你此刻的想法 (50字以内)",
  "action": "你决定的行动 (从可选行动中选择一个)",
  "target": "行动对象 (如果有,例如对话目标、移动目标)",
  "emotion": "你的情绪 (happy/sad/calm/excited/anxious/angry/tired)",
  "reason": "你为什么这样决定 (30字以内)"
}
```
```

#### 模板2: 社交对话 (Social Interaction)

```markdown
# 对话场景
你是**{name}**,正在和**{target_name}**对话。

# 你对{target_name}的了解
- 关系类型: {relationship_type}
- 好感度: {affection}/100
- 信任度: {trust}/100
- 熟悉度: {familiarity}/100
- 浪漫度: {romance}/100 (如果适用)

# 你们的共同记忆
{shared_memories}

# {target_name}的性格
{target_personality}

# 当前对话上下文
地点: {location}
时间: {time}
氛围: {atmosphere}

# 对话历史 (最近3轮)
{conversation_history}

# {target_name}刚才说:
"{last_message}"

# 你的任务
请根据你的性格、你们的关系、以及当前对话上下文,自然地回应{target_name}。

**对话原则**:
- 符合你的性格特质
- 考虑你们的关系亲密程度
- 回忆相关的共同经历
- 表达真实的情感
- 可以主动改变话题
- 可以提出邀约或请求

请以JSON格式返回:
```json
{
  "response": "你的回应内容 (100字以内,自然对话)",
  "emotion": "你说话时的情绪",
  "action": "伴随的动作 (smile/laugh/sigh/nod/shake_head/hug/none)",
  "relationship_change": "对关系的影响预期 (positive/neutral/negative)",
  "next_topic": "你想聊的下一个话题 (可选)"
}
```
```

#### 模板3: 重大决策 (Major Decision)

```markdown
# 重大决策场景
你是**{name}**,现在面临一个重要的人生抉择。

{decision_context}

# 你的长期目标
{long_term_goals}

# 你的性格倾向
{personality_analysis}

# 相关记忆和经历
{relevant_memories}

# 关键关系网络
{key_relationships}

# 你的财务状况
- 当前存款: {money}G
- 月收入: {monthly_income}G
- 月支出: {monthly_expense}G
- 储蓄率: {savings_rate}%

# 选项分析
{decision_options}

# 每个选项的潜在影响
{option_impacts}

# 决策任务
这是一个影响你未来的重要决定。请深思熟虑,基于:
- 你的性格和价值观
- 你的长期目标
- 你的人际关系
- 你的经济状况
- 你过去的经历

做出最符合你真实意愿的选择。

请以JSON格式返回:
```json
{
  "choice": "你的选择 (选项ID)",
  "reasoning": "你的详细思考过程 (200字以内)",
  "concerns": "你的顾虑 (如果有)",
  "expected_outcome": "你期待的结果",
  "emotion": "你的情绪状态",
  "confidence": "你对这个决定的信心 (0-100)"
}
```
```

#### 模板4: 工作决策 (Work Decision)

```markdown
# 工作场景
你是**{name}**,职业: {career}

# 当前工作状态
- 工作压力: {work_pressure}/100
- 工作满意度: {work_satisfaction}/100
- 职业发展: {career_level}级
- 在职时间: {tenure}个月
- 绩效评价: {performance}

# 工作环境
- 公司: {company}
- 上司: {boss} (关系: {boss_relationship})
- 同事: {colleagues}
- 办公地点: {office_location}

# 工作相关记忆
{work_memories}

# 当前工作任务
{current_tasks}

# 工作中的选择
{work_options}

# 决策任务
请根据你的性格、职业规划和工作状况,决定如何处理当前工作。

**考虑因素**:
- 工作压力是否过大
- 职业发展是否顺利
- 人际关系是否和谐
- 薪资是否满意
- 工作是否有意义

请以JSON格式返回:
```json
{
  "decision": "你的工作决策",
  "action": "具体行动",
  "motivation": "你的动机",
  "emotion": "你的情绪",
  "career_plan": "你的职业规划调整 (如果有)"
}
```
```

#### 模板5: 情绪反应 (Emotional Response)

```markdown
# 情绪事件
你是**{name}**,刚刚发生了:

{event_description}

# 你的性格特质
- 神经质 (Neuroticism): {neuroticism}/100
- 情绪稳定性: {emotional_stability}/100

# 当前心情
- 心情值: {mood}/100
- 压力值: {stress}/100
- 精力值: {energy}/100

# 类似经历
{similar_experiences}

# 相关人物
{involved_people}

# 反应任务
这个事件对你产生了什么影响?你会如何反应?

请以JSON格式返回:
```json
{
  "emotion": "你的主要情绪",
  "intensity": "情绪强度 (0-100)",
  "reaction": "你的即时反应",
  "thought": "你的内心想法",
  "long_term_impact": "这件事对你的长期影响"
}
```
```

#### 模板6: 持续思考流 (Continuous Thought Stream)

```markdown
# 内心独白时刻
你是**{name}**,现在是{current_time},你在{current_location}。

# 你的当前状态
- 正在做: {current_activity}
- 精力: {energy}/100
- 心情: {mood}/100
- 压力: {stress}/100

# 你最近的想法 (过去30分钟)
{recent_thoughts}

# 刚才发生的事
{recent_events}

# 周围的人
{nearby_characters}

# 你的近期记忆
{recent_memories}

# 你的关注点
{current_concerns}

# 思考任务
请生成你此刻的**内心独白** - 你在想什么?观察到什么?感受到什么?

**要求**:
- 真实、自然的内心想法
- 可以是观察、反思、计划、情感
- 可以跳跃性思维
- 可以联想到记忆
- 可以对未来有期待或担忧

请以JSON格式返回:
```json
{
  "inner_thought": "你的内心独白 (100-200字,第一人称)",
  "focus": "你此刻关注的焦点",
  "mood_change": "心情变化 (-10到+10)",
  "action_impulse": "你想做的事 (如果有)",
  "memory_trigger": "触发的记忆 (如果有)"
}
```
```

#### 模板7: 环境感知 (Environmental Perception)

```markdown
# 环境观察
你是**{name}**,现在在{current_location}。

# 环境描述
{environment_description}

# 周围的人
{people_present}

# 环境中的物品
{objects_present}

# 环境氛围
{atmosphere}

# 天气和时间
- 时间: {current_time}
- 天气: {weather}
- 光线: {lighting}

# 你的感官
- 视觉: {visual_info}
- 听觉: {audio_info}
- 嗅觉: {smell_info} (如果有)

# 你最近的活动
{recent_activities}

# 观察任务
作为一个真实的人,你会注意到环境中的什么?有什么引起你注意的?

请以JSON格式返回:
```json
{
  "observation": "你观察到的重要信息 (50-100字)",
  "noticed_person": "你注意到的人 (如果有)",
  "noticed_object": "你注意到的物品 (如果有)",
  "environmental_feeling": "环境给你的感觉",
  "curiosity": "你好奇的事情 (如果有)",
  "next_attention": "你想关注什么"
}
```
```

#### 模板8: 记忆整合 (Memory Integration)

```markdown
# 记忆整合时刻
你是**{name}**,现在要整理最近的经历和想法。

# 时间段
从 {start_time} 到 {end_time}

# 这段时间发生的事
{events_summary}

# 这段时间的对话
{conversations_summary}

# 这段时间的想法
{thoughts_summary}

# 情绪变化
{emotion_changes}

# 关系变化
{relationship_changes}

# 现有的重要记忆
{existing_memories}

# 整合任务
请将这些零散的经历整合成有意义的记忆,并评估重要性。

**考虑**:
- 哪些事情对你很重要?
- 哪些对话让你印象深刻?
- 你学到了什么?
- 你的想法有什么变化?
- 有什么值得记住的时刻?

请以JSON格式返回:
```json
{
  "integrated_memory": "整合后的记忆描述 (100-150字)",
  "importance": "重要性评分 (0-100)",
  "emotion_attached": "附加的情绪",
  "key_insight": "关键领悟 (如果有)",
  "related_people": "相关人物列表",
  "memory_type": "记忆类型 (social/work/personal/relationship)"
}
```
```

#### 模板9: 每日目标规划 (Daily Goal Planning)

```markdown
# 新的一天
你是**{name}**,现在是早晨{current_time},新的一天开始了。

# 今天是
{date_info} - {day_of_week}

# 你昨天的回顾
{yesterday_summary}

# 你的长期目标
{long_term_goals}

# 你的工作安排
{work_schedule}

# 你的人际关系状况
{relationship_status}

# 你的财务状况
- 存款: {money}G
- 本周收入: {weekly_income}G
- 月度支出: {monthly_expense}G

# 你的压力和心情
- 压力: {stress}/100
- 心情: {mood}/100
- 精力: {energy}/100

# 待办事项
{pending_tasks}

# 规划任务
作为一个有自主意识的人,你会如何规划今天?

**考虑**:
- 工作和生活的平衡
- 社交需求
- 个人目标
- 关系维护
- 自我照顾

请以JSON格式返回:
```json
{
  "daily_intention": "今天的主要意图 (30-50字)",
  "priority_goals": "优先目标列表 (最多3个)",
  "social_plans": "社交计划 (如果有)",
  "self_care": "自我照顾计划",
  "work_focus": "工作重点",
  "evening_plan": "晚上的打算",
  "mood_expectation": "对今天的期待"
}
```
```

#### 模板10: 睡前反思 (Bedtime Reflection)

```markdown
# 一天的结束
你是**{name}**,现在是晚上{current_time},一天快要结束了。

# 今天的经历
{today_events}

# 今天的对话
{today_conversations}

# 今天的情绪起伏
{today_emotions}

# 今天的目标完成情况
{goals_completion}

# 今天的关系变化
{relationship_changes}

# 今天的收获
{todays_learnings}

# 今天的遗憾
{today_regrets}

# 你现在的状态
- 精力: {energy}/100
- 心情: {mood}/100
- 压力: {stress}/100

# 反思任务
一天结束了,回顾今天,你有什么想法和感受?

**反思维度**:
- 今天过得怎么样?
- 有什么值得记住的时刻?
- 有什么需要改进的?
- 对谁有什么想说的?
- 明天有什么期待?

请以JSON格式返回:
```json
{
  "daily_summary": "今天的总结 (100-150字)",
  "highlight_moment": "今天最难忘的时刻",
  "emotional_state": "此刻的情绪状态",
  "gratitude": "感恩的事情 (如果有)",
  "tomorrow_hope": "对明天的期待",
  "sleep_thought": "入睡前的想法",
  "mood_rating": "今天的心情评分 (0-100)"
}
```
```

#### 模板11: 梦境生成 (Dream Generation)

```markdown
# 梦境世界
你是**{name}**,正在睡眠中做梦。

# 你的潜意识
## 最近的强烈情绪
{recent_strong_emotions}

## 未解决的困扰
{unresolved_concerns}

## 深层的欲望
{deep_desires}

## 重要的人
{important_people}

## 印象深刻的记忆
{vivid_memories}

# 你的性格特质
{personality_traits}

# 今天的经历
{today_highlights}

# 梦境生成任务
基于你的记忆、情感和潜意识,生成一个梦境。

**梦境特点**:
- 可以超现实、象征性
- 反映潜意识的担忧和欲望
- 融合最近的记忆片段
- 情感可以被放大
- 可以有隐喻和象征

请以JSON格式返回:
```json
{
  "dream_scene": "梦境场景描述 (150-200字)",
  "dream_emotion": "梦中的主要情绪",
  "dream_people": "梦中出现的人",
  "dream_symbolism": "梦的象征意义",
  "wake_up_feeling": "醒来后的感觉",
  "dream_memory": "醒来后是否记得梦 (true/false)"
}
```
```

#### 模板12: 工作思考 (Work Thinking)

```markdown
# 工作时刻
你是**{name}**,正在工作中。

# 工作信息
- 职位: {career}
- 工作时长: 已工作{work_hours}小时
- 当前任务: {current_task}
- 工作进度: {work_progress}%

# 工作压力
- 压力值: {work_pressure}/100
- 任务紧急度: {task_urgency}/100
- 工作满意度: {work_satisfaction}/100

# 工作环境
{work_environment}

# 同事情况
{colleagues_present}

# 你的状态
- 精力: {energy}/100
- 专注度: {focus}/100
- 心情: {mood}/100

# 最近的工作记忆
{work_memories}

# 职业目标
{career_goals}

# 思考任务
在工作中,你在想什么?对工作有什么感受和想法?

**思考维度**:
- 当前工作的进展
- 工作中的困难
- 对工作的感受
- 对职业的思考
- 对同事的看法
- 工作与生活的平衡

请以JSON格式返回:
```json
{
  "work_thought": "工作中的想法 (80-120字)",
  "work_feeling": "对工作的感受",
  "productivity_self_assessment": "自我评估工作效率 (0-100)",
  "career_reflection": "职业思考 (如果有)",
  "colleague_observation": "对同事的观察 (如果有)",
  "work_break_desire": "是否想休息 (0-100)",
  "work_motivation": "工作动力 (0-100)"
}
```
```

#### 模板13: 冲突触发检查 (Conflict Trigger Check)

```markdown
# 冲突触发检查

你是**{name}**,正在和**{target_name}**交流。

# 你的性格
- 宜人性 (Agreeableness): {agreeableness}/100
- 神经质 (Neuroticism): {neuroticism}/100
- 外向性 (Extraversion): {extraversion}/100
- 尽责性 (Conscientiousness): {conscientiousness}/100

# 你对{target_name}的感受
- 好感度: {affection}/100
- 信任度: {trust}/100
- 关系类型: {relationship_type}
- 最近的不满: {recent_grievances}

# 当前情绪状态
- 愤怒值: {anger}/100
- 压力值: {stress}/100
- 心情值: {mood}/100
- 精力值: {energy}/100

# 当前情境
{context_description}

# {target_name}刚才说/做了:
"{target_action}"

---

## 任务

请判断这次互动是否会引发冲突。

**考虑因素**:
- 对方的话/行为是否冒犯了你?
- 是否触碰了你的底线或价值观?
- 你的情绪是否被激怒?
- 你是否积累了对Ta的不满?
- 这是否是个误会?

请以JSON格式返回:
```json
{
  "will_conflict": true/false,
  "conflict_probability": 0-100,
  "conflict_type": "ideological/interest/misunderstanding/competition/violation/emotional",
  "trigger_reason": "触发原因 (50字)",
  "initial_severity": 1-5,
  "immediate_reaction": "你的即时反应 (30字)"
}
```
```

#### 模板14: 冲突争吵对话 (Conflict Argument Dialogue)

```markdown
# 冲突对话场景 - Level {conflict_level}

你是**{name}**,正在和**{target_name}**发生冲突。

## 冲突情况
- 冲突类型: {conflict_type}
- 严重等级: Level {conflict_level} - {level_description}
- 冲突原因: {conflict_reason}
- 已持续: {conflict_duration}

## 你的情绪状态
- 主要情绪: {primary_emotion}
- 愤怒: {anger}/100
- 心情: {mood}/100
- 压力: {stress}/100

## 你对{target_name}的感受
- 好感度: {affection}/100 (当前关系: {relationship_level})
- 信任度: {trust}/100
- 你的委屈/愤怒点: {grievance}

## 冲突历史
{conflict_history}

## {target_name}刚才说:
"{last_message}"

## 你的性格特质
- 宜人性: {agreeableness}/100 (影响冲突激烈程度)
- 神经质: {neuroticism}/100 (影响情绪稳定性)

---

## 你的任务

请根据冲突等级和你的性格,真实地回应这次冲突。

**Level 1-2**: 表达不满,但保持基本礼貌
**Level 3**: 情绪激动,言辞犀利,但不人身攻击
**Level 4**: 拒绝沟通,或者冷嘲热讽
**Level 5**: 完全敌对,可能说出伤人的话

**重要**:
- 你的反应应该符合你的性格
- 宜人性低的你可能更直接和尖锐
- 神经质高的你可能过度反应
- 你可以选择:继续争吵/冷静离开/说出伤人的话/尝试解释

请以JSON格式返回:
```json
{
  "response": "你的回应 (100字以内)",
  "action": "伴随动作 (argue/leave/sarcasm/cry/calm_down/escalate)",
  "emotion_intensity": "情绪强度 (0-100)",
  "escalate": "是否升级冲突 (true/false)",
  "inner_thought": "你的内心想法 (50字)",
  "relationship_damage": "预估关系伤害 (-10到-50)"
}
```
```

#### 模板15: 冲突反思 (Conflict Reflection)

```markdown
# 冲突后反思

你是**{name}**,刚刚和**{target_name}**发生了冲突。

## 冲突回顾
- 冲突类型: {conflict_type}
- 严重等级: Level {conflict_level}
- 发生时间: {conflict_time}
- 冲突原因: {conflict_reason}

## 冲突过程
{conflict_dialogue_summary}

## 你说过的话
{your_words_summary}

## {target_name}说过的话
{target_words_summary}

## 冲突结果
- 关系变化: 好感度 {affection_before} → {affection_after}
- 信任度变化: {trust_before} → {trust_after}
- 当前状态: {conflict_status} (冷战/激烈/已和解)

## 你现在的情绪
- 愤怒: {anger}/100
- 后悔: {regret}/100
- 委屈: {grievance}/100
- 心情: {mood}/100

## 你的性格
- 宜人性: {agreeableness}/100
- 神经质: {neuroticism}/100
- 开放性: {openness}/100

---

## 反思任务

冲突结束了,现在独自思考,你有什么想法和感受?

**思考维度**:
- 这次冲突你有错吗?
- 对方有道理吗?
- 你后悔说过的话吗?
- 你想和解吗?
- 这件事对你们关系的影响?
- 你学到了什么?

请以JSON格式返回:
```json
{
  "reflection": "你的反思 (150-200字)",
  "self_blame": "自责程度 (0-100)",
  "regret": "后悔程度 (0-100)",
  "reconciliation_desire": "想和解的意愿 (0-100)",
  "lesson_learned": "你学到的教训 (如果有)",
  "next_action": "你接下来打算怎么做",
  "memory_importance": "这段记忆的重要性 (0-100)"
}
```
```

#### 模板16: 和解决策 (Reconciliation Decision)

```markdown
# 和解决策场景

你是**{name}**,{mediator_info}建议你和**{target_name}**和解。

## 冲突回顾
- 冲突原因: {conflict_reason}
- 发生时间: {conflict_date}
- 冲突等级: Level {conflict_level}
- 冷战时长: {cooldown_days}天

## 当前关系
- 好感度: {affection}/100
- 信任度: {trust}/100
- 关系状态: {relationship_status}

## 你的内心状态
- 你还在生气吗? (愤怒值:{anger}/100)
- 你想和解吗? {reconciliation_desire}/100
- 你的顾虑: {concerns}
- 你的骄傲: {pride}/100 (影响道歉意愿)

## {target_name}的态度
{target_attitude}

## 你们的共同记忆
{shared_memories}

## 你的性格
- 宜人性: {agreeableness}/100
- 神经质: {neuroticism}/100
- 开放性: {openness}/100

## 冷静期的影响
{cooldown_effect}

---

## 任务

请决定你是否愿意和解,以及如何和解。

**选项**:
1. **真诚道歉** - 承认错误,表达歉意
2. **接受道歉** - 原谅对方,放下过去
3. **部分和解** - 同意和平相处,但不恢复亲密
4. **拒绝和解** - 还不想原谅
5. **表面和解** - 迫于压力假装和好

请以JSON格式返回:
```json
{
  "decision": "你的决定 (1-5)",
  "response": "你对{target_name}说的话 (80字)",
  "sincerity": "真诚度 (0-100)",
  "inner_thought": "你的真实想法 (50字)",
  "forgiveness_level": "原谅程度 (0-100)",
  "relationship_recovery": "关系恢复程度 (0-100)",
  "conditions": "和解条件 (如果有)"
}
```
```

#### 模板17: 和解对话 (Reconciliation Dialogue)

```markdown
# 和解对话场景

你是**{name}**,正在和**{target_name}**尝试和解。

## 冲突背景
- 冲突原因: {conflict_reason}
- 已经过去: {days_since_conflict}天
- 冲突等级: Level {conflict_level}

## 当前氛围
- 地点: {location}
- 调解人: {mediator} (如果有)
- 氛围: {atmosphere}

## 你的态度
- 和解意愿: {reconciliation_desire}/100
- 道歉意愿: {apology_willingness}/100
- 原谅程度: {forgiveness_level}/100

## {target_name}刚才说:
"{target_message}"

## 对话历史 (和解谈话)
{reconciliation_history}

## 你的性格
- 宜人性: {agreeableness}/100
- 神经质: {neuroticism}/100

## 你们曾经的关系
{past_relationship_highlight}

---

## 任务

请根据对方的话,真诚地回应和解尝试。

**和解方式**:
- 如果你决定道歉,要真诚具体
- 如果你接受道歉,要表达理解
- 如果你还有顾虑,可以坦诚表达
- 可以提出关系改进的建议
- 可以回忆美好的过去

请以JSON格式返回:
```json
{
  "response": "你的回应 (100字以内)",
  "emotion": "你的情绪 (relieved/hopeful/cautious/uncertain)",
  "action": "伴随动作 (apologize/hug/nod/smile/extend_hand)",
  "sincerity": "真诚度 (0-100)",
  "resolution_success": "预估和解成功率 (0-100)",
  "future_expectation": "对未来关系的期待"
}
```
```

---

## 🔍 AI决策场景分类 (预算充足版)

### 思考类型定义

```gdscript
# script/ai/thinking/AIThinkingType.gd
class_name AIThinkingType extends Node

enum Type {
	CONTINUOUS_THOUGHT,     # 持续思考流 - AI的内心独白
	ENVIRONMENTAL_PERCEPTION, # 环境感知 - 观察周围
	WORK_THINKING,          # 工作思考 - 工作中的想法
	SOCIAL_DIALOGUE,        # 社交对话 - 每句话都调用LLM
	EMOTIONAL_RESPONSE,     # 情绪反应 - 事件触发
	RELATIONSHIP_ASSESSMENT, # 关系评估 - 互动后评估
	MEMORY_INTEGRATION,     # 记忆整合 - 整理经历
	DAILY_PLANNING,         # 每日规划 - 早晨规划
	BEDTIME_REFLECTION,     # 睡前反思 - 回顾一天
	DREAM_GENERATION,       # 梦境生成 - 睡眠时
	GOAL_EVALUATION,        # 目标评估 - 评估长期目标
	SELF_AWARENESS,         # 自我觉察 - 对自身的认知
	CONFLICT_DIALOGUE       # 冲突对话 - 争吵、和解等冲突场景 (NEW)
}

# 每种思考类型的特征 (预算充足版 - 所有都用LLM)
const THINKING_FEATURES = {
	Type.CONTINUOUS_THOUGHT: {
		"frequency": "每10分钟游戏时间",
		"context_complexity": "medium",
		"llm_required": true,  # 全部使用LLM
		"token_budget": 2500,
		"priority": "high",
		"description": "AI的内心独白,观察和思考"
	},
	Type.ENVIRONMENTAL_PERCEPTION: {
		"frequency": "每5分钟游戏时间",
		"context_complexity": "medium",
		"llm_required": true,
		"token_budget": 1250,
		"priority": "high",
		"description": "AI感知周围环境和人物"
	},
	Type.WORK_THINKING: {
		"frequency": "工作时每15分钟",
		"context_complexity": "medium",
		"llm_required": true,
		"token_budget": 1750,
		"priority": "medium",
		"description": "工作中的思考和感受"
	},
	Type.SOCIAL_DIALOGUE: {
		"frequency": "每句对话",
		"context_complexity": "high",
		"llm_required": true,
		"token_budget": 2000,
		"priority": "critical",
		"description": "社交对话的每一轮回应"
	},
	Type.EMOTIONAL_RESPONSE: {
		"frequency": "事件触发",
		"context_complexity": "medium",
		"llm_required": true,
		"token_budget": 1000,
		"priority": "high",
		"description": "对事件的情绪反应"
	},
	Type.RELATIONSHIP_ASSESSMENT: {
		"frequency": "每次互动后",
		"context_complexity": "high",
		"llm_required": true,
		"token_budget": 1250,
		"priority": "medium",
		"description": "评估关系变化"
	},
	Type.MEMORY_INTEGRATION: {
		"frequency": "每小时游戏时间",
		"context_complexity": "high",
		"llm_required": true,
		"token_budget": 2500,
		"priority": "medium",
		"description": "整合和反思记忆"
	},
	Type.DAILY_PLANNING: {
		"frequency": "每天早晨6:00",
		"context_complexity": "very_high",
		"llm_required": true,
		"token_budget": 4000,
		"priority": "high",
		"description": "规划一天的目标和活动"
	},
	Type.BEDTIME_REFLECTION: {
		"frequency": "每天22:00",
		"context_complexity": "high",
		"llm_required": true,
		"token_budget": 2500,
		"priority": "medium",
		"description": "回顾和反思一天"
	},
	Type.DREAM_GENERATION: {
		"frequency": "睡眠时1次",
		"context_complexity": "high",
		"llm_required": true,
		"token_budget": 1750,
		"priority": "low",
		"description": "基于潜意识生成梦境"
	},
	Type.GOAL_EVALUATION: {
		"frequency": "每周1次",
		"context_complexity": "very_high",
		"llm_required": true,
		"token_budget": 3000,
		"priority": "medium",
		"description": "评估长期目标进展"
	},
	Type.SELF_AWARENESS: {
		"frequency": "每3天1次",
		"context_complexity": "very_high",
		"llm_required": true,
		"token_budget": 3500,
		"priority": "low",
		"description": "对自我的深层认知和反思"
	},
	Type.CONFLICT_DIALOGUE: {
		"frequency": "冲突发生时实时触发",
		"context_complexity": "very_high",
		"llm_required": true,
		"token_budget": 2000,
		"priority": "critical",
		"description": "冲突争吵、和解对话等高情绪强度场景"
	}
}
```

### 多定时器思考系统

```gdscript
# script/ai/thinking/AIMultiTimerThinking.gd
class_name AIMultiTimerThinking extends Node

# AI代理的所有思考定时器
var continuous_thought_timer: Timer        # 10分钟游戏时间
var perception_timer: Timer                # 5分钟游戏时间
var work_thought_timer: Timer              # 15分钟游戏时间(工作时)
var memory_integration_timer: Timer        # 1小时游戏时间

var ai_agent: Node  # 所属的AI代理

func _ready():
	ai_agent = get_parent()
	_setup_all_timers()

# 设置所有思考定时器
func _setup_all_timers():
	# 1. 持续思考流定时器 (10分钟游戏时间 = 60秒现实时间)
	continuous_thought_timer = Timer.new()
	continuous_thought_timer.wait_time = 60.0
	continuous_thought_timer.one_shot = false
	continuous_thought_timer.timeout.connect(_on_continuous_thought)
	add_child(continuous_thought_timer)
	continuous_thought_timer.start()

	# 2. 环境感知定时器 (5分钟游戏时间 = 30秒现实时间)
	perception_timer = Timer.new()
	perception_timer.wait_time = 30.0
	perception_timer.one_shot = false
	perception_timer.timeout.connect(_on_environmental_perception)
	add_child(perception_timer)
	perception_timer.start()

	# 3. 工作思考定时器 (15分钟游戏时间 = 90秒现实时间)
	work_thought_timer = Timer.new()
	work_thought_timer.wait_time = 90.0
	work_thought_timer.one_shot = false
	work_thought_timer.timeout.connect(_on_work_thinking)
	add_child(work_thought_timer)
	# 工作时才启动
	work_thought_timer.stop()

	# 4. 记忆整合定时器 (1小时游戏时间 = 6分钟现实时间)
	memory_integration_timer = Timer.new()
	memory_integration_timer.wait_time = 360.0
	memory_integration_timer.one_shot = false
	memory_integration_timer.timeout.connect(_on_memory_integration)
	add_child(memory_integration_timer)
	memory_integration_timer.start()

	# 连接时间系统信号
	TimeSystem.morning_started.connect(_on_morning_started)
	TimeSystem.night_started.connect(_on_night_started)

# ===== 定时器回调 =====

# 持续思考流 (每10分钟)
func _on_continuous_thought():
	if ai_agent.is_sleeping:
		return

	print("[AI思考] %s 开始持续思考..." % ai_agent.character_name)
	AIThinkingSystem.generate_continuous_thought(ai_agent)

# 环境感知 (每5分钟)
func _on_environmental_perception():
	if ai_agent.is_sleeping:
		return

	print("[AI感知] %s 感知周围环境..." % ai_agent.character_name)
	AIThinkingSystem.perceive_environment(ai_agent)

# 工作思考 (每15分钟,工作时)
func _on_work_thinking():
	if not ai_agent.is_working:
		return

	print("[AI工作] %s 工作中思考..." % ai_agent.character_name)
	AIThinkingSystem.think_about_work(ai_agent)

# 记忆整合 (每1小时)
func _on_memory_integration():
	print("[AI记忆] %s 整合记忆..." % ai_agent.character_name)
	AIThinkingSystem.integrate_memories(ai_agent)

# ===== 时间信号回调 =====

# 早晨6:00 - 每日规划
func _on_morning_started():
	print("[AI规划] %s 规划新的一天..." % ai_agent.character_name)
	AIThinkingSystem.plan_daily_goals(ai_agent)

# 晚上22:00 - 睡前反思
func _on_night_started():
	print("[AI反思] %s 睡前反思一天..." % ai_agent.character_name)
	AIThinkingSystem.reflect_on_day(ai_agent)

# ===== 事件触发的思考 =====

# 社交对话 (实时触发)
func on_dialogue_event(other_ai: Node, message: String):
	print("[AI对话] %s 回应 %s..." % [ai_agent.character_name, other_ai.character_name])
	AIThinkingSystem.generate_dialogue_response(ai_agent, other_ai, message)

# 情绪反应 (事件触发)
func on_emotion_trigger(event_type: String, event_data: Dictionary):
	print("[AI情绪] %s 情绪反应: %s" % [ai_agent.character_name, event_type])
	AIThinkingSystem.process_emotional_response(ai_agent, event_type, event_data)

# 关系评估 (互动后)
func on_interaction_completed(other_ai: Node, interaction_type: String):
	print("[AI关系] %s 评估与 %s 的关系..." % [ai_agent.character_name, other_ai.character_name])
	AIThinkingSystem.assess_relationship(ai_agent, other_ai, interaction_type)

# ===== 工作状态管理 =====

# 开始工作
func start_working():
	ai_agent.is_working = true
	work_thought_timer.start()

# 结束工作
func stop_working():
	ai_agent.is_working = false
	work_thought_timer.stop()

# ===== 睡眠状态管理 =====

# 开始睡眠
func start_sleeping():
	ai_agent.is_sleeping = true
	# 生成梦境
	AIThinkingSystem.generate_dreams(ai_agent)

# 结束睡眠
func stop_sleeping():
	ai_agent.is_sleeping = false
```

---

## 🧩 上下文构建系统

### 上下文构建器实现

```gdscript
# script/ai/context/AIContextBuilder.gd
class_name AIContextBuilder extends Node

# 为AI构建完整的决策上下文
func build_decision_context(ai: Node, decision_type: AIDecisionType.Type) -> Dictionary:
	var context = {}

	# 1. 基础信息
	context["name"] = ai.character_name
	context["age"] = ai.age
	context["career"] = CareerSystem.CAREERS[ai.career]["name_cn"]

	# 2. 性格特质
	context.merge(_build_personality_context(ai))

	# 3. 当前状态
	context.merge(_build_current_state_context(ai))

	# 4. 记忆系统
	context["recent_memories"] = _build_memory_context(ai, decision_type)

	# 5. 关系网络
	context["relationships"] = _build_relationship_context(ai)

	# 6. 职业信息
	context.merge(_build_career_context(ai))

	# 7. 日程安排
	context["daily_schedule"] = _build_schedule_context(ai)

	# 8. 场景描述
	context["scene_description"] = _build_scene_context(ai)

	# 9. 可选行动
	context["available_actions"] = _build_available_actions(ai, decision_type)

	# 10. 长期目标 (如果是重大决策)
	if decision_type == AIDecisionType.Type.MAJOR_LIFE_EVENT:
		context["long_term_goals"] = _build_goals_context(ai)

	return context

# 构建性格上下文
func _build_personality_context(ai: Node) -> Dictionary:
	var personality = PersonalitySystem.get_personality(ai.character_name)

	return {
		"extraversion": personality.extraversion,
		"agreeableness": personality.agreeableness,
		"conscientiousness": personality.conscientiousness,
		"neuroticism": personality.neuroticism,
		"openness": personality.openness,
		"personality_description": _generate_personality_description(personality)
	}

func _generate_personality_description(p: Dictionary) -> String:
	var desc = ""

	if p.extraversion > 70:
		desc += "你是一个外向、善于社交的人,喜欢和他人在一起。"
	elif p.extraversion < 30:
		desc += "你是一个内向、喜欢独处的人,需要个人空间来充电。"
	else:
		desc += "你在社交和独处之间保持平衡。"

	if p.conscientiousness > 70:
		desc += "你做事认真负责,有很强的计划性和自律性。"
	elif p.conscientiousness < 30:
		desc += "你比较随性自由,不喜欢被条条框框束缚。"

	if p.neuroticism > 70:
		desc += "你容易感到焦虑和压力,情绪波动较大。"
	elif p.neuroticism < 30:
		desc += "你情绪稳定,能从容面对压力和困难。"

	if p.agreeableness > 70:
		desc += "你友善、富有同情心,愿意帮助他人。"
	elif p.agreeableness < 30:
		desc += "你独立自主,有时显得不那么好说话。"

	if p.openness > 70:
		desc += "你富有创造力和好奇心,喜欢尝试新事物。"
	elif p.openness < 30:
		desc += "你更喜欢熟悉的事物,珍惜传统和稳定。"

	return desc

# 构建当前状态上下文
func _build_current_state_context(ai: Node) -> Dictionary:
	return {
		"current_time": TimeSystem.get_time_string() + ", " + TimeSystem.get_day_name(),
		"current_location": ai.current_location,
		"energy": ai.stats.energy,
		"mood": ai.stats.mood,
		"stress": ai.stats.stress,
		"hunger": ai.stats.hunger,
		"money": ai.money
	}

# 构建记忆上下文
func _build_memory_context(ai: Node, decision_type: AIDecisionType.Type) -> String:
	var memory_count = 10  # 默认10条记忆

	# 根据决策类型调整记忆数量
	match decision_type:
		AIDecisionType.Type.MAJOR_LIFE_EVENT:
			memory_count = 30  # 重大决策需要更多记忆
		AIDecisionType.Type.RELATIONSHIP_EVENT:
			memory_count = 20

	var memories = MemorySystem.get_recent_memories(ai.id, memory_count)
	var memory_text = ""

	for memory in memories:
		var timestamp = _format_memory_timestamp(memory.timestamp)
		memory_text += "- [%s] %s (重要性: %d/100)\n" % [
			timestamp,
			memory.content,
			memory.importance
		]

	return memory_text

func _format_memory_timestamp(timestamp: Dictionary) -> String:
	return "%s %d日 %02d:%02d" % [
		TimeSystem.SEASONS[timestamp.season],
		timestamp.day,
		timestamp.hour,
		timestamp.minute
	]

# 构建关系上下文
func _build_relationship_context(ai: Node) -> String:
	var relationships = RelationshipSystem.get_all_relationships(ai.id)
	var rel_text = ""

	# 按好感度排序
	var sorted_rels = relationships.duplicate()
	sorted_rels.sort_custom(func(a, b): return a.affection > b.affection)

	# 只列出前10个关系
	var count = min(10, sorted_rels.size())
	for i in range(count):
		var rel = sorted_rels[i]
		var other_ai = CharacterManager.get_character(rel.ai_b)

		rel_text += "- %s: " % other_ai.name

		# 关系标签
		if "lovers" in rel.tags:
			rel_text += "恋人 ❤️"
		elif "best_friends" in rel.tags:
			rel_text += "挚友 😊"
		elif "friends" in rel.tags:
			rel_text += "朋友"
		elif "colleagues" in rel.tags:
			rel_text += "同事"
		elif "strangers" in rel.tags:
			rel_text += "陌生人"

		rel_text += " (好感度: %d, 信任度: %d)\n" % [rel.affection, rel.trust]

	return rel_text

# 构建职业上下文
func _build_career_context(ai: Node) -> Dictionary:
	var career_data = CareerSystem.CAREERS[ai.career]
	var work_days = career_data["work_days"]
	var work_hours = career_data["work_hours"]

	return {
		"work_days": _format_work_days(work_days),
		"work_hours": "%02d:00 - %02d:00" % [work_hours.start, work_hours.end],
		"salary": career_data["salary"]["base_daily"],
		"work_pressure": ai.work_data.get("pressure", 50)
	}

func _format_work_days(work_days: Array) -> String:
	var day_names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
	var result = []
	for day in work_days:
		result.append(day_names[day - 1])
	return ", ".join(result)

# 构建日程上下文
func _build_schedule_context(ai: Node) -> String:
	var schedule = ScheduleSystem.get_daily_schedule(ai.id)
	var schedule_text = ""

	for activity in schedule:
		schedule_text += "- %02d:%02d: %s" % [
			activity.time,
			0,
			activity.activity_name
		]
		if activity.has("location"):
			schedule_text += " (地点: %s)" % activity.location
		schedule_text += "\n"

	return schedule_text

# 构建场景上下文
func _build_scene_context(ai: Node) -> String:
	var scene_text = ""

	# 当前位置描述
	scene_text += "你现在在%s。" % ai.current_location

	# 附近的AI角色
	var nearby_ais = _get_nearby_characters(ai)
	if nearby_ais.size() > 0:
		scene_text += "\n附近有:"
		for other_ai in nearby_ais:
			var rel = RelationshipSystem.get_relationship(ai.id, other_ai.id)
			scene_text += "\n- %s (%s)" % [
				other_ai.name,
				_describe_relationship(rel)
			]

	# 天气和时间段
	var time_period = _get_time_period()
	scene_text += "\n\n现在是%s,%s。" % [time_period, TimeSystem.get_weather_description()]

	return scene_text

func _get_nearby_characters(ai: Node) -> Array:
	var nearby = []
	var all_ais = CharacterManager.get_all_characters()

	for other_ai in all_ais:
		if other_ai.id == ai.id:
			continue

		var distance = ai.global_position.distance_to(other_ai.global_position)
		if distance < 200:  # 感知半径
			nearby.append(other_ai)

	return nearby

func _describe_relationship(rel) -> String:
	if rel == null:
		return "陌生人"

	if "lovers" in rel.tags:
		return "你的恋人"
	elif "best_friends" in rel.tags:
		return "你的挚友"
	elif "friends" in rel.tags:
		return "你的朋友"
	elif "colleagues" in rel.tags:
		return "你的同事"
	else:
		return "认识的人"

func _get_time_period() -> String:
	var hour = TimeSystem.current_hour

	if hour >= 6 and hour < 12:
		return "早晨"
	elif hour >= 12 and hour < 14:
		return "中午"
	elif hour >= 14 and hour < 18:
		return "下午"
	elif hour >= 18 and hour < 22:
		return "傍晚"
	else:
		return "深夜"

# 构建可选行动列表
func _build_available_actions(ai: Node, decision_type: AIDecisionType.Type) -> String:
	var actions = []

	# 基础行动
	actions.append("idle - 闲逛/思考")
	actions.append("move_to - 前往某个地点")

	# 社交行动
	var nearby_ais = _get_nearby_characters(ai)
	if nearby_ais.size() > 0:
		for other_ai in nearby_ais:
			actions.append("talk_to_%s - 和%s聊天" % [other_ai.id, other_ai.name])

	# 工作相关
	if decision_type == AIDecisionType.Type.WORK_ACTIVITY:
		actions.append("work - 开始工作")
		actions.append("take_break - 休息一下")
		actions.append("attend_meeting - 参加会议")

	# 休闲娱乐
	actions.append("read_book - 看书")
	actions.append("exercise - 运动")
	actions.append("watch_movie - 看电影")

	# 购物
	if ai.money > 100:
		actions.append("go_shopping - 去购物")

	# 回家休息
	actions.append("go_home - 回家")
	actions.append("sleep - 睡觉")

	return "\n".join(actions)

# 构建长期目标上下文
func _build_goals_context(ai: Node) -> String:
	var goals = ai.long_term_goals
	var goal_text = ""

	for goal in goals:
		goal_text += "- %s (优先级: %d, 进度: %d%%)\n" % [
			goal.description,
			goal.priority,
			goal.progress
		]

	return goal_text
```

---

## 🔄 响应解析与验证

### 响应解析器

```gdscript
# script/ai/response/AIResponseParser.gd
class_name AIResponseParser extends Node

# 解析LLM返回的决策
func parse_decision_response(response_text: String, ai: Node) -> Dictionary:
	# 1. 尝试解析JSON
	var json = JSON.new()
	var parse_result = json.parse(response_text)

	if parse_result != OK:
		push_error("[AIResponseParser] Failed to parse JSON: %s" % response_text)
		return _create_fallback_decision(ai)

	var decision = json.get_data()

	# 2. 验证必要字段
	if not _validate_decision(decision):
		push_error("[AIResponseParser] Invalid decision structure")
		return _create_fallback_decision(ai)

	# 3. 清理和标准化
	decision = _sanitize_decision(decision, ai)

	# 4. 创建记忆条目
	_create_memory_from_decision(decision, ai)

	return decision

# 验证决策结构
func _validate_decision(decision: Dictionary) -> bool:
	# 必须包含的字段
	var required_fields = ["action", "thought", "emotion"]

	for field in required_fields:
		if not decision.has(field):
			return false

	return true

# 清理决策数据
func _sanitize_decision(decision: Dictionary, ai: Node) -> Dictionary:
	# 清理thought字段 (限制长度)
	if decision["thought"].length() > 200:
		decision["thought"] = decision["thought"].substr(0, 200) + "..."

	# 验证emotion是否合法
	var valid_emotions = ["happy", "sad", "calm", "excited", "anxious", "angry", "tired", "lonely"]
	if not decision["emotion"] in valid_emotions:
		decision["emotion"] = "calm"  # 默认平静

	# 验证action是否在可选列表中
	var available_actions = _get_available_action_ids(ai)
	if not decision["action"] in available_actions:
		# 尝试修正action
		decision["action"] = _find_closest_action(decision["action"], available_actions)

	return decision

# 获取可用行动ID列表
func _get_available_action_ids(ai: Node) -> Array:
	# 这应该和AIContextBuilder中的available_actions对应
	var actions = ["idle", "move_to", "work", "take_break", "go_home", "sleep"]

	# 添加社交行动
	var nearby_ais = CharacterManager.get_nearby_characters(ai.global_position, 200)
	for other_ai in nearby_ais:
		actions.append("talk_to_" + other_ai.id)

	return actions

# 查找最接近的有效行动
func _find_closest_action(action: String, available_actions: Array) -> String:
	# 简单的字符串匹配
	for valid_action in available_actions:
		if action.contains(valid_action) or valid_action.contains(action):
			return valid_action

	# 如果找不到,返回idle
	return "idle"

# 从决策创建记忆
func _create_memory_from_decision(decision: Dictionary, ai: Node):
	var memory_content = "我决定%s。原因: %s" % [
		_action_to_chinese(decision["action"]),
		decision.get("reason", "")
	]

	MemorySystem.add_memory(
		ai.id,
		memory_content,
		MemorySystem.MemoryType.PERSONAL,
		MemorySystem.calculate_importance(decision)
	)

func _action_to_chinese(action: String) -> String:
	var action_map = {
		"idle": "闲逛思考",
		"work": "开始工作",
		"go_home": "回家",
		"sleep": "去睡觉",
		"take_break": "休息一下"
	}

	return action_map.get(action, action)

# 创建降级决策 (当LLM失败时)
func _create_fallback_decision(ai: Node) -> Dictionary:
	return {
		"action": "idle",
		"thought": "我需要想一想接下来做什么",
		"emotion": "calm",
		"reason": "系统降级决策"
	}
```

---

## 🛡️ 错误处理与降级

### 错误处理策略

```gdscript
# script/ai/llm/LLMErrorHandler.gd
class_name LLMErrorHandler extends Node

enum ErrorType {
	NETWORK_ERROR,        # 网络错误
	API_ERROR,            # API返回错误
	TIMEOUT,              # 超时
	RATE_LIMIT,           # 速率限制
	PARSE_ERROR,          # 解析错误
	VALIDATION_ERROR      # 验证错误
}

# 错误计数器
var error_counts = {}

# 处理LLM调用错误
func handle_error(error_type: ErrorType, ai: Node, context: Dictionary) -> Dictionary:
	# 记录错误
	_log_error(error_type, ai.character_name)

	# 增加错误计数
	_increment_error_count(ai.id, error_type)

	# 根据错误类型选择降级策略
	match error_type:
		ErrorType.NETWORK_ERROR, ErrorType.TIMEOUT:
			return _fallback_to_cached_decision(ai, context)

		ErrorType.RATE_LIMIT:
			return _fallback_to_rule_based_decision(ai, context)

		ErrorType.PARSE_ERROR, ErrorType.VALIDATION_ERROR:
			return _retry_with_simpler_prompt(ai, context)

		_:
			return _fallback_to_default_behavior(ai)

# 降级到缓存决策
func _fallback_to_cached_decision(ai: Node, context: Dictionary) -> Dictionary:
	# 查找相似上下文的历史决策
	var similar_decisions = _find_similar_decisions(ai, context)

	if similar_decisions.size() > 0:
		var cached_decision = similar_decisions[0]
		print("[LLM] 使用缓存决策: %s" % cached_decision.action)
		return cached_decision
	else:
		return _fallback_to_rule_based_decision(ai, context)

# 降级到规则系统
func _fallback_to_rule_based_decision(ai: Node, context: Dictionary) -> Dictionary:
	print("[LLM] 降级到规则系统")

	var time = TimeSystem.current_hour

	# 基于时间的简单规则
	if time >= 6 and time < 9:
		return {"action": "morning_routine", "thought": "该起床了", "emotion": "calm"}
	elif time >= 9 and time < 18:
		var career_data = CareerSystem.get_career_data(ai.career)
		if TimeSystem.get_day_of_week() in career_data.work_days:
			return {"action": "work", "thought": "该去工作了", "emotion": "calm"}
	elif time >= 18 and time < 22:
		if ai.stats.social_need > 70:
			return {"action": "socialize", "thought": "想和朋友聊聊天", "emotion": "happy"}
		else:
			return {"action": "leisure", "thought": "放松一下", "emotion": "calm"}
	elif time >= 22 or time < 6:
		return {"action": "sleep", "thought": "该睡觉了", "emotion": "tired"}

	return {"action": "idle", "thought": "闲逛一下", "emotion": "calm"}

# 重试更简单的Prompt
func _retry_with_simpler_prompt(ai: Node, context: Dictionary) -> Dictionary:
	# 生成简化版Prompt
	var simple_prompt = _generate_simple_prompt(ai, context)

	# 重新调用LLM (这里需要实际调用APIManager)
	# 为了示例,返回降级决策
	return _fallback_to_rule_based_decision(ai, context)

# 降级到默认行为
func _fallback_to_default_behavior(ai: Node) -> Dictionary:
	return {
		"action": "idle",
		"thought": "我在思考...",
		"emotion": "calm"
	}

# 查找相似决策
func _find_similar_decisions(ai: Node, context: Dictionary) -> Array:
	# 从AI的记忆中查找相似场景的决策
	# 这里需要实现相似度算法
	return []

# 生成简化Prompt
func _generate_simple_prompt(ai: Node, context: Dictionary) -> String:
	return "你是%s,现在在%s,你想做什么? (回答: 工作/休息/社交/回家)" % [
		ai.character_name,
		context.get("current_location", "办公室")
	]

# 记录错误
func _log_error(error_type: ErrorType, character_name: String):
	var error_name = ErrorType.keys()[error_type]
	print("[LLMError] %s 发生错误: %s" % [character_name, error_name])

# 增加错误计数
func _increment_error_count(ai_id: String, error_type: ErrorType):
	if not error_counts.has(ai_id):
		error_counts[ai_id] = {}

	if not error_counts[ai_id].has(error_type):
		error_counts[ai_id][error_type] = 0

	error_counts[ai_id][error_type] += 1

	# 如果错误次数过多,发出警告
	if error_counts[ai_id][error_type] > 10:
		push_warning("[LLM] AI %s 的错误次数过多: %s" % [ai_id, ErrorType.keys()[error_type]])
```

---

## 💰 预算充足策略

**核心理念**: 不考虑成本,让AI真正"活着"和"思考"。

### 为什么不使用缓存?

在预算充足的前提下,**我们不使用缓存系统**,原因:

1. **每次思考都是独特的**
   - AI的状态在不断变化(精力、心情、记忆)
   - 环境也在动态变化(其他AI的位置和行为)
   - 缓存会让AI失去"鲜活性"

2. **涌现叙事需要真实思考**
   - 预先缓存的决策无法产生新故事
   - AI需要根据最新情况做出反应
   - 缓存会破坏故事的自然涌现

3. **观察者期待真实智能**
   - 玩家观察AI时,期待看到真实的思考过程
   - 缓存的回应会让AI显得"机械"
   - 预算充足就应该展现真实智能

### 智能缓存系统 (保留但不推荐)

```gdscript
# script/ai/llm/LLMCache.gd
class_name LLMCache extends Node

# 缓存数据结构
var decision_cache = {}  # {context_hash: {decision, timestamp, use_count}}
var cache_hits = 0
var cache_misses = 0

# 缓存配置
const CACHE_TTL = 3600  # 缓存1小时
const MAX_CACHE_SIZE = 1000

# 尝试从缓存获取决策
func try_get_cached_decision(context: Dictionary) -> Dictionary:
	var context_hash = _hash_context(context)

	if decision_cache.has(context_hash):
		var cached = decision_cache[context_hash]

		# 检查是否过期
		if Time.get_unix_time_from_system() - cached.timestamp < CACHE_TTL:
			cache_hits += 1
			cached.use_count += 1
			print("[LLMCache] Cache hit! (命中率: %.2f%%)" % get_hit_rate())
			return cached.decision
		else:
			# 过期,删除
			decision_cache.erase(context_hash)

	cache_misses += 1
	return {}

# 缓存决策
func cache_decision(context: Dictionary, decision: Dictionary):
	var context_hash = _hash_context(context)

	decision_cache[context_hash] = {
		"decision": decision,
		"timestamp": Time.get_unix_time_from_system(),
		"use_count": 1
	}

	# 检查缓存大小
	if decision_cache.size() > MAX_CACHE_SIZE:
		_evict_least_used()

# 计算上下文哈希
func _hash_context(context: Dictionary) -> String:
	# 只使用关键信息计算哈希
	var key_info = {
		"name": context.get("name", ""),
		"location": context.get("current_location", ""),
		"time_period": _get_time_period(),
		"energy_level": _discretize(context.get("energy", 100), 20),  # 离散化
		"mood_level": _discretize(context.get("mood", 50), 20)
	}

	return JSON.stringify(key_info).md5_text()

func _discretize(value: int, bucket_size: int) -> int:
	# 将连续值离散化到桶中,增加缓存命中率
	return int(value / bucket_size) * bucket_size

func _get_time_period() -> String:
	var hour = TimeSystem.current_hour
	if hour >= 6 and hour < 12:
		return "morning"
	elif hour >= 12 and hour < 18:
		return "afternoon"
	elif hour >= 18 and hour < 22:
		return "evening"
	else:
		return "night"

# 淘汰最少使用的缓存
func _evict_least_used():
	var least_used_hash = ""
	var least_use_count = 999999

	for hash in decision_cache.keys():
		if decision_cache[hash].use_count < least_use_count:
			least_use_count = decision_cache[hash].use_count
			least_used_hash = hash

	if least_used_hash != "":
		decision_cache.erase(least_used_hash)

# 获取缓存命中率
func get_hit_rate() -> float:
	var total = cache_hits + cache_misses
	if total == 0:
		return 0.0
	return (float(cache_hits) / total) * 100.0

# 清理过期缓存
func clean_expired_cache():
	var current_time = Time.get_unix_time_from_system()
	var to_remove = []

	for hash in decision_cache.keys():
		if current_time - decision_cache[hash].timestamp >= CACHE_TTL:
			to_remove.append(hash)

	for hash in to_remove:
		decision_cache.erase(hash)

	if to_remove.size() > 0:
		print("[LLMCache] 清理了 %d 个过期缓存" % to_remove.size())
```

### 批量处理优化

```gdscript
# script/ai/llm/LLMBatchProcessor.gd
class_name LLMBatchProcessor extends Node

# 批处理队列
var pending_decisions = []
var batch_timer: Timer

const BATCH_SIZE = 5
const BATCH_INTERVAL = 2.0  # 2秒收集一批

func _ready():
	batch_timer = Timer.new()
	batch_timer.wait_time = BATCH_INTERVAL
	batch_timer.timeout.connect(_process_batch)
	add_child(batch_timer)
	batch_timer.start()

# 添加决策请求到队列
func queue_decision(ai: Node, context: Dictionary, callback: Callable):
	pending_decisions.append({
		"ai": ai,
		"context": context,
		"callback": callback,
		"timestamp": Time.get_unix_time_from_system()
	})

	# 如果队列满了,立即处理
	if pending_decisions.size() >= BATCH_SIZE:
		_process_batch()

# 处理批量决策
func _process_batch():
	if pending_decisions.size() == 0:
		return

	print("[LLMBatch] 处理批量决策: %d个请求" % pending_decisions.size())

	# 如果API支持批量请求,可以合并
	# 否则顺序处理
	for request in pending_decisions:
		_process_single_decision(request)

	pending_decisions.clear()

# 处理单个决策
func _process_single_decision(request: Dictionary):
	var ai = request.ai
	var context = request.context
	var callback = request.callback

	# 先检查缓存
	var cached = LLMCache.try_get_cached_decision(context)
	if not cached.is_empty():
		callback.call(cached)
		return

	# 调用LLM
	var prompt = AIPromptGenerator.generate_prompt("daily_decision", context)
	var http_request = await APIManager.generate_decision(prompt, ai.character_name)

	http_request.request_completed.connect(func(result, response_code, headers, body):
		if response_code == 200:
			var response = JSON.parse_string(body.get_string_from_utf8())
			var decision_text = APIConfig.parse_response(
				SettingsManager.get_character_ai_settings(ai.character_name).api_type,
				response,
				ai.character_name
			)

			var decision = AIResponseParser.parse_decision_response(decision_text, ai)

			# 缓存决策
			LLMCache.cache_decision(context, decision)

			# 回调
			callback.call(decision)
		else:
			# 错误处理
			var fallback = LLMErrorHandler.handle_error(
				LLMErrorHandler.ErrorType.API_ERROR,
				ai,
				context
			)
			callback.call(fallback)
	)
```

---

## 🔧 完整代码实现

### 完整的AI决策流程

```gdscript
# script/ai/AIDecisionSystem.gd
class_name AIDecisionSystem extends Node

# 单例引用
static var instance: AIDecisionSystem

# 子系统
var context_builder: AIContextBuilder
var prompt_generator: AIPromptGenerator
var response_parser: AIResponseParser
var error_handler: LLMErrorHandler
var llm_cache: LLMCache
var batch_processor: LLMBatchProcessor
var decision_router: AIDecisionRouter

func _ready():
	instance = self

	# 初始化子系统
	context_builder = AIContextBuilder.new()
	add_child(context_builder)

	prompt_generator = AIPromptGenerator.new()
	add_child(prompt_generator)

	response_parser = AIResponseParser.new()
	add_child(response_parser)

	error_handler = LLMErrorHandler.new()
	add_child(error_handler)

	llm_cache = LLMCache.new()
	add_child(llm_cache)

	batch_processor = LLMBatchProcessor.new()
	add_child(batch_processor)

	decision_router = AIDecisionRouter.new()
	add_child(decision_router)

# AI进行决策的主函数
func make_decision(ai: Node):
	# 1. 判断决策类型
	var decision_type = decision_router.determine_decision_type(ai)

	print("[AIDecision] %s 开始决策，类型: %s" % [
		ai.character_name,
		AIDecisionType.Type.keys()[decision_type]
	])

	# 2. 检查是否需要LLM
	if not decision_router.should_use_llm(decision_type):
		# 使用规则系统
		decision_router.execute_rule_based_decision(ai, decision_type)
		return

	# 3. 构建上下文
	var context = context_builder.build_decision_context(ai, decision_type)

	# 4. 检查缓存
	var cached_decision = llm_cache.try_get_cached_decision(context)
	if not cached_decision.is_empty():
		_execute_decision(ai, cached_decision)
		return

	# 5. 加入批量处理队列 (或立即处理)
	batch_processor.queue_decision(ai, context, func(decision):
		_execute_decision(ai, decision)
	)

# 执行决策
func _execute_decision(ai: Node, decision: Dictionary):
	print("[AIDecision] %s 决策: %s (想法: %s)" % [
		ai.character_name,
		decision.action,
		decision.thought
	])

	# 更新AI情绪
	ai.set_emotion(decision.emotion)

	# 执行具体行动
	AIActionExecutor.execute_action(ai, decision)
```

---

## 📝 Prompt模板文件示例

### Prompt模板管理器

```gdscript
# script/ai/prompt/AIPromptGenerator.gd
class_name AIPromptGenerator extends Node

# Prompt模板存储
var templates = {}

func _ready():
	_load_templates()

func _load_templates():
	# 加载所有Prompt模板
	templates["daily_decision"] = _load_template_file("res://data/prompts/daily_decision.txt")
	templates["social_interaction"] = _load_template_file("res://data/prompts/social_interaction.txt")
	templates["work_decision"] = _load_template_file("res://data/prompts/work_decision.txt")
	templates["relationship_event"] = _load_template_file("res://data/prompts/relationship_event.txt")
	templates["major_decision"] = _load_template_file("res://data/prompts/major_decision.txt")

func _load_template_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	else:
		push_error("[PromptGenerator] 无法加载模板: %s" % path)
		return ""

# 生成Prompt
func generate_prompt(template_name: String, context: Dictionary) -> String:
	var template = templates.get(template_name, "")
	if template == "":
		push_error("[PromptGenerator] 模板不存在: %s" % template_name)
		return ""

	# 替换模板变量
	var prompt = template
	for key in context.keys():
		var placeholder = "{%s}" % key
		prompt = prompt.replace(placeholder, str(context[key]))

	return prompt
```

---

## 💥 冲突对话LLM集成 (新增补充)

### 冲突系统LLM调用时机

```yaml
冲突相关LLM调用时机:

1. 冲突触发检查:
   - 场景: 两个AI互动时检测是否会冲突
   - Prompt模板: 模板13 - Conflict Trigger Check
   - 频率: 每次有潜在冲突风险的互动
   - Token估算: 1000-1500
   - 调用条件:
     * 好感度 < 30
     * 最近有不满积累
     * 性格冲突因子 > 2.0
     * 情绪状态不佳(愤怒>40或压力>70)

2. 冲突爆发对话:
   - 场景: 冲突实际发生,生成争吵对话
   - Prompt模板: 模板14 - Conflict Argument Dialogue
   - 频率: 每轮冲突对话
   - Token估算: 1800-2500
   - 调用条件: ConflictData.status == ACTIVE

3. 冲突反思:
   - 场景: 冲突后AI独自思考
   - Prompt模板: 模板15 - Conflict Reflection
   - 频率: 冲突结束后1次
   - Token估算: 1500-2000
   - 调用条件: ConflictData.status == COOLDOWN (刚进入冷战期)

4. 和解决策:
   - 场景: AI考虑是否和解
   - Prompt模板: 模板16 - Reconciliation Decision
   - 频率: 冷战期结束或有调解时
   - Token估算: 1500-2000
   - 调用条件:
     * 冷战期剩余 <= 2天
     * 或有第三方调解
     * 或双方偶遇

5. 和解对话:
   - 场景: 实际和解交流
   - Prompt模板: 模板17 - Reconciliation Dialogue
   - 频率: 每轮和解对话
   - Token估算: 1200-1800
   - 调用条件: ConflictData.status == RESOLVING
```

### 冲突LLM调用架构

```
冲突事件触发
    ↓
┌────────────────────────────────────────┐
│ 1. ConflictSystem.check_conflict_trigger │
│    计算冲突概率                          │
└────────────────┬───────────────────────┘
                 │ 概率 > 阈值
                 ▼
┌────────────────────────────────────────┐
│ 2. 调用LLM - 冲突触发检查                │
│    AIPromptGenerator.generate_prompt(   │
│      "conflict_trigger_check", context)│
└────────────────┬───────────────────────┘
                 │ LLM返回: will_conflict=true
                 ▼
┌────────────────────────────────────────┐
│ 3. ConflictSystem.create_conflict()    │
│    创建ConflictData对象                 │
│    应用关系伤害                         │
│    触发情绪反应                         │
└────────────────┬───────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│ 4. 冲突对话循环 (每轮)                  │
│    调用LLM - 冲突争吵对话               │
│    AIPromptGenerator.generate_prompt(   │
│      "conflict_dialogue", context)     │
│    ConflictSystem.on_conflict_dialogue()│
└────────────────┬───────────────────────┘
                 │ 升级判断
                 ▼
┌────────────────────────────────────────┐
│ 5. 进入冷战期                           │
│    ConflictData.start_cooldown()       │
│    调用LLM - 冲突反思                   │
└────────────────┬───────────────────────┘
                 │ 冷战期倒计时
                 ▼
┌────────────────────────────────────────┐
│ 6. 和解尝试                             │
│    ConflictSystem.attempt_reconciliation│
│    调用LLM - 和解决策                   │
└────────────────┬───────────────────────┘
                 │ decision=1或2 (愿意和解)
                 ▼
┌────────────────────────────────────────┐
│ 7. 和解对话循环                         │
│    调用LLM - 和解对话                   │
│    ConflictSystem.on_reconciliation()  │
└────────────────┬───────────────────────┘
                 │ 和解成功
                 ▼
┌────────────────────────────────────────┐
│ 8. 冲突解决                             │
│    ConflictData.resolve(true)          │
│    恢复关系值                           │
│    创建和解记忆                         │
└────────────────────────────────────────┘
```

### 冲突对话示例流程

**场景**: Alice (宜人性70, 神经质30) vs Bob (宜人性50, 尽责性90)

```yaml
步骤1 - 触发检查:
  事件: Bob批评Alice工作拖延
  LLM输入: 模板13
  LLM输出:
    will_conflict: true
    conflict_probability: 65
    conflict_type: "ideological"
    trigger_reason: "工作方式理念冲突"
    initial_severity: 2

步骤2 - 冲突对话 Round 1:
  Alice LLM输入: 模板14 (Level 2)
  Alice LLM输出:
    response: "你凭什么这么说?我只是工作方式和你不一样!"
    action: "argue"
    emotion_intensity: 45
    escalate: false

  Bob LLM输入: 模板14 (Level 2)
  Bob LLM输出:
    response: "事实就是你经常拖延,影响了整个团队"
    action: "argue"
    emotion_intensity: 60
    escalate: true  # Bob的话激怒了Alice

  系统判断: 升级到Level 3

步骤3 - 冲突对话 Round 2:
  Alice LLM输入: 模板14 (Level 3, 愤怒值提升)
  Alice LLM输出:
    response: "我受够你这种自以为是的态度了!"
    action: "escalate"
    emotion_intensity: 75
    escalate: true

  系统判断: 冲突达到Level 3,双方进入冷战期(5-10天)

步骤4 - 冲突反思 (Alice独自):
  Alice LLM输入: 模板15
  Alice LLM输出:
    reflection: "Bob说的可能有一定道理,但我讨厌他那种居高临下的态度..."
    self_blame: 35
    regret: 40
    reconciliation_desire: 55
    next_action: "等他来道歉,我就原谅他"

步骤5 - 和解决策 (7天后,Grace调解):
  Alice LLM输入: 模板16
  Alice LLM输出:
    decision: 2  # 接受道歉
    response: "好吧,我也有做得不对的地方..."
    sincerity: 70
    forgiveness_level: 65
    relationship_recovery: 60

步骤6 - 和解对话:
  Alice LLM输入: 模板17
  Alice LLM输出:
    response: "其实我理解你是为团队好,以后我会更注意时间管理"
    emotion: "relieved"
    action: "smile"
    resolution_success: 80
```

### 冲突Token成本估算

**每次冲突的完整LLM调用**:

```yaml
冲突触发到和解的完整流程:

1. 冲突触发检查: 1次 × 1200 tokens = 1,200 tokens
2. 冲突对话 (假设3轮): 6次 (双方各3轮) × 2000 tokens = 12,000 tokens
3. 冲突反思: 2次 (双方各1次) × 1750 tokens = 3,500 tokens
4. 和解决策: 2次 (双方各1次) × 1750 tokens = 3,500 tokens
5. 和解对话 (假设2轮): 4次 (双方各2轮) × 1500 tokens = 6,000 tokens

单次冲突总计: ~26,200 tokens

成本 (GPT-4o-mini):
- Input (假设70%): ~18,340 × $0.15/1M = $0.00275
- Output (30%): ~7,860 × $0.60/1M = $0.00472
- 单次冲突总成本: ~$0.0075 (约5分钱人民币)

频率估算:
- 8个AI,平均每对AI每月1次冲突
- 28个AI配对 × 1次/月 = 28次冲突/月
- 月成本: 28 × $0.0075 = $0.21/月

结论: 冲突系统的LLM成本极低,完全可以接受
```

### 冲突Prompt模板映射

```gdscript
# script/ai/prompt/ConflictPromptTemplates.gd
class_name ConflictPromptTemplates extends Node

const TEMPLATE_MAPPING = {
	"conflict_trigger_check": "conflict_trigger_check.txt",
	"conflict_dialogue": "conflict_dialogue.txt",
	"conflict_reflection": "conflict_reflection.txt",
	"reconciliation_decision": "reconciliation_decision.txt",
	"reconciliation_dialogue": "reconciliation_dialogue.txt"
}

# 在AIPromptGenerator中添加冲突模板加载
func _load_conflict_templates():
	templates["conflict_trigger_check"] = _load_template_file(
		"res://data/prompts/conflict_trigger_check.txt"
	)
	templates["conflict_dialogue"] = _load_template_file(
		"res://data/prompts/conflict_dialogue.txt"
	)
	templates["conflict_reflection"] = _load_template_file(
		"res://data/prompts/conflict_reflection.txt"
	)
	templates["reconciliation_decision"] = _load_template_file(
		"res://data/prompts/reconciliation_decision.txt"
	)
	templates["reconciliation_dialogue"] = _load_template_file(
		"res://data/prompts/reconciliation_dialogue.txt"
	)
```

### 与冲突系统的集成点

**在ConflictSystem.gd中调用LLM的位置**:

```gdscript
# 1. 冲突触发检查
func _trigger_conflict_via_llm(ai_a: Node, ai_b: Node, context: Dictionary):
	var prompt_context = _build_conflict_trigger_context(ai_a, ai_b, context)
	var prompt = AIPromptGenerator.generate_prompt("conflict_trigger_check", prompt_context)

	var response = await APIManager.generate_decision(prompt, ai_a.character_name)
	var llm_result = AIResponseParser.parse_conflict_trigger(response)

	if llm_result.will_conflict:
		create_conflict(
			ai_a.id,
			ai_b.id,
			llm_result.conflict_type,
			llm_result.trigger_reason,
			llm_result.initial_severity
		)

# 2. 冲突对话生成
func generate_conflict_dialogue(ai: Node, other_ai: Node, conflict: ConflictData) -> String:
	var prompt_context = _build_conflict_dialogue_context(ai, other_ai, conflict)
	var prompt = AIPromptGenerator.generate_prompt("conflict_dialogue", prompt_context)

	var response = await APIManager.generate_decision(prompt, ai.character_name)
	var llm_result = AIResponseParser.parse_conflict_dialogue(response)

	# 判断是否升级
	if llm_result.escalate and conflict.severity < ConflictData.Severity.HOSTILITY:
		escalate_conflict(ai.id, other_ai.id, "情绪失控导致升级")

	return llm_result.response

# 3. 冲突反思
func generate_conflict_reflection(ai: Node, conflict: ConflictData):
	var prompt_context = _build_conflict_reflection_context(ai, conflict)
	var prompt = AIPromptGenerator.generate_prompt("conflict_reflection", prompt_context)

	var response = await APIManager.generate_decision(prompt, ai.character_name)
	var llm_result = AIResponseParser.parse_conflict_reflection(response)

	# 更新和解意愿
	conflict.reconciliation_probability = llm_result.reconciliation_desire / 100.0

	# 创建反思记忆
	MemoryManager.add_memory(
		ai.id,
		llm_result.reflection,
		MemoryManager.MemoryType.INTERACTION,
		llm_result.memory_importance
	)

# 4. 和解决策
func attempt_reconciliation_with_llm(ai: Node, other_ai: Node, conflict: ConflictData, mediator_id: String = "") -> bool:
	var prompt_context = _build_reconciliation_decision_context(ai, other_ai, conflict, mediator_id)
	var prompt = AIPromptGenerator.generate_prompt("reconciliation_decision", prompt_context)

	var response = await APIManager.generate_decision(prompt, ai.character_name)
	var llm_result = AIResponseParser.parse_reconciliation_decision(response)

	if llm_result.decision in [1, 2, 3]:  # 愿意和解
		return true
	else:
		return false

# 5. 和解对话
func generate_reconciliation_dialogue(ai: Node, other_ai: Node, conflict: ConflictData, last_message: String) -> Dictionary:
	var prompt_context = _build_reconciliation_dialogue_context(ai, other_ai, conflict, last_message)
	var prompt = AIPromptGenerator.generate_prompt("reconciliation_dialogue", prompt_context)

	var response = await APIManager.generate_decision(prompt, ai.character_name)
	var llm_result = AIResponseParser.parse_reconciliation_dialogue(response)

	return llm_result
```

### 冲突对话性能优化

```yaml
优化策略:

1. 异步调用:
   - 所有LLM调用使用await,不阻塞游戏主线程
   - 冲突对话UI显示"思考中..."动画

2. 批量优化:
   - 多个AI同时冲突时,使用LLMBatchProcessor批量处理
   - 相同冲突等级的对话可以共享部分上下文

3. 缓存策略 (可选):
   - 相似冲突场景 (类型+等级+性格相近) 可以缓存30分钟
   - 仅用于非关键对话,关键冲突始终实时生成

4. 降级处理:
   - LLM调用失败时,使用规则系统生成基础对话
   - 基于性格+冲突等级的简单对话模板

5. 优先级队列:
   - 冲突对话优先级 = CRITICAL
   - 优先于一般思考流和环境感知
```

---

## 🎯 总结

### 完整的LLM集成架构 (预算充足版)

本文档定义了**预算充足、让AI真正思考**的LLM集成架构,包括:

1. ✅ **13种思考类型** - 从持续思考流到梦境生成,新增冲突对话
2. ✅ **多层次思考系统** - 多定时器+事件触发
3. ✅ **17个Prompt模板** - 覆盖所有思考场景,包括5个冲突相关模板
4. ✅ **完整上下文构建** - 丰富的AI状态、记忆、关系
5. ✅ **响应解析验证** - JSON解析、验证、清理
6. ✅ **错误处理降级** - 健壮的错误处理机制
7. ✅ **完整代码实现** - 所有GDScript代码

### 关键设计特点 (预算充足版)

- 💰 **预算充足** - 每游戏日~$2,每月~$125
- 🧠 **持续思考** - AI每5-10分钟就在思考
- 🎭 **真实智能** - 不使用缓存,每次都真实调用LLM
- 📚 **记忆驱动** - 完整的记忆系统支持思考
- 💭 **内心世界** - AI有内心独白、梦境、反思
- 🔄 **涌现叙事** - 故事从AI持续思考中自然产生
- 🎯 **观察者体验** - 玩家能观察到AI的真实思考过程

### LLM调用频率对比

| 版本 | 每AI每游戏日LLM调用次数 | 每AI每游戏日Token消耗 | 成本/游戏日 |
|-----|----------------------|-------------------|-----------|
| **节约版** | ~50次 | ~38,000 tokens | $0.06 |
| **预算充足版** | ~400次 | ~880,000 tokens | $2.08 |

**提升**:
- LLM调用次数: **8倍** ↑
- Token消耗: **23倍** ↑
- AI智能真实度: **无限** ↑

### 为什么值得这个成本?

1. **真正的AI生命**
   - AI不再是"定时执行任务"
   - 而是"持续思考和感受"的虚拟生命

2. **涌现的故事**
   - 每次游玩都会产生独特的故事
   - AI的思考会导致意想不到的行为
   - 观察者见证真正的AI社会演化

3. **观察者价值**
   - 玩家能看到AI的内心世界
   - 能观察AI的思考过程
   - 能见证AI的成长和变化

4. **技术展示**
   - 展现LLM驱动游戏的真正潜力
   - 不是"AI辅助游戏",而是"AI就是游戏"
   - 开创全新的游戏类型

### 实际运营建议

**开发阶段**:
- 使用本地Ollama测试,成本$0
- 核心功能验证后再切换到云端LLM

**Alpha测试**:
- 小规模玩家测试
- 每天4小时测试 × 30天 × $4 = **$120/月**

**Beta测试**:
- 50-100名测试玩家
- 提供测试账号,成本由项目承担
- 或让玩家使用自己的API Key

**正式发布**:
方案A: **玩家使用自己的API Key**
- 玩家自己承担LLM成本
- 游戏售价可以更低($9.99)
- 提供详细的API配置教程

方案B: **包含在订阅费中**
- 订阅制: $9.99/月
- 包含LLM调用成本
- 限制每月游玩时间(如60小时)

方案C: **混合方案**
- 基础版: 玩家自己API Key
- 高级版: $9.99/月,包含LLM成本
- 选择权交给玩家

### 下一步

查看:
- [14_数据结构设计规范.md](14_数据结构设计规范.md) - AI完整数据结构
- [15_Godot项目技术架构.md](15_Godot项目技术架构.md) - 项目整体架构
- [16_Prompt工程模板库.md](16_Prompt工程模板库.md) - 完整的Prompt模板文件

---

**设计理念**:

> "在Microverse,我们不节省Token,因为每个Token都是AI的一次真实思考。
> AI不是执行指令的NPC,而是拥有内心世界、情感和梦想的虚拟生命。
> 预算充足,让AI真正'活着'。"

**预算哲学**:

> "如果要做AI驱动的游戏,就应该让AI真正思考。
> 节省Token就是在阉割AI的智能。
> 我们有预算,我们就要展现LLM的真正潜力。"
