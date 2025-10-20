extends RefCounted

# ========================================
# MicroverseTheme - 统一UI主题配置
# ========================================
#
# 功能:
# - 提供统一的颜色方案
# - 统一的字体大小
# - 统一的边距和间距
# - 可应用于所有UI组件
#
# 使用方法:
# var theme = MicroverseTheme.create_theme()
# control.theme = theme
#
# ========================================

# 颜色方案
class ColorScheme:
	# 主色调
	var primary: Color = Color(0.2, 0.6, 0.8)       # 蓝色
	var primary_light: Color = Color(0.3, 0.7, 0.9)
	var primary_dark: Color = Color(0.1, 0.4, 0.6)

	# 背景色
	var background: Color = Color(0.15, 0.15, 0.15)  # 深灰色背景
	var background_light: Color = Color(0.2, 0.2, 0.2)
	var background_dark: Color = Color(0.1, 0.1, 0.1)

	# 面板色
	var panel: Color = Color(0.18, 0.18, 0.18)
	var panel_selected: Color = Color(0.25, 0.25, 0.25)

	# 文本色
	var text: Color = Color(0.9, 0.9, 0.9)
	var text_secondary: Color = Color(0.7, 0.7, 0.7)
	var text_disabled: Color = Color(0.5, 0.5, 0.5)

	# 强调色
	var accent: Color = Color(0.9, 0.5, 0.2)  # 橙色
	var success: Color = Color(0.3, 0.8, 0.3)  # 绿色
	var warning: Color = Color(0.9, 0.7, 0.2)  # 黄色
	var error: Color = Color(0.9, 0.2, 0.2)    # 红色

	# 边框色
	var border: Color = Color(0.3, 0.3, 0.3)
	var border_focus: Color = Color(0.5, 0.7, 0.9)

# 字体大小
class FontSizes:
	var heading1: int = 24
	var heading2: int = 20
	var heading3: int = 16
	var body: int = 14
	var small: int = 12
	var tiny: int = 10

# 间距
class Spacing:
	var tiny: int = 4
	var small: int = 8
	var medium: int = 12
	var large: int = 16
	var xlarge: int = 24

static func create_theme() -> Theme:
	"""创建主题资源

	Returns:
		Theme实例
	"""
	var theme = Theme.new()
	var colors = ColorScheme.new()
	var fonts = FontSizes.new()
	var spacing = Spacing.new()

	# 配置Panel
	_configure_panel(theme, colors, spacing)

	# 配置Button
	_configure_button(theme, colors, fonts, spacing)

	# 配置Label
	_configure_label(theme, colors, fonts)

	# 配置LineEdit
	_configure_line_edit(theme, colors, fonts, spacing)

	# 配置OptionButton
	_configure_option_button(theme, colors, fonts, spacing)

	# 配置ScrollContainer
	_configure_scroll_container(theme, colors)

	# 配置TabContainer
	_configure_tab_container(theme, colors, fonts, spacing)

	return theme

static func _configure_panel(theme: Theme, colors: ColorScheme, spacing: Spacing):
	"""配置Panel样式"""
	var panel_stylebox = StyleBoxFlat.new()
	panel_stylebox.bg_color = colors.panel
	panel_stylebox.border_width_left = 1
	panel_stylebox.border_width_top = 1
	panel_stylebox.border_width_right = 1
	panel_stylebox.border_width_bottom = 1
	panel_stylebox.border_color = colors.border
	panel_stylebox.corner_radius_top_left = 4
	panel_stylebox.corner_radius_top_right = 4
	panel_stylebox.corner_radius_bottom_left = 4
	panel_stylebox.corner_radius_bottom_right = 4
	panel_stylebox.content_margin_left = spacing.medium
	panel_stylebox.content_margin_top = spacing.medium
	panel_stylebox.content_margin_right = spacing.medium
	panel_stylebox.content_margin_bottom = spacing.medium

	theme.set_stylebox("panel", "Panel", panel_stylebox)
	theme.set_stylebox("panel", "PanelContainer", panel_stylebox)

