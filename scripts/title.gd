class_name Title extends CanvasLayer
## Main menu: logo over a live attract-mode game, character select, shop, options.

signal start_run(char_id: String)
signal quit_game

enum P { MAIN, SELECT, SHOP, OPTIONS, ACHIEVEMENTS }

class Btn:
	var rect := Rect2()
	var text := ""
	var data = null
	var cb: Callable = Callable()
	var enabled: bool = true
	var kind: int = 1                # 0 card, 1 button
	var hov: float = 0.0
	var adjust: Callable = Callable()
	var big: bool = false
	var on: bool = false             # toggled look

class Canvas extends Control:
	var ui: Title
	func _draw() -> void:
		ui.paint(self)
	func _input(ev: InputEvent) -> void:
		ui.on_input(ev)

var canvas: Canvas
var page: int = P.MAIN
var btns: Array[Btn] = []
var focus: int = 0
var clock: float = 0.0
var page_t: float = 0.0
var sel_char: String = "cap"
var toast: String = ""
var toast_t: float = 0.0
var last_mouse := Vector2(-1, -1)
var last_nav_ms: int = 0
var demo_run: Run = null
var spring := Vector2.ZERO
var dragging_slider: String = ""

func _ready() -> void:
	layer = 20
	canvas = Canvas.new()
	canvas.ui = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(canvas)
	sel_char = G.data["selected"]
	if not G.is_unlocked(sel_char):
		sel_char = "cap"
	if G.data["unlocked"].size() >= Defs.CHAR_ORDER.size():
		G.unlock_achievement("unlock_all")
	if int(G.data["coins"]) >= 1000:
		G.unlock_achievement("coins_1000")
	G.language_changed.connect(_layout)
	canvas.resized.connect(_layout)
	_go(P.MAIN)

func _go(p: int) -> void:
	dragging_slider = ""
	page = p
	page_t = 0.0
	focus = 0
	last_mouse = canvas.get_local_mouse_position()
	_layout()
	if demo_run != null:
		demo_run.cam_bias = Vector2(-250, 10) if p == P.MAIN else Vector2.ZERO
		demo_run.process_mode = Node.PROCESS_MODE_INHERIT if p == P.MAIN else Node.PROCESS_MODE_DISABLED
		demo_run.visible = (p == P.MAIN)

func _add(text: String, rect: Rect2, cb: Callable, kind: int = 1, enabled: bool = true) -> Btn:
	var b := Btn.new()
	b.text = text
	b.rect = rect
	b.cb = cb
	b.kind = kind
	b.enabled = enabled
	btns.append(b)
	return b

