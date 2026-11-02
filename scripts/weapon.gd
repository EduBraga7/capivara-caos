class_name Weapon extends RefCounted
## Base class for the player's auto-weapons. Subclasses live in Weapons.

var run: Run
var id: String = ""
var def: Dictionary = {}
var level: int = 1
var evolved: bool = false
var st: Dictionary = {}
var timer: float = 0.0

func setup(r: Run, wid: String) -> void:
	run = r
	id = wid
	def = Defs.WEAPONS[wid]
	level = 1
	rebuild()
	timer = 0.35

func rebuild() -> void:
	st = (def["base"] as Dictionary).duplicate()
	var levels: Array = def["levels"]
	for i in range(1, level):
		_apply(levels[i])
	if evolved:
		_apply(def["evo"]["mods"])

func _apply(delta: Dictionary) -> void:
	for k in delta:
		if k in Defs.MULT_KEYS:
			st[k] = float(st[k]) * float(delta[k])
		else:
			st[k] = st[k] + delta[k]

func is_max() -> bool:
	return level >= Defs.MAX_WEAPON_LEVEL

func level_up() -> void:
	if not is_max():
		level += 1
		rebuild()
		on_rebuild()

func evolve() -> void:
	evolved = true
	rebuild()
	on_rebuild()

func display_name() -> String:
	if evolved:
		return G.L(def["evo"]["name"])
	return G.L(def["name"])

func icon() -> String:
	return def["icon"]

# ---- stats with player modifiers
func dmg() -> float:
	return float(st["dmg"]) * run.player.might

func cd() -> float:
	return float(st["cd"]) * run.player.cdm

func amt() -> int:
	return int(st["amt"]) + run.player.amount_bonus

func area() -> float:
	return float(st["area"]) * run.player.area

func on_rebuild() -> void:
	pass

func update(_dt: float) -> void:
	pass

func draw(_c: CanvasItem) -> void:
	pass

func draw_glow(_c: CanvasItem) -> void:
	pass
