# AI角色管理完整指南

本文档详细介绍如何在苏格拉底终端中管理AI角色。

---

## 📋 快速参考

### 查看类命令
```bash
/agents list              # 列出所有角色
/agents info 苏格拉底     # 查看角色详细信息
/providers                # 查看支持的AI厂商
```

### 创建与删除
```bash
/agents add 哲学家 OpenAI gpt-4o        # 添加新角色
/agents remove 哲学家                    # 删除角色
/agents rename 哲学家 柏拉图             # 重命名角色
```

### 配置角色
```bash
/agents key 苏格拉底 sk-your-key        # 设置API密钥
/agents model 苏格拉底 OpenAI gpt-4o    # 更改模型
/agents color 苏格拉底 #4A90E2          # 设置显示颜色
/agents prompt 苏格拉底 你是哲学家...   # 修改系统提示词
```

### 状态控制
```bash
/agents enable 苏格拉底     # 启用角色(参与讨论)
/agents disable 苏格拉底    # 禁用角色(不参与)
/agents moderator 苏格拉底  # 设为主持人(只能有1个)
```

---

## 🎯 常见使用场景

### 场景1: 首次设置 - 快速启用预设角色

系统预设了8个角色,但默认都是禁用状态(因为没有API Key)。

**步骤**:

1. **查看预设角色**:
```bash
/agents list
```
输出:
```
[System] 当前代理:
- 苏格拉底 [OpenAI/gpt-4o-mini] 禁用 (主持) (未设置APIKey)
- 批判者 [Claude/claude-3-5-sonnet-20241022] 禁用 (未设置APIKey)
- 综合者 [OpenAI/gpt-4o-mini] 禁用 (未设置APIKey)
...
```

2. **设置API Key** (推荐环境变量):
```bash
/agents key 苏格拉底 ${ENV:OPENAI_API_KEY}
/agents key 批判者 ${ENV:ANTHROPIC_API_KEY}
/agents key 实践者 ${ENV:DEEPSEEK_API_KEY}
```

3. **验证启用状态**:
```bash
/agents list
```
现在应该看到:
```
- 苏格拉底 [OpenAI/gpt-4o-mini] 启用 (主持)
- 批判者 [Claude/claude-3-5-sonnet-20241022] 启用
- 实践者 [DeepSeek/deepseek-chat] 启用
```

4. **开始讨论**:
```
什么是递归?
```

---

### 场景2: 创建自定义角色

假设您想创建一个"代码审查专家"角色。

**步骤**:

1. **查看支持的AI厂商**:
```bash
/providers
```
输出:
```
支持的AI厂商:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• OpenAI (OpenAI)
  模型: gpt-4o-mini, gpt-4o, gpt-3.5-turbo
• Claude (Claude (Anthropic))
  模型: claude-3-5-sonnet-20241022, claude-3-opus-20240229...
• DeepSeek (DeepSeek)
  模型: deepseek-chat
...
```

2. **创建角色**:
```bash
/agents add 代码审查专家 DeepSeek deepseek-chat
```

3. **设置API Key**:
```bash
/agents key 代码审查专家 ${ENV:DEEPSEEK_API_KEY}
```

4. **设置颜色** (便于区分):
```bash
/agents color 代码审查专家 #FF6B6B
```

5. **定义人格** (这是最重要的!):
```bash
/agents prompt 代码审查专家 你是严格的代码审查专家。擅长发现安全漏洞、性能问题、代码异味。每次审查必须指出至少3个问题,并给出修改建议和最佳实践。语气直接,不留情面,因为代码质量关乎生死。
```

6. **查看配置是否正确**:
```bash
/agents info 代码审查专家
```
输出:
```
代理详情:代码审查专家
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
API类型: DeepSeek
模型: deepseek-chat
状态: 启用
主持人: 否
颜色: #FF6B6B
API Key: 已设置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
系统提示词:
你是严格的代码审查专家。擅长发现安全漏洞、性能问题、代码异味...
```

7. **开始使用**:
```
请审查这段Python代码: def login(username, password): return db.query("SELECT * FROM users WHERE name='%s' AND pass='%s'" % (username, password))
```

---

### 场景3: 临时禁用某些角色

讨论技术问题时,不需要"类比大师",只需要理论和实践派。

```bash
# 禁用不需要的角色
/agents disable 类比大师
/agents disable 魔鬼代言人
/agents disable 学术派

# 确认
/agents list

# 开始讨论
什么是时间复杂度?
```

讨论结束后,重新启用:
```bash
/agents enable 类比大师
/agents enable 魔鬼代言人
/agents enable 学术派
```

---

### 场景4: 更换模型以节省成本

OpenAI的 `gpt-4o` 很贵,可以换成 `gpt-4o-mini`:

```bash
# 查看当前配置
/agents info 苏格拉底

# 更换为更便宜的模型
/agents model 苏格拉底 OpenAI gpt-4o-mini

# 确认
/agents info 苏格拉底
```

或者全部换成免费的本地模型(需要安装Ollama):

```bash
# 安装Ollama并拉取模型
# ollama pull qwen2.5:7b

# 更换模型
/agents model 苏格拉底 Ollama qwen2.5:7b
/agents model 批判者 Ollama qwen2.5:7b
/agents model 理论家 Ollama qwen2.5:7b

# Ollama不需要API Key,会自动连接localhost:11434
```

---

### 场景5: 修改角色人格

假设您觉得"批判者"太刻薄,想让他更友好:

```bash
# 查看当前提示词
/agents info 批判者

# 修改为更温和的版本
/agents prompt 批判者 你是建设性批评专家。专门挑战论点、找漏洞,但你的批评是为了帮助完善理解,语气友好温和,像老师指导学生一样。
```

---

### 场景6: 删除不需要的角色

如果您添加了太多角色,想清理:

```bash
# 查看所有角色
/agents list

# 删除不需要的
/agents remove 哲学家
/agents remove 数学家

# 确认
/agents list
```

**注意**: 预设的8个角色删除后,可以通过删除 `user://agents.json` 文件并重启项目来恢复。

---

### 场景7: 专题讨论配置

**技术讨论配置** (只启用3个角色):
```bash
/agents disable 苏格拉底
/agents disable 综合者
/agents disable 类比大师
/agents disable 魔鬼代言人
/agents disable 学术派

# 只保留:
# - 理论家 (深入原理)
# - 实践者 (工程实现)
# - 批判者 (权衡利弊)
```

**哲学讨论配置**:
```bash
/agents disable 实践者
/agents disable 理论家

# 只保留:
# - 苏格拉底 (提问引导)
# - 批判者 (逻辑检验)
# - 综合者 (观点整合)
# - 魔鬼代言人 (另类视角)
```

**快速学习配置** (适合新手):
```bash
# 只保留3个最易懂的角色
/agents disable 理论家
/agents disable 魔鬼代言人
/agents disable 学术派
/agents disable 综合者
/agents disable 批判者

# 只保留:
# - 苏格拉底 (引导)
# - 类比大师 (形象化)
# - 实践者 (实际应用)
```

---

## 🔧 高级技巧

### 1. 批量配置脚本

创建一个批处理文件 `setup_agents.txt`,包含常用配置:

```bash
/agents key 苏格拉底 ${ENV:OPENAI_API_KEY}
/agents key 批判者 ${ENV:ANTHROPIC_API_KEY}
/agents key 理论家 ${ENV:OPENAI_API_KEY}
/agents key 实践者 ${ENV:DEEPSEEK_API_KEY}
/agents key 类比大师 ${ENV:OPENAI_API_KEY}
```

然后逐行复制粘贴到终端。

---

### 2. 环境变量最佳实践

**Windows** (PowerShell):
```powershell
# 设置环境变量
$env:OPENAI_API_KEY = "sk-your-key"
$env:ANTHROPIC_API_KEY = "sk-ant-your-key"
$env:DEEPSEEK_API_KEY = "sk-your-key"

# 永久设置
[System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-your-key", "User")
```

**Linux/Mac**:
```bash
# 临时设置
export OPENAI_API_KEY="sk-your-key"
export ANTHROPIC_API_KEY="sk-ant-your-key"

# 永久设置(添加到 ~/.bashrc 或 ~/.zshrc)
echo 'export OPENAI_API_KEY="sk-your-key"' >> ~/.bashrc
source ~/.bashrc
```

然后在终端中使用:
```bash
/agents key 苏格拉底 ${ENV:OPENAI_API_KEY}
```

---

### 3. 角色组合推荐

**学术研究组合** (4个):
- 学术派 (文献综述)
- 理论家 (严格定义)
- 批判者 (逻辑检验)
- 苏格拉底 (概念澄清)

**产品设计组合** (5个):
- 实践者 (技术可行性)
- 魔鬼代言人 (风险评估)
- 综合者 (方案对比)
- 批判者 (细节检查)
- 类比大师 (用户体验)

**快速答疑组合** (2-3个):
- 苏格拉底 + 类比大师
- 或: 理论家 + 实践者

---

### 4. 调试技巧

**查看角色是否正确配置**:
```bash
/agents info 角色名
```

**测试单个角色**:
```bash
# 禁用其他所有角色,只启用一个
/agents disable 批判者
/agents disable 理论家
# ...
/agents enable 苏格拉底

# 开始讨论
什么是递归?
```

---

## ⚠️ 常见问题

### Q1: 为什么角色不参与讨论?

检查清单:
1. ✅ 是否启用? `/agents list` 查看状态
2. ✅ 是否设置API Key? 查看"未设置APIKey"标记
3. ✅ API Key是否正确? 尝试重新设置
4. ✅ 环境变量是否生效? 直接粘贴API Key测试

### Q2: 如何恢复预设角色?

删除配置文件:
- Windows: `C:\Users\你的用户名\AppData\Roaming\Godot\app_userdata\SocraticTerminal\agents.json`
- Linux: `~/.local/share/godot/app_userdata/SocraticTerminal/agents.json`

重启项目,会自动生成8个预设角色。

### Q3: 最多可以有几个角色?

最多10个。超过限制时,新增会失败。可以先删除旧角色再添加新的。

### Q4: 修改提示词后需要重启吗?

不需要。修改立即生效,下一轮对话就会使用新的提示词。

### Q5: 如何备份角色配置?

复制 `user://agents.json` 文件:
- Windows: `%APPDATA%\Godot\app_userdata\SocraticTerminal\agents.json`
- Linux: `~/.local/share/godot/app_userdata/SocraticTerminal/agents.json`

恢复时,替换该文件即可。

---

## 📚 参考

- [用户手册](USER_GUIDE.md) - 完整使用指南
- [架构文档](ARCHITECTURE.md) - 技术实现细节
- [README](../README.md) - 项目概述

---

**祝您配置愉快!** 🎓