# ------------------------------------------------------------------ layout
func _layout() -> void:
	var keep := focus
	btns.clear()
	var vs := canvas.size
	match page:
		P.MAIN:
			var bx := 90.0
			var by := 298.0
			var pb := _add(G.T("play"), Rect2(bx, by, 380, 62), _go.bind(P.SELECT))
			pb.big = true
			_add(G.T("shop"), Rect2(bx, by + 72, 380, 48), _go.bind(P.SHOP))
			_add(G.T("achievements"), Rect2(bx, by + 130, 380, 48), _go.bind(P.ACHIEVEMENTS))
			_add(G.T("options"), Rect2(bx, by + 188, 380, 48), _go.bind(P.OPTIONS))
			_add(G.T("quit"), Rect2(bx, by + 246, 380, 46), func(): quit_game.emit())
			_add(G.L(["Feito por Eduardo Braga  •  itch.io", "Made by Eduardo Braga  •  itch.io"]), Rect2(bx, by + 300, 380, 38), _open_itch, 2)
			var lb := _add("PT / EN", Rect2(vs.x - 150, vs.y - 64, 120, 40), _toggle_lang)
			lb.text = "PT  •  EN" if G.lang == 0 else "EN  •  PT"
		P.SELECT:
			var n := Defs.CHAR_ORDER.size()
			var avail_w := vs.x - 48.0
			var cw := minf(206.0, (avail_w - (n - 1) * 12.0) / float(n))
			var gap := 12.0 if cw < 206.0 else 14.0
			var total := n * cw + (n - 1) * gap
			var x0 := (vs.x - total) * 0.5
			var y0 := clampi(int(vs.y * 0.5 - 256.0), 64, 104)
			for i in n:
				var b := _add("", Rect2(x0 + i * (cw + gap), y0, cw, 360), _click_char.bind(i), 0)
				b.data = i
			var dy := y0 + 376.0
			var dw := 150.0
			var dx := vs.x * 0.5 - (3 * dw + 20) * 0.5
			for d in 3:
				var db := _add(G.T("diff%d" % d), Rect2(dx + d * (dw + 10), dy, dw, 42), _set_diff.bind(d))
				db.on = int(G.data["settings"]["difficulty"]) == d
			_add(G.T("start"), Rect2(vs.x * 0.5 + 20, dy + 70, 280, 58), _start).big = true
			_add(G.T("back"), Rect2(vs.x * 0.5 - 220, dy + 70, 190, 58), _go.bind(P.MAIN))
			focus = _char_index(sel_char)
		P.SHOP:
			var cols := 4
			var cw2 := 280.0
			var ch2 := 124.0
			var gp := 14.0
			var total2 := cols * cw2 + (cols - 1) * gp
			var x02 := (vs.x - total2) * 0.5
			var y02 := 132.0
			for i in Defs.SHOP_ORDER.size():
				var id: String = Defs.SHOP_ORDER[i]
				var r := Rect2(x02 + (i % cols) * (cw2 + gp), y02 + (i / cols) * (ch2 + gp), cw2, ch2)
				var sb := _add("", r, _buy.bind(id), 0)
				sb.data = id
			_add(G.T("back"), Rect2(vs.x * 0.5 - 110, y02 + 3 * (ch2 + gp) + 14, 220, 54), _go.bind(P.MAIN))
		P.OPTIONS:
			var bx2 := vs.x * 0.5 - 260.0
			var by2 := 122.0
			var rows := [
				["master", _opt_text("master"), "vol"],
				["music", _opt_text("music"), "vol"],
				["sfx", _opt_text("sfx"), "vol"],
				["shake", _opt_text("shake"), "shake"],
				["numbers", _opt_text("numbers"), "numbers"],
				["fullscreen", _opt_text("fullscreen"), "fullscreen"],
				["flashes", _opt_text("flashes"), "flashes"],
				["language", _opt_text("language"), "language"],
			]
			for i in rows.size():
				var ob := _add(rows[i][1], Rect2(bx2, by2 + i * 52, 520, 44), _opt_click.bind(rows[i][0], rows[i][2]))
				ob.adjust = _opt_adjust.bind(rows[i][0], rows[i][2])
				ob.data = rows[i][0]
			_add(G.T("back"), Rect2(vs.x * 0.5 - 110, by2 + rows.size() * 52 + 18, 220, 50), _go.bind(P.MAIN))
		P.ACHIEVEMENTS:
			var cols := 4
			var cw3 := 280.0
			var ch3 := 92.0
			var gpx := 14.0
			var gpy := 12.0
			var total_w := cols * cw3 + (cols - 1) * gpx
			var x03 := (vs.x - total_w) * 0.5
			var y03 := 122.0
			for i in Defs.ACHIEVEMENT_ORDER.size():
				var aid: String = Defs.ACHIEVEMENT_ORDER[i]
				var col := i % cols
				var row := i / cols
				var r := Rect2(x03 + col * (cw3 + gpx), y03 + row * (ch3 + gpy), cw3, ch3)
				var ab := _add("", r, Callable(), 0)
				ab.data = aid
			_add(G.T("back"), Rect2(vs.x * 0.5 - 110, y03 + 4 * (ch3 + gpy) + 14, 220, 50), _go.bind(P.MAIN))
	if page != P.SELECT:
		focus = clampi(keep if page_t > 0.01 else 0, 0, maxi(0, btns.size() - 1))

func _char_index(cid: String) -> int:
	return maxi(0, Defs.CHAR_ORDER.find(cid))

func _opt_text(key: String) -> String:
	var s: Dictionary = G.data["settings"]
	match key:
		"master", "music", "sfx":
			return G.T(key)
		"shake":
			return "%s   %s" % [G.T("shake"), G.T("shake%d" % int(s["shake"]))]
		"numbers":
			return "%s   %s" % [G.T("numbers"), G.T("on") if bool(s["numbers"]) else G.T("off")]
		"fullscreen":
			return "%s   %s" % [G.T("fullscreen"), G.T("on") if bool(s["fullscreen"]) else G.T("off")]
		"flashes":
			return "%s   %s" % [G.T("flashes"), G.T("on") if bool(s["flashes"]) else G.T("off")]
		"language":
			return "%s   %s" % [G.T("language"), G.T("lang_name")]
	return key

func _get_slider_btn(key: String) -> Btn:
	for b in btns:
		if b.data != null and str(b.data) == key:
			return b
	return null

func _calc_slider_ratio(b: Btn, pos: Vector2) -> float:
	var sc := 1.0 + 0.04 * b.hov
	var center := b.rect.get_center()
	var local_x := (pos.x - center.x) / sc
	var sr_x := b.rect.size.x * 0.5 - 220.0
	var track_x0 := sr_x + 3.0
	var track_len := 140.0 - 6.0
	return clampf((local_x - track_x0) / track_len, 0.0, 1.0)

