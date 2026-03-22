# ============================================================
# HUD — Mobile Game UI with sprite icons, build panel, stats
# Top bar + read-only pie chart + build panel + upgrades
# ============================================================
extends CanvasLayer

signal restart_requested
signal save_requested
signal call_to_arms_requested
signal promote_requested(role: int)
signal emergency_repair_requested
signal building_upgrade_requested

var building_manager

# ── Icons loaded from sprite sheet ───────────────────────────
var icons: Dictionary = {}  # name -> ImageTexture

# ── Dynamic UI refs ──────────────────────────────────────────
var hp_bar_fill: ColorRect
var hp_label: Label
var res_wood_lbl: Label
var res_stone_lbl: Label
var res_gold_lbl: Label
var rate_wood_lbl: Label
var rate_stone_lbl: Label
var rate_gold_lbl: Label
var res_research_lbl: Label
var pop_lbl: Label
var wave_lbl: Label
var game_over_panel: Control
var stage_lbl: Label
var evolve_btn: Button
var left_panel: PanelContainer
var left_quest_btn: Button
var left_call_btn: Button
var selected_villager_lbl: Label
var selected_building_lbl: Label
var selected_building_upgrade_btn: Button
var build_tab_btn: Button
var research_tab_btn: Button
var upgrade_tab_btn: Button
var build_content_wrap: Control
var research_content_wrap: Control
var upgrade_content_wrap: Control
var build_cards_grid: GridContainer
var research_content: VBoxContainer
var upgrade_content: VBoxContainer
var top_bar: Panel
var minimap_wrap: Control
var hammer_corner: PanelContainer

# Pie chart (read-only)
var pie_chart: Control

# Build panel
var build_panel: PanelContainer
var build_visible := false
var build_toggle_btn: Button
var carpentry_btn: Button
var mining_btn: Button
var army_btn: Button
var healing_btn: Button
var mine_btn: Button
var watch_tower_btn: Button
var forester_lodge_btn: Button
var training_grounds_btn: Button
var ballista_tower_btn: Button
var armory_btn: Button
var trap_btn: Button
var barricade_btn: Button
var carpentry_count_lbl: Label
var mining_count_lbl: Label
var army_count_lbl: Label
var healing_count_lbl: Label
var mine_count_lbl: Label
var watch_tower_count_lbl: Label
var forester_lodge_count_lbl: Label
var training_grounds_count_lbl: Label
var ballista_tower_count_lbl: Label
var armory_count_lbl: Label
var trap_count_lbl: Label
var barricade_count_lbl: Label
var build_cards: Dictionary = {}

# Upgrade panel
var upgrade_panel: PanelContainer
var upgrade_visible := false
var upgrade_toggle_btn: Button
var axe_btn: Button
var pick_btn: Button
var sword_btn: Button
var axe_info_lbl: Label
var pick_info_lbl: Label
var sword_info_lbl: Label

# Settings panel
var settings_panel: PanelContainer
var settings_visible := false
var settings_toggle_btn: Button
var music_toggle_btn: Button
var sfx_toggle_btn: Button

# Tutorial
var tutorial_step := 0   # 0=carpentry, 1=mining, 2=army, 3=done
var tutorial_panel: PanelContainer
var tutorial_lbl: Label
var tutorial_toggle_btn: Button
var tutorial_visible := true

# Minimap + wave warning
var minimap: Control
var minimap_ground: Array = []
var minimap_center_pos := Vector2.ZERO
var minimap_threats: Array = []
var wave_warn_lbl: Label
var research_panel: PanelContainer
var research_toggle_btn: Button
var research_labels: Dictionary = {}
var research_buttons: Dictionary = {}
var research_progress_bars: Dictionary = {}

# Pie chart data
var role_colors: Dictionary = {
	GameConfig.Role.IDLE: Color(0.55, 0.55, 0.50),
	GameConfig.Role.DEFENDER: Color(0.85, 0.25, 0.25),
	GameConfig.Role.LUMBERJACK: Color(0.30, 0.70, 0.30),
	GameConfig.Role.MINER: Color(0.35, 0.55, 0.80),
	GameConfig.Role.BUILDER: Color(0.78, 0.52, 0.24),
	GameConfig.Role.SCHOLAR: Color(0.60, 0.40, 0.82),
	GameConfig.Role.FORESTER: Color(0.20, 0.72, 0.34),
}
var role_order: Array = [GameConfig.Role.IDLE, GameConfig.Role.DEFENDER, GameConfig.Role.BUILDER, GameConfig.Role.SCHOLAR, GameConfig.Role.FORESTER, GameConfig.Role.LUMBERJACK, GameConfig.Role.MINER]

# ── Colour palette ───────────────────────────────────────────
const BG_BAR := Color(0.15, 0.13, 0.11, 0.92)
const BG_PANEL := Color(0.22, 0.19, 0.16, 0.95)
const BG_CARD := Color(0.28, 0.25, 0.21, 0.90)
const BG_BTN := Color(0.35, 0.30, 0.24)
const ACCENT := Color(0.85, 0.65, 0.20)
const TEXT_W := Color(0.95, 0.93, 0.88)
const TEXT_DIM := Color(0.72, 0.68, 0.60)
const TEXT_COST := Color(0.90, 0.70, 0.25)
const C_GREEN := Color(0.35, 0.75, 0.30)
const C_RED := Color(0.85, 0.22, 0.18)
const C_HP_BG := Color(0.60, 0.15, 0.12)
const R := 12
const R_BTN := 8

# Icon regions from ui_icons.png (x, y, w, h)
const SHEET_REGIONS := {
	"wood":    Rect2(94, 46, 192, 192),
	"stone":   Rect2(406, 46, 184, 192),
	"gold":    Rect2(724, 46, 178, 192),
	"person":  Rect2(114, 324, 160, 212),
	"swords":  Rect2(386, 324, 230, 212),
	"skull":   Rect2(718, 324, 190, 212),
	"swords_s": Rect2(1048, 324, 180, 212),
	"skull_s": Rect2(1422, 324, 112, 152),
	"horn": Rect2(1421, 373, 113, 119),
	"scroll": Rect2(2019, 382, 106, 128),
	"book": Rect2(2222, 388, 119, 121),
	"close_x": Rect2(106, 620, 176, 206),
	"axe":     Rect2(78, 968, 254, 254),
	"pickaxe": Rect2(390, 968, 232, 254),
	"sword":   Rect2(698, 968, 246, 254),
	"quiver":  Rect2(1034, 968, 256, 254),
	"arrow":   Rect2(1392, 968, 264, 200),
	"c_shield": Rect2(70, 1374, 240, 276),
	"c_axe":   Rect2(376, 1374, 242, 276),
	"c_pick":  Rect2(686, 1374, 240, 276),
	"d_swords": Rect2(1740, 1374, 244, 276),
	"d_quiver": Rect2(1998, 1374, 240, 276),
	"d_hammer": Rect2(2252, 1374, 244, 276),
	"wood_panel": Rect2(2086, 784, 390, 584),
	"wood_btn": Rect2(2186, 541, 342, 87),
}

const ICON_SIZE_TOP := 22
const ICON_SIZE_UPGRADE := 28
const ICON_SIZE_PIE := 22


func _ready() -> void:
	_load_icons()
	_build_top_bar()
	_build_left_panel()
	_build_build_panel()
	_build_upgrade_toggle()
	_build_upgrade_panel()
	_build_settings_toggle()
	_build_settings_panel()
	_build_minimap()
	_build_corner_hammer()
	wave_warn_lbl = _make_lbl("", 12, Color(1.0, 0.3, 0.3))
	wave_warn_lbl.visible = false
	wave_warn_lbl.z_index = 200
	add_child(wave_warn_lbl)

	ResourceManager.resources_changed.connect(_on_res_changed)
	TaskManager.allocation_changed.connect(_on_alloc_changed)
	ResourceManager.research_changed.connect(_on_research_changed)
	ResourceManager.tech_researched.connect(_on_tech_researched)
	ResourceManager.tool_upgraded.connect(_on_tool_upgraded)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_responsive_layout()

	update_resources()
	update_tasks()


# ── Icon loader ──────────────────────────────────────────────

func _load_icons() -> void:
	var path := ProjectSettings.globalize_path("res://ui/ui_iconsv2.png")
	var sheet := Image.load_from_file(path)
	if sheet == null:
		push_warning("Failed to load ui_iconsv2.png")
		return

	for key: String in SHEET_REGIONS:
		var region: Rect2 = SHEET_REGIONS[key]
		var cropped := sheet.get_region(Rect2i(int(region.position.x), int(region.position.y), int(region.size.x), int(region.size.y)))
		var tex := ImageTexture.create_from_image(cropped)
		icons[key] = tex


func _icon_tex(icon_name: String, sz: int) -> TextureRect:
	var tr := TextureRect.new()
	if icons.has(icon_name):
		tr.texture = icons[icon_name]
	tr.custom_minimum_size = Vector2(sz, sz)
	tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


# ── Connections ──────────────────────────────────────────────

func set_building_manager(bm) -> void:
	building_manager = bm
	building_manager.evolved.connect(_on_evolved)
	building_manager.building_placed.connect(_on_building_placed)
	building_manager.building_destroyed.connect(_on_building_destroyed)
	update_building()

func _on_res_changed(_r: Dictionary) -> void:
	update_resources()
	_update_upgrade_buttons()
	_update_build_buttons()
	update_building()

func _on_alloc_changed(_a: Dictionary) -> void:
	update_tasks()

func _on_evolved(_s: int) -> void:
	update_building()
	_update_build_buttons()

func _on_tool_upgraded(_t: String, _l: int) -> void:
	_update_upgrade_buttons()

func _on_building_placed(key: String) -> void:
	_update_build_buttons()
	update_tasks()
	_advance_tutorial(key)

func _on_building_destroyed(_key: String, _bld_data: Dictionary) -> void:
	_update_build_buttons()
	update_tasks()


