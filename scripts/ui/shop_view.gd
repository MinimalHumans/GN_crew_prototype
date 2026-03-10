class_name ShopView
extends VBoxContainer
## ShopView — Trade goods and supply purchasing panel.
## Built programmatically and added to the planet view's service area.

signal back_pressed
signal log_message(text: String)

var planet_id: int = -1
var planet_prices: Dictionary = {}  # {commodity_id: {buy, sell}}
var galaxy_averages: Dictionary = {}  # {commodity_id: {avg_buy, avg_sell}}
var commodity_names: Dictionary = {}  # {commodity_id: name}
var cargo_quantities: Dictionary = {}  # {commodity_id: quantity}

# Repair cost per HP by planet id
const REPAIR_COST: Dictionary = {
	1: 2, 2: 3, 3: 3, 4: 1, 5: 3, 6: 4,
	7: 2, 8: 3, 9: 4, 10: 2, 11: 5, 12: 3,
}

# Color constants
const COLOR_GOOD: String = "#27AE60"
const COLOR_BAD: String = "#C0392B"
const COLOR_MUTED: String = "#718096"
const COLOR_ACCENT: String = "#4A90D9"
const COLOR_CREDITS: String = "#E6D159"

# UI refs that need refreshing
var cargo_capacity_label: Label
var your_cargo_container: VBoxContainer
var available_container: VBoxContainer
var fuel_info_label: Label
var fuel_cost_label: Label
var fuel_spin: SpinBox
var food_info_label: Label
var food_cost_label: Label
var food_spin: SpinBox
var repair_section: VBoxContainer


func _init(p_planet_id: int = -1) -> void:
	planet_id = p_planet_id


func _ready() -> void:
	if planet_id < 0:
		return
	_load_data()
	_build_ui()
	# Listen for changes to refresh display
	EventBus.credits_changed.connect(func(_n: int) -> void: _refresh_trade_display())
	EventBus.cargo_changed.connect(func(_cid: int, _q: int) -> void: _reload_cargo(); _refresh_trade_display())
	EventBus.fuel_changed.connect(func(_c: float, _m: float) -> void: _refresh_supply_display())
	EventBus.food_changed.connect(func(_s: float) -> void: _refresh_supply_display())
	EventBus.hull_changed.connect(func(_c: int, _m: int) -> void: _refresh_supply_display())


# === DATA LOADING ===

func _load_data() -> void:
	# Load commodity names
	var commodities: Array = DatabaseManager.get_all_commodities()
	for c: Dictionary in commodities:
		commodity_names[c.id] = c.name

	# Load planet prices into a dict keyed by commodity_id
	var prices: Array = DatabaseManager.get_planet_prices(planet_id)
	for p: Dictionary in prices:
		planet_prices[p.commodity_id] = {"buy": p.current_buy, "sell": p.current_sell}

	# Load galaxy averages
	galaxy_averages = DatabaseManager.get_galaxy_averages()

	# Load cargo
	_reload_cargo()


func _reload_cargo() -> void:
	var cargo: Array = DatabaseManager.get_cargo(GameManager.save_id)
	cargo_quantities.clear()
	for c: Dictionary in cargo:
		cargo_quantities[c.commodity_id] = c.quantity


# === UI BUILDING ===

func _build_ui() -> void:
	# Header row: Back button + title + cargo capacity
	var header: HBoxContainer = HBoxContainer.new()
	var back_btn: Button = Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(80, 32)
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	header.add_child(back_btn)

	var title: Label = Label.new()
	title.text = "  SHOP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(COLOR_ACCENT))
	header.add_child(title)

	cargo_capacity_label = Label.new()
	cargo_capacity_label.add_theme_font_size_override("font_size", 13)
	header.add_child(cargo_capacity_label)
	add_child(header)

	_update_cargo_label()

	# Scrollable content
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)

	# Trade goods section
	_build_trade_section(content)

	# Separator
	content.add_child(HSeparator.new())

	# Supplies section
	_build_supply_section(content)

	scroll.add_child(content)
	add_child(scroll)