func _handle_slider_click(b: Btn, pos: Vector2) -> void:
	var sc := 1.0 + 0.04 * b.hov
	var center := b.rect.get_center()
	var local_x := (pos.x - center.x) / sc
	var sr_x := b.rect.size.x * 0.5 - 220.0
	var key := str(b.data)
	if local_x >= sr_x - 6.0 and local_x <= sr_x + 146.0:
		var ratio := _calc_slider_ratio(b, pos)
		var v := clampf(snappedf(ratio, 0.05), 0.0, 1.0)
		G.set_setting(key, v)
		Sfx.apply_volumes()
		dragging_slider = key
		Sfx.play("ui_hover", -6.0)
		canvas.queue_redraw()
	elif local_x > sr_x + 146.0:
		_opt_adjust(1, key, "vol")
	elif local_x >= sr_x - 45.0:
		_opt_adjust(-1, key, "vol")
	else:
		Sfx.play("ui_hover", -10.0)

func _opt_click(key: String, type: String) -> void:
	_opt_adjust(1, key, type)

func _opt_adjust(dir: int, key: String, type: String) -> void:
	var s: Dictionary = G.data["settings"]
	match type:
		"vol":
			var v := clampf(float(s[key]) + 0.05 * dir, 0.0, 1.0)
			G.set_setting(key, snappedf(v, 0.05))
			Sfx.apply_volumes()
		"shake":
			G.set_setting("shake", posmod(int(s["shake"]) + dir, 3))
		"numbers":
			G.set_setting("numbers", not bool(s["numbers"]))
		"fullscreen":
			G.set_setting("fullscreen", not bool(s["fullscreen"]))
			G.apply_settings()
		"flashes":
			G.set_setting("flashes", not bool(s["flashes"]))
		"language":
			G.set_lang(1 - G.lang)
	Sfx.play("ui_hover", -6.0)
	G.save()
	if type != "vol":
		_layout()
	else:
		canvas.queue_redraw()

func _toggle_lang() -> void:
	G.set_lang(1 - G.lang)
	Sfx.play("ui_click")
	G.save()
	_layout()

func _set_diff(d: int) -> void:
	G.set_setting("difficulty", d)
	Sfx.play("ui_click")
	G.save()
	_layout()

func _click_char(i: int) -> void:
	var cid: String = Defs.CHAR_ORDER[i]
	var d: Dictionary = Defs.CHARACTERS[cid]
	if G.is_unlocked(cid):
		sel_char = cid
		G.data["selected"] = cid
		G.save()
		Sfx.play("ui_click")
		return
	var price: int = d["price"]
	if int(G.data["coins"]) >= price:
		G.data["coins"] = int(G.data["coins"]) - price
		G.data["unlocked"].append(cid)
		sel_char = cid
		G.data["selected"] = cid
		G.save()
		Sfx.play("levelup")
		_toast(G.L(d["name"]) + " !")
		if G.data["unlocked"].size() >= Defs.CHAR_ORDER.size():
			G.unlock_achievement("unlock_all")
	else:
		Sfx.play("hurt", -8.0)
		_toast("%s %s" % [G.fmt_num(price), G.T("coins")])

func _buy(id: String) -> void:
	var d: Dictionary = Defs.SHOP[id]
	var lv := G.shop_level(id)
	if lv >= int(d["max"]):
		Sfx.play("hurt", -10.0)
		return
	var cost: int = d["cost"][lv]
	if int(G.data["coins"]) >= cost:
		G.data["coins"] = int(G.data["coins"]) - cost
		G.data["shop"][id] = lv + 1
		G.save()
		Sfx.play("levelup", -2.0, 1.4)
		_toast(G.L(d["name"]) + "  +")
	else:
		Sfx.play("hurt", -8.0)
		_toast("%s %s" % [G.fmt_num(cost), G.T("coins")])

func _start() -> void:
	Sfx.play("ui_click")
	start_run.emit(sel_char)

func _toast(s: String) -> void:
	toast = s
	toast_t = 1.6

# --------------------------------------------------------------------- tick
func _process(dt: float) -> void:
	clock += dt
	page_t += dt
	if toast_t > 0.0:
		toast_t -= dt
	if dragging_slider != "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging_slider = ""
		G.save()
	var mp := canvas.get_local_mouse_position()
	if dragging_slider == "" and mp.distance_to(last_mouse) > 2.0:
		last_mouse = mp
		for i in btns.size():
			if btns[i].rect.has_point(mp):
				if focus != i:
					focus = i
					Sfx.play("ui_hover", -12.0)
				break
	for i in btns.size():
		btns[i].hov = move_toward(btns[i].hov, 1.0 if i == focus else 0.0, dt * 9.0)
	canvas.queue_redraw()