# ╔══════════════════════════════════════════════════════════╗
# ║  TOP BAR  —  [wood] 20  [stone] 12  [gold] 6  HP BAR    ║
# ║              [person] 6  [swords] WAVE 2                  ║
# ╚══════════════════════════════════════════════════════════╝

func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.name = "TopBar"
	top_bar = bar
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_top = 0
	bar.offset_bottom = 52
	bar.add_theme_stylebox_override("panel", _sb(BG_BAR, 0, 0, R, R))
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Wood pill
	var wood_pill := _top_pill()
	var wood_h := HBoxContainer.new()
	wood_h.add_theme_constant_override("separation", 4)
	wood_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wood_h.add_child(_icon_tex("wood", ICON_SIZE_TOP))
	var wood_vbox := _res_vbox()
	res_wood_lbl = _make_lbl("0", 13, TEXT_W)
	wood_vbox.add_child(res_wood_lbl)
	rate_wood_lbl = _make_lbl("", 8, C_GREEN)
	wood_vbox.add_child(rate_wood_lbl)
	wood_h.add_child(wood_vbox)
	wood_pill.add_child(wood_h)
	hbox.add_child(wood_pill)

	# Stone pill
	var stone_pill := _top_pill()
	var stone_h := HBoxContainer.new()
	stone_h.add_theme_constant_override("separation", 4)
	stone_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stone_h.add_child(_icon_tex("stone", ICON_SIZE_TOP))
	var stone_vbox := _res_vbox()
	res_stone_lbl = _make_lbl("0", 13, TEXT_W)
	stone_vbox.add_child(res_stone_lbl)
	rate_stone_lbl = _make_lbl("", 8, C_GREEN)
	stone_vbox.add_child(rate_stone_lbl)
	stone_h.add_child(stone_vbox)
	stone_pill.add_child(stone_h)
	hbox.add_child(stone_pill)

	# Gold pill
	var gold_pill := _top_pill()
	var gold_h := HBoxContainer.new()
	gold_h.add_theme_constant_override("separation", 4)
	gold_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_h.add_child(_icon_tex("gold", ICON_SIZE_TOP))
	var gold_vbox := _res_vbox()
	res_gold_lbl = _make_lbl("0", 13, TEXT_W)
	gold_vbox.add_child(res_gold_lbl)
	rate_gold_lbl = _make_lbl("", 8, C_GREEN)
	gold_vbox.add_child(rate_gold_lbl)
	gold_h.add_child(gold_vbox)
	gold_pill.add_child(gold_h)
	hbox.add_child(gold_pill)

	# HP bar pill
	var hp_pill := _top_pill()
	var hp_box := VBoxContainer.new()
	hp_box.add_theme_constant_override("separation", -1)
	hp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_outer := PanelContainer.new()
	hp_outer.custom_minimum_size = Vector2(140, 20)
	hp_outer.add_theme_stylebox_override("panel", _sb(C_HP_BG, 5, 5, 5, 5))
	hp_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_inner := Control.new()
	hp_inner.custom_minimum_size = Vector2(110, 14)
	hp_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = C_GREEN
	hp_bar_fill.anchor_right = 1.0
	hp_bar_fill.anchor_bottom = 1.0
	hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_inner.add_child(hp_bar_fill)
	hp_label = _make_lbl("%d/%d" % [GameConfig.CABIN_MAX_HP, GameConfig.CABIN_MAX_HP], 10, TEXT_W)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_outer.add_child(hp_inner)
	hp_box.add_child(hp_outer)
	hp_box.add_child(hp_label)
	hp_pill.add_child(hp_box)
	hbox.add_child(hp_pill)

	# Population pill
	var pop_pill := _top_pill()
	var pop_h := HBoxContainer.new()
	pop_h.add_theme_constant_override("separation", 4)
	pop_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_h.add_child(_icon_tex("person", ICON_SIZE_TOP))
	pop_lbl = _make_lbl(str(GameConfig.INITIAL_VILLAGERS), 13, TEXT_W)
	pop_h.add_child(pop_lbl)
	pop_pill.add_child(pop_h)
	hbox.add_child(pop_pill)

	# Wave pill
	var wave_pill := _top_pill()
	var wave_h := HBoxContainer.new()
	wave_h.add_theme_constant_override("separation", 4)
	wave_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_h.add_child(_icon_tex("swords_s", ICON_SIZE_TOP))
	var wave_title := _make_lbl("WAVE", 10, TEXT_DIM)
	wave_h.add_child(wave_title)
	wave_lbl = _make_lbl("0", 13, C_RED)
	wave_h.add_child(wave_lbl)
	wave_pill.add_child(wave_h)
	hbox.add_child(wave_pill)

	# RP pill
	var rp_pill := _top_pill()
	var rp_h := HBoxContainer.new()
	rp_h.add_theme_constant_override("separation", 4)
	rp_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp_h.add_child(_icon_tex("book", ICON_SIZE_TOP))
	res_research_lbl = _make_lbl("RP 0", 13, Color(0.84, 0.72, 0.95))
	rp_h.add_child(res_research_lbl)
	rp_pill.add_child(rp_h)
	hbox.add_child(rp_pill)

	bar.add_child(hbox)

	# Settings gear button pinned to the right edge of the top bar.
	settings_toggle_btn = Button.new()
	settings_toggle_btn.text = "\u2699"
	settings_toggle_btn.add_theme_font_size_override("font_size", 20)
	settings_toggle_btn.custom_minimum_size = Vector2(36, 36)
	settings_toggle_btn.anchor_left = 1.0
	settings_toggle_btn.anchor_right = 1.0
	settings_toggle_btn.offset_left = -42
	settings_toggle_btn.offset_right = -6
	settings_toggle_btn.offset_top = 8
	settings_toggle_btn.offset_bottom = 44
	_style_btn(settings_toggle_btn, Color(0.25, 0.22, 0.18, 0.9))
	settings_toggle_btn.pressed.connect(_toggle_settings)
	bar.add_child(settings_toggle_btn)

	add_child(bar)


func _build_left_panel() -> void:
	left_panel = PanelContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.anchor_left = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 6
	left_panel.offset_right = 256
	left_panel.offset_top = 62
	left_panel.offset_bottom = -228
	left_panel.add_theme_stylebox_override("panel", _sb(BG_PANEL, 14, 14, 14, 14))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 6)

	left_quest_btn = Button.new()
	left_quest_btn.custom_minimum_size = Vector2(112, 80)
	left_quest_btn.text = "QUEST LOG"
	left_quest_btn.icon = icons.get("scroll", null)
	left_quest_btn.expand_icon = false
	left_quest_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left_quest_btn.add_theme_constant_override("icon_max_width", 24)
	left_quest_btn.add_theme_constant_override("h_separation", 6)
	left_quest_btn.add_theme_font_size_override("font_size", 11)
	_style_btn(left_quest_btn, Color(0.33, 0.28, 0.22, 0.95))
	hero_row.add_child(left_quest_btn)

	left_call_btn = Button.new()
	left_call_btn.custom_minimum_size = Vector2(112, 80)
	left_call_btn.text = "HIDE"
	left_call_btn.icon = icons.get("horn", null)
	left_call_btn.expand_icon = false
	left_call_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left_call_btn.add_theme_constant_override("icon_max_width", 28)
	left_call_btn.add_theme_constant_override("h_separation", 6)
	left_call_btn.add_theme_font_size_override("font_size", 11)
	_style_btn(left_call_btn, Color(0.58, 0.20, 0.16, 0.95))
	left_call_btn.pressed.connect(func(): call_to_arms_requested.emit())
	hero_row.add_child(left_call_btn)

	root.add_child(hero_row)

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 6)
	var builder_btn := Button.new()
	builder_btn.text = "BUILDER"
	builder_btn.icon = icons.get("d_hammer", null)
	builder_btn.expand_icon = false
	builder_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	builder_btn.add_theme_constant_override("icon_max_width", 22)
	builder_btn.add_theme_constant_override("h_separation", 6)
	builder_btn.custom_minimum_size = Vector2(112, 56)
	builder_btn.pressed.connect(func(): promote_requested.emit(GameConfig.Role.BUILDER))
	_style_btn(builder_btn, Color(0.52, 0.33, 0.18, 0.95))
	role_row.add_child(builder_btn)
	var scholar_btn := Button.new()
	scholar_btn.text = "SCHOLAR"
	scholar_btn.icon = icons.get("book", null)
	scholar_btn.expand_icon = false
	scholar_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	scholar_btn.add_theme_constant_override("icon_max_width", 22)
	scholar_btn.add_theme_constant_override("h_separation", 6)
	scholar_btn.custom_minimum_size = Vector2(112, 56)
	scholar_btn.pressed.connect(func(): promote_requested.emit(GameConfig.Role.SCHOLAR))
	_style_btn(scholar_btn, Color(0.35, 0.22, 0.52, 0.95))
	role_row.add_child(scholar_btn)
	root.add_child(role_row)

	var sel_card := PanelContainer.new()
	sel_card.add_theme_stylebox_override("panel", _sb(Color(0.20, 0.17, 0.14, 0.94), 8, 8, 8, 8))
	selected_villager_lbl = _make_lbl("SELECT A VILLAGER TO VIEW EXPERTISE", 10, TEXT_DIM)
	selected_villager_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	selected_villager_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sel_card.add_child(selected_villager_lbl)
	root.add_child(sel_card)

	var bld_card := PanelContainer.new()
	bld_card.add_theme_stylebox_override("panel", _sb(Color(0.20, 0.17, 0.14, 0.94), 8, 8, 8, 8))
	var bld_box := VBoxContainer.new()
	bld_box.add_theme_constant_override("separation", 6)
	selected_building_lbl = _make_lbl("SELECT A BUILDING TO LEVEL IT", 10, TEXT_DIM)
	selected_building_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	selected_building_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bld_box.add_child(selected_building_lbl)
	selected_building_upgrade_btn = Button.new()
	selected_building_upgrade_btn.text = "UPGRADE"
	selected_building_upgrade_btn.custom_minimum_size = Vector2(0, 28)
	selected_building_upgrade_btn.add_theme_font_size_override("font_size", 10)
	selected_building_upgrade_btn.disabled = true
	_style_disabled_btn(selected_building_upgrade_btn)
	selected_building_upgrade_btn.pressed.connect(func():
		building_upgrade_requested.emit()
	)
	bld_box.add_child(selected_building_upgrade_btn)
	bld_card.add_child(bld_box)
	root.add_child(bld_card)

	var pie_wrap := Control.new()
	pie_wrap.custom_minimum_size = Vector2(0, 200)
	pie_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pie_chart = Control.new()
	pie_chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pie_chart.connect("draw", _draw_pie)
	pie_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie_wrap.add_child(pie_chart)
	root.add_child(pie_wrap)

	left_panel.add_child(root)
	add_child(left_panel)