func _build_trade_section(parent: VBoxContainer) -> void:
	var trade_header: Label = _make_section_label("TRADE GOODS")
	parent.add_child(trade_header)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)

	# Left column: Your Cargo (sell)
	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 4)
	var sell_header: Label = _make_section_label("YOUR CARGO (Sell)")
	sell_header.add_theme_font_size_override("font_size", 11)
	left_vbox.add_child(sell_header)
	your_cargo_container = VBoxContainer.new()
	your_cargo_container.add_theme_constant_override("separation", 4)
	left_vbox.add_child(your_cargo_container)
	columns.add_child(left_vbox)

	# Separator
	columns.add_child(VSeparator.new())

	# Right column: Available (buy)
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 4)
	var buy_header: Label = _make_section_label("AVAILABLE (Buy)")
	buy_header.add_theme_font_size_override("font_size", 11)
	right_vbox.add_child(buy_header)
	available_container = VBoxContainer.new()
	available_container.add_theme_constant_override("separation", 4)
	right_vbox.add_child(available_container)
	columns.add_child(right_vbox)

	parent.add_child(columns)

	# Populate
	_populate_trade_rows()


func _populate_trade_rows() -> void:
	# Clear
	for child: Node in your_cargo_container.get_children():
		child.queue_free()
	for child: Node in available_container.get_children():
		child.queue_free()

	# Sell side: commodities player has in cargo
	var has_cargo: bool = false
	for cid: int in commodity_names:
		var qty: int = cargo_quantities.get(cid, 0)
		if qty <= 0:
			continue
		has_cargo = true
		var sell_price: int = planet_prices.get(cid, {}).get("sell", 0)
		if sell_price <= 0:
			continue
		your_cargo_container.add_child(_make_trade_row(cid, sell_price, qty, false))

	if not has_cargo:
		var empty: Label = Label.new()
		empty.text = "Cargo hold empty"
		empty.add_theme_color_override("font_color", Color(COLOR_MUTED))
		empty.add_theme_font_size_override("font_size", 12)
		your_cargo_container.add_child(empty)

	# Buy side: all commodities available at this planet
	for cid: int in commodity_names:
		var buy_price: int = planet_prices.get(cid, {}).get("buy", 0)
		if buy_price <= 0:
			continue
		available_container.add_child(_make_trade_row(cid, buy_price, 0, true))