func on_input(ev: InputEvent) -> void:
	if not visible:
		return
	var handled := false
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = ev.position
		for i in btns.size():
			if btns[i].rect.has_point(mp):
				focus = i
				if page == P.OPTIONS and btns[i].data != null and str(btns[i].data) in ["master", "music", "sfx"]:
					_handle_slider_click(btns[i], mp)
				else:
					_activate(i)
				break
		handled = true
	elif ev is InputEventMouseMotion:
		if dragging_slider != "":
			var b := _get_slider_btn(dragging_slider)
			if b != null:
				var ratio := _calc_slider_ratio(b, ev.position)
				var v := clampf(snappedf(ratio, 0.05), 0.0, 1.0)
				var old_v := float(G.data["settings"][dragging_slider])
				if not is_equal_approx(v, old_v):
					G.set_setting(dragging_slider, v)
					Sfx.apply_volumes()
					canvas.queue_redraw()
			handled = true
	elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if dragging_slider != "":
			dragging_slider = ""
			G.save()
			canvas.queue_redraw()
			handled = true
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			var mp: Vector2 = ev.position
			for i in btns.size():
				if btns[i].rect.has_point(mp) and btns[i].data != null and str(btns[i].data) in ["master", "music", "sfx"]:
					_opt_adjust(1, str(btns[i].data), "vol")
					handled = true
					break
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var mp: Vector2 = ev.position
			for i in btns.size():
				if btns[i].rect.has_point(mp) and btns[i].data != null and str(btns[i].data) in ["master", "music", "sfx"]:
					_opt_adjust(-1, str(btns[i].data), "vol")
					handled = true
					break
	elif ev is InputEventKey or ev is InputEventJoypadButton or ev is InputEventJoypadMotion or ev is InputEventAction:
		if ev is InputEventJoypadMotion:
			var now := Time.get_ticks_msec()
			if now - last_nav_ms < 190:
				return
			last_nav_ms = now
		if ev.is_action_pressed("ui_cancel") and page != P.MAIN:
			_go(P.MAIN)
			handled = true
		elif ev.is_action_pressed("ui_left") or ev.is_action_pressed("move_left"):
			_nav(Vector2.LEFT)
			handled = true
		elif ev.is_action_pressed("ui_right") or ev.is_action_pressed("move_right"):
			_nav(Vector2.RIGHT)
			handled = true
		elif ev.is_action_pressed("ui_up") or ev.is_action_pressed("move_up"):
			_nav(Vector2.UP)
			handled = true
		elif ev.is_action_pressed("ui_down") or ev.is_action_pressed("move_down"):
			_nav(Vector2.DOWN)
			handled = true
		elif ev.is_action_pressed("ui_accept"):
			if page == P.SELECT and focus < btns.size() and btns[focus].kind == 0 and G.is_unlocked(Defs.CHAR_ORDER[int(btns[focus].data)]):
				_click_char(int(btns[focus].data))
				_start()
			else:
				_activate(focus)
			handled = true
	if handled:
		get_viewport().set_input_as_handled()

func _activate(i: int) -> void:
	if i < 0 or i >= btns.size():
		return
	var b := btns[i]
	if b.cb.is_valid() and b.enabled:
		if (b.kind == 1 or b.kind == 2) and page != P.OPTIONS:
			Sfx.play("ui_click")
		b.cb.call()

func _open_itch() -> void:
	OS.shell_open("https://edubraga7.itch.io/capivara-caos")

func _nav(dir: Vector2) -> void:
	if btns.is_empty():
		return
	if btns[focus].adjust.is_valid() and (dir == Vector2.LEFT or dir == Vector2.RIGHT):
		btns[focus].adjust.call(1 if dir == Vector2.RIGHT else -1)
		return
	var cur := btns[focus].rect.get_center()
	var best := -1
	var bs := 1e12
	for i in btns.size():
		if i == focus:
			continue
		var d := btns[i].rect.get_center() - cur
		if d.dot(dir) <= 1.0:
			continue
		var score := d.dot(dir) + absf(d.dot(Vector2(-dir.y, dir.x))) * 2.5
		if score < bs:
			bs = score
			best = i
	if best >= 0:
		focus = best
		Sfx.play("ui_hover", -10.0)
		if page == P.SELECT and btns[focus].kind == 0:
			var cid: String = Defs.CHAR_ORDER[int(btns[focus].data)]
			if G.is_unlocked(cid):
				sel_char = cid
				G.data["selected"] = cid

# -------------------------------------------------------------------- paint
func paint(c: Control) -> void:
	var vs := c.size
	if page == P.MAIN:
		_paint_main(c, vs)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.05, 0.12, 0.8))
		_paint_coins(c, vs)
		match page:
			P.SELECT: _paint_select(c, vs)
			P.SHOP: _paint_shop(c, vs)
			P.OPTIONS: _paint_options(c, vs)
			P.ACHIEVEMENTS: _paint_achievements(c, vs)
	if toast_t > 0.0:
		var a := clampf(toast_t * 2.0, 0.0, 1.0)
		Ui.ctext(c, Vector2(vs.x * 0.5, vs.y - 90 - (1.6 - toast_t) * 20.0), toast, 28, Color(1.0, 0.9, 0.4, a), 6)

func _paint_coins(c: Control, vs: Vector2) -> void:
	var r := Rect2(vs.x - 230, 18, 212, 46)
	Ui.panel(c, r, Color(0.08, 0.12, 0.2, 0.92), Color("ffd43b"), 23, 3, 4)
	Ui.icon(c, "coin", r.position + Vector2(26, 23), 32)
	Ui.text(c, r.position + Vector2(48, 32), G.fmt_num(int(G.data["coins"])), 26, Color("ffe066"), HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 5)