# ╔══════════════════════════════════════════════════════════╗
# ║  PIE CHART  —  Bottom-left task allocation               ║
# ╚══════════════════════════════════════════════════════════╝

func _build_pie_chart() -> void:
	# Legacy entry point kept for compatibility.
	if pie_chart:
		return
	_build_left_panel()


func _draw_pie() -> void:
	if not pie_chart:
		return
	var size := pie_chart.size
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var alloc := TaskManager.get_allocation()
	var start_angle := -PI / 2.0
	var total := 0
	for role_key: int in role_order:
		total += int(alloc.get(role_key, 0))
	if total == 0:
		total = 100

	for i: int in range(role_order.size()):
		var role: int = role_order[i]
		var pct: int = int(alloc.get(role, 0))
		var sweep := (float(pct) / total) * TAU
		if pct <= 0:
			continue
		var color: Color = role_colors.get(role, Color.GRAY)

		# Draw filled arc using polygon
		var points := PackedVector2Array()
		points.append(center)
		var steps := maxi(int(sweep / 0.1), 4)
		for s: int in range(steps + 1):
			var angle := start_angle + sweep * float(s) / float(steps)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		pie_chart.draw_colored_polygon(points, color)

		# Draw separator line
		var end_angle := start_angle + sweep
		pie_chart.draw_line(center, center + Vector2(cos(end_angle), sin(end_angle)) * radius, Color(0, 0, 0, 0.3), 2.0)

		# Label at midpoint of arc
		var mid_angle := start_angle + sweep * 0.5
		var label_pos := center + Vector2(cos(mid_angle), sin(mid_angle)) * (radius * 0.6)

		# Draw percentage text
		var font := ThemeDB.fallback_font
		var font_size := 24
		var txt := "%d%%" % pct
		var txt_size := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		pie_chart.draw_string(font, label_pos - txt_size * 0.5 + Vector2(0, txt_size.y * 0.5), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.95))

		# Draw icon
		var icon_name := ""
		match role:
			GameConfig.Role.IDLE: icon_name = "person"
			GameConfig.Role.DEFENDER: icon_name = "c_shield"
			GameConfig.Role.BUILDER: icon_name = "d_hammer"
			GameConfig.Role.SCHOLAR: icon_name = "gold"
			GameConfig.Role.FORESTER: icon_name = "c_axe"
			GameConfig.Role.LUMBERJACK: icon_name = "c_axe"
			GameConfig.Role.MINER: icon_name = "c_pick"
		if icons.has(icon_name):
			var icon_pos := center + Vector2(cos(mid_angle), sin(mid_angle)) * (radius * 0.35)
			var icon_sz := maxf(20.0, radius * 0.26)
			var icon_rect := Rect2(icon_pos - Vector2(icon_sz, icon_sz) * 0.5, Vector2(icon_sz, icon_sz))
			pie_chart.draw_texture_rect(icons[icon_name], icon_rect, false)

		start_angle += sweep

	# Outline circle
	pie_chart.draw_arc(center, radius, 0, TAU, 64, Color(0, 0, 0, 0.3), 2.0)


# ╔══════════════════════════════════════════════════════════╗
# ║  BUILD PANEL — bottom-center: buildings + evolve          ║
# ╚══════════════════════════════════════════════════════════╝

func _build_build_panel() -> void:
	build_panel = PanelContainer.new()
	build_panel.name = "BuildPanel"
	build_panel.anchor_left = 0.0
	build_panel.anchor_right = 1.0
	build_panel.anchor_top = 1.0
	build_panel.anchor_bottom = 1.0
	build_panel.offset_left = 268
	build_panel.offset_right = -184
	build_panel.offset_top = -196
	build_panel.offset_bottom = -10
	build_panel.add_theme_stylebox_override("panel", _sb(BG_PANEL, R, R, R, R))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Header rows: tabs then stage (keeps all tabs visible on narrow widths)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	build_tab_btn = Button.new()
	build_tab_btn.text = "[BUILD]"
	build_tab_btn.custom_minimum_size = Vector2(0, 30)
	build_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_tab_btn.add_theme_font_size_override("font_size", 13)
	_style_upgrade_btn(build_tab_btn)
	build_tab_btn.pressed.connect(func(): _show_build_tab("build"))
	tab_row.add_child(build_tab_btn)

	research_tab_btn = Button.new()
	research_tab_btn.text = "[RESEARCH]"
	research_tab_btn.custom_minimum_size = Vector2(0, 30)
	research_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	research_tab_btn.add_theme_font_size_override("font_size", 13)
	_style_btn(research_tab_btn, Color(0.2, 0.2, 0.2, 0.95))
	research_tab_btn.pressed.connect(func(): _show_build_tab("research"))
	tab_row.add_child(research_tab_btn)

	upgrade_tab_btn = Button.new()
	upgrade_tab_btn.text = "[UPGRADES]"
	upgrade_tab_btn.custom_minimum_size = Vector2(0, 30)
	upgrade_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_tab_btn.add_theme_font_size_override("font_size", 13)
	_style_btn(upgrade_tab_btn, Color(0.2, 0.2, 0.2, 0.95))
	upgrade_tab_btn.pressed.connect(func(): _show_build_tab("upgrades"))
	tab_row.add_child(upgrade_tab_btn)
	header.add_child(tab_row)

	stage_lbl = _make_lbl("Tent", 12, TEXT_DIM)
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(stage_lbl)
	vbox.add_child(header)

	# Evolve button
	evolve_btn = Button.new()
	evolve_btn.text = "EVOLVE CABIN"
	evolve_btn.custom_minimum_size = Vector2(0, 30)
	evolve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_accent_btn(evolve_btn)
	evolve_btn.add_theme_font_size_override("font_size", 11)
	evolve_btn.pressed.connect(_on_evolve_pressed)
	vbox.add_child(evolve_btn)

	# Build cards list (scrollable so lower rows like trap/barricade are reachable)
	var build_scroll := ScrollContainer.new()
	build_scroll.custom_minimum_size = Vector2(0, 126)
	build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	build_content_wrap = build_scroll

	build_cards_grid = GridContainer.new()
	build_cards_grid.columns = 2
	build_cards_grid.add_theme_constant_override("h_separation", 8)
	build_cards_grid.add_theme_constant_override("v_separation", 6)

	var c1 := _make_build_btn("Carpentry", "c_axe", "carpentry")
	carpentry_btn = c1[0]
	carpentry_count_lbl = c1[1]
	build_cards["carpentry"] = c1[2]
	build_cards_grid.add_child(c1[2])

	var c2 := _make_build_btn("Mining House", "c_pick", "mining_house")
	mining_btn = c2[0]
	mining_count_lbl = c2[1]
	build_cards["mining_house"] = c2[2]
	build_cards_grid.add_child(c2[2])

	var c3 := _make_build_btn("Army Base", "c_shield", "army_base")
	army_btn = c3[0]
	army_count_lbl = c3[1]
	build_cards["army_base"] = c3[2]
	build_cards_grid.add_child(c3[2])

	var c4 := _make_build_btn("Healing Hut", "person", "healing_hut")
	healing_btn = c4[0]
	healing_count_lbl = c4[1]
	build_cards["healing_hut"] = c4[2]
	build_cards_grid.add_child(c4[2])

	var c4b := _make_build_btn("Forester Lodge", "c_axe", "forester_lodge")
	forester_lodge_btn = c4b[0]
	forester_lodge_count_lbl = c4b[1]
	build_cards["forester_lodge"] = c4b[2]
	build_cards_grid.add_child(c4b[2])

	var c4c := _make_build_btn("Training Grounds", "c_shield", "training_grounds")
	training_grounds_btn = c4c[0]
	training_grounds_count_lbl = c4c[1]
	build_cards["training_grounds"] = c4c[2]
	build_cards_grid.add_child(c4c[2])

	var c4d := _make_build_btn("Armory", "sword", "armory")
	armory_btn = c4d[0]
	armory_count_lbl = c4d[1]
	build_cards["armory"] = c4d[2]
	build_cards_grid.add_child(c4d[2])

	var c4e := _make_build_btn("Mine", "c_pick", "mine")
	mine_btn = c4e[0]
	mine_count_lbl = c4e[1]
	build_cards["mine"] = c4e[2]
	build_cards_grid.add_child(c4e[2])

	var c4f := _make_build_btn("Watch Tower", "quiver", "watch_tower")
	watch_tower_btn = c4f[0]
	watch_tower_count_lbl = c4f[1]
	build_cards["watch_tower"] = c4f[2]
	build_cards_grid.add_child(c4f[2])

	var c4g := _make_build_btn("Ballista Tower", "arrow", "ballista_tower")
	ballista_tower_btn = c4g[0]
	ballista_tower_count_lbl = c4g[1]
	build_cards["ballista_tower"] = c4g[2]
	build_cards_grid.add_child(c4g[2])

	var c5 := _make_build_btn("Spike Trap", "swords_s", "trap")
	trap_btn = c5[0]
	trap_count_lbl = c5[1]
	build_cards["trap"] = c5[2]
	build_cards_grid.add_child(c5[2])

	var c6 := _make_build_btn("Barricade", "wood", "barricade")
	barricade_btn = c6[0]
	barricade_count_lbl = c6[1]
	build_cards["barricade"] = c6[2]
	build_cards_grid.add_child(c6[2])
	build_scroll.add_child(build_cards_grid)
	vbox.add_child(build_scroll)

	var research_scroll := ScrollContainer.new()
	research_scroll.custom_minimum_size = Vector2(0, 126)
	research_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	research_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	research_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	research_content_wrap = research_scroll

	research_content = VBoxContainer.new()
	research_content.visible = false
	research_content.add_theme_constant_override("separation", 6)
	var r_title := _make_lbl("RESEARCH PROJECTS", 13, TEXT_W)
	research_content.add_child(r_title)
	for key: String in GameConfig.TECHNOLOGIES.keys():
		var tech_key: String = key
		var info: Dictionary = GameConfig.TECHNOLOGIES[tech_key]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _sb(BG_CARD, 8, 8, 8, 8))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_icon_tex("arrow", 20))
		var name_lbl := _make_lbl(String(info.get("name", tech_key.capitalize())), 11, TEXT_W)
		name_lbl.custom_minimum_size = Vector2(136, 0)
		row.add_child(name_lbl)
		var pbar := ProgressBar.new()
		pbar.custom_minimum_size = Vector2(170, 18)
		pbar.min_value = 0
		pbar.max_value = 100
		pbar.show_percentage = false
		research_progress_bars[tech_key] = pbar
		row.add_child(pbar)
		var val_lbl := _make_lbl("0/0", 10, TEXT_COST)
		research_labels[tech_key] = val_lbl
		row.add_child(val_lbl)
		var btn := Button.new()
		btn.text = "RESEARCH"
		btn.custom_minimum_size = Vector2(100, 28)
		_style_upgrade_btn(btn)
		btn.pressed.connect(func():
			ResourceManager.research_technology(tech_key)
			_update_research_panel()
			_update_build_buttons()
		)
		research_buttons[tech_key] = btn
		row.add_child(btn)
		card.add_child(row)
		research_content.add_child(card)
	research_scroll.add_child(research_content)
	vbox.add_child(research_scroll)

	# Upgrade content (embedded)
	var upgrade_scroll := ScrollContainer.new()
	upgrade_scroll.custom_minimum_size = Vector2(0, 126)
	upgrade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrade_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upgrade_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	upgrade_content_wrap = upgrade_scroll

	upgrade_content = VBoxContainer.new()
	upgrade_content.visible = false
	upgrade_content.add_theme_constant_override("separation", 6)
	var u_title := _make_lbl("TOOL UPGRADES", 13, TEXT_W)
	upgrade_content.add_child(u_title)
	var upgrade_grid := GridContainer.new()
	upgrade_grid.columns = 3
	upgrade_grid.add_theme_constant_override("h_separation", 8)
	upgrade_grid.add_theme_constant_override("v_separation", 8)
	var axe_card := _make_upgrade_card("axe", "axe")
	axe_info_lbl = axe_card[0]
	axe_btn = axe_card[1]
	upgrade_grid.add_child(axe_card[2])
	var pick_card := _make_upgrade_card("pickaxe", "pickaxe")
	pick_info_lbl = pick_card[0]
	pick_btn = pick_card[1]
	upgrade_grid.add_child(pick_card[2])
	var sword_card := _make_upgrade_card("sword", "sword")
	sword_info_lbl = sword_card[0]
	sword_btn = sword_card[1]
	upgrade_grid.add_child(sword_card[2])
	upgrade_content.add_child(upgrade_grid)
	upgrade_scroll.add_child(upgrade_content)
	vbox.add_child(upgrade_scroll)

	build_panel.add_child(vbox)
	add_child(build_panel)
	_show_build_tab("build")
	_update_research_panel()
	_update_build_buttons()
	_update_upgrade_buttons()


