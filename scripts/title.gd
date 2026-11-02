class_name Title extends CanvasLayer
## Main menu: logo over a live attract-mode game, character select, shop, options.

signal start_run(char_id: String)
signal quit_game

enum P { MAIN, SELECT, SHOP, OPTIONS }

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
	G.language_changed.connect(_layout)
	canvas.resized.connect(_layout)
	_go(P.MAIN)

func _go(p: int) -> void:
	page = p
	page_t = 0.0
	focus = 0
	last_mouse = canvas.get_local_mouse_position()
	_layout()
	if demo_run != null:
		demo_run.cam_bias = Vector2(-250, 10) if p == P.MAIN else Vector2.ZERO

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
			var by := vs.y * 0.5 - 20.0
			var pb := _add(G.T("play"), Rect2(bx, by, 380, 74), _go.bind(P.SELECT))
			pb.big = true
			_add(G.T("shop"), Rect2(bx, by + 90, 380, 58), _go.bind(P.SHOP))
			_add(G.T("options"), Rect2(bx, by + 160, 380, 58), _go.bind(P.OPTIONS))
			_add(G.T("quit"), Rect2(bx, by + 230, 380, 50), func(): quit_game.emit())
			var lb := _add("PT / EN", Rect2(vs.x - 150, vs.y - 64, 120, 40), _toggle_lang)
			lb.text = "PT  •  EN" if G.lang == 0 else "EN  •  PT"
		P.SELECT:
			var n := Defs.CHAR_ORDER.size()
			var cw := 206.0
			var gap := 14.0
			var total := n * cw + (n - 1) * gap
			var x0 := (vs.x - total) * 0.5
			var y0 := 104.0
			for i in n:
				var b := _add("", Rect2(x0 + i * (cw + gap), y0, cw, 360), _click_char.bind(i), 0)
				b.data = i
			var dy := y0 + 380.0
			var dw := 150.0
			var dx := vs.x * 0.5 - (3 * dw + 20) * 0.5
			for d in 3:
				var db := _add(G.T("diff%d" % d), Rect2(dx + d * (dw + 10), dy, dw, 42), _set_diff.bind(d))
				db.on = int(G.data["settings"]["difficulty"]) == d
			_add(G.T("start"), Rect2(vs.x * 0.5 + 20, dy + 80, 280, 62), _start).big = true
			_add(G.T("back"), Rect2(vs.x * 0.5 - 220, dy + 80, 190, 62), _go.bind(P.MAIN))
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
			var bx2 := vs.x * 0.5 - 250.0
			var by2 := 150.0
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
				var ob := _add(rows[i][1], Rect2(bx2, by2 + i * 60, 500, 50), _opt_click.bind(rows[i][0], rows[i][2]))
				ob.adjust = _opt_adjust.bind(rows[i][0], rows[i][2])
			_add(G.T("back"), Rect2(vs.x * 0.5 - 110, by2 + rows.size() * 60 + 20, 220, 54), _go.bind(P.MAIN))
	if page != P.SELECT:
		focus = clampi(keep if page_t > 0.01 else 0, 0, maxi(0, btns.size() - 1))

func _char_index(cid: String) -> int:
	return maxi(0, Defs.CHAR_ORDER.find(cid))

func _opt_text(key: String) -> String:
	var s: Dictionary = G.data["settings"]
	match key:
		"master", "music", "sfx":
			return "%s   %d%%" % [G.T(key), int(round(float(s[key]) * 100.0))]
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

func _opt_click(key: String, type: String) -> void:
	_opt_adjust(1, key, type)

func _opt_adjust(dir: int, key: String, type: String) -> void:
	var s: Dictionary = G.data["settings"]
	match type:
		"vol":
			var v := float(s[key]) + 0.1 * dir
			if v > 1.001:
				v = 0.0
			if v < -0.001:
				v = 1.0
			G.set_setting(key, snappedf(v, 0.1))
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
	_layout()

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
	var mp := canvas.get_local_mouse_position()
	if mp != last_mouse:
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
		var mp := canvas.get_local_mouse_position()
		for i in btns.size():
			if btns[i].rect.has_point(mp):
				focus = i
				_activate(i)
				break
		handled = true
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
		if b.kind == 1 and page != P.OPTIONS:
			Sfx.play("ui_click")
		b.cb.call()

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
	c.draw_set_transform(Vector2(280, 128), -0.03 + wob, Vector2.ONE)
	Ui.text(c, Vector2(-300, 20), l1, 92, Color("fff3dc"), HORIZONTAL_ALIGNMENT_CENTER, 600.0, 14)
	c.draw_set_transform(Vector2(280, 218), 0.02 - wob, Vector2(1.0 + 0.03 * sin(clock * 5.0), 1.0 + 0.03 * sin(clock * 5.0)))
	Ui.text(c, Vector2(-300, 30), l2, 112, Color("ff9a1f"), HORIZONTAL_ALIGNMENT_CENTER, 600.0, 16)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Ui.ctext(c, Vector2(280, 286), G.T("tagline"), 26, Color("ffe9b8"), 6)
	for i in btns.size():
		var b := btns[i]
		if i < 4:
			_paint_btn(c, b)
		else:
			_paint_small_btn(c, b)
	# records
	var d: Dictionary = G.data
	var rec := "%s %s   •   %s %s   •   %s %d   •   %s %d" % [G.T("best"), G.fmt_time(float(d["best_time"])), G.T("total_kills"), G.fmt_num(int(d["total_kills"])), G.T("runs"), int(d["runs"]), G.T("wins"), int(d["wins"])]
	Ui.text(c, Vector2(24, vs.y - 22), rec, 16, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, false)
	Ui.text(c, Vector2(vs.x - 380, vs.y - 80), "v1.0", 14, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, 350.0, 3, false)
	_paint_coins(c, vs)

func _paint_btn(c: Control, b: Btn) -> void:
	var sc := 1.0 + 0.05 * b.hov
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
	Ui.panel(c, rr, bg, border, 16, 4, 8)
	Ui.text(c, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + (13 if b.big else 9)), b.text, 38 if b.big else 25, tc, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 0)
	if b.adjust.is_valid() and b.hov > 0.1:
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

func _lock(c: Control, p: Vector2) -> void:
	c.draw_arc(p + Vector2(0, -8), 15, PI, TAU, 16, Color("c8c8d0"), 7.0, true)
	Ui.panel(c, Rect2(p + Vector2(-22, -8), Vector2(44, 36)), Color("e8b83a"), Color("5a3a0a"), 7, 3, 0)
	c.draw_circle(p + Vector2(0, 8), 5, Color("5a3a0a"))

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