func _paint_main(c: Control, vs: Vector2) -> void:
	# soft left-side shade so the logo reads over any terrain
	c.draw_texture_rect(Ui.shade_h(), Rect2(0, 0, 780, vs.y), false, Color(0.02, 0.04, 0.12, 1.0))
	# logo
	var wob := sin(clock * 2.0) * 0.025
	var l1 := G.L(["CAPIVARA", "CAPYBARA"])
	var l2 := G.L(["CAOS", "CHAOS"])
	c.draw_set_transform(Vector2(280, 96), -0.03 + wob, Vector2.ONE)
	Ui.text(c, Vector2(-300, 20), l1, 84, Color("fff3dc"), HORIZONTAL_ALIGNMENT_CENTER, 600.0, 14)
	c.draw_set_transform(Vector2(280, 172), 0.02 - wob, Vector2(1.0 + 0.03 * sin(clock * 5.0), 1.0 + 0.03 * sin(clock * 5.0)))
	Ui.text(c, Vector2(-300, 26), l2, 98, Color("ff9a1f"), HORIZONTAL_ALIGNMENT_CENTER, 600.0, 16)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Ui.ctext(c, Vector2(280, 240), G.T("tagline"), 20, Color("ffe9b8"), 5)
	for i in btns.size():
		var b := btns[i]
		if b.kind == 2:
			_paint_credit_btn(c, b)
		elif b.rect.size.x > 200:
			_paint_btn(c, b)
		else:
			_paint_small_btn(c, b)
	# records
	var d: Dictionary = G.data
	var rec := "%s %s   •   %s %s   •   %s %d   •   %s %d" % [G.T("best"), G.fmt_time(float(d["best_time"])), G.T("total_kills"), G.fmt_num(int(d["total_kills"])), G.T("runs"), int(d["runs"]), G.T("wins"), int(d["wins"])]
	Ui.text(c, Vector2(24, vs.y - 22), rec, 16, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, false)
	var nav_hint := "%s %s   •   %s %s" % [G.p_accept(), G.T("select"), G.p_nav(), G.L(["Navegar", "Navigate"])]
	Ui.text(c, Vector2(vs.x - 360, vs.y - 22), nav_hint, 15, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_RIGHT, 340.0, 3, false)
	var ver := "v1.1  •  %s" % G.L(["por Eduardo Braga", "by Eduardo Braga"])
	Ui.text(c, Vector2(vs.x - 280, vs.y - 74), ver, 14, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 3, false)
	_paint_coins(c, vs)

func _paint_btn(c: Control, b: Btn) -> void:
	var sc := 1.0 + 0.04 * b.hov
	var center := b.rect.get_center()
	c.draw_set_transform(center, 0.0, Vector2(sc, sc))
	var rr := Rect2(-b.rect.size * 0.5, b.rect.size)
	var bg := Color("ff9a1f").lerp(Color("ffc44a"), b.hov)
	var border := Color("5a2c0a")
	var tc := Color("2a1208")
	if b.on:
		bg = Color("39d9c0").lerp(Color("7af0dc"), b.hov)
		border = Color("0b4a44")
	if not b.enabled:
		bg = Color("4a5568")
		border = Color("2a303a")
		tc = Color("8a94a6")
	elif b.hov > 0.05:
		var pulse := 0.5 + 0.5 * sin(clock * 8.0)
		border = Color("ffd43b").lerp(Color("ffffff"), pulse * 0.7)
	Ui.panel(c, rr, bg, border, 16, 4 if b.hov <= 0.05 else 5, 8 + int(4 * b.hov))
	if b.data != null and str(b.data) in ["master", "music", "sfx"]:
		Ui.text(c, Vector2(rr.position.x + 24, rr.position.y + rr.size.y * 0.5 + 8), b.text, 22, tc, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 0)
		var vol: float = float(G.data["settings"][str(b.data)])
		var sr := Rect2(rr.position.x + rr.size.x - 220, rr.position.y + rr.size.y * 0.5 - 7, 140, 14)
		var is_active := dragging_slider == str(b.data)
		Ui.slider(c, sr, vol, Color("0b4a44") if not b.hov > 0.05 else Color("06302c"), is_active, b.hov)
		Ui.text(c, Vector2(rr.position.x + rr.size.x - 70, rr.position.y + rr.size.y * 0.5 + 8), "%d%%" % int(round(vol * 100.0)), 18, tc, HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 0)
	else:
		Ui.text(c, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + (13 if b.big else 9)), b.text, 38 if b.big else 24, tc, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 0)
	if b.adjust.is_valid() and b.hov > 0.1 and not (b.data != null and str(b.data) in ["master", "music", "sfx"]):
		Ui.text(c, Vector2(rr.position.x + 14, rr.position.y + rr.size.y * 0.5 + 9), "◀", 20, tc, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 0)
		Ui.text(c, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + 9), "▶", 20, tc, HORIZONTAL_ALIGNMENT_RIGHT, rr.size.x - 14, 0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_small_btn(c: Control, b: Btn) -> void:
	var sc := 1.0 + 0.05 * b.hov
	c.draw_set_transform(b.rect.get_center(), 0.0, Vector2(sc, sc))
	var rr := Rect2(-b.rect.size * 0.5, b.rect.size)
	Ui.panel(c, rr, Color(0.1, 0.16, 0.28, 0.9).lerp(Color(0.2, 0.3, 0.5, 0.95), b.hov), Color("7a8aa8"), 12, 2, 4)
	Ui.text(c, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + 6), b.text, 16, Color("e8f0ff"), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_credit_btn(c: Control, b: Btn) -> void:
	var sc := 1.0 + 0.04 * b.hov
	var center := b.rect.get_center()
	c.draw_set_transform(center, 0.0, Vector2(sc, sc))
	var rr := Rect2(-b.rect.size * 0.5, b.rect.size)
	var bg := Color(0.08, 0.14, 0.25, 0.88).lerp(Color(0.14, 0.22, 0.38, 0.96), b.hov)
	var border := Color(0.65, 0.55, 0.3, 0.6)
	if b.hov > 0.05:
		var pulse := 0.5 + 0.5 * sin(clock * 8.0)
		border = Color("ffd43b").lerp(Color.WHITE, pulse * 0.5)
	Ui.panel(c, rr, bg, border, 12, 2 if b.hov <= 0.05 else 3, 4 + int(4 * b.hov))
	var tc := Color("fff3dc").lerp(Color("ffe066"), b.hov)
	Ui.text(c, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + 6), b.text, 15, tc, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 2 if b.hov > 0.05 else 0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_title(c: Control, vs: Vector2, s: String, sub: String = "") -> void:
	Ui.ctext(c, Vector2(vs.x * 0.5, 54), s, 52, Color("ffd43b"), 9)
	if sub != "":
		Ui.ctext(c, Vector2(vs.x * 0.5, 92), sub, 20, Color("c8d8f0"), 4, false)