func _show_build_tab(tab: String) -> void:
	if build_content_wrap:
		build_content_wrap.visible = (tab == "build")
	if evolve_btn:
		evolve_btn.visible = (tab == "build")
	if research_content_wrap:
		research_content_wrap.visible = (tab == "research")
	if research_content:
		research_content.visible = (tab == "research")
	if upgrade_content_wrap:
		upgrade_content_wrap.visible = (tab == "upgrades")
	if upgrade_content:
		upgrade_content.visible = (tab == "upgrades")
	# Style active tab
	var tabs := {"build": build_tab_btn, "research": research_tab_btn, "upgrades": upgrade_tab_btn}
	for key: String in tabs:
		var btn: Button = tabs[key]
		if btn:
			if key == tab:
				_style_upgrade_btn(btn)
			else:
				_style_btn(btn, Color(0.2, 0.2, 0.2, 0.95))


func _make_build_btn(label_text: String, icon_name: String, building_key: String) -> Array:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(186, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _sb(BG_CARD, R_BTN, R_BTN, R_BTN, R_BTN))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	hbox.add_child(_icon_tex(icon_name, 24))

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := _make_lbl(label_text, 11, TEXT_W)
	info_vbox.add_child(name_lbl)

	# Cost label
	var info: Dictionary = GameConfig.BUILDINGS[building_key]
	var cost: Dictionary = info["cost"]
	var cost_parts: Array = []
	if int(cost["wood"]) > 0:
		cost_parts.append("W:%d" % int(cost["wood"]))
	if int(cost["stone"]) > 0:
		cost_parts.append("S:%d" % int(cost["stone"]))
	if int(cost["gold"]) > 0:
		cost_parts.append("G:%d" % int(cost["gold"]))
	var cost_lbl := _make_lbl(" ".join(cost_parts), 9, TEXT_COST)
	info_vbox.add_child(cost_lbl)

	var count_lbl := _make_lbl("x0", 9, TEXT_DIM)
	info_vbox.add_child(count_lbl)

	hbox.add_child(info_vbox)

	var btn := Button.new()
	btn.text = "BUILD"
	btn.custom_minimum_size = Vector2(56, 26)
	btn.add_theme_font_size_override("font_size", 10)
	_style_build_btn_3d(btn)
	btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		if building_manager:
			building_manager.try_place(building_key)
	)
	hbox.add_child(btn)

	card.add_child(hbox)
	return [btn, count_lbl, card]


func _on_evolve_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	if building_manager:
		building_manager.try_evolve()


func _update_build_buttons() -> void:
	if not building_manager:
		return

	# Evolve button
	if evolve_btn:
		var next: Variant = building_manager.get_next_requirements()
		if next == null:
			evolve_btn.text = "MAX EVOLUTION"
			evolve_btn.disabled = true
			_style_disabled_btn(evolve_btn)
		else:
			var nd: Dictionary = next as Dictionary
			var ok: bool = building_manager.can_evolve()
			if not _is_tutorial_completed():
				ok = false
			evolve_btn.text = "EVOLVE  W:%d S:%d G:%d" % [nd["wood"], nd["stone"], nd["gold"]]
			evolve_btn.disabled = not ok
			if ok:
				_style_accent_btn(evolve_btn)
			else:
				_style_disabled_btn(evolve_btn)

	# Building buttons
	_update_one_build("carpentry", carpentry_btn, carpentry_count_lbl)
	_update_one_build("mining_house", mining_btn, mining_count_lbl)
	_update_one_build("army_base", army_btn, army_count_lbl)
	_update_one_build("healing_hut", healing_btn, healing_count_lbl)
	_update_one_build("forester_lodge", forester_lodge_btn, forester_lodge_count_lbl)
	_update_one_build("training_grounds", training_grounds_btn, training_grounds_count_lbl)
	_update_one_build("armory", armory_btn, armory_count_lbl)
	_update_one_build("mine", mine_btn, mine_count_lbl)
	_update_one_build("watch_tower", watch_tower_btn, watch_tower_count_lbl)
	_update_one_build("ballista_tower", ballista_tower_btn, ballista_tower_count_lbl)
	_update_one_build("trap", trap_btn, trap_count_lbl)
	_update_one_build("barricade", barricade_btn, barricade_count_lbl)


func _update_one_build(key: String, btn: Button, count_lbl: Label) -> void:
	if not btn or not count_lbl or not building_manager:
		return
	var info: Dictionary = GameConfig.BUILDINGS[key]
	var cost: Dictionary = info["cost"]
	var card: Control = null
	if build_cards.has(key):
		card = build_cards[key]
	if not building_manager.is_unlocked(key):
		if card:
			card.visible = false
		btn.disabled = true
		btn.text = "LOCKED"
		_style_disabled_btn(btn)
		count_lbl.text = ""
		return
	if card:
		card.visible = true
	if not _is_build_allowed_by_tutorial(key):
		btn.disabled = true
		btn.text = "WAIT"
		_style_disabled_btn(btn)
		return
	btn.text = "BUILD"
	var ok: bool = building_manager.can_place(key)
	btn.disabled = not ok
	if ok:
		_style_build_btn_3d(btn)
	else:
		_style_disabled_btn(btn)
	var cnt: int = building_manager.get_placed_count(key)
	count_lbl.text = "x%d" % cnt


# ╔══════════════════════════════════════════════════════════╗
# ║  TUTORIAL — step-by-step guide at top center              ║
# ╚══════════════════════════════════════════════════════════╝

const TUTORIAL_STEPS: Array = [
	"Step 1: Build a CARPENTRY to get Lumberjacks chopping wood!",
	"Step 2: Wait for wood, then build a MINING HOUSE for miners!",
	"Step 3: Now build an ARMY BASE to get defenders!",
	"",
]

