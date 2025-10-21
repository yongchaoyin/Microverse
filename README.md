# 苏格拉底终端 Socratic Terminal

> 与8位AI思想家进行深度对话的终端应用
> **Deep AI Discussion · 让每个话题都讲透彻**

![Godot 4.4+](https://img.shields.io/badge/Godot-4.4+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 📖 项目简介

**苏格拉底终端**是一个基于Godot引擎的AI深度讨论工具。它汇集了8位不同人格的AI"思想家",通过苏格拉底式对话方法,帮助您深入理解任何复杂话题。

### 核心特性

- 🧠 **8种AI角色预设**: 苏格拉底、批判者、理论家、实践者、类比大师等,从多角度剖析问题
- 🎯 **深度检测系统**: 自动评估讨论深度,引导AI从表象深入本质
- 💬 **智能对话编排**: AI们会互相批评、纠正、补充,直到您说"懂了"
- 🎨 **终端风格界面**: Linux终端风格,支持自定义颜色、字体大小
- 📝 **Markdown支持**: 代码块、粗体、引用等格式自动渲染
- 🔌 **多AI厂商支持**: OpenAI、Claude、DeepSeek、Gemini、Ollama等
- 💾 **对话导出**: 自动保存讨论记录到本地文件

---

## 🚀 快速开始

### 环境要求

- [Godot 4.4+](https://godotengine.org/download) (推荐最新稳定版)
- 至少一个AI服务的API Key (OpenAI/Claude/DeepSeek/Gemini等)

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/yourusername/Socratic-Terminal.git
cd Socratic-Terminal
```

2. **在Godot中打开**
   - 启动Godot编辑器
   - 点击"导入" → 选择项目目录下的`project.godot`

3. **运行项目**
   - 按`F5`或点击编辑器右上角的"运行"按钮
   - 终端界面将启动

### 首次配置

启动后,您将看到欢迎界面。按以下步骤配置AI角色:

```bash
# 1. 查看预设的8个AI角色
/agents list

# 2. 为角色设置API Key
/agents key 苏格拉底 sk-your-openai-api-key
/agents key 批判者 sk-ant-your-claude-api-key

# 3. (可选)设置主持人角色
/agents moderator 苏格拉底

# 4. 开始讨论!
什么是量子纠缠?
```

**提示**: API Key支持环境变量,如 `/agents key 苏格拉底 ${ENV:OPENAI_API_KEY}`

---

## 🎮 使用指南

### 基本对话流程

1. **输入话题** → 直接输入任何您想深入了解的话题
2. **AI们开始讨论** → 8位AI轮流发言,从不同角度解释
3. **随时插话** → 输入您的疑问或观点,AI会立即回应
4. **深度检测** → 系统每5轮评估深度,不足时会引导AI深入
5. **说"懂了"结束** → 输入"懂了"或`/stop`结束讨论

### 常用命令

| 命令 | 说明 |
|------|------|
| `直接输入话题` | 开始新讨论 |
| `/topic 主题` | 明确开始新话题 |
| `/say 文本` | 在讨论中插话 |
| `/stop` 或 `懂了` | 停止讨论 |
| `/agents list` | 查看所有AI角色 |
| `/agents key 名称 APIKEY` | 设置API密钥 |
| `/export 文件名` | 导出对话记录 |
| `/help` | 显示完整帮助 |

### AI角色说明

| 角色 | 特点 | 适合话题 |
|------|------|----------|
| **苏格拉底** | 通过提问引导思考,揭示假设 | 概念定义、价值观讨论 |
| **批判者** | 挑战论点,找漏洞和反例 | 论证检验、逻辑分析 |
| **理论家** | 深入原理、数学推导 | 科学原理、技术细节 |
| **实践者** | 关注实际应用和工程实现 | 技术选型、方案设计 |
| **类比大师** | 用生动比喻解释复杂概念 | 抽象概念的理解 |
| **综合者** | 整合多方观点,构建框架 | 系统性理解 |
| **魔鬼代言人** | 故意唱反调,避免思维盲区 | 风险评估、完整性检查 |
| **学术派** | 引经据典,提供权威来源 | 学术研究、历史追溯 |

---

## 🛠️ 高级配置

### 自定义AI角色

您可以添加自己的AI角色:

```bash
/agents add 哲学家 OpenAI gpt-4o
/agents key 哲学家 sk-your-key
/agents color 哲学家 #FF5733
```

然后编辑`user://agents.json`文件,修改`system_prompt`字段自定义人格。

### 环境变量配置

推荐在系统环境变量中设置API Key,避免明文存储:

**Windows**:
```powershell
setx OPENAI_API_KEY "sk-your-key"
setx ANTHROPIC_API_KEY "sk-ant-your-key"
```

**Linux/Mac**:
```bash
export OPENAI_API_KEY="sk-your-key"
export ANTHROPIC_API_KEY="sk-ant-your-key"
```

然后在终端中使用:
```bash
/agents key 苏格拉底 ${ENV:OPENAI_API_KEY}
```

### 深度检测参数调整

编辑 [script/ai/terminal/DepthAnalyzer.gd](script/ai/terminal/DepthAnalyzer.gd):

```gdscript
const MIN_DEPTH_SCORE := 0.6  # 最低深度分数(0-1)
const MIN_CONCEPT_LAYERS := 2  # 最少概念层次
const MIN_INTERACTIONS := 3    # 最少批判性互动次数
```

---

## 📁 项目结构

```
Socratic-Terminal/
├── project.godot          # Godot项目配置
├── scene/
│   └── ui/
│       └── TerminalChat.tscn  # 终端界面场景
├── script/
│   ├── ai/
│   │   ├── APIConfig.gd       # AI厂商配置
│   │   ├── APIManager.gd      # API调用管理
│   │   └── terminal/
│   │       ├── AgentManager.gd          # AI角色管理
│   │       ├── MultiAgentOrchestrator.gd  # 对话编排
│   │       ├── DepthAnalyzer.gd         # 深度分析
│   │       └── TerminalChat.gd          # 终端UI控制
│   └── ui/
│       └── SettingsManager.gd  # 设置管理
└── docs/
    ├── runing/            # 对话记录导出目录
    ├── USER_GUIDE.md      # 详细用户手册
    └── ARCHITECTURE.md    # 架构文档
```

---

## 🎯 使用场景

### 学习场景

- 🎓 **学生**: 理解复杂概念(量子力学、相对论、算法原理等)
- 📚 **研究人员**: 多角度分析问题,发现研究盲点
- 💼 **技术选型**: 评估不同方案的优劣

### 对话示例

**话题**: "什么是递归?"

```
[苏格拉底] 在回答之前,我想先问:你认为"自己调用自己"就是递归的全部吗?

[理论家] 递归的数学定义是函数f(n)在定义中包含f(n-1),需要基础情况防止无限循环...

[类比大师] 就像俄罗斯套娃,每个娃娃里还有更小的娃娃,直到最小的实心娃娃(基础情况)...

[批判者] 等等,类比不够准确。套娃是空间嵌套,递归是时间展开。更像照镜子时镜中镜...

[实践者] 实际编程中,递归的问题是栈溢出。尾递归优化能解决,但不是所有语言都支持...

[深度分析]
深度分数: 72% (>60%为合格)
概念层次: 3层 (需≥2层)
批判互动: 4次 (需≥3次)
✓ 讨论深度充分
```

---

## 🤝 贡献指南

欢迎贡献!您可以:

1. 🐛 报告Bug或提出功能建议 → Issues
2. 🔧 提交代码改进 → Pull Requests
3. 📝 完善文档或翻译
4. 🎨 设计新的AI角色模板

提交PR前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

---

## 🙏 致谢

- [Godot Engine](https://godotengine.org/) - 优秀的开源游戏引擎
- 所有AI服务提供商 (OpenAI、Anthropic、DeepSeek等)
- 苏格拉底 - 启发式对话方法的鼻祖

---

**让每个话题都讲透彻 - Socratic Terminal**