func _paint_select(c: Control, vs: Vector2) -> void:
	_paint_title(c, vs, G.T("choose_hero"))
	for i in btns.size():
		var b := btns[i]
		if b.kind == 0:
			_paint_char_card(c, b, int(b.data))
		else:
			_paint_btn(c, b)
	if btns.size() > 5:
		var drect := btns[5].rect
		var dsel := int(G.data["settings"]["difficulty"])
		Ui.ctext(c, Vector2(vs.x * 0.5, drect.position.y + 62), G.T("diff_hint%d" % dsel), 15, Color(1, 1, 1, 0.75), 3, false)
		Ui.text(c, Vector2(drect.position.x - 216, drect.position.y + 28), G.T("difficulty") + ":", 20, Color("c8d8f0"), HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 4, false)

func _paint_char_card(c: Control, b: Btn, idx: int) -> void:
	var cid: String = Defs.CHAR_ORDER[idx]
	var d: Dictionary = Defs.CHARACTERS[cid]
	var unlocked := G.is_unlocked(cid)
	var selected := cid == sel_char
	var r := b.rect
	var k := clampf((page_t - idx * 0.07) / 0.3, 0.0, 1.0)
	var yo := (1.0 - Ui.ease_out_back(k)) * 60.0
	var rr := Rect2(r.position + Vector2(0, yo - 4.0 * b.hov), r.size)
	var border := Color("ffd43b") if selected else Color("4a6a9a").lerp(Color("9ad0ff"), b.hov)
	Ui.panel(c, rr, Color("14274a").lerp(Color("1d3a6e"), b.hov), border, 18, 5 if selected else 3, 10)
	# portrait
	var ground := rr.position + Vector2(rr.size.x * 0.5, 170)
	c.draw_circle(ground + Vector2(0, -40), 70, Color(1, 1, 1, 0.06))
	Ui.icon(c, "shadow", ground + Vector2(0, 4), 120, Color(1, 1, 1, 0.9))
	var active := selected or b.hov > 0.3
	Capy.draw(c, clock + idx * 0.7, 1.0 if active else 0.0, 1.0, 1.0, d["body"], d["hat"], 0.0, Vector2(0, 3.0 * sin(clock * 5.0)), cid == "cap", ground + Vector2(-8, 0), 1.0, 1.55)
	if not unlocked:
		c.draw_rect(Rect2(rr.position + Vector2(6, 6), Vector2(rr.size.x - 12, 190)), Color(0.02, 0.04, 0.1, 0.62))
		_lock(c, rr.position + Vector2(rr.size.x * 0.5, 110))
	# text
	Ui.fit(c, Vector2(rr.position.x + rr.size.x * 0.5, rr.position.y + 214), G.L(d["name"]), rr.size.x - 14, 25, Color("fff3dc"), 4)
	var wd: Dictionary = Defs.WEAPONS[d["weapon"]]
	Ui.icon(c, wd["icon"], rr.position + Vector2(30, 252), 34)
	Ui.text(c, rr.position + Vector2(52, 258), G.L(wd["name"]), 15, Color("ffd27a"), HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 56, 3, true)
	Ui.wrap(c, Vector2(rr.position.x + 10, rr.position.y + 282), G.L(d["trait"]), rr.size.x - 20, 13, Color("c8d8f0"), 3)
	# status
	var sy := rr.position.y + rr.size.y - 14
	if not unlocked:
		var afford := int(G.data["coins"]) >= int(d["price"])
		Ui.icon(c, "coin", Vector2(rr.position.x + rr.size.x * 0.5 - 44, sy - 8), 22)
		Ui.text(c, Vector2(rr.position.x, sy), "%s" % G.fmt_num(int(d["price"])), 20, Color("7be04a") if afford else Color("ff6b6b"), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x + 30.0, 4)
	elif selected:
		Ui.text(c, Vector2(rr.position.x, sy), G.T("selected"), 17, Color("7be04a"), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 4)
	else:
		Ui.text(c, Vector2(rr.position.x, sy), G.T("select"), 15, Color(1, 1, 1, 0.5 + 0.4 * b.hov), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 3)

