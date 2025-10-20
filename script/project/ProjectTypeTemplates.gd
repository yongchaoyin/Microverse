# script/project/ProjectTypeTemplates.gd
class_name ProjectTypeTemplates
extends Node

# Autoload单例: ProjectTypeTemplates

# ========================================
# 项目类型模板数据
# ========================================

const TEMPLATES = {
	"software_development": {
		"name": "软件开发项目",
		"name_en": "Software Development",
		"description": "开发一个软件产品(网站、App、游戏等)",
		"icon": "res://assets/icons/project_software.png",

		# 角色映射规则
		"role_mapping": {
			"project_lead": ["Stephen"],      # 项目经理
			"frontend_dev": ["Alice"],        # 前端开发
			"backend_dev": ["Tom"],           # 后端开发
			"ui_designer": ["Lea"],           # UI设计师
			"qa_tester": ["Joe"],             # 测试员
			"operations": ["Grace"],          # 运营
			"support": ["Jack", "Monica"]     # 支援
		},

		# 角色职责定义
		"role_definitions": {
			"project_lead": {
				"title": "项目经理",
				"title_en": "Project Manager",
				"responsibilities": [
					"需求分析与规划",
					"项目进度管理",
					"团队协调",
					"风险控制"
				],
				"skill_requirements": ["管理能力", "沟通能力", "技术理解"]
			},
			"frontend_dev": {
				"title": "前端工程师",
				"title_en": "Frontend Developer",
				"responsibilities": [
					"前端界面开发",
					"用户交互实现",
					"前端性能优化",
					"与后端API对接"
				],
				"skill_requirements": ["编程能力", "UI实现", "逻辑思维"]
			},
			"backend_dev": {
				"title": "后端工程师",
				"title_en": "Backend Developer",
				"responsibilities": [
					"后端架构设计",
					"API开发",
					"数据库设计",
					"性能优化"
				],
				"skill_requirements": ["编程能力", "架构设计", "数据库"]
			},
			"ui_designer": {
				"title": "UI设计师",
				"title_en": "UI Designer",
				"responsibilities": [
					"界面设计",
					"视觉规范制定",
					"交互设计",
					"设计资产输出"
				],
				"skill_requirements": ["审美能力", "设计工具", "用户体验"]
			},
			"qa_tester": {
				"title": "测试工程师",
				"title_en": "QA Tester",
				"responsibilities": [
					"功能测试",
					"Bug发现与报告",
					"回归测试",
					"质量把控"
				],
				"skill_requirements": ["细心", "逻辑思维", "沟通能力"]
			},
			"operations": {
				"title": "运营专员",
				"title_en": "Operations Specialist",
				"responsibilities": [
					"用户运营",
					"数据分析",
					"活动策划",
					"内容运营"
				],
				"skill_requirements": ["运营能力", "数据分析", "创意思维"]
			}
		},

		# Epic模板 (LLM会参考这些模板生成具体Epic)
		"epic_templates": [
			{
				"title": "需求分析与项目规划",
				"description": "明确项目需求,制定详细开发计划,确定技术方案",
				"typical_duration": 2,
				"typical_roles": ["project_lead", "frontend_dev", "backend_dev"]
			},
			{
				"title": "技术架构设计",
				"description": "设计系统架构,确定技术栈,制定开发规范",
				"typical_duration": 3,
				"typical_roles": ["backend_dev", "frontend_dev"]
			},
			{
				"title": "UI设计与原型",
				"description": "设计界面原型,制定视觉规范,输出设计稿",
				"typical_duration": 3,
				"typical_roles": ["ui_designer", "project_lead"]
			},
			{
				"title": "核心功能开发",
				"description": "开发系统核心功能模块",
				"typical_duration": 10,
				"typical_roles": ["frontend_dev", "backend_dev"]
			},
			{
				"title": "UI实现与联调",
				"description": "实现UI界面,前后端联调对接",
				"typical_duration": 5,
				"typical_roles": ["frontend_dev", "backend_dev"]
			},
			{
				"title": "测试与Bug修复",
				"description": "全面测试,发现并修复Bug",
				"typical_duration": 4,
				"typical_roles": ["qa_tester", "frontend_dev", "backend_dev"]
			},
			{
				"title": "上线部署与运营准备",
				"description": "部署上线,运营准备,文档整理",
				"typical_duration": 3,
				"typical_roles": ["backend_dev", "operations"]
			}
		]
	},

	# ========================================
	# 小说创作项目模板
	# ========================================

	"novel_writing": {
		"name": "小说创作项目",
		"name_en": "Novel Writing",
		"description": "创作一部小说(科幻、玄幻、现实、悬疑等)",
		"icon": "res://assets/icons/project_novel.png",

		"role_mapping": {
			"chief_editor": ["Stephen"],      # 主编/策划
			"main_writer": ["Alice"],         # 主笔作家
			"plot_designer": ["Tom"],         # 情节设计师
			"editor": ["Grace"],              # 文字编辑
			"cover_designer": ["Lea"],        # 封面设计师
			"researcher": ["Jack"],           # 资料研究员
			"proofreader": ["Joe"],           # 校对员
			"support": ["Monica"]
		},

		"role_definitions": {
			"chief_editor": {
				"title": "主编/策划",
				"title_en": "Chief Editor",
				"responsibilities": [
					"确定小说主题和风格",
					"制定创作计划",
					"审核内容质量",
					"把控整体方向"
				],
				"skill_requirements": ["文学素养", "管理能力", "审美判断"]
			},
			"main_writer": {
				"title": "主笔作家",
				"title_en": "Main Writer",
				"responsibilities": [
					"撰写章节内容",
					"塑造人物形象",
					"把控整体风格",
					"推进剧情发展"
				],
				"skill_requirements": ["写作能力", "创意思维", "文学功底"]
			},
			"plot_designer": {
				"title": "情节设计师",
				"title_en": "Plot Designer",
				"responsibilities": [
					"设计故事大纲",
					"规划情节走向",
					"设置冲突与高潮",
					"把控节奏"
				],
				"skill_requirements": ["逻辑思维", "创意能力", "叙事技巧"]
			},
			"editor": {
				"title": "文字编辑",
				"title_en": "Editor",
				"responsibilities": [
					"润色文字",
					"修改语病",
					"统一风格",
					"提升可读性"
				],
				"skill_requirements": ["语言能力", "细心", "审美"]
			},
			"cover_designer": {
				"title": "封面设计师",
				"title_en": "Cover Designer",
				"responsibilities": [
					"设计封面",
					"制作宣传图",
					"视觉呈现"
				],
				"skill_requirements": ["美术能力", "设计软件", "创意"]
			},
			"researcher": {
				"title": "资料研究员",
				"title_en": "Researcher",
				"responsibilities": [
					"收集背景资料",
					"考据历史细节",
					"提供专业知识",
					"支撑世界观构建"
				],
				"skill_requirements": ["研究能力", "知识广博", "细心"]
			},
			"proofreader": {
				"title": "校对员",
				"title_en": "Proofreader",
				"responsibilities": [
					"检查错别字",
					"纠正标点符号",
					"发现逻辑漏洞",
					"确保质量"
				],
				"skill_requirements": ["细心", "耐心", "语言基础"]
			}
		},

		"epic_templates": [
			{
				"title": "主题确定与大纲设计",
				"description": "确定小说主题、世界观、主要角色设定,制定详细大纲",
				"typical_duration": 3,
				"typical_roles": ["chief_editor", "main_writer", "plot_designer"]
			},
			{
				"title": "人物设定与背景构建",
				"description": "详细设定主要角色背景、性格、关系,构建世界观背景",
				"typical_duration": 2,
				"typical_roles": ["main_writer", "plot_designer", "researcher"]
			},
			{
				"title": "第一幕: 开篇",
				"description": "撰写开篇章节,建立世界观,引出主要矛盾",
				"typical_duration": 5,
				"typical_roles": ["main_writer"]
			},
			{
				"title": "第一幕校对与润色",
				"description": "编辑和校对第一幕内容,提升质量",
				"typical_duration": 2,
				"typical_roles": ["editor", "proofreader"]
			},
			{
				"title": "第二幕: 发展",
				"description": "深化矛盾,推进剧情,塑造角色成长",
				"typical_duration": 8,
				"typical_roles": ["main_writer"]
			},
			{
				"title": "第二幕校对与润色",
				"description": "编辑和校对第二幕内容",
				"typical_duration": 2,
				"typical_roles": ["editor", "proofreader"]
			},
			{
				"title": "第三幕: 高潮",
				"description": "进入高潮,冲突爆发,情节紧张",
				"typical_duration": 4,
				"typical_roles": ["main_writer", "plot_designer"]
			},
			{
				"title": "第四幕: 结局",
				"description": "解决矛盾,揭示主题,完美收官",
				"typical_duration": 4,
				"typical_roles": ["main_writer"]
			},
			{
				"title": "全文修改润色与校对",
				"description": "整体审阅,统一风格,修改润色,全文校对",
				"typical_duration": 3,
				"typical_roles": ["editor", "proofreader", "chief_editor"]
			},
			{
				"title": "封面设计与出版准备",
				"description": "设计封面,制作宣传图,准备出版资料",
				"typical_duration": 2,
				"typical_roles": ["cover_designer"]
			}
		]
	},

	# ========================================
	# 影视制作项目模板
	# ========================================

	"film_production": {
		"name": "影视制作项目",
		"name_en": "Film Production",
		"description": "拍摄一部影视作品(微电影、纪录片、短片等)",
		"icon": "res://assets/icons/project_film.png",

		"role_mapping": {
			"director": ["Stephen"],          # 导演
			"screenwriter": ["Alice"],        # 编剧
			"cinematographer": ["Tom"],       # 摄影师
			"art_director": ["Lea"],          # 美术指导
			"producer": ["Grace"],            # 制片人
			"actor_1": ["Monica"],            # 演员1
			"actor_2": ["Jack"],              # 演员2
			"editor": ["Joe"],                # 剪辑师
		},

		"role_definitions": {
			"director": {
				"title": "导演",
				"title_en": "Director",
				"responsibilities": [
					"把控整体风格",
					"指导演员表演",
					"现场调度",
					"艺术创作决策"
				],
				"skill_requirements": ["艺术素养", "领导力", "沟通能力"]
			},
			"screenwriter": {
				"title": "编剧",
				"title_en": "Screenwriter",
				"responsibilities": [
					"撰写剧本",
					"设计对白",
					"修改剧本",
					"故事创作"
				],
				"skill_requirements": ["写作能力", "创意思维", "叙事技巧"]
			},
			"cinematographer": {
				"title": "摄影师",
				"title_en": "Cinematographer",
				"responsibilities": [
					"镜头设计",
					"灯光布置",
					"拍摄执行",
					"画面构图"
				],
				"skill_requirements": ["摄影技术", "美学素养", "技术操作"]
			},
			"art_director": {
				"title": "美术指导",
				"title_en": "Art Director",
				"responsibilities": [
					"场景设计",
					"服装道具",
					"视觉风格",
					"美术统筹"
				],
				"skill_requirements": ["美术能力", "设计能力", "审美"]
			},
			"producer": {
				"title": "制片人",
				"title_en": "Producer",
				"responsibilities": [
					"项目统筹",
					"预算管理",
					"资源协调",
					"宣发策划"
				],
				"skill_requirements": ["管理能力", "商业思维", "资源整合"]
			},
			"actor_1": {
				"title": "演员",
				"title_en": "Actor",
				"responsibilities": [
					"角色演绎",
					"台词表演",
					"情感表达"
				],
				"skill_requirements": ["表演能力", "情感表达", "台词功底"]
			},
			"actor_2": {
				"title": "演员",
				"title_en": "Actor",
				"responsibilities": [
					"角色演绎",
					"台词表演",
					"情感表达"
				],
				"skill_requirements": ["表演能力", "情感表达", "台词功底"]
			},
			"editor": {
				"title": "剪辑师",
				"title_en": "Editor",
				"responsibilities": [
					"后期剪辑",
					"节奏把控",
					"特效合成",
					"成片输出"
				],
				"skill_requirements": ["剪辑技术", "节奏感", "软件操作"]
			}
		},

		"epic_templates": [
			{
				"title": "剧本创作",
				"description": "撰写剧本,确定故事结构,完成分场脚本",
				"typical_duration": 5,
				"typical_roles": ["screenwriter", "director"]
			},
			{
				"title": "前期筹备",
				"description": "演员选角、场地勘景、道具准备、制定拍摄计划",
				"typical_duration": 4,
				"typical_roles": ["producer", "art_director", "director"]
			},
			{
				"title": "分镜设计",
				"description": "设计分镜头脚本,规划镜头语言",
				"typical_duration": 3,
				"typical_roles": ["director", "cinematographer"]
			},
			{
				"title": "拍摄执行",
				"description": "现场拍摄,演员表演,摄影执行",
				"typical_duration": 10,
				"typical_roles": ["director", "cinematographer", "actor_1", "actor_2", "art_director"]
			},
			{
				"title": "后期剪辑",
				"description": "素材剪辑,镜头组接,节奏调整",
				"typical_duration": 5,
				"typical_roles": ["editor", "director"]
			},
			{
				"title": "配音配乐",
				"description": "配音、配乐、音效制作",
				"typical_duration": 3,
				"typical_roles": ["editor"]
			},
			{
				"title": "成片审核与发布",
				"description": "最终审核,调色,输出成片,宣发准备",
				"typical_duration": 2,
				"typical_roles": ["director", "producer", "editor"]
			}
		]
	}
}

