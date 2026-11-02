extends Node
## Autoload "G": palette, language, persistent save, input map, shared helpers.

signal language_changed
signal achievement_unlocked(id: String, title: String, desc: String, icon: String)

const SAVE_PATH := "user://capivara_caos_save.json"

class ToastItem:
	var id: String = ""
	var title: String = ""
	var desc: String = ""
	var icon: String = "skull"
	var t: float = 0.0

var toast_queue: Array[ToastItem] = []
var toast_cur: ToastItem = null
var toast_canvas: CanvasLayer = null
var toast_control: Control = null

# ---- palette
const OUT := Color("2a1810")
const CREAM := Color("fff3dc")
const ORANGE := Color("ff9a1f")
const ORANGE_L := Color("ffc15e")
const GREEN := Color("6cc04a")
const TEAL := Color("1fb5a8")
const NAVY := Color("152238")
const NAVY_L := Color("24395f")
const RED := Color("ff4d4d")
const GOLD := Color("ffd43b")
const PINK := Color("ff7eb6")

var lang: int = 0
var data: Dictionary = {}
var tex: Texture2D = null            # sprite atlas
var spr: Dictionary = {}             # name -> Rect2 (pixels inside atlas)
var spr_logic: Dictionary = {}       # name -> Vector2 (logical size)
var title_font: FontVariation
var body_font: Font
var test_mode := false               # set by command line flags (--bot, --shots)
var save_path: String = SAVE_PATH
var ui_hold := false                 # tests: keep modals open for screenshots
var is_gamepad: bool = false