func _build_tutorial() -> void:
	# Replaced with unified left panel.
	return

	tutorial_toggle_btn = Button.new()
	tutorial_toggle_btn.anchor_left = 0.0
	tutorial_toggle_btn.anchor_right = 0.0
	tutorial_toggle_btn.anchor_top = 0.0
	tutorial_toggle_btn.anchor_bottom = 0.0
	tutorial_toggle_btn.offset_left = 8
	tutorial_toggle_btn.offset_right = 126
	tutorial_toggle_btn.offset_top = 62
	tutorial_toggle_btn.offset_bottom = 92
	tutorial_toggle_btn.text = "QUEST LOG"
	tutorial_toggle_btn.add_theme_font_size_override("font_size", 10)
	_style_btn(tutorial_toggle_btn, Color(0.18, 0.22, 0.18, 0.95))
	tutorial_toggle_btn.pressed.connect(func():
		tutorial_visible = not tutorial_visible
		if tutorial_panel:
			tutorial_panel.visible = tutorial_visible
	)
	add_child(tutorial_toggle_btn)

	tutorial_panel = PanelContainer.new()
	tutorial_panel.name = "Tutorial"
	tutorial_panel.anchor_left = 0.0
	tutorial_panel.anchor_right = 0.0
	tutorial_panel.anchor_top = 0.0
	tutorial_panel.anchor_bottom = 0.0
	tutorial_panel.offset_left = 8
	tutorial_panel.offset_right = 320
	tutorial_panel.offset_top = 96
	tutorial_panel.offset_bottom = 138
	tutorial_panel.add_theme_stylebox_override("panel", _sb(Color(0.12, 0.10, 0.08, 0.92), R, R, R, R))

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 8)

	var arrow := _make_lbl(">>>", 12, ACCENT)
	hbox.add_child(arrow)

	tutorial_lbl = _make_lbl(TUTORIAL_STEPS[0], 12, TEXT_W)
	tutorial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tutorial_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tutorial_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(tutorial_lbl)

	tutorial_panel.add_child(hbox)
	add_child(tutorial_panel)


func _advance_tutorial(building_key: String) -> void:
	if tutorial_step >= 3:
		return
	match tutorial_step:
		0:
			if building_key == "carpentry":
				tutorial_step = 1
		1:
			if building_key == "mining_house":
				tutorial_step = 2
		2:
			if building_key == "army_base":
				tutorial_step = 3
	_update_tutorial()


func _update_tutorial() -> void:
	if not tutorial_panel or not tutorial_lbl:
		return
	if tutorial_step >= 3:
		# Tutorial complete — fade out
		tutorial_lbl.text = "Tutorial complete! You're ready!"
		tutorial_lbl.add_theme_color_override("font_color", C_GREEN)
		var tween := tutorial_panel.create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(tutorial_panel, "modulate:a", 0.0, 1.0)
		tween.tween_callback(tutorial_panel.queue_free)
	else:
		tutorial_lbl.text = TUTORIAL_STEPS[tutorial_step]


func _is_tutorial_completed() -> bool:
	return tutorial_step >= 3


func is_tutorial_completed() -> bool:
	return _is_tutorial_completed()


func get_tutorial_step() -> int:
	return tutorial_step


func set_tutorial_step(step: int) -> void:
	tutorial_step = clampi(step, 0, 3)
	_update_tutorial()
	_update_build_buttons()


func sync_tutorial_from_buildings(placed: Dictionary) -> void:
	if int(placed.get("army_base", 0)) > 0:
		tutorial_step = 3
	elif int(placed.get("mining_house", 0)) > 0:
		tutorial_step = 2
	elif int(placed.get("carpentry", 0)) > 0:
		tutorial_step = 1
	else:
		tutorial_step = 0
	_update_tutorial()
	_update_build_buttons()


func _is_build_allowed_by_tutorial(building_key: String) -> bool:
	if tutorial_step >= 3:
		return true
	match tutorial_step:
		0:
			return building_key == "carpentry"
		1:
			return building_key == "mining_house"
		2:
			return building_key == "army_base"
	return true


func _build_minimap() -> void:
	var wrap := Control.new()
	wrap.name = "MiniMapWrap"
	minimap_wrap = wrap
	wrap.anchor_left = 1.0
	wrap.anchor_right = 1.0
	wrap.anchor_top = 0.0
	wrap.anchor_bottom = 0.0
	wrap.offset_left = -170
	wrap.offset_right = -12
	wrap.offset_top = 58
	wrap.offset_bottom = 216

	minimap = Control.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap.connect("draw", _draw_minimap)
	wrap.add_child(minimap)
	add_child(wrap)


func _build_corner_hammer() -> void:
	var frame := PanelContainer.new()
	frame.name = "HammerCorner"
	hammer_corner = frame
	frame.anchor_left = 0.0
	frame.anchor_right = 0.0
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 8
	frame.offset_right = 84
	frame.offset_top = -86
	frame.offset_bottom = -10
	frame.add_theme_stylebox_override("panel", _sb(BG_PANEL, 10, 10, 10, 10))
	var icon := _icon_tex("d_hammer", 46)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.add_child(icon)
	add_child(frame)


func setup_minimap(ms: Dictionary) -> void:
	if ms.has("ground_data"):
		minimap_ground = ms["ground_data"]


func update_minimap_entities(center_pos: Vector2, threat_positions: Array) -> void:
	minimap_center_pos = center_pos
	minimap_threats = threat_positions
	if minimap:
		minimap.queue_redraw()


func _draw_minimap() -> void:
	if not minimap or minimap_ground.is_empty():
		return
	var size := minimap.size
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 2.0
	minimap.draw_circle(center, radius, Color(0.05, 0.06, 0.08, 0.96))

	var h: int = minimap_ground.size()
	if h <= 0:
		return
	var w: int = (minimap_ground[0] as Array).size()
	if w <= 0:
		return

	for y in range(h):
		for x in range(w):
			var tx := (float(x) / float(maxi(w - 1, 1))) * size.x
			var ty := (float(y) / float(maxi(h - 1, 1))) * size.y
			var p := Vector2(tx, ty)
			if p.distance_to(center) > radius:
				continue
			var t: int = int(minimap_ground[y][x])
			var c := Color(0.16, 0.31, 0.52, 0.75)
			if t == GameConfig.TileType.SAND:
				c = Color(0.78, 0.70, 0.50, 0.90)
			elif t == GameConfig.TileType.DIRT:
				c = Color(0.44, 0.35, 0.25, 0.90)
			elif t == GameConfig.TileType.GRASS:
				c = Color(0.26, 0.46, 0.24, 0.90)
			minimap.draw_rect(Rect2(p, Vector2(1.0, 1.0)), c)

	var ww := float(GameConfig.MAP_WIDTH * GameConfig.TILE_SIZE)
	var wh := float(GameConfig.MAP_HEIGHT * GameConfig.TILE_SIZE)
	if ww > 0.0 and wh > 0.0:
		var bp := Vector2(minimap_center_pos.x / ww * size.x, minimap_center_pos.y / wh * size.y)
		if bp.distance_to(center) <= radius:
			minimap.draw_circle(bp, 2.7, Color(1.0, 0.95, 0.2, 1.0))

		for tp: Vector2 in minimap_threats:
			var ep := Vector2(tp.x / ww * size.x, tp.y / wh * size.y)
			if ep.distance_to(center) <= radius:
				minimap.draw_circle(ep, 2.0, Color(0.95, 0.22, 0.22, 0.92))

	minimap.draw_arc(center, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.10), 1.2)


func _build_call_to_arms() -> void:
	# Replaced with unified left panel.
	return

	var btn := Button.new()
	btn.name = "CallToArms"
	btn.anchor_left = 0.0
	btn.anchor_right = 0.0
	btn.anchor_top = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left = 8
	btn.offset_right = 126
	btn.offset_top = 144
	btn.offset_bottom = 180
	btn.text = "CALL TO ARMS"
	btn.add_theme_font_size_override("font_size", 10)
	_style_btn(btn, Color(0.58, 0.20, 0.16, 0.95))
	btn.pressed.connect(func(): call_to_arms_requested.emit())
	add_child(btn)

	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 0.0
	row.anchor_top = 0.0
	row.anchor_bottom = 0.0
	row.offset_left = 8
	row.offset_right = 214
	row.offset_top = 186
	row.offset_bottom = 214
	row.add_theme_constant_override("separation", 4)

	var guard_btn := Button.new()
	guard_btn.text = "GUARD"
	guard_btn.custom_minimum_size = Vector2(64, 26)
	_style_btn(guard_btn, Color(0.52, 0.22, 0.22, 0.95))
	guard_btn.add_theme_font_size_override("font_size", 9)
	guard_btn.pressed.connect(func(): promote_requested.emit(GameConfig.Role.DEFENDER))
	row.add_child(guard_btn)

	var builder_btn := Button.new()
	builder_btn.text = "BUILDER"
	builder_btn.custom_minimum_size = Vector2(68, 26)
	_style_btn(builder_btn, Color(0.52, 0.33, 0.18, 0.95))
	builder_btn.add_theme_font_size_override("font_size", 9)
	builder_btn.pressed.connect(func(): promote_requested.emit(GameConfig.Role.BUILDER))
	row.add_child(builder_btn)

	var scholar_btn := Button.new()
	scholar_btn.text = "SCHOLAR"
	scholar_btn.custom_minimum_size = Vector2(68, 26)
	_style_btn(scholar_btn, Color(0.35, 0.22, 0.52, 0.95))
	scholar_btn.add_theme_font_size_override("font_size", 9)
	scholar_btn.pressed.connect(func(): promote_requested.emit(GameConfig.Role.SCHOLAR))
	row.add_child(scholar_btn)

	add_child(row)

	var repair_btn := Button.new()
	repair_btn.anchor_left = 0.0
	repair_btn.anchor_right = 0.0
	repair_btn.anchor_top = 0.0
	repair_btn.anchor_bottom = 0.0
	repair_btn.offset_left = 8
	repair_btn.offset_right = 126
	repair_btn.offset_top = 218
	repair_btn.offset_bottom = 250
	repair_btn.text = "EMERGENCY REPAIR"
	repair_btn.add_theme_font_size_override("font_size", 9)
	_style_btn(repair_btn, Color(0.20, 0.42, 0.22, 0.95))
	repair_btn.pressed.connect(func(): emergency_repair_requested.emit())
	add_child(repair_btn)

	wave_warn_lbl = _make_lbl("", 12, Color(1.0, 0.3, 0.3))
	wave_warn_lbl.visible = false
	wave_warn_lbl.z_index = 200
	add_child(wave_warn_lbl)