func _make_trade_row(commodity_id: int, price: int, held_qty: int, is_buy: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Commodity name
	var name_label: Label = Label.new()
	name_label.text = commodity_names.get(commodity_id, "???")
	name_label.custom_minimum_size = Vector2(55, 0)
	name_label.add_theme_font_size_override("font_size", 13)
	row.add_child(name_label)

	# Price with color coding
	var price_label: Label = Label.new()
	var price_color: String = _get_price_color(commodity_id, price, is_buy)
	price_label.text = "%d cr" % price
	price_label.custom_minimum_size = Vector2(45, 0)
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.add_theme_color_override("font_color", Color(price_color))
	row.add_child(price_label)

	# Quantity selector
	var spin: SpinBox = SpinBox.new()
	spin.min_value = 1
	spin.value = 1
	spin.custom_minimum_size = Vector2(60, 0)
	spin.add_theme_font_size_override("font_size", 12)

	if is_buy:
		var max_afford: int = GameManager.credits / maxi(price, 1)
		var max_cargo: int = GameManager.get_cargo_space_remaining()
		spin.max_value = maxi(mini(max_afford, max_cargo), 1)
	else:
		spin.max_value = maxi(held_qty, 1)

	row.add_child(spin)

	# Action button
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(50, 28)
	btn.add_theme_font_size_override("font_size", 12)

	if is_buy:
		btn.text = "Buy"
		btn.pressed.connect(_on_buy.bind(commodity_id, spin, price))
	else:
		btn.text = "Sell"
		btn.pressed.connect(_on_sell.bind(commodity_id, spin, price))

	row.add_child(btn)
	return row


func _get_price_color(commodity_id: int, price: int, is_buy: bool) -> String:
	if not galaxy_averages.has(commodity_id):
		return "#F7FAFC"

	var avg: float
	if is_buy:
		avg = galaxy_averages[commodity_id].avg_buy
		# Below average buy = good for player (green)
		if price < avg * 0.9:
			return COLOR_GOOD
		elif price > avg * 1.1:
			return COLOR_BAD
	else:
		avg = galaxy_averages[commodity_id].avg_sell
		# Above average sell = good for player (green)
		if price > avg * 1.1:
			return COLOR_GOOD
		elif price < avg * 0.9:
			return COLOR_BAD
	return "#F7FAFC"


# === SUPPLY SECTION ===

func _build_supply_section(parent: VBoxContainer) -> void:
	parent.add_child(_make_section_label("SUPPLIES"))

	# Fuel
	var fuel_buy: int = planet_prices.get(2, {}).get("buy", 12)  # Commodity 2 = Fuel
	var fuel_needed: float = GameManager.fuel_max - GameManager.fuel_current

	var fuel_row: HBoxContainer = HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 6)

	fuel_info_label = Label.new()
	fuel_info_label.add_theme_font_size_override("font_size", 13)
	fuel_row.add_child(fuel_info_label)

	fuel_spin = SpinBox.new()
	fuel_spin.min_value = 1
	fuel_spin.max_value = maxf(1, fuel_needed)
	fuel_spin.value = maxf(1, fuel_needed)
	fuel_spin.custom_minimum_size = Vector2(65, 0)
	fuel_spin.add_theme_font_size_override("font_size", 12)
	fuel_spin.value_changed.connect(func(_v: float) -> void: _update_fuel_cost())
	fuel_row.add_child(fuel_spin)

	fuel_cost_label = Label.new()
	fuel_cost_label.add_theme_font_size_override("font_size", 12)
	fuel_cost_label.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	fuel_row.add_child(fuel_cost_label)

	var fuel_btn: Button = Button.new()
	fuel_btn.text = "Refuel"
	fuel_btn.custom_minimum_size = Vector2(60, 28)
	fuel_btn.add_theme_font_size_override("font_size", 12)
	fuel_btn.pressed.connect(_on_refuel.bind(fuel_buy))
	fuel_row.add_child(fuel_btn)

	parent.add_child(fuel_row)

	# Food
	var food_buy: int = planet_prices.get(1, {}).get("buy", 10)  # Commodity 1 = Food

	var food_row: HBoxContainer = HBoxContainer.new()
	food_row.add_theme_constant_override("separation", 6)

	food_info_label = Label.new()
	food_info_label.add_theme_font_size_override("font_size", 13)
	food_row.add_child(food_info_label)

	food_spin = SpinBox.new()
	food_spin.min_value = 1
	food_spin.max_value = 50
	food_spin.value = 5
	food_spin.custom_minimum_size = Vector2(65, 0)
	food_spin.add_theme_font_size_override("font_size", 12)
	food_spin.value_changed.connect(func(_v: float) -> void: _update_food_cost())
	food_row.add_child(food_spin)

	food_cost_label = Label.new()
	food_cost_label.add_theme_font_size_override("font_size", 12)
	food_cost_label.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	food_row.add_child(food_cost_label)

	var food_btn: Button = Button.new()
	food_btn.text = "Restock"
	food_btn.custom_minimum_size = Vector2(60, 28)
	food_btn.add_theme_font_size_override("font_size", 12)
	food_btn.pressed.connect(_on_buy_food.bind(food_buy))
	food_row.add_child(food_btn)

	parent.add_child(food_row)

	# Repair — only if damaged
	repair_section = VBoxContainer.new()
	_build_repair_row(repair_section)
	parent.add_child(repair_section)

	_refresh_supply_display()


func _build_repair_row(parent: VBoxContainer) -> void:
	for child: Node in parent.get_children():
		child.queue_free()

	var damage: int = GameManager.hull_max - GameManager.hull_current
	if damage <= 0:
		return

	var cost_per_hp: int = REPAIR_COST.get(planet_id, 3)
	var total_cost: int = damage * cost_per_hp

	var repair_row: HBoxContainer = HBoxContainer.new()
	repair_row.add_theme_constant_override("separation", 6)

	var info: Label = Label.new()
	info.text = "Repair Hull (%d HP damage)" % damage
	info.add_theme_font_size_override("font_size", 13)
	repair_row.add_child(info)

	var cost_lbl: Label = Label.new()
	cost_lbl.text = "%d cr" % total_cost
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(COLOR_CREDITS))
	repair_row.add_child(cost_lbl)

	var repair_btn: Button = Button.new()
	repair_btn.text = "Repair"
	repair_btn.custom_minimum_size = Vector2(60, 28)
	repair_btn.add_theme_font_size_override("font_size", 12)
	repair_btn.pressed.connect(_on_repair.bind(damage, total_cost))
	repair_row.add_child(repair_btn)

	parent.add_child(repair_row)