const TR := {
	"title": ["CAPIVARA CAOS", "CAPYBARA CHAOS"],
	"tagline": ["ela só queria relaxar", "she just wanted to chill"],
	"play": ["JOGAR", "PLAY"],
	"shop": ["LOJA", "SHOP"],
	"options": ["OPÇÕES", "OPTIONS"],
	"quit": ["SAIR", "QUIT"],
	"back": ["VOLTAR", "BACK"],
	"start": ["COMEÇAR!", "START!"],
	"choose_hero": ["ESCOLHA SUA CAPIVARA", "CHOOSE YOUR CAPYBARA"],
	"select": ["ESCOLHER", "SELECT"],
	"selected": ["ESCOLHIDA", "SELECTED"],
	"locked": ["BLOQUEADA", "LOCKED"],
	"unlock": ["DESBLOQUEAR", "UNLOCK"],
	"starts_with": ["Começa com", "Starts with"],
	"difficulty": ["Dificuldade", "Difficulty"],
	"diff0": ["Zen", "Zen"],
	"diff1": ["Normal", "Normal"],
	"diff2": ["Caos", "Chaos"],
	"coins": ["Moedas", "Coins"],
	"shop_title": ["LOJA DA FEIRA", "MARKET SHOP"],
	"shop_sub": ["Melhorias permanentes pra próxima partida", "Permanent upgrades for every run"],
	"buy": ["COMPRAR", "BUY"],
	"max": ["MÁXIMO", "MAX"],
	"options_title": ["OPÇÕES", "OPTIONS"],
	"achievements": ["CONQUISTAS", "ACHIEVEMENTS"],
	"achievements_title": ["CONQUISTAS", "ACHIEVEMENTS"],
	"achievements_sub": ["Suas glórias e momentos no Pantanal", "Your swamp glories and feats"],
	"achievement_unlocked": ["CONQUISTA DESBLOQUEADA!", "ACHIEVEMENT UNLOCKED!"],
	"ach_unlocked_stat": ["Desbloqueadas", "Unlocked"],
	"master": ["Volume geral", "Master volume"],
	"music": ["Música", "Music"],
	"sfx": ["Efeitos", "Effects"],
	"shake": ["Tremida de tela", "Screen shake"],
	"numbers": ["Números de dano", "Damage numbers"],
	"fullscreen": ["Tela cheia", "Fullscreen"],
	"flashes": ["Clarões de tela", "Screen flashes"],
	"diff_hint0": ["Inimigos mais fracos e em menor número. Relaxe.", "Weaker, fewer enemies. Just chill."],
	"diff_hint1": ["A experiência padrão do Pantanal.", "The standard Pantanal experience."],
	"diff_hint2": ["Mais fortes, mais numerosos e +50% de moedas.", "Stronger, more numerous, +50% coins."],
	"language": ["Idioma", "Language"],
	"on": ["LIGADO", "ON"],
	"off": ["DESLIGADO", "OFF"],
	"shake0": ["Nenhuma", "None"],
	"shake1": ["Normal", "Normal"],
	"shake2": ["Pouca", "Low"],
	"lang_name": ["Português", "English"],
	"level": ["NV", "LV"],
	"level_up": ["NÍVEL UP!", "LEVEL UP!"],
	"choose_up": ["Escolha uma melhoria", "Pick an upgrade"],
	"reroll": ["TROCAR", "REROLL"],
	"new": ["NOVA!", "NEW!"],
	"evolution": ["EVOLUÇÃO!", "EVOLUTION!"],
	"combines": ["Evolui com", "Evolves with"],
	"heal_item": ["Marmita Quentinha", "Hot Lunch"],
	"heal_desc": ["Recupera 40% da vida.", "Restores 40% HP."],
	"coins_item": ["Cofrinho Cheio", "Full Piggy Bank"],
	"coins_desc": ["+40 moedas.", "+40 coins."],
	"paused": ["PAUSADO", "PAUSED"],
	"resume": ["CONTINUAR", "RESUME"],
	"menu": ["MENU", "MENU"],
	"again": ["DE NOVO!", "AGAIN!"],
	"game_over": ["A capivara caiu...", "The capybara fell..."],
	"game_over_sub": ["Mas ela volta mais relaxada.", "But she'll be back, chillier."],
	"victory": ["VITÓRIA!", "VICTORY!"],
	"victory_sub": ["A capivara finalmente relaxou.", "The capybara finally got to chill."],
	"survived": ["Sobreviveu", "Survived"],
	"kills": ["Bichos derrotados", "Critters beaten"],
	"level_reached": ["Nível alcançado", "Level reached"],
	"coins_earned": ["Moedas ganhas", "Coins earned"],
	"record": ["NOVO RECORDE!", "NEW RECORD!"],
	"copy": ["COPIAR RESULTADO", "COPY RESULT"],
	"copied": ["COPIADO!", "COPIED!"],
	"endless": ["CONTINUAR (INFINITO)", "KEEP GOING (ENDLESS)"],
	"chest": ["BAÚ!", "CHEST!"],
	"take": ["PEGAR", "TAKE"],
	"dodge": ["ESQUIVA!", "DODGE!"],
	"hint_move": ["WASD / Setas / Analógico: mover", "WASD / Arrows / Stick: move"],
	"hint_dash": ["ESPAÇO / Shift / A: esquivar", "SPACE / Shift / A: dodge"],
	"hint_auto": ["O resto é automático. Só relaxe.", "Everything else is automatic. Just chill."],
	"hint_nav": ["Setas/WASD + Enter  •  Mouse também funciona", "Arrows/WASD + Enter  •  Mouse works too"],
	"best": ["Melhor tempo", "Best time"],
	"total_kills": ["Total de bichos", "Total critters"],
	"runs": ["Partidas", "Runs"],
	"wins": ["Vitórias", "Wins"],
	"boss_warn": ["CHEFÃO!", "BOSS!"],
	"stat_hint": ["Passe o mouse ou use as setas", "Hover or use the arrows"],
	"share_text": ["🦫 Capivara Caos: sobrevivi %s, derrubei %s bichos e cheguei ao nível %d!%s Consegue me superar?", "🦫 Capybara Chaos: I survived %s, beat %s critters and reached level %d!%s Can you beat me?"],
	"share_win": [" VENCI A SUCURI!", " I BEAT THE ANACONDA!"],
	"weapons": ["Armas", "Weapons"],
	"passives": ["Itens", "Items"],
	"slots_full": ["Slots cheios", "Slots full"],
	"milestone100": ["100 BICHOS!", "100 CRITTERS!"],
	"milestone500": ["QUE ISSO, CAPIVARA!", "WOW, CAPYBARA!"],
	"milestone1000": ["MIL BICHOS! LENDÁRIA!", "A THOUSAND! LEGENDARY!"],
	"milestone2000": ["DESCONTROLADA!!", "UNSTOPPABLE!!"],
	"milestone4000": ["APOCALIPSE DE CAPIVARA!!!", "CAPYBARA APOCALYPSE!!!"],
	"magnet": ["ÍMÃ!", "MAGNET!"],
	"bomb": ["FOGOS!", "FIREWORKS!"],
	"heal": ["Marmita!", "Lunch!"],
	"revived": ["SEGUNDA CHANCE!", "SECOND CHANCE!"],
	"water": ["Na água a capivara regenera.", "Water heals the capybara."],
	"loading": ["Preparando a capivara...", "Preparing the capybara..."],
	"zen": ["Zen", "Zen"],
	"controls_title": ["COMO JOGAR", "HOW TO PLAY"],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	load_save()
	_init_toast_layer()
	for a in OS.get_cmdline_user_args():
		if a == "--bot" or a.begins_with("--shots") or a == "--test":
			test_mode = true
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = 0.85
	title_font = f
	var f2 := FontVariation.new()
	f2.base_font = ThemeDB.fallback_font
	f2.variation_embolden = 0.35
	body_font = f2
	apply_settings()

class ToastDraw extends Control:
	var g: Node
	func _draw() -> void:
		g._draw_toast(self)

func _init_toast_layer() -> void:
	toast_canvas = CanvasLayer.new()
	toast_canvas.layer = 120
	toast_control = ToastDraw.new()
	toast_control.g = self
	toast_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_canvas.add_child(toast_control)
	add_child(toast_canvas)

func _process(dt: float) -> void:
	if toast_cur != null:
		toast_cur.t += dt
		if toast_cur.t >= 4.0:
			toast_cur = null
		if toast_control != null and is_instance_valid(toast_control):
			toast_control.queue_redraw()
	elif not toast_queue.is_empty():
		toast_cur = toast_queue.pop_front()
		toast_cur.t = 0.0
		if has_node("/root/Sfx"):
			get_node("/root/Sfx").play("milestone", -2.0)
		if toast_control != null and is_instance_valid(toast_control):
			toast_control.queue_redraw()

func _draw_toast(c: Control) -> void:
	if toast_cur == null:
		return
	var vs := c.size
	var t := toast_cur.t
	var k := 1.0
	if t < 0.4:
		k = Ui.ease_out_back(clampf(t / 0.4, 0.0, 1.0))
	elif t > 3.6:
		k = 1.0 - clampf((t - 3.6) / 0.4, 0.0, 1.0)
	var tw := 340.0
	var th := 74.0
	var rx := vs.x - tw - 24.0
	var ry := vs.y - th - 24.0 + (1.0 - k) * 90.0
	var r := Rect2(rx, ry, tw, th)
	Ui.panel(c, r, Color("101a2e"), Color("ffd43b"), 14, 3, 12)
	var ic_center := Vector2(rx + 38, ry + th * 0.5)
	c.draw_circle(ic_center, 24, Color(0.15, 0.25, 0.42, 0.85))
	c.draw_arc(ic_center, 24, 0.0, TAU, 32, Color("ffd43b"), 2.0, true)
	var is_wide := toast_cur.icon.begins_with("jacare") or toast_cur.icon.begins_with("onca")
	Ui.icon(c, toast_cur.icon, ic_center, 40.0 if is_wide else 34.0)
	Ui.text(c, Vector2(rx + 72, ry + 22), "🏆 " + T("achievement_unlocked"), 12, Color("ffd43b"), HORIZONTAL_ALIGNMENT_LEFT, tw - 80, 0, true)
	Ui.text(c, Vector2(rx + 72, ry + 42), toast_cur.title, 16, Color("fff3dc"), HORIZONTAL_ALIGNMENT_LEFT, tw - 80, 0, true)
	Ui.text(c, Vector2(rx + 72, ry + 60), toast_cur.desc, 12, Color("a8c0e8"), HORIZONTAL_ALIGNMENT_LEFT, tw - 80, 0, false)

func _exit_tree() -> void:
	title_font = null
	body_font = null
	tex = null
	spr.clear()
	spr_logic.clear()
	Ui._cache.clear()
	Ui._vignette = null
	Ui._shade_h = null
	toast_queue.clear()
	toast_cur = null

func _input(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton:
		is_gamepad = true
	elif ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.4:
		is_gamepad = true
	elif ev is InputEventKey or (ev is InputEventMouseButton and ev.pressed):
		is_gamepad = false

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F11:
		set_setting("fullscreen", not bool(data["settings"]["fullscreen"]))
		apply_settings()

func p_accept() -> String:
	return "(A)" if is_gamepad else "[Enter]"

func p_cancel() -> String:
	return "(B)" if is_gamepad else "[Esc]"

func p_reroll() -> String:
	return "(Y)" if is_gamepad else "[R]"

func p_dash() -> String:
	return "(A / RB)" if is_gamepad else "[Espaço]"

func p_nav() -> String:
	return "(D-Pad)" if is_gamepad else "[WASD / Setas]"

func hint_move_str() -> String:
	return "(Analógico / D-Pad) para mover" if is_gamepad else L(["WASD / Setas: mover", "WASD / Arrows: move"])

func hint_dash_str() -> String:
	return "(A / RB): esquivar" if is_gamepad else L(["ESPAÇO / Shift: esquivar", "SPACE / Shift: dodge"])

# ---------------------------------------------------------------- i18n
func L(pair: Array) -> String:
	return pair[lang] if lang < pair.size() else pair[0]

func T(key: String) -> String:
	if TR.has(key):
		return L(TR[key])
	return key

func set_lang(i: int) -> void:
	lang = clampi(i, 0, 1)
	data["settings"]["lang"] = lang
	language_changed.emit()

# --------------------------------------------------------------- inputs
func _setup_inputs() -> void:
	_act("move_left", [KEY_A, KEY_LEFT], [[JOY_AXIS_LEFT_X, -1.0]], [JOY_BUTTON_DPAD_LEFT])
	_act("move_right", [KEY_D, KEY_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]], [JOY_BUTTON_DPAD_RIGHT])
	_act("move_up", [KEY_W, KEY_UP], [[JOY_AXIS_LEFT_Y, -1.0]], [JOY_BUTTON_DPAD_UP])
	_act("move_down", [KEY_S, KEY_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]], [JOY_BUTTON_DPAD_DOWN])
	_act("dash", [KEY_SPACE, KEY_SHIFT], [], [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER])
	_act("pause", [KEY_ESCAPE, KEY_P], [], [JOY_BUTTON_START])
	_act("reroll", [KEY_R], [], [JOY_BUTTON_Y])