func _on_research_changed(_points: int) -> void:
	update_resources()
	_update_build_buttons()
	_update_research_panel()


func _build_research_panel() -> void:
	# Replaced with tabbed build panel research tab.
	return

	research_toggle_btn = Button.new()
	research_toggle_btn.anchor_left = 1.0
	research_toggle_btn.anchor_right = 1.0
	research_toggle_btn.anchor_top = 0.0
	research_toggle_btn.anchor_bottom = 0.0
	research_toggle_btn.offset_left = -126
	research_toggle_btn.offset_right = -8
	research_toggle_btn.offset_top = 62
	research_toggle_btn.offset_bottom = 92
	research_toggle_btn.text = "RESEARCH"
	research_toggle_btn.add_theme_font_size_override("font_size", 10)
	_style_btn(research_toggle_btn, Color(0.24, 0.20, 0.30, 0.95))
	research_toggle_btn.pressed.connect(func():
		if research_panel:
			research_panel.visible = not research_panel.visible
	)
	add_child(research_toggle_btn)

	research_panel = PanelContainer.new()
	research_panel.anchor_left = 1.0
	research_panel.anchor_right = 1.0
	research_panel.anchor_top = 0.0
	research_panel.anchor_bottom = 0.0
	research_panel.offset_left = -300
	research_panel.offset_right = -8
	research_panel.offset_top = 96
	research_panel.offset_bottom = 204
	research_panel.add_theme_stylebox_override("panel", _sb(BG_PANEL, R, R, R, R))
	research_panel.visible = false

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var title := _make_lbl("RESEARCH UNLOCKS", 12, TEXT_W)
	vb.add_child(title)

	for key: String in GameConfig.TECHNOLOGIES.keys():
		var tech_key: String = key
		var info: Dictionary = GameConfig.TECHNOLOGIES[tech_key]
		var req: int = int(info.get("cost", 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_lbl := _make_lbl(String(info.get("name", key.capitalize())), 10, TEXT_DIM)
		name_lbl.custom_minimum_size = Vector2(100, 0)
		row.add_child(name_lbl)
		var val_lbl := _make_lbl("0 / %d" % req, 10, TEXT_COST)
		research_labels[tech_key] = val_lbl
		row.add_child(val_lbl)
		var btn := Button.new()
		btn.text = "RESEARCH"
		btn.custom_minimum_size = Vector2(74, 24)
		btn.add_theme_font_size_override("font_size", 9)
		_style_upgrade_btn(btn)
		btn.pressed.connect(func():
			ResourceManager.research_technology(tech_key)
			_update_research_panel()
			_update_build_buttons()
		)
		research_buttons[tech_key] = btn
		row.add_child(btn)
		vb.add_child(row)

	research_panel.add_child(vb)
	add_child(research_panel)
	_update_research_panel()


func _update_research_panel() -> void:
	if research_labels.is_empty():
		return
	var points: int = ResourceManager.get_research_points()
	for key: String in research_labels.keys():
		var lbl: Label = research_labels[key]
		var info: Dictionary = GameConfig.TECHNOLOGIES.get(key, {})
		var req: int = int(info.get("cost", 0))
		var btn: Button = research_buttons.get(key, null)
		if req <= 0:
			continue
		var pbar: ProgressBar = research_progress_bars.get(key, null)
		if pbar:
			pbar.value = clampf(float(points) / float(req) * 100.0, 0.0, 100.0)
		var researched := ResourceManager.has_technology(key)
		if researched:
			lbl.text = "RESEARCHED"
			lbl.add_theme_color_override("font_color", C_GREEN)
			if btn:
				btn.disabled = true
				btn.text = "DONE"
				_style_disabled_btn(btn)
		else:
			var prereq: Array = info.get("requires", [])
			var prereq_ok := true
			for p: String in prereq:
				if not ResourceManager.has_technology(p):
					prereq_ok = false
					break
			lbl.text = "%d / %d" % [points, req]
			lbl.add_theme_color_override("font_color", TEXT_COST)
			if btn:
				btn.disabled = not (prereq_ok and points >= req)
				btn.text = "RESEARCH"
				if btn.disabled:
					_style_disabled_btn(btn)
				else:
					_style_upgrade_btn(btn)


func _on_tech_researched(_tech_key: String) -> void:
	_update_research_panel()
	_update_build_buttons()

func show_wave_warning(camera_pos: Vector2, spawn_pos: Vector2) -> void:
	if not wave_warn_lbl:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var dir := (spawn_pos - camera_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var edge := vp_size * 0.5 + dir * Vector2(vp_size.x * 0.35, vp_size.y * 0.28)

	var arrow := "!"
	if absf(dir.x) > absf(dir.y):
		arrow = ">>>" if dir.x > 0.0 else "<<<"
	else:
		arrow = "VVV" if dir.y > 0.0 else "^^^"

	wave_warn_lbl.text = "WAVE INCOMING " + arrow
	wave_warn_lbl.position = edge
	wave_warn_lbl.visible = true
	wave_warn_lbl.modulate = Color(1, 1, 1, 1)

	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(wave_warn_lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func():
		if wave_warn_lbl:
			wave_warn_lbl.visible = false
	)


# ╔══════════════════════════════════════════════════════════╗
# ║  UPGRADE PANEL — right side with close X                 ║
# ╚══════════════════════════════════════════════════════════╝

func _build_upgrade_toggle() -> void:
	return  # Upgrades now in bottom panel tabs
	upgrade_toggle_btn = Button.new()
	upgrade_toggle_btn.name = "UpgToggle"
	upgrade_toggle_btn.anchor_left = 1.0
	upgrade_toggle_btn.anchor_right = 1.0
	upgrade_toggle_btn.anchor_top = 0.5
	upgrade_toggle_btn.offset_left = -52
	upgrade_toggle_btn.offset_right = -8
	upgrade_toggle_btn.offset_top = -22
	upgrade_toggle_btn.offset_bottom = 22
	_style_circle_btn(upgrade_toggle_btn, BG_BTN)

	upgrade_toggle_btn.icon = icons.get("d_hammer", null)
	upgrade_toggle_btn.text = ""
	upgrade_toggle_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_toggle_btn.expand_icon = true

	upgrade_toggle_btn.pressed.connect(_toggle_upgrades)
	add_child(upgrade_toggle_btn)


func _toggle_upgrades() -> void:
	upgrade_visible = not upgrade_visible
	if upgrade_panel:
		upgrade_panel.visible = upgrade_visible


func _build_upgrade_panel() -> void:
	return  # Upgrades now in bottom panel tabs
	upgrade_panel = PanelContainer.new()
	upgrade_panel.name = "UpgradePanel"
	upgrade_panel.anchor_left = 1.0
	upgrade_panel.anchor_right = 1.0
	upgrade_panel.offset_left = -310
	upgrade_panel.offset_top = 56
	upgrade_panel.offset_right = -6
	upgrade_panel.add_theme_stylebox_override("panel", _sb(BG_PANEL, R, R, R, R))
	upgrade_panel.visible = false

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)

	# Header with close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)

	var title := _make_lbl("UPGRADES", 16, TEXT_W)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(30, 30)
	_style_btn(close_btn, Color(0.4, 0.2, 0.2, 0.8))
	if icons.has("close_x"):
		close_btn.icon = icons["close_x"]
		close_btn.text = ""
		close_btn.expand_icon = true
	else:
		close_btn.text = "X"
	close_btn.pressed.connect(_toggle_upgrades)
	header.add_child(close_btn)

	main_vbox.add_child(header)

	# 2-column grid of upgrade cards
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	var axe_card := _make_upgrade_card("axe", "axe")
	axe_info_lbl = axe_card[0]
	axe_btn = axe_card[1]
	grid.add_child(axe_card[2])

	var pick_card := _make_upgrade_card("pickaxe", "pickaxe")
	pick_info_lbl = pick_card[0]
	pick_btn = pick_card[1]
	grid.add_child(pick_card[2])

	var sword_card := _make_upgrade_card("sword", "sword")
	sword_info_lbl = sword_card[0]
	sword_btn = sword_card[1]
	grid.add_child(sword_card[2])

	main_vbox.add_child(grid)
	upgrade_panel.add_child(main_vbox)
	add_child(upgrade_panel)
	_update_upgrade_buttons()


func _make_upgrade_card(icon_name: String, tool_type: String) -> Array:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _sb(BG_CARD, R_BTN, R_BTN, R_BTN, R_BTN))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Icon + name row
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	top_row.add_child(_icon_tex(icon_name, ICON_SIZE_UPGRADE))

	var info := Label.new()
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", TEXT_W)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(info)

	vbox.add_child(top_row)

	# Upgrade button
	var btn := Button.new()
	btn.text = "UPGRADE"
	btn.custom_minimum_size = Vector2(0, 30)
	btn.add_theme_font_size_override("font_size", 10)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_upgrade_btn(btn)
	btn.pressed.connect(func():
		ResourceManager.try_upgrade_tool(tool_type)
		_update_upgrade_buttons()
	)
	vbox.add_child(btn)

	card.add_child(vbox)
	return [info, btn, card]


# ╔══════════════════════════════════════════════════════════╗
# ║  SETTINGS PANEL — gear icon top-right                    ║
# ╚══════════════════════════════════════════════════════════╝

func _build_settings_toggle() -> void:
	return  # Settings gear now in top bar
	settings_toggle_btn = Button.new()
	settings_toggle_btn.name = "SettingsToggle"
	settings_toggle_btn.anchor_left = 1.0
	settings_toggle_btn.anchor_right = 1.0
	settings_toggle_btn.anchor_top = 0.0
	settings_toggle_btn.offset_left = -52
	settings_toggle_btn.offset_right = -8
	settings_toggle_btn.offset_top = 62
	settings_toggle_btn.offset_bottom = 106
	_style_circle_btn(settings_toggle_btn, BG_BTN)

	settings_toggle_btn.text = "\u2699"
	settings_toggle_btn.add_theme_font_size_override("font_size", 24)

	settings_toggle_btn.pressed.connect(_toggle_settings)
	add_child(settings_toggle_btn)


func _toggle_settings() -> void:
	AudioManager.play_sfx("ui_click")
	settings_visible = not settings_visible
	if settings_panel:
		settings_panel.visible = settings_visible


func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.anchor_left = 0.5
	settings_panel.anchor_right = 0.5
	settings_panel.anchor_top = 0.5
	settings_panel.anchor_bottom = 0.5
	settings_panel.offset_left = -150
	settings_panel.offset_right = 150
	settings_panel.offset_top = -140
	settings_panel.offset_bottom = 140
	settings_panel.add_theme_stylebox_override("panel", _sb(BG_PANEL, R, R, R, R))
	settings_panel.visible = false

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)

	# Title
	var title := _make_lbl("SETTINGS", 20, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Music toggle
	var music_row := HBoxContainer.new()
	music_row.alignment = BoxContainer.ALIGNMENT_CENTER
	music_row.add_theme_constant_override("separation", 8)
	var music_lbl := _make_lbl("Music", 14, TEXT_W)
	music_row.add_child(music_lbl)
	music_toggle_btn = Button.new()
	music_toggle_btn.text = "ON"
	music_toggle_btn.custom_minimum_size = Vector2(70, 30)
	music_toggle_btn.add_theme_font_size_override("font_size", 12)
	_style_upgrade_btn(music_toggle_btn)
	music_toggle_btn.pressed.connect(_on_music_toggle)
	music_row.add_child(music_toggle_btn)
	vbox.add_child(music_row)

	# SFX toggle
	var sfx_row := HBoxContainer.new()
	sfx_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sfx_row.add_theme_constant_override("separation", 8)
	var sfx_lbl := _make_lbl("SFX", 14, TEXT_W)
	sfx_row.add_child(sfx_lbl)
	sfx_toggle_btn = Button.new()
	sfx_toggle_btn.text = "ON"
	sfx_toggle_btn.custom_minimum_size = Vector2(70, 30)
	sfx_toggle_btn.add_theme_font_size_override("font_size", 12)
	_style_upgrade_btn(sfx_toggle_btn)
	sfx_toggle_btn.pressed.connect(_on_sfx_toggle)
	sfx_row.add_child(sfx_toggle_btn)
	vbox.add_child(sfx_row)

	vbox.add_child(_spacer(4))

	# Save button
	var save_btn := Button.new()
	save_btn.text = "SAVE GAME"
	save_btn.custom_minimum_size = Vector2(200, 36)
	save_btn.add_theme_font_size_override("font_size", 13)
	_style_accent_btn(save_btn)
	save_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		save_requested.emit()
	)
	vbox.add_child(save_btn)

	# Restart button
	var restart_btn := Button.new()
	restart_btn.text = "RESTART"
	restart_btn.custom_minimum_size = Vector2(200, 36)
	restart_btn.add_theme_font_size_override("font_size", 13)
	_style_btn(restart_btn, Color(0.6, 0.2, 0.2))
	restart_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		restart_requested.emit()
	)
	vbox.add_child(restart_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(200, 30)
	close_btn.add_theme_font_size_override("font_size", 11)
	_style_btn(close_btn, Color(0.3, 0.3, 0.3))
	close_btn.pressed.connect(_toggle_settings)
	vbox.add_child(close_btn)

	settings_panel.add_child(vbox)
	add_child(settings_panel)


func _on_music_toggle() -> void:
	AudioManager.play_sfx("ui_click")
	var enabled := not AudioManager.music_enabled
	AudioManager.set_music_enabled(enabled)
	if music_toggle_btn:
		music_toggle_btn.text = "ON" if enabled else "OFF"
		if enabled:
			_style_upgrade_btn(music_toggle_btn)
		else:
			_style_btn(music_toggle_btn, Color(0.4, 0.2, 0.2))


func _on_sfx_toggle() -> void:
	var enabled := not AudioManager.sfx_enabled
	AudioManager.set_sfx_enabled(enabled)
	if sfx_toggle_btn:
		sfx_toggle_btn.text = "ON" if enabled else "OFF"
		if enabled:
			_style_upgrade_btn(sfx_toggle_btn)
		else:
			_style_btn(sfx_toggle_btn, Color(0.4, 0.2, 0.2))


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var portrait := vp_size.y > vp_size.x

	if top_bar:
		top_bar.offset_bottom = 64 if portrait else 52

	if left_panel:
		if portrait:
			var panel_w := clampf(vp_size.x * 0.56, 190.0, 320.0)
			left_panel.offset_left = 6
			left_panel.offset_right = 6 + panel_w
			left_panel.offset_top = 72
			left_panel.offset_bottom = -252
		else:
			left_panel.offset_left = 6
			left_panel.offset_right = 256
			left_panel.offset_top = 62
			left_panel.offset_bottom = -228

	if build_panel:
		if portrait:
			build_panel.offset_left = 8
			build_panel.offset_right = -8
			build_panel.offset_top = -246
			build_panel.offset_bottom = -8
		else:
			build_panel.offset_left = 268
			build_panel.offset_right = -184
			build_panel.offset_top = -196
			build_panel.offset_bottom = -10

	if build_cards_grid:
		build_cards_grid.columns = 1 if portrait else 2

	if minimap_wrap:
		if portrait:
			minimap_wrap.offset_left = -146
			minimap_wrap.offset_right = -8
			minimap_wrap.offset_top = 72
			minimap_wrap.offset_bottom = 210
		else:
			minimap_wrap.offset_left = -170
			minimap_wrap.offset_right = -12
			minimap_wrap.offset_top = 58
			minimap_wrap.offset_bottom = 216

	if hammer_corner:
		if portrait:
			hammer_corner.offset_left = 8
			hammer_corner.offset_right = 84
			hammer_corner.offset_top = -170
			hammer_corner.offset_bottom = -94
		else:
			hammer_corner.offset_left = 8
			hammer_corner.offset_right = 84
			hammer_corner.offset_top = -86
			hammer_corner.offset_bottom = -10


# ╔══════════════════════════════════════════════════════════╗
# ║  GAME OVER                                               ║
# ╚══════════════════════════════════════════════════════════╝

func show_game_over() -> void:
	if game_over_panel:
		return

	game_over_panel = Control.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.add_child(overlay)

	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -170
	card.offset_right = 170
	card.offset_top = -120
	card.offset_bottom = 120
	card.add_theme_stylebox_override("panel", _sb(BG_PANEL, 20, 20, 20, 20))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)

	# Skull icon
	var skull := _icon_tex("skull", 64)
	skull.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(skull)

	var title := _make_lbl("GAME OVER", 28, C_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := _make_lbl("Your cabin has been destroyed!", 13, TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var restart_btn := Button.new()
	restart_btn.text = "PLAY AGAIN"
	restart_btn.custom_minimum_size = Vector2(190, 46)
	_style_upgrade_btn(restart_btn)
	restart_btn.add_theme_font_size_override("font_size", 16)
	restart_btn.pressed.connect(func(): restart_requested.emit())
	vbox.add_child(restart_btn)

	card.add_child(vbox)
	game_over_panel.add_child(card)
	add_child(game_over_panel)


# ╔══════════════════════════════════════════════════════════╗
# ║  UPDATE METHODS                                          ║
# ╚══════════════════════════════════════════════════════════╝

func update_resources() -> void:
	var res := ResourceManager.get_all()
	if res_wood_lbl: res_wood_lbl.text = str(res["wood"])
	if res_stone_lbl: res_stone_lbl.text = str(res["stone"])
	if res_gold_lbl: res_gold_lbl.text = str(res["gold"])
	if res_research_lbl: res_research_lbl.text = "RP %d" % int(res.get("research", 0))
	# Per-minute rates
	_update_rate_lbl(rate_wood_lbl, "wood")
	_update_rate_lbl(rate_stone_lbl, "stone")
	_update_rate_lbl(rate_gold_lbl, "gold")


func _update_rate_lbl(lbl: Label, type: String) -> void:
	if not lbl:
		return
	var rate := ResourceManager.get_rate(type)
	if rate > 0.0:
		lbl.text = "+%d/min" % int(rate)
		lbl.add_theme_color_override("font_color", C_GREEN)
	else:
		lbl.text = ""


func update_tasks() -> void:
	if pie_chart:
		pie_chart.queue_redraw()


func set_hide_mode(active: bool) -> void:
	if not left_call_btn:
		return
	left_call_btn.text = "UNHIDE" if active else "HIDE"


func _role_name(role_key: int) -> String:
	match role_key:
		GameConfig.Role.IDLE:
			return "Idle"
		GameConfig.Role.DEFENDER:
			return "Defender"
		GameConfig.Role.BUILDER:
			return "Builder"
		GameConfig.Role.SCHOLAR:
			return "Scholar"
		GameConfig.Role.FORESTER:
			return "Forester"
		GameConfig.Role.LUMBERJACK:
			return "Lumberjack"
		GameConfig.Role.MINER:
			return "Miner"
	return "Unknown"


func set_selected_villager_info(data: Dictionary) -> void:
	if not selected_villager_lbl:
		return
	if data.is_empty():
		selected_villager_lbl.text = "SELECT A VILLAGER TO VIEW EXPERTISE"
		selected_villager_lbl.add_theme_color_override("font_color", TEXT_DIM)
		return
	var role_key := int(data.get("role", GameConfig.Role.IDLE))
	var level := int(data.get("level", 0))
	var hp := int(data.get("hp", 0))
	var max_hp := int(data.get("max_hp", 0))
	var gather_bonus := float(data.get("gather_bonus_pct", 0.0))
	var hp_bonus := float(data.get("hp_bonus_pct", 0.0))
	var bonus_line := "No active expertise bonus"
	if gather_bonus > 0.0:
		bonus_line = "+%d%% gather speed" % int(round(gather_bonus))
	elif hp_bonus > 0.0:
		bonus_line = "+%d%% max HP" % int(round(hp_bonus))
	selected_villager_lbl.text = "SELECTED: %s\nEXPERTISE LV %d\nBONUS: %s\nHP: %d/%d" % [
		_role_name(role_key),
		level,
		bonus_line,
		hp,
		max_hp,
	]
	selected_villager_lbl.add_theme_color_override("font_color", TEXT_W)


func set_selected_building_info(data: Dictionary) -> void:
	if not selected_building_lbl or not selected_building_upgrade_btn:
		return
	if data.is_empty():
		selected_building_lbl.text = "SELECT A BUILDING TO LEVEL IT"
		selected_building_lbl.add_theme_color_override("font_color", TEXT_DIM)
		selected_building_upgrade_btn.disabled = true
		selected_building_upgrade_btn.text = "UPGRADE"
		_style_disabled_btn(selected_building_upgrade_btn)
		return
	var name := String(data.get("name", "Building"))
	var level := int(data.get("level", 1))
	var max_allowed := int(data.get("max_allowed", 1))
	var hp := int(data.get("hp", 0))
	var max_hp := int(data.get("max_hp", 0))
	var bonus := String(data.get("bonus", ""))
	selected_building_lbl.text = "%s\nLEVEL %d / %d\nHP: %d/%d\nBONUS: %s" % [
		name,
		level,
		max_allowed,
		hp,
		max_hp,
		bonus,
	]
	selected_building_lbl.add_theme_color_override("font_color", TEXT_W)
	var can_upgrade := bool(data.get("can_upgrade", false))
	var cost_txt := String(data.get("cost_text", ""))
	selected_building_upgrade_btn.disabled = not can_upgrade
	if can_upgrade:
		selected_building_upgrade_btn.text = "UPGRADE " + cost_txt
		_style_upgrade_btn(selected_building_upgrade_btn)
	else:
		selected_building_upgrade_btn.text = "UPGRADE " + cost_txt if cost_txt != "" else "UPGRADE"
		_style_disabled_btn(selected_building_upgrade_btn)


func update_building() -> void:
	if not building_manager:
		return
	if stage_lbl:
		stage_lbl.text = building_manager.get_stage_name()
	_update_build_buttons()
	_update_research_panel()
	_update_upgrade_buttons()


func update_cabin_hp(current: int, maximum: int) -> void:
	if hp_bar_fill:
		var ratio := clampf(float(current) / float(maximum), 0.0, 1.0)
		hp_bar_fill.anchor_right = ratio
		if ratio > 0.5:
			hp_bar_fill.color = C_GREEN
		elif ratio > 0.25:
			hp_bar_fill.color = Color(0.90, 0.65, 0.15)
		else:
			hp_bar_fill.color = C_RED
	if hp_label:
		hp_label.text = "%d/%d" % [current, maximum]


func update_population(count: int) -> void:
	if pop_lbl:
		pop_lbl.text = str(count)
		pop_lbl.add_theme_color_override("font_color", C_RED if count <= 2 else TEXT_W)


func update_wave(wave: int) -> void:
	if wave_lbl:
		wave_lbl.text = str(wave)


func _update_upgrade_buttons() -> void:
	_update_one_upgrade("axe", axe_info_lbl, axe_btn)
	_update_one_upgrade("pickaxe", pick_info_lbl, pick_btn)
	_update_one_upgrade("sword", sword_info_lbl, sword_btn)


func _update_one_upgrade(tool_type: String, info_label: Label, btn: Button) -> void:
	if not info_label or not btn:
		return
	var info: Dictionary = ResourceManager.get_tool_info(tool_type)
	info_label.text = info["name"]

	var next: Dictionary = ResourceManager.get_next_tool_info(tool_type)
	if next.is_empty():
		btn.text = "MAX"
		btn.disabled = true
		_style_disabled_btn(btn)
	else:
		var cost: Dictionary = next["cost"]
		var ok := ResourceManager.can_afford(cost)
		var need_armory: bool = tool_type == "sword" and building_manager and not building_manager.has_armory()
		if need_armory:
			ok = false
		if need_armory:
			btn.text = "UPGRADE\nREQUIRES ARMORY"
		else:
			btn.text = "UPGRADE\nCOST: %dW, %dS, %dG" % [cost["wood"], cost["stone"], cost["gold"]]
		btn.disabled = not ok
		if ok:
			_style_upgrade_btn(btn)
		else:
			_style_disabled_btn(btn)


# ╔══════════════════════════════════════════════════════════╗
# ║  STYLE HELPERS                                           ║
# ╚══════════════════════════════════════════════════════════╝

func _sb(bg: Color, tl: int = R, tr: int = R, bl: int = R, br: int = R) -> StyleBox:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = tl
	s.corner_radius_top_right = tr
	s.corner_radius_bottom_left = bl
	s.corner_radius_bottom_right = br
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.45, 0.38, 0.28, 0.7)
	return s


func _style_btn(btn: Button, bg: Color) -> void:
	for sn: String in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = R_BTN
		sb.corner_radius_top_right = R_BTN
		sb.corner_radius_bottom_left = R_BTN
		sb.corner_radius_bottom_right = R_BTN
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.50, 0.42, 0.30, 0.7)
		match sn:
			"normal": sb.bg_color = bg
			"hover": sb.bg_color = bg.lightened(0.12)
			"pressed": sb.bg_color = bg.darkened(0.1)
			"disabled": sb.bg_color = bg.darkened(0.3)
		btn.add_theme_stylebox_override(sn, sb)
	btn.add_theme_color_override("font_color", TEXT_W)
	btn.add_theme_color_override("font_hover_color", TEXT_W)
	btn.add_theme_color_override("font_pressed_color", TEXT_W)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)