static func _configure_button(theme: Theme, colors: ColorScheme, fonts: FontSizes, spacing: Spacing):
	"""配置Button样式"""
	# 正常状态
	var button_normal = StyleBoxFlat.new()
	button_normal.bg_color = colors.primary
	button_normal.corner_radius_top_left = 4
	button_normal.corner_radius_top_right = 4
	button_normal.corner_radius_bottom_left = 4
	button_normal.corner_radius_bottom_right = 4
	button_normal.content_margin_left = spacing.medium
	button_normal.content_margin_top = spacing.small
	button_normal.content_margin_right = spacing.medium
	button_normal.content_margin_bottom = spacing.small

	# 悬停状态
	var button_hover = button_normal.duplicate()
	button_hover.bg_color = colors.primary_light

	# 按下状态
	var button_pressed = button_normal.duplicate()
	button_pressed.bg_color = colors.primary_dark

	# 禁用状态
	var button_disabled = button_normal.duplicate()
	button_disabled.bg_color = colors.background_light

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)

	theme.set_color("font_color", "Button", colors.text)
	theme.set_color("font_hover_color", "Button", colors.text)
	theme.set_color("font_pressed_color", "Button", colors.text)
	theme.set_color("font_disabled_color", "Button", colors.text_disabled)

	theme.set_font_size("font_size", "Button", fonts.body)

static func _configure_label(theme: Theme, colors: ColorScheme, fonts: FontSizes):
	"""配置Label样式"""
	theme.set_color("font_color", "Label", colors.text)
	theme.set_font_size("font_size", "Label", fonts.body)

static func _configure_line_edit(theme: Theme, colors: ColorScheme, fonts: FontSizes, spacing: Spacing):
	"""配置LineEdit样式"""
	# 正常状态
	var lineedit_normal = StyleBoxFlat.new()
	lineedit_normal.bg_color = colors.background_dark
	lineedit_normal.border_width_left = 1
	lineedit_normal.border_width_top = 1
	lineedit_normal.border_width_right = 1
	lineedit_normal.border_width_bottom = 1
	lineedit_normal.border_color = colors.border
	lineedit_normal.corner_radius_top_left = 4
	lineedit_normal.corner_radius_top_right = 4
	lineedit_normal.corner_radius_bottom_left = 4
	lineedit_normal.corner_radius_bottom_right = 4
	lineedit_normal.content_margin_left = spacing.small
	lineedit_normal.content_margin_top = spacing.small
	lineedit_normal.content_margin_right = spacing.small
	lineedit_normal.content_margin_bottom = spacing.small

	# 聚焦状态
	var lineedit_focus = lineedit_normal.duplicate()
	lineedit_focus.border_color = colors.border_focus

	theme.set_stylebox("normal", "LineEdit", lineedit_normal)
	theme.set_stylebox("focus", "LineEdit", lineedit_focus)

	theme.set_color("font_color", "LineEdit", colors.text)
	theme.set_color("font_placeholder_color", "LineEdit", colors.text_secondary)
	theme.set_font_size("font_size", "LineEdit", fonts.body)

static func _configure_option_button(theme: Theme, colors: ColorScheme, fonts: FontSizes, spacing: Spacing):
	"""配置OptionButton样式"""
	# 复用Button样式
	_configure_button(theme, colors, fonts, spacing)

	var option_normal = StyleBoxFlat.new()
	option_normal.bg_color = colors.background_light
	option_normal.border_width_left = 1
	option_normal.border_width_top = 1
	option_normal.border_width_right = 1
	option_normal.border_width_bottom = 1
	option_normal.border_color = colors.border
	option_normal.corner_radius_top_left = 4
	option_normal.corner_radius_top_right = 4
	option_normal.corner_radius_bottom_left = 4
	option_normal.corner_radius_bottom_right = 4
	option_normal.content_margin_left = spacing.small
	option_normal.content_margin_top = spacing.small
	option_normal.content_margin_right = spacing.small
	option_normal.content_margin_bottom = spacing.small

	var option_hover = option_normal.duplicate()
	option_hover.bg_color = colors.panel_selected

	theme.set_stylebox("normal", "OptionButton", option_normal)
	theme.set_stylebox("hover", "OptionButton", option_hover)
	theme.set_stylebox("pressed", "OptionButton", option_hover)

	theme.set_color("font_color", "OptionButton", colors.text)
	theme.set_font_size("font_size", "OptionButton", fonts.body)