func _lock(c: Control, p: Vector2, sc: float = 1.0) -> void:
	if sc != 1.0:
		c.draw_set_transform(p, 0.0, Vector2(sc, sc))
		p = Vector2.ZERO
	c.draw_arc(p + Vector2(0, -8), 15, PI, TAU, 16, Color("c8c8d0"), 7.0, true)
	Ui.panel(c, Rect2(p + Vector2(-22, -8), Vector2(44, 36)), Color("e8b83a"), Color("5a3a0a"), 7, 3, 0)
	c.draw_circle(p + Vector2(0, 8), 5, Color("5a3a0a"))
	if sc != 1.0:
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_shop(c: Control, vs: Vector2) -> void:
	_paint_title(c, vs, G.T("shop_title"), G.T("shop_sub"))
	for i in btns.size():
		var b := btns[i]
		if b.kind == 0:
			_paint_shop_card(c, b, str(b.data))
		else:
			_paint_btn(c, b)

func _paint_shop_card(c: Control, b: Btn, id: String) -> void:
	var d: Dictionary = Defs.SHOP[id]
	var lv := G.shop_level(id)
	var mx: int = d["max"]
	var maxed := lv >= mx
	var idx := Defs.SHOP_ORDER.find(id)
	var k := clampf((page_t - idx * 0.03) / 0.25, 0.0, 1.0)
	var r := Rect2(b.rect.position + Vector2(0, (1.0 - Ui.ease_out_back(k)) * 40.0 - 3.0 * b.hov), b.rect.size)
	var cost: int = d["cost"][lv] if not maxed else 0
	var afford := int(G.data["coins"]) >= cost
	var border := Color("4a6a9a").lerp(Color("9ad0ff"), b.hov)
	if maxed:
		border = Color("ffd43b")
	Ui.panel(c, r, Color("14274a").lerp(Color("1d3a6e"), b.hov), border, 16, 3, 8)
	Ui.icon(c, d["icon"], r.position + Vector2(48, 50), 62)
	Ui.text(c, r.position + Vector2(92, 34), G.L(d["name"]), 20, Color("fff3dc"), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 100, 4)
	Ui.wrap(c, Vector2(r.position.x + 92, r.position.y + 54), G.L(d["desc"]), r.size.x - 100, 13, Color("c8d8f0"), 2, HORIZONTAL_ALIGNMENT_LEFT)
	for p in mx:
		var pc := r.position + Vector2(98 + p * 17, 92)
		c.draw_circle(pc, 6, Color("0a1428"))
		c.draw_circle(pc, 4.5, Color("ffd43b") if p < lv else Color("2a3a5a"))
	if maxed:
		Ui.text(c, r.position + Vector2(r.size.x - 120, 104), G.T("max"), 16, Color("ffd43b"), HORIZONTAL_ALIGNMENT_RIGHT, 108.0, 4)
	else:
		Ui.icon(c, "coin", r.position + Vector2(r.size.x - 82, 100), 22)
		Ui.text(c, r.position + Vector2(r.size.x - 70, 107), G.fmt_num(cost), 18, Color("7be04a") if afford else Color("ff6b6b"), HORIZONTAL_ALIGNMENT_LEFT, 64.0, 4)

func _paint_options(c: Control, vs: Vector2) -> void:
	_paint_title(c, vs, G.T("options_title"))
	for i in btns.size():
		_paint_btn(c, btns[i])
	Ui.ctext(c, Vector2(vs.x * 0.5, vs.y - 48), G.L(["Capivara Caos — Desenvolvido por Eduardo Braga", "Capybara Chaos — Developed by Eduardo Braga"]), 16, Color("fff3dc"), 4)
	Ui.ctext(c, Vector2(vs.x * 0.5, vs.y - 24), "edubraga7.itch.io/capivara-caos", 14, Color("7be04a"), 3)