# ========================================
# API函数
# ========================================

func get_template(template_id: String) -> Dictionary:
	"""获取项目类型模板"""
	return TEMPLATES.get(template_id, {})

func get_all_template_ids() -> Array:
	"""获取所有模板ID"""
	return TEMPLATES.keys()

func get_template_list() -> Array:
	"""获取模板列表(用于UI下拉选择)"""
	var list = []
	for template_id in TEMPLATES.keys():
		var template = TEMPLATES[template_id]
		list.append({
			"id": template_id,
			"name": template.get("name", ""),
			"name_en": template.get("name_en", ""),
			"description": template.get("description", ""),
			"icon": template.get("icon", "")
		})
	return list

func get_role_title(template_id: String, role_id: String) -> String:
	"""获取角色职称"""
	var template = get_template(template_id)
	var role_def = template.get("role_definitions", {}).get(role_id, {})
	return role_def.get("title", "未知角色")

func get_character_role_for_project(template_id: String, character_name: String) -> Dictionary:
	"""获取角色在项目中的职责"""
	var template = get_template(template_id)
	var role_mapping = template.get("role_mapping", {})

	for role_id in role_mapping.keys():
		var characters = role_mapping[role_id]
		if character_name in characters:
			var role_def = template.get("role_definitions", {}).get(role_id, {})
			return {
				"role_id": role_id,
				"title": role_def.get("title", ""),
				"title_en": role_def.get("title_en", ""),
				"responsibilities": role_def.get("responsibilities", []),
				"skill_requirements": role_def.get("skill_requirements", [])
			}

	return {}