func _act(name: String, keys: Array, axes: Array, buttons: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	for a in axes:
		var j := InputEventJoypadMotion.new()
		j.axis = a[0]
		j.axis_value = a[1]
		InputMap.action_add_event(name, j)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(name, jb)

# ---------------------------------------------------------------- save
func _default_data() -> Dictionary:
	return {
		"coins": 0,
		"shop": {},
		"unlocked": ["cap"],
		"selected": "cap",
		"best_time": 0.0,
		"best_kills": 0,
		"best_level": 0,
		"total_kills": 0,
		"runs": 0,
		"wins": 0,
		"seen_hint": 0,
		"achievements": [],
		"settings": {"master": 0.85, "music": 0.65, "sfx": 0.9, "shake": 1, "numbers": true, "flashes": true, "lang": -1, "difficulty": 1, "fullscreen": false},
	}

func has_achievement(id: String) -> bool:
	return (data.get("achievements", []) as Array).has(id)

func unlock_achievement(id: String) -> void:
	if not Defs.ACHIEVEMENTS.has(id):
		return
	if not data.has("achievements") or not (data["achievements"] is Array):
		data["achievements"] = []
	if data["achievements"].has(id):
		return
	data["achievements"].append(id)
	save()
	var d: Dictionary = Defs.ACHIEVEMENTS[id]
	var item := ToastItem.new()
	item.id = id
	item.title = L(d["name"])
	item.desc = L(d["desc"])
	item.icon = str(d.get("icon", "skull"))
	toast_queue.append(item)
	achievement_unlocked.emit(id, item.title, item.desc, item.icon)

func load_save() -> void:
	data = _default_data()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_merge(data, parsed)
	var l: int = int(data["settings"]["lang"])
	if l < 0:
		l = 0 if OS.get_locale_language() == "pt" else 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			l = 0 if a.substr(7) == "pt" else 1
	lang = l

func _merge(base: Dictionary, over: Dictionary) -> void:
	for k in over:
		if base.has(k) and base[k] is Dictionary and over[k] is Dictionary:
			_merge(base[k], over[k])
		else:
			base[k] = over[k]

func save() -> void:
	if test_mode:
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func set_setting(key: String, value) -> void:
	data["settings"][key] = value

func setting(key: String):
	return data["settings"][key]

func apply_settings() -> void:
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").apply_volumes()
	if not test_mode and DisplayServer.get_name() != "headless":
		var want_full: bool = bool(data["settings"]["fullscreen"])
		var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if want_full != is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)

# ----------------------------------------------------------- meta helpers
func shop_level(id: String) -> int:
	return int(data["shop"].get(id, 0))

func meta_bonus(stat: String) -> float:
	var total := 0.0
	for id in Defs.SHOP:
		var d: Dictionary = Defs.SHOP[id]
		if d["stat"] == stat:
			total += float(d["per"]) * shop_level(id)
	return total

func is_unlocked(id: String) -> bool:
	return id in data["unlocked"]

func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d" % [s / 60, s % 60]

func fmt_num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out if lang == 0 else "," + out
	return ("-" if n < 0 else "") + out