func _paint_achievements(c: Control, vs: Vector2) -> void:
	var unlocked_count := 0
	for aid in Defs.ACHIEVEMENT_ORDER:
		if G.has_achievement(aid):
			unlocked_count += 1
	var total_count := Defs.ACHIEVEMENT_ORDER.size()
	var pct := int(round(float(unlocked_count) / float(total_count) * 100.0))

	Ui.ctext(c, Vector2(vs.x * 0.5, 46), G.T("achievements_title"), 46, Color("ffd43b"), 8)
	var sub := "%s: %d / %d (%d%%)" % [G.T("ach_unlocked_stat"), unlocked_count, total_count, pct]
	Ui.ctext(c, Vector2(vs.x * 0.5, 80), sub, 18, Color("c8d8f0"), 3, false)

	var bar_w := 360.0
	var bar_r := Rect2((vs.x - bar_w) * 0.5, 96.0, bar_w, 8.0)
	c.draw_rect(bar_r, Color(0.1, 0.15, 0.25, 0.8))
	if pct > 0:
		var fill_w := bar_w * clampf(float(unlocked_count) / float(total_count), 0.0, 1.0)
		c.draw_rect(Rect2(bar_r.position, Vector2(fill_w, bar_r.size.y)), Color("7be04a"))
	c.draw_rect(bar_r, Color(0.2, 0.3, 0.45, 0.6), false, 1.5)

	for b in btns:
		if b.kind == 0 and b.data != null and str(b.data) in Defs.ACHIEVEMENTS:
			_paint_achievement_card(c, b, str(b.data))
		else:
			_paint_btn(c, b)

func _paint_achievement_card(c: Control, b: Btn, aid: String) -> void:
	var d: Dictionary = Defs.ACHIEVEMENTS[aid]
	var unlocked := G.has_achievement(aid)
	var idx := Defs.ACHIEVEMENT_ORDER.find(aid)
	var k := clampf((page_t - idx * 0.02) / 0.22, 0.0, 1.0)
	var yo := (1.0 - Ui.ease_out_back(k)) * 30.0
	var r := Rect2(b.rect.position + Vector2(0, yo - 3.0 * b.hov), b.rect.size)

	var bg: Color
	var border: Color
	if unlocked:
		bg = Color("14274a").lerp(Color("1e3d6b"), b.hov)
		border = Color("ffd43b") if b.hov > 0.05 else Color("3e72aa")
	else:
		bg = Color(0.06, 0.09, 0.15, 0.88).lerp(Color(0.09, 0.13, 0.20, 0.95), b.hov)
		border = Color("556688") if b.hov > 0.05 else Color("222d40")

	if b.hov > 0.05:
		var pulse := 0.5 + 0.5 * sin(clock * 8.0)
		border = border.lerp(Color.WHITE, pulse * 0.5)

	Ui.panel(c, r, bg, border, 14, 3 if b.hov <= 0.05 else 4, 6)

	# Icon frame on the left
	var ibox := Rect2(r.position.x + 12, r.position.y + (r.size.y - 62.0) * 0.5, 62, 62)
	var ibg := Color("0b1828") if unlocked else Color(0.03, 0.05, 0.08, 0.7)
	var iborder := Color("ffd43b") if unlocked else Color("2a3548")
	Ui.panel(c, ibox, ibg, iborder, 10, 2, 0)

	var icon_name: String = d.get("icon", "ic_capy")
	var is_wide := icon_name.begins_with("jacare") or icon_name.begins_with("onca")
	var isz: float = 52.0 if is_wide else 44.0
	if not unlocked:
		isz *= 0.86
	if unlocked:
		Ui.icon(c, icon_name, ibox.get_center(), isz, Color.WHITE)
	else:
		Ui.icon(c, icon_name, ibox.get_center(), isz, Color(0.35, 0.4, 0.5, 0.35))
		_lock(c, ibox.get_center(), 0.65)

	# Title & description on right (left-aligned with clean vertical separation)
	var tx := r.position.x + 84.0
	var tw := r.size.x - 92.0
	var title_col := Color("fff3dc") if unlocked else Color("7a8aa8")
	var desc_col := Color("c8d8f0") if unlocked else Color("4d5a70")
	var title_text: String = G.L(d["name"])
	var desc_text: String = G.L(d["desc"])

	Ui.text(c, Vector2(tx, r.position.y + 28), title_text, 16, title_col, HORIZONTAL_ALIGNMENT_LEFT, tw, 3 if unlocked else 0, true)
	Ui.wrap(c, Vector2(tx, r.position.y + 47), desc_text, tw, 11, desc_col, 2, HORIZONTAL_ALIGNMENT_LEFT)

	if unlocked:
		var pill_pos := Vector2(r.position.x + r.size.x - 26, r.position.y + r.size.y - 14)
		Ui.pill(c, pill_pos, "OK", Color("1b6638"), Color("7be04a"), 10)
