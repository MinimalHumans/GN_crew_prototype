class_name ShipyardView
extends VBoxContainer
## ShipyardView — Displays available ships for purchase with specs and upgrade path.
## Built programmatically and added to the planet view's service area.

signal back_pressed
signal log_message(text: String)
signal ship_purchased

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"
const COLOR_LOCKED: String = "#E67E22"

# Ship classes in upgrade order
const SHIP_CLASSES: Array[String] = ["skiff", "corvette", "frigate"]

# UI refs
var ship_card_container: VBoxContainer


func _ready() -> void:
	_build_ui()


# === UI BUILDING ===

func _build_ui() -> void:
	# Header
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 32)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  SHIPYARD"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	header.add_child(title)

	var credits_lbl: Label = Label.new()
	credits_lbl.text = "%d credits" % GameManager.credits
	credits_lbl.add_theme_font_size_override("font_size", 13)
	credits_lbl.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	header.add_child(credits_lbl)
	add_child(header)

	# Current ship info
	add_child(_make_section_label("CURRENT SHIP"))
	var current_info: Label = Label.new()
	current_info.text = "%s  (%s-class)  —  Hull: %d/%d  Fuel: %.0f/%.0f  Cargo: %d  Crew: %d" % [
		GameManager.ship_name, GameManager.ship_class.capitalize(),
		GameManager.hull_current, GameManager.hull_max,
		GameManager.fuel_current, GameManager.fuel_max,
		GameManager.cargo_max, GameManager.crew_max,
	]
	current_info.add_theme_font_size_override("font_size", 12)
	current_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(current_info)

	# Separator
	add_child(HSeparator.new())

	# Available ships
	add_child(_make_section_label("AVAILABLE SHIPS"))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	ship_card_container = VBoxContainer.new()
	ship_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_card_container.add_theme_constant_override("separation", 10)

	_populate_ship_cards()

	scroll.add_child(ship_card_container)
	add_child(scroll)


func _populate_ship_cards() -> void:
	for child: Node in ship_card_container.get_children():
		child.queue_free()

	var class_order: Dictionary = {"skiff": 0, "corvette": 1, "frigate": 2}
	var current_rank: int = class_order.get(GameManager.ship_class, 0)

	for ship_class: String in SHIP_CLASSES:
		var template: Dictionary = DatabaseManager.get_ship_template(ship_class)
		var rank: int = class_order.get(ship_class, 0)
		ship_card_container.add_child(_make_ship_card(template, rank, current_rank))