static func _configure_scroll_container(theme: Theme, colors: ColorScheme):
	"""配置ScrollContainer样式"""
	# 滚动条背景
	var scrollbar_bg = StyleBoxFlat.new()
	scrollbar_bg.bg_color = colors.background_dark

	# 滚动条抓手
	var scrollbar_grabber = StyleBoxFlat.new()
	scrollbar_grabber.bg_color = colors.border
	scrollbar_grabber.corner_radius_top_left = 4
	scrollbar_grabber.corner_radius_top_right = 4
	scrollbar_grabber.corner_radius_bottom_left = 4
	scrollbar_grabber.corner_radius_bottom_right = 4

	var scrollbar_grabber_hover = scrollbar_grabber.duplicate()
	scrollbar_grabber_hover.bg_color = colors.text_secondary

	theme.set_stylebox("scroll", "VScrollBar", scrollbar_bg)
	theme.set_stylebox("grabber", "VScrollBar", scrollbar_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scrollbar_grabber_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scrollbar_grabber_hover)

	theme.set_stylebox("scroll", "HScrollBar", scrollbar_bg)
	theme.set_stylebox("grabber", "HScrollBar", scrollbar_grabber)
	theme.set_stylebox("grabber_highlight", "HScrollBar", scrollbar_grabber_hover)
	theme.set_stylebox("grabber_pressed", "HScrollBar", scrollbar_grabber_hover)

static func _configure_tab_container(theme: Theme, colors: ColorScheme, fonts: FontSizes, spacing: Spacing):
	"""配置TabContainer样式"""
	# 标签背景
	var tab_bg = StyleBoxFlat.new()
	tab_bg.bg_color = colors.background_light
	tab_bg.corner_radius_top_left = 4
	tab_bg.corner_radius_top_right = 4
	tab_bg.content_margin_left = spacing.medium
	tab_bg.content_margin_top = spacing.small
	tab_bg.content_margin_right = spacing.medium
	tab_bg.content_margin_bottom = spacing.small

	# 选中标签
	var tab_selected = tab_bg.duplicate()
	tab_selected.bg_color = colors.panel

	# 未选中标签
	var tab_unselected = tab_bg.duplicate()
	tab_unselected.bg_color = colors.background

	# 面板背景
	var panel_bg = StyleBoxFlat.new()
	panel_bg.bg_color = colors.panel
	panel_bg.border_width_left = 1
	panel_bg.border_width_top = 1
	panel_bg.border_width_right = 1
	panel_bg.border_width_bottom = 1
	panel_bg.border_color = colors.border
	panel_bg.content_margin_left = spacing.medium
	panel_bg.content_margin_top = spacing.medium
	panel_bg.content_margin_right = spacing.medium
	panel_bg.content_margin_bottom = spacing.medium

	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)
	theme.set_stylebox("panel", "TabContainer", panel_bg)

	theme.set_color("font_selected_color", "TabContainer", colors.text)
	theme.set_color("font_unselected_color", "TabContainer", colors.text_secondary)
	theme.set_font_size("font_size", "TabContainer", fonts.body)

static func get_color_scheme() -> ColorScheme:
	"""获取颜色方案

	Returns:
		ColorScheme实例
	"""
	return ColorScheme.new()

static func get_font_sizes() -> FontSizes:
	"""获取字体大小配置

	Returns:
		FontSizes实例
	"""
	return FontSizes.new()

static func get_spacing() -> Spacing:
	"""获取间距配置

	Returns:
		Spacing实例
	"""
	return Spacing.new()