func _style_circle_btn(btn: Button, bg: Color) -> void:
	for sn: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 22
		sb.corner_radius_top_right = 22
		sb.corner_radius_bottom_left = 22
		sb.corner_radius_bottom_right = 22
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		match sn:
			"normal": sb.bg_color = bg
			"hover": sb.bg_color = bg.lightened(0.15)
			"pressed": sb.bg_color = bg.darkened(0.15)
		btn.add_theme_stylebox_override(sn, sb)
	btn.add_theme_color_override("font_color", TEXT_W)


func _style_upgrade_btn(btn: Button) -> void:
	for sn: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = R_BTN
		sb.corner_radius_top_right = R_BTN
		sb.corner_radius_bottom_left = R_BTN
		sb.corner_radius_bottom_right = R_BTN
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.50, 0.42, 0.30, 0.7)
		match sn:
			"normal": sb.bg_color = BG_BTN
			"hover": sb.bg_color = BG_BTN.lightened(0.12)
			"pressed": sb.bg_color = BG_BTN.darkened(0.12)
		btn.add_theme_stylebox_override(sn, sb)
	btn.add_theme_color_override("font_color", TEXT_COST)
	btn.add_theme_color_override("font_hover_color", TEXT_COST)
	btn.add_theme_color_override("font_pressed_color", TEXT_COST)