func _make_ship_card(template: Dictionary, rank: int, current_rank: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)

	var ship_class: String = template["class"]
	var price: int = GameManager.get_ship_price(ship_class)
	var unlock_level: int = GameManager.get_ship_unlock_level(ship_class)
	var is_current: bool = rank == current_rank
	var is_owned: bool = rank < current_rank
	var is_upgrade: bool = rank > current_rank

	# Title row: ship name + status
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)

	var title_lbl: Label = Label.new()
	title_lbl.text = template.name
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 16)
	if is_current:
		title_lbl.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	title_row.add_child(title_lbl)

	var status_lbl: Label = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 13)
	if is_current:
		status_lbl.text = "[CURRENT SHIP]"
		status_lbl.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	elif is_owned:
		status_lbl.text = "[PREVIOUS]"
		status_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	elif price > 0:
		status_lbl.text = "%d credits" % price
		status_lbl.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	title_row.add_child(status_lbl)

	card_vbox.add_child(title_row)

	# Spec grid
	var specs_text: String = "Hull: %d  |  Fuel: %.0f  |  Cargo: %d  |  Crew: %d" % [
		template.hull_max, template.fuel_max, template.cargo_max, template.crew_max,
	]
	var specs_lbl: Label = Label.new()
	specs_lbl.text = specs_text
	specs_lbl.add_theme_font_size_override("font_size", 12)
	specs_lbl.add_theme_color_override("font_color", Color(COLOR_MUTED))
	card_vbox.add_child(specs_lbl)

	# Upgrade comparison (only for upgrade candidates)
	if is_upgrade:
		var compare: Label = Label.new()
		var hull_diff: int = template.hull_max - GameManager.hull_max
		var fuel_diff: float = template.fuel_max - GameManager.fuel_max
		var cargo_diff: int = template.cargo_max - GameManager.cargo_max
		var crew_diff: int = template.crew_max - GameManager.crew_max
		compare.text = "vs current:  Hull +%d  |  Fuel +%.0f  |  Cargo +%d  |  Crew +%d" % [
			hull_diff, fuel_diff, cargo_diff, crew_diff,
		]
		compare.add_theme_font_size_override("font_size", 11)
		compare.add_theme_color_override("font_color", Color(COLOR_GOOD))
		card_vbox.add_child(compare)

	# Level requirement and purchase button (for upgrades only)
	if is_upgrade:
		var btn_row: HBoxContainer = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)

		var level_ok: bool = GameManager.captain_level >= unlock_level
		var credits_ok: bool = GameManager.credits >= price

		if not level_ok:
			var req_lbl: Label = Label.new()
			req_lbl.text = "Requires Level %d (you are Level %d)" % [unlock_level, GameManager.captain_level]
			req_lbl.add_theme_font_size_override("font_size", 12)
			req_lbl.add_theme_color_override("font_color", Color(COLOR_LOCKED))
			btn_row.add_child(req_lbl)
		else:
			var buy_btn: Button = Button.new()
			buy_btn.text = "Purchase %s" % template.name
			buy_btn.custom_minimum_size = Vector2(150, 36)

			if not credits_ok:
				buy_btn.disabled = true
				buy_btn.tooltip_text = "Need %d credits (have %d)" % [price, GameManager.credits]
			else:
				buy_btn.pressed.connect(_on_purchase.bind(ship_class))
			btn_row.add_child(buy_btn)

			if not credits_ok:
				var short_lbl: Label = Label.new()
				short_lbl.text = "Need %d more credits" % (price - GameManager.credits)
				short_lbl.add_theme_font_size_override("font_size", 11)
				short_lbl.add_theme_color_override("font_color", Color(COLOR_BAD))
				btn_row.add_child(short_lbl)

		card_vbox.add_child(btn_row)

	card.add_child(card_vbox)
	return card


# === ACTIONS ===

func _on_purchase(target_class: String) -> void:
	var template: Dictionary = DatabaseManager.get_ship_template(target_class)
	var price: int = GameManager.get_ship_price(target_class)

	if GameManager.purchase_ship(target_class):
		# Atmospheric purchase text
		var purchase_text: String = TextTemplates.get_ship_purchase_text(target_class)
		log_message.emit("")
		log_message.emit("[color=%s]==============================[/color]" % COLOR_ACCENT)
		log_message.emit("[color=%s]  NEW SHIP: %s-class[/color]" % [COLOR_ACCENT, template.name])
		log_message.emit("[color=%s]  -%d credits[/color]" % [COLOR_CREDITS, price])
		log_message.emit("[color=%s]  %s[/color]" % [COLOR_MUTED, purchase_text])
		log_message.emit("[color=%s]==============================[/color]" % COLOR_ACCENT)
		log_message.emit("")

		# Carry-over report
		log_message.emit("[color=%s]Fuel carried: %.0f/%.0f[/color]" % [
			COLOR_MUTED, GameManager.fuel_current, GameManager.fuel_max,
		])
		log_message.emit("[color=%s]Food carried: %.0f[/color]" % [
			COLOR_MUTED, GameManager.food_supply,
		])
		var total_cargo: int = GameManager.get_total_cargo()
		if total_cargo > 0:
			log_message.emit("[color=%s]Cargo transferred: %d units[/color]" % [COLOR_MUTED, total_cargo])

		ship_purchased.emit()

		# Refresh cards
		_populate_ship_cards()
	else:
		log_message.emit("[color=%s]Unable to purchase ship. Check credits and level.[/color]" % COLOR_BAD)


# === HELPERS ===

func _make_section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(COLOR_MUTED))
	label.add_theme_font_size_override("font_size", 11)
	return label