# === ACTIONS ===

func _on_buy(commodity_id: int, spin: SpinBox, price: int) -> void:
	var qty: int = int(spin.value)
	if qty <= 0:
		return
	var name: String = commodity_names.get(commodity_id, "goods")
	if GameManager.buy_commodity(commodity_id, qty, price):
		log_message.emit("[color=%s]Bought %d units of %s for %d credits.[/color]" % [COLOR_GOOD, qty, name, qty * price])
	else:
		log_message.emit("[color=%s]Can't afford that or cargo hold full.[/color]" % COLOR_BAD)


func _on_sell(commodity_id: int, spin: SpinBox, price: int) -> void:
	var qty: int = int(spin.value)
	if qty <= 0:
		return
	var name: String = commodity_names.get(commodity_id, "goods")
	if GameManager.sell_commodity(commodity_id, qty, price):
		log_message.emit("[color=%s]Sold %d units of %s for %d credits.[/color]" % [COLOR_GOOD, qty, name, qty * price])
	else:
		log_message.emit("[color=%s]Not enough cargo to sell.[/color]" % COLOR_BAD)


func _on_refuel(price_per_unit: int) -> void:
	var units: float = float(fuel_spin.value)
	var cost: int = int(units) * price_per_unit
	if GameManager.refuel(units, cost):
		if GameManager.fuel_current >= GameManager.fuel_max:
			log_message.emit("[color=%s]Refueled — tank full. (%d credits)[/color]" % [COLOR_GOOD, cost])
		else:
			log_message.emit("[color=%s]Refueled %.0f units. (%d credits)[/color]" % [COLOR_GOOD, units, cost])
	else:
		log_message.emit("[color=%s]Not enough credits to refuel.[/color]" % COLOR_BAD)


func _on_buy_food(price_per_unit: int) -> void:
	var units: float = float(food_spin.value)
	var cost: int = int(units) * price_per_unit
	if GameManager.buy_food(units, cost):
		log_message.emit("[color=%s]Restocked %.0f food supplies. (%d credits)[/color]" % [COLOR_GOOD, units, cost])
	else:
		log_message.emit("[color=%s]Not enough credits for food.[/color]" % COLOR_BAD)


func _on_repair(damage: int, cost: int) -> void:
	if GameManager.repair_hull(damage, cost):
		log_message.emit("[color=%s]Hull fully repaired. (%d credits)[/color]" % [COLOR_GOOD, cost])
		_build_repair_row(repair_section)
	else:
		log_message.emit("[color=%s]Not enough credits for repairs.[/color]" % COLOR_BAD)


# === REFRESH ===

func _refresh_trade_display() -> void:
	_populate_trade_rows()
	_update_cargo_label()
	_refresh_supply_display()


func _refresh_supply_display() -> void:
	var fuel_needed: float = GameManager.fuel_max - GameManager.fuel_current
	if fuel_info_label:
		fuel_info_label.text = "Fuel (%.0f/%.0f)" % [GameManager.fuel_current, GameManager.fuel_max]
	if fuel_spin:
		fuel_spin.max_value = maxf(1, fuel_needed)
		fuel_spin.value = minf(fuel_spin.value, fuel_spin.max_value)
	_update_fuel_cost()

	if food_info_label:
		food_info_label.text = "Food (%.0f aboard)" % GameManager.food_supply
	_update_food_cost()

	_build_repair_row(repair_section)


func _update_cargo_label() -> void:
	if cargo_capacity_label:
		var total: int = GameManager.get_total_cargo()
		cargo_capacity_label.text = "Cargo: %d/%d" % [total, GameManager.cargo_max]


func _update_fuel_cost() -> void:
	if fuel_cost_label and fuel_spin:
		var fuel_buy: int = planet_prices.get(2, {}).get("buy", 12)
		fuel_cost_label.text = "= %d cr" % (int(fuel_spin.value) * fuel_buy)


func _update_food_cost() -> void:
	if food_cost_label and food_spin:
		var food_buy: int = planet_prices.get(1, {}).get("buy", 10)
		food_cost_label.text = "= %d cr" % (int(food_spin.value) * food_buy)


# === HELPERS ===

func _make_section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(COLOR_MUTED))
	label.add_theme_font_size_override("font_size", 11)
	return label