func _style_build_btn_3d(btn: Button) -> void:
	for sn: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = R_BTN
		sb.corner_radius_top_right = R_BTN
		sb.corner_radius_bottom_left = R_BTN
		sb.corner_radius_bottom_right = R_BTN
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 2
		sb.border_width_bottom = 3
		if sn == "normal":
			sb.bg_color = Color(0.43, 0.33, 0.20)
			sb.border_color = Color(0.23, 0.17, 0.11, 0.92)
			sb.content_margin_top = 3
			sb.content_margin_bottom = 5
		elif sn == "hover":
			sb.bg_color = Color(0.49, 0.38, 0.24)
			sb.border_color = Color(0.27, 0.20, 0.12, 0.95)
			sb.content_margin_top = 3
			sb.content_margin_bottom = 5
		else:
			sb.bg_color = Color(0.31, 0.24, 0.15)
			sb.border_color = Color(0.20, 0.15, 0.10, 0.95)
			sb.content_margin_top = 6
			sb.content_margin_bottom = 2
		btn.add_theme_stylebox_override(sn, sb)
	btn.add_theme_color_override("font_color", TEXT_COST)
	btn.add_theme_color_override("font_hover_color", TEXT_COST)
	btn.add_theme_color_override("font_pressed_color", TEXT_COST)


func _style_disabled_btn(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	sb.corner_radius_top_left = R_BTN
	sb.corner_radius_top_right = R_BTN
	sb.corner_radius_bottom_left = R_BTN
	sb.corner_radius_bottom_right = R_BTN
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.35, 0.30, 0.22, 0.5)
	btn.add_theme_stylebox_override("disabled", sb)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)


func _style_accent_btn(btn: Button) -> void:
	for sn: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = R_BTN
		sb.corner_radius_top_right = R_BTN
		sb.corner_radius_bottom_left = R_BTN
		sb.corner_radius_bottom_right = R_BTN
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.60, 0.48, 0.18, 0.7)
		match sn:
			"normal": sb.bg_color = ACCENT.darkened(0.3)
			"hover": sb.bg_color = ACCENT.darkened(0.15)
			"pressed": sb.bg_color = ACCENT.darkened(0.45)
		btn.add_theme_stylebox_override(sn, sb)
	btn.add_theme_color_override("font_color", TEXT_W)
	btn.add_theme_color_override("font_hover_color", TEXT_W)
	btn.add_theme_color_override("font_pressed_color", TEXT_W)


func _make_lbl(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _top_pill() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.35, 0.30, 0.22, 0.6)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _spacer(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _res_vbox() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return vb
