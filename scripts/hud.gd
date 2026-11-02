class_name Hud extends CanvasLayer
## In-run interface: bars, timers, announcements and every modal
## (level-up cards, chest slot machine, pause, game over, victory).

enum M { NONE, LEVELUP, CHEST, PAUSE, OPTIONS, OVER, WIN }

class Btn:
	var rect := Rect2()
	var text := ""
	var data = null
	var cb: Callable = Callable()
	var enabled: bool = true
	var kind: int = 1            # 0 card, 1 button
	var hov: float = 0.0
	var adjust: Callable = Callable()

class Canvas extends Control:
	var hud: Hud
	func _draw() -> void:
		hud.paint(self)
	func _input(ev: InputEvent) -> void:
		hud.on_input(ev)

var run: Run
var canvas: Canvas
var modal: int = M.NONE
var btns: Array[Btn] = []
var focus: int = 0
var modal_t: float = 0.0
var card_info: Array = []
var cards: Array = []
var result: Dictionary = {}
var hurt_flash: float = 0.0
var low_hp: float = 0.0
var bot: bool = false
var announce_text: String = ""
var announce_col := Color.WHITE
var announce_t: float = 0.0
var announce_dur: float = 2.0
var milestone_text: String = ""
var milestone_t: float = 0.0
var banner_title: String = ""
var banner_sub: String = ""
var banner_col := Color.RED
var banner_t: float = 0.0
var hint_t: float = 0.0
var copied_t: float = 0.0
var show_fps: bool = false
var bot_timer: float = 0.0
var last_mouse := Vector2(-1, -1)
var last_nav_ms: int = 0
var chest_revealed: bool = false
var levelup_no: int = 1
var clock: float = 0.0
var clean: bool = false          # screenshots: hide hints and the BOT tag
var dragging_slider: String = ""

func setup(r: Run) -> void:
	run = r
	layer = 10
	canvas = Canvas.new()
	canvas.hud = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(canvas)
	canvas.resized.connect(func(): if modal != M.NONE: _layout())
	G.language_changed.connect(func(): if modal != M.NONE: _layout())
	if run.demo:
		canvas.visible = false
	else:
		hint_t = 13.0 if int(G.data["runs"]) < 4 else 5.0

func set_bot(b: bool) -> void:
	bot = b

# ------------------------------------------------------------- public API
func announce(text: String, col: Color, dur: float) -> void:
	announce_text = text
	announce_col = col
	announce_t = dur
	announce_dur = dur

func milestone(text: String) -> void:
	milestone_text = text
	milestone_t = 2.4
	Sfx.play("milestone", -4.0)

func banner(title: String, sub: String, col: Color) -> void:
	banner_title = title
	banner_sub = sub
	banner_col = col
	banner_t = 2.6

func _open(m: int) -> void:
	dragging_slider = ""
	modal = m
	modal_t = 0.0
	focus = 0
	bot_timer = 0.0
	last_mouse = canvas.get_local_mouse_position()
	chest_revealed = false

func show_levelup(choices: Array, lv_no: int, reroll_only: bool = false) -> void:
	cards = choices
	card_info.clear()
	for c in choices:
		card_info.append(run.describe(c))
	levelup_no = lv_no
	if not reroll_only or modal != M.LEVELUP:
		_open(M.LEVELUP)
	else:
		modal_t = 0.15
	_layout()

func show_chest(rewards: Array) -> void:
	cards = rewards
	card_info.clear()
	for c in rewards:
		card_info.append(run.describe(c))
	_open(M.CHEST)
	_layout()

func show_pause() -> void:
	_open(M.PAUSE)
	_layout()

func show_over(res: Dictionary) -> void:
	result = res
	_open(M.OVER)
	_layout()
	if G.test_mode:
		print("[bot] DEAD t=%s level=%d kills=%d coins=%d" % [G.fmt_time(res["time"]), res["level"], res["kills"], res["coins"]])

func show_win(res: Dictionary) -> void:
	result = res
	_open(M.WIN)
	_layout()
	if G.test_mode:
		print("[bot] WIN t=%s level=%d kills=%d coins=%d" % [G.fmt_time(res["time"]), res["level"], res["kills"], res["coins"]])

func close_modal() -> void:
	dragging_slider = ""
	modal = M.NONE
	btns.clear()

# ------------------------------------------------------------------ layout
func _add_btn(text: String, rect: Rect2, cb: Callable, kind: int = 1, enabled: bool = true) -> Btn:
	var b := Btn.new()
	b.text = text
	b.rect = rect
	b.cb = cb
	b.kind = kind
	b.enabled = enabled
	btns.append(b)
	return b

func _layout() -> void:
	btns.clear()
	var vs := canvas.size
	match modal:
		M.LEVELUP:
			var n := cards.size()
			var cw := 250.0
			var ch := 336.0
			var gap := 26.0
			var total := n * cw + (n - 1) * gap
			var x0 := (vs.x - total) * 0.5
			var y0 := vs.y * 0.5 - ch * 0.5 + 18.0
			for i in n:
				var b := _add_btn("", Rect2(x0 + i * (cw + gap), y0, cw, ch), _pick_card.bind(i), 0)
				b.data = i
			_add_btn("%s  (%d)" % [G.T("reroll"), run.rerolls_left], Rect2(vs.x * 0.5 - 110.0, y0 + ch + 30.0, 220.0, 50.0), _do_reroll, 1, run.rerolls_left > 0)
		M.CHEST:
			var n2 := cards.size()
			var cw2 := 220.0
			var ch2 := 300.0
			var gap2 := 22.0
			var total2 := n2 * cw2 + (n2 - 1) * gap2
			var x02 := (vs.x - total2) * 0.5
			var y02 := vs.y * 0.5 - ch2 * 0.5
			for i in n2:
				var b2 := _add_btn("", Rect2(x02 + i * (cw2 + gap2), y02, cw2, ch2), Callable(), 0)
				b2.data = i
				b2.enabled = false
			_add_btn(G.T("take"), Rect2(vs.x * 0.5 - 120.0, y02 + ch2 + 34.0, 240.0, 58.0), _take_chest, 1, false)
			focus = btns.size() - 1
		M.PAUSE:
			var pw := 640.0
			var ph := 480.0
			var ptop := vs.y * 0.5 - ph * 0.5
			var bx := vs.x * 0.5 - 150.0
			var by := ptop + 242.0
			_add_btn(G.T("resume"), Rect2(bx, by, 300, 52), _resume)
			_add_btn(G.T("options"), Rect2(bx, by + 64, 300, 50), _open_options)
			_add_btn(G.T("menu"), Rect2(bx, by + 126, 300, 48), _quit_menu)
		M.OPTIONS:
			var pw2 := 580.0
			var ph2 := 570.0
			var ptop2 := vs.y * 0.5 - ph2 * 0.5
			var bx2 := vs.x * 0.5 - 250.0
			var by2 := ptop2 + 74.0
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
				var ob := _add_btn(rows[i][1], Rect2(bx2, by2 + i * 48.0, 500, 42), _opt_click.bind(rows[i][0], rows[i][2]))
				ob.adjust = _opt_adjust.bind(rows[i][0], rows[i][2])
				ob.data = rows[i][0]
			_add_btn(G.T("back"), Rect2(vs.x * 0.5 - 110, by2 + rows.size() * 48.0 + 14.0, 220, 48), _back_to_pause)
		M.OVER, M.WIN:
			var bx2 := vs.x * 0.5 - 150.0
			var is_win := modal == M.WIN
			var ph2 := 610.0 if is_win else 548.0
			var ptop := vs.y * 0.5 - ph2 * 0.5 - 6.0
			var by2 := ptop + ph2 - 26.0 - (224.0 if is_win else 162.0)
			var yy := by2
			if modal == M.WIN:
				_add_btn(G.T("endless"), Rect2(bx2 - 30, yy, 360, 52), _endless)
				yy += 62.0
			_add_btn(G.T("again"), Rect2(bx2, yy, 300, 52), _again)
			_add_btn(G.T("copy") if copied_t <= 0.0 else G.T("copied"), Rect2(bx2, yy + 62.0, 300, 46), _copy)
			_add_btn(G.T("menu"), Rect2(bx2, yy + 118.0, 300, 46), _quit_menu)
	focus = clampi(focus, 0, maxi(0, btns.size() - 1))
	if modal == M.CHEST:
		focus = btns.size() - 1

# ---------------------------------------------------------------- actions
func _pick_card(i: int) -> void:
	Sfx.play("ui_click")
	close_modal()
	run.choose(cards[i])

func _do_reroll() -> void:
	run.reroll()

func _take_chest() -> void:
	Sfx.play("ui_click")
	close_modal()
	run.take_chest()

func _resume() -> void:
	Sfx.play("ui_click")
	close_modal()
	run.resume()

func _quit_menu() -> void:
	Sfx.play("ui_click")
	close_modal()
	run.request_finish("menu")

func _again() -> void:
	Sfx.play("ui_click")
	close_modal()
	run.request_finish("again")

func _endless() -> void:
	Sfx.play("ui_click")
	close_modal()
	run.continue_endless()

func _open_options() -> void:
	Sfx.play("ui_click")
	_open(M.OPTIONS)
	_layout()

func _back_to_pause() -> void:
	Sfx.play("ui_click")
	_open(M.PAUSE)
	focus = 1
	_layout()

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

func _share_text() -> String:
	var r := result
	var win_s := G.T("share_win") if bool(r.get("victory", false)) else ""
	return G.T("share_text") % [G.fmt_time(r["time"]), G.fmt_num(int(r["kills"])), int(r["level"]), win_s]

func _copy() -> void:
	DisplayServer.clipboard_set(_share_text())
	copied_t = 2.5
	Sfx.play("coin")
	_layout()

# -------------------------------------------------------------------- tick
func tick(dt: float) -> void:
	clock += dt
	hurt_flash = maxf(0.0, hurt_flash - dt * 2.2)
	if announce_t > 0.0:
		announce_t -= dt
	if milestone_t > 0.0:
		milestone_t -= dt
	if banner_t > 0.0:
		banner_t -= dt
	if hint_t > 0.0 and run.t > 0.5:
		hint_t -= dt
	if copied_t > 0.0:
		copied_t -= dt
		if copied_t <= 0.0 and (modal == M.OVER or modal == M.WIN):
			_layout()
	if modal != M.NONE:
		modal_t += dt
		_hover(dt)
		if modal == M.CHEST:
			var rev := modal_t >= 1.55
			if rev and not chest_revealed:
				chest_revealed = true
				Sfx.play("slot", -2.0, 1.2)
				run.fx.confetti(run.player.position, 22)
				for b in btns:
					if b.kind == 1:
						b.enabled = true
			elif not rev and fmod(modal_t, 0.12) < dt:
				Sfx.play("ui_hover", -14.0, 1.0 + randf() * 0.4)
		if (bot or G.test_mode) and not G.ui_hold:
			_bot_act(dt)
	if canvas != null and canvas.visible:
		canvas.queue_redraw()

func _hover(dt: float) -> void:
	if dragging_slider != "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging_slider = ""
		G.save()
	var mp := canvas.get_local_mouse_position()
	if dragging_slider == "" and mp.distance_to(last_mouse) > 2.0:
		last_mouse = mp
		for i in btns.size():
			if btns[i].enabled and btns[i].rect.has_point(mp):
				if focus != i:
					focus = i
					Sfx.play("ui_hover", -10.0)
				break
	for i in btns.size():
		btns[i].hov = move_toward(btns[i].hov, 1.0 if i == focus else 0.0, dt * 9.0)

func _bot_act(dt: float) -> void:
	bot_timer += dt
	if bot_timer < 0.25:
		return
	bot_timer = 0.0
	match modal:
		M.LEVELUP:
			var best := 0
			var best_score := -1.0
			for i in cards.size():
				var ty: String = cards[i]["type"]
				var sc := randf() * 0.5
				match ty:
					"evo": sc += 10.0
					"wup": sc += 3.0
					"wnew": sc += 2.5 if run.weapons.size() < 4 else 0.5
					"pup": sc += 1.5
					"pnew": sc += 1.0
				if sc > best_score:
					best_score = sc
					best = i
			_pick_card(best)
		M.CHEST:
			if chest_revealed:
				_take_chest()
		M.PAUSE:
			_resume()
		M.OPTIONS:
			_back_to_pause()
		M.OVER, M.WIN:
			if G.test_mode:
				get_tree().quit()

# ------------------------------------------------------------------- input
func on_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F3:
		show_fps = not show_fps
	if modal == M.NONE:
		return
	var handled := false
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = ev.position
		for i in btns.size():
			if btns[i].rect.has_point(mp) and btns[i].enabled:
				focus = i
				if modal == M.OPTIONS and btns[i].data != null and str(btns[i].data) in ["master", "music", "sfx"]:
					_handle_slider_click(btns[i], mp)
				else:
					_activate(i, 0)
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
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if modal == M.LEVELUP and ev.keycode >= KEY_1 and ev.keycode <= KEY_3:
			var idx: int = ev.keycode - KEY_1
			if idx < cards.size():
				_pick_card(idx)
			handled = true
		elif ev.is_action_pressed("reroll") and modal == M.LEVELUP and run.rerolls_left > 0:
			_do_reroll()
			handled = true
	if not handled and (ev is InputEventKey or ev is InputEventJoypadButton or ev is InputEventJoypadMotion or ev is InputEventAction):
		if ev is InputEventJoypadMotion:
			var now := Time.get_ticks_msec()
			if now - last_nav_ms < 190:
				return
			last_nav_ms = now
		var is_esc: bool = (ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_ESCAPE or ev.physical_keycode == KEY_ESCAPE or ev.key_label == KEY_ESCAPE))
		if ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("pause") or is_esc:
			if modal == M.PAUSE:
				_resume()
				handled = true
			elif modal == M.OPTIONS:
				_back_to_pause()
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
			_activate(focus, 0)
			handled = true
	if handled:
		get_viewport().set_input_as_handled()

func _activate(i: int, dir: int) -> void:
	if i < 0 or i >= btns.size():
		return
	var b := btns[i]
	if not b.enabled:
		return
	if b.cb.is_valid():
		b.cb.call()

func _nav(dir: Vector2) -> void:
	if btns.is_empty():
		return
	var cur := btns[focus].rect.get_center()
	# adjustable rows react to left/right
	if btns[focus].adjust.is_valid() and (dir == Vector2.LEFT or dir == Vector2.RIGHT):
		btns[focus].adjust.call(1 if dir == Vector2.RIGHT else -1)
		return
	var best := -1
	var bs := 1e12
	for i in btns.size():
		if i == focus or not btns[i].enabled:
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

# ------------------------------------------------------------------- paint
func paint(c: Control) -> void:
	var vs := c.size
	if not run.demo:
		_paint_hud(c, vs)
	if modal != M.NONE:
		c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.03, 0.08, 0.66))
		match modal:
			M.LEVELUP: _paint_levelup(c, vs)
			M.CHEST: _paint_chest(c, vs)
			M.PAUSE: _paint_pause(c, vs)
			M.OPTIONS: _paint_options_modal(c, vs)
			M.OVER, M.WIN: _paint_end(c, vs)
	_paint_overlays(c, vs)

func _paint_overlays(c: Control, vs: Vector2) -> void:
	var night := clampf((run.minutes() - 7.0) / 2.0, 0.0, 1.0)
	c.draw_texture_rect(Ui.vignette(), Rect2(Vector2.ZERO, vs), false, Color(0.02, 0.03, 0.1, 0.32 + 0.25 * night))
	var red := hurt_flash * 0.5 + low_hp * (0.28 + 0.14 * sin(clock * 7.0))
	if red > 0.01:
		c.draw_texture_rect(Ui.vignette(), Rect2(Vector2.ZERO, vs), false, Color(1.0, 0.08, 0.08, clampf(red, 0.0, 0.85)))
	if run.fx != null and run.fx.flash_a > 0.01:
		var fc := run.fx.flash_col
		c.draw_rect(Rect2(Vector2.ZERO, vs), Color(fc.r, fc.g, fc.b, run.fx.flash_a * 0.55))
	if show_fps:
		Ui.text(c, Vector2(10, vs.y - 10), "FPS %d  enemies %d  proj %d" % [Engine.get_frames_per_second(), run.en.count(), run.pj.list.size()], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)

func _paint_hud(c: Control, vs: Vector2) -> void:
	var pl := run.player
	# --- XP bar
	var xr := run.xp / maxf(1.0, run.xp_need)
	Ui.bar(c, Rect2(0, 0, vs.x, 20), xr, Color("39d9c0"), Color(0.05, 0.08, 0.14, 0.85), 4)
	Ui.text(c, Vector2(12, 16), "%s %d" % [G.T("level"), run.level], 17, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	# --- clock
	var ts := G.fmt_time(run.t)
	Ui.ctext(c, Vector2(vs.x * 0.5, 48), ts, 38, Color("fff3dc"), 7)
	if run.endless:
		Ui.ctext(c, Vector2(vs.x * 0.5 + 84, 48), "∞", 34, Color("ffd43b"), 6)
	# --- counters
	Ui.icon(c, "skull", Vector2(vs.x - 168, 46), 28)
	Ui.text(c, Vector2(vs.x - 14 - 130, 56), G.fmt_num(run.kills), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 130.0, 5)
	Ui.icon(c, "coin", Vector2(vs.x - 168, 82), 28)
	Ui.text(c, Vector2(vs.x - 14 - 130, 92), G.fmt_num(int(run.coins_run)), 26, Color("ffd43b"), HORIZONTAL_ALIGNMENT_RIGHT, 130.0, 5)
	# --- weapons / passives
	var x := 14.0
	for w in run.weapons:
		_slot(c, Vector2(x, 32), w.icon(), w.level, w.evolved, true)
		x += 46.0
	x = 14.0
	for pid in run.passives:
		_slot(c, Vector2(x, 78), Defs.PASSIVES[pid]["icon"], int(run.passives[pid]), false, false)
		x += 42.0
	# --- hp bar + dash
	var bw := 380.0
	var bx := vs.x * 0.5 - bw * 0.5
	var by := vs.y - 50.0
	var hr := pl.hp / maxf(1.0, pl.max_hp)
	var hc := Color("5fd35a")
	if hr < 0.5:
		hc = Color("f2c23a")
	if hr < 0.25:
		hc = Color("ff4d4d")
	Ui.bar(c, Rect2(bx, by, bw, 26), hr, hc, Color(0.1, 0.05, 0.06, 0.85), 10)
	Ui.ctext(c, Vector2(vs.x * 0.5, by + 13), "%d / %d" % [int(ceil(pl.hp)), int(pl.max_hp)], 18, Color.WHITE, 4)
	Ui.icon(c, "heart", Vector2(bx - 20, by + 13), 32)
	var dc := Vector2(bx + bw + 38, by + 13)
	var dk := 1.0 - clampf(pl.dash_cd / maxf(0.01, pl.dash_cd_max * pl.dashcd_mult), 0.0, 1.0)
	c.draw_circle(dc, 21, Color(0.05, 0.08, 0.14, 0.85))
	c.draw_arc(dc, 18, -PI * 0.5, -PI * 0.5 + TAU * dk, 32, Color("4dd2ff") if dk >= 1.0 else Color("7a8aa8"), 5.0, true)
	if dk >= 1.0:
		Ui.ctext(c, dc, "»", 26, Color("c8f0ff"), 4)
	else:
		Ui.ctext(c, dc, "%.1f" % maxf(0.0, pl.dash_cd), 14, Color("c0c8d8"), 3)
	if pl.in_water:
		Ui.ctext(c, Vector2(vs.x * 0.5, by - 18), "~ %s ~" % G.T("water"), 17, Color("8fe0ff"), 4)
	# --- boss bar
	var br := run.en.boss_ref
	if br != null and not br.dead:
		var wbw := 560.0
		var wx := vs.x * 0.5 - wbw * 0.5
		Ui.ctext(c, Vector2(vs.x * 0.5, 96), G.L(br.name_pair), 22, Color("ff6b6b"), 5)
		Ui.bar(c, Rect2(wx, 112, wbw, 20), br.hp / br.max_hp, Color("ff4d4d"), Color(0.14, 0.04, 0.04, 0.88), 8)
	# --- chest arrows
	for k in run.pk.chests():
		_chest_arrow(c, vs, k.pos)
	# --- announcement / milestone / banner / hint
	if announce_t > 0.0:
		var k2 := 1.0 - announce_t / announce_dur
		var sc := 1.0 + maxf(0.0, 0.6 - k2 * 5.0)
		var a := clampf(announce_t * 2.5, 0.0, 1.0)
		var col := announce_col
		col.a = a
		Ui.ctext(c, Vector2(vs.x * 0.5, 160), announce_text, int(44 * sc), col, 8)
	if milestone_t > 0.0:
		var a2 := clampf(milestone_t, 0.0, 1.0)
		var sc2 := 1.0 + 0.08 * sin(clock * 12.0)
		Ui.ctext(c, Vector2(vs.x * 0.5, 218), milestone_text, int(30 * sc2), Color(1.0, 0.85, 0.25, a2), 6)
	if banner_t > 0.0:
		_paint_banner(c, vs)
	if hint_t > 0.0 and modal == M.NONE and not clean:
		var ha := clampf(hint_t, 0.0, 1.0)
		var hy := vs.y - 150.0
		Ui.ctext(c, Vector2(vs.x * 0.5, hy), G.hint_move_str(), 20, Color(1, 1, 1, ha), 5)
		Ui.ctext(c, Vector2(vs.x * 0.5, hy + 30), G.hint_dash_str(), 20, Color(1, 1, 1, ha), 5)
		Ui.ctext(c, Vector2(vs.x * 0.5, hy + 60), G.T("hint_auto"), 18, Color(1.0, 0.85, 0.4, ha), 5)
	if bot and not clean:
		Ui.text(c, Vector2(vs.x - 90, vs.y - 12), "BOT", 18, Color("ff5fd2"))

func _slot(c: Control, p: Vector2, icon_key: String, lv: int, evolved: bool, is_weapon: bool) -> void:
	var r := Rect2(p, Vector2(40, 40))
	var border := Color("ffd43b") if evolved else (Color("4dd2ff") if is_weapon else Color("7be04a"))
	Ui.panel(c, r, Color(0.08, 0.12, 0.2, 0.86), border, 8, 2, 0)
	Ui.icon(c, icon_key, r.get_center(), 34)
	Ui.text(c, Vector2(p.x + 20, p.y + 46), str(lv) if not evolved else "★", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 20.0, 4)

func _chest_arrow(c: Control, vs: Vector2, wpos: Vector2) -> void:
	var cen := run.cam.get_screen_center_position()
	var sp := (wpos - cen) * run.cam.zoom.x + vs * 0.5
	var margin := 46.0
	if sp.x > margin and sp.x < vs.x - margin and sp.y > margin and sp.y < vs.y - margin:
		return
	var p := Vector2(clampf(sp.x, margin, vs.x - margin), clampf(sp.y, margin + 60.0, vs.y - margin - 30.0))
	var dirv := (sp - vs * 0.5).normalized()
	var pulse := 1.0 + 0.1 * sin(clock * 8.0)
	c.draw_circle(p, 26 * pulse, Color(0.1, 0.07, 0.02, 0.8))
	c.draw_arc(p, 26 * pulse, 0.0, TAU, 28, Color("ffd43b"), 3.0, true)
	Ui.icon(c, "bau", p, 34)
	var tip := p + dirv * 40.0
	var side := Vector2(-dirv.y, dirv.x)
	c.draw_colored_polygon(PackedVector2Array([tip + dirv * 10.0, tip - dirv * 4.0 + side * 9.0, tip - dirv * 4.0 - side * 9.0]), Color("ffd43b"))

func _paint_banner(c: Control, vs: Vector2) -> void:
	var k := 1.0 - banner_t / 2.6
	var a := clampf(minf(k * 6.0, banner_t * 2.0), 0.0, 1.0)
	var h := 130.0 * clampf(k * 8.0, 0.0, 1.0)
	var cy := vs.y * 0.36
	c.draw_rect(Rect2(0, cy - h * 0.5, vs.x, h), Color(0.08, 0.0, 0.0, 0.78 * a))
	c.draw_rect(Rect2(0, cy - h * 0.5, vs.x, 4), Color(banner_col.r, banner_col.g, banner_col.b, a))
	c.draw_rect(Rect2(0, cy + h * 0.5 - 4, vs.x, 4), Color(banner_col.r, banner_col.g, banner_col.b, a))
	var slide := (1.0 - Ui.ease_out_back(clampf(k * 4.0, 0.0, 1.0))) * 300.0
	var col := banner_col
	col.a = a
	Ui.ctext(c, Vector2(vs.x * 0.5 - slide, cy - 14), banner_title, 62, col, 9)
	Ui.ctext(c, Vector2(vs.x * 0.5 + slide, cy + 40), banner_sub, 26, Color(1, 1, 1, a), 5)

# --------------------------------------------------------------- modals
func _paint_levelup(c: Control, vs: Vector2) -> void:
	var wob := 1.0 + 0.04 * sin(clock * 6.0)
	Ui.ctext(c, Vector2(vs.x * 0.5, vs.y * 0.5 - 250), G.T("level_up"), int(64 * wob), Color("ffd43b"), 10)
	Ui.ctext(c, Vector2(vs.x * 0.5, vs.y * 0.5 - 196), "%s %d  •  %s" % [G.T("level"), levelup_no + 0, G.T("choose_up")], 22, Color("c8d8f0"), 5)
	for i in btns.size():
		var b := btns[i]
		if b.kind == 0:
			_paint_card(c, b, i, card_info[int(b.data)], int(b.data), 1.0)
		else:
			_paint_button(c, b, i)
	if run.rerolls_left > 0:
		var rh := "%s %s  (%d)" % [G.p_reroll(), G.T("reroll"), run.rerolls_left]
		Ui.ctext(c, Vector2(vs.x * 0.5, vs.y * 0.5 + 238 + 54), rh, 16, Color(1, 1, 1, 0.65), 3)

func _paint_card(c: Control, b: Btn, i: int, info: Dictionary, idx: int, reveal: float) -> void:
	var k := clampf((modal_t - idx * 0.09) / 0.32, 0.0, 1.0)
	var off := (1.0 - Ui.ease_out_back(k)) * 70.0
	var r := b.rect
	var center := r.get_center() + Vector2(0, off)
	var sc := (1.0 + 0.055 * b.hov) * clampf(k * 1.4, 0.0, 1.0) * reveal
	var tag_col: Color = info["tag_col"]
	if b.hov > 0.05:
		var pulse := 0.5 + 0.5 * sin(clock * 8.0)
		tag_col = tag_col.lerp(Color("ffffff"), pulse * 0.5)
	c.draw_set_transform(center, 0.0, Vector2(sc, sc))
	var rr := Rect2(-r.size * 0.5, r.size)
	var bg := Color("17294a").lerp(Color("22407a"), b.hov)
	Ui.panel(c, rr, bg, tag_col, 18, 3 + int(3 * b.hov), 10 + int(6 * b.hov))
	# tag pill
	var tw := 86.0
	Ui.panel(c, Rect2(rr.position + Vector2(12, 12), Vector2(tw + 18, 26)), tag_col, tag_col.darkened(0.3), 13, 2, 0)
	Ui.text(c, rr.position + Vector2(12, 31), info["tag"], 15, Color("1a1020"), HORIZONTAL_ALIGNMENT_CENTER, tw + 18, 0)
	# icon
	var ic := Vector2(0, rr.position.y + 112)
	c.draw_circle(ic, 58, Color(tag_col.r, tag_col.g, tag_col.b, 0.22))
	c.draw_circle(ic, 46, Color(0.05, 0.08, 0.16, 0.6))
	Ui.icon(c, info["icon"], ic + Vector2(0, -1), 92.0 + 6.0 * sin(clock * 3.0 + idx))
	# title + description
	Ui.fit(c, Vector2(0, rr.position.y + 188), info["title"], rr.size.x - 20, 25, Color("fff3dc"), 4)
	Ui.wrap(c, Vector2(rr.position.x + 14, rr.position.y + 250), info["desc"], rr.size.x - 28, 16, Color("c8d8f0"), 4)
	if info["hint"] != "":
		Ui.wrap(c, Vector2(rr.position.x + 10, rr.position.y + rr.size.y - 32), info["hint"], rr.size.x - 20, 13, Color("ffd27a"), 1)
	if modal == M.LEVELUP:
		var key_hint := "[%d]" % (idx + 1) if not G.is_gamepad else ("(A)" if b.hov > 0.5 else "")
		if key_hint != "":
			Ui.text(c, Vector2(rr.position.x + rr.size.x - 38, rr.position.y + 32), key_hint, 14, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
	if b.hov > 0.01 and modal == M.LEVELUP:
		c.draw_arc(Vector2.ZERO, 1.0, 0.0, 0.0, 3, Color.WHITE, 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_button(c: Control, b: Btn, i: int, big: bool = false) -> void:
	var sc := 1.0 + 0.06 * b.hov
	var center := b.rect.get_center()
	c.draw_set_transform(center, 0.0, Vector2(sc, sc))
	var rr := Rect2(-b.rect.size * 0.5, b.rect.size)
	var bg := Color("ff9a1f").lerp(Color("ffc44a"), b.hov)
	var border := Color("5a2c0a")
	var tc := Color("2a1208")
	if not b.enabled:
		bg = Color("4a5568")
		border = Color("2a303a")
		tc = Color("8a94a6")
	elif b.hov > 0.05:
		var pulse := 0.5 + 0.5 * sin(clock * 8.0)
		border = Color("ffd43b").lerp(Color("ffffff"), pulse * 0.7)
	Ui.panel(c, rr, bg, border, 14, 3 if b.hov <= 0.05 else 5, 6 + int(4 * b.hov))
	if b.data != null and str(b.data) in ["master", "music", "sfx"]:
		Ui.text(c, Vector2(rr.position.x + 24, rr.position.y + rr.size.y * 0.5 + 8), b.text, 20, tc, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 0)
		var vol: float = float(G.data["settings"][str(b.data)])
		var sr := Rect2(rr.position.x + rr.size.x - 220, rr.position.y + rr.size.y * 0.5 - 7, 140, 14)
		var is_active := dragging_slider == str(b.data)
		Ui.slider(c, sr, vol, Color("0b4a44") if not b.hov > 0.05 else Color("06302c"), is_active, b.hov)
		Ui.text(c, Vector2(rr.position.x + rr.size.x - 70, rr.position.y + rr.size.y * 0.5 + 8), "%d%%" % int(round(vol * 100.0)), 18, tc, HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 0)
	else:
		Ui.text(c, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + 8), b.text, 22 if not big else 28, tc, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 0)
	if b.adjust.is_valid() and b.hov > 0.1 and not (b.data != null and str(b.data) in ["master", "music", "sfx"]):
		Ui.text(c, Vector2(rr.position.x + 12, rr.position.y + rr.size.y * 0.5 + 8), "◀", 18, tc, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 0)
		Ui.text(c, Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5 + 8), "▶", 18, tc, HORIZONTAL_ALIGNMENT_RIGHT, rr.size.x - 12, 0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_chest(c: Control, vs: Vector2) -> void:
	Ui.ctext(c, Vector2(vs.x * 0.5, vs.y * 0.5 - 230), G.T("chest"), int(62 * (1.0 + 0.04 * sin(clock * 8.0))), Color("ffd43b"), 10)
	var spin := modal_t < 1.55
	var keys := ["ic_orange", "ic_flipflop", "ic_cheese", "ic_thunder", "ic_birds", "ic_trevo", "ic_cafe", "ic_vuvuzela", "ic_tenis", "ic_cofrinho"]
	for i in btns.size():
		var b := btns[i]
		if b.kind == 0:
			var idx := int(b.data)
			if spin:
				var r := b.rect
				var ctr := r.get_center()
				Ui.panel(c, r, Color("17294a"), Color("ffd43b"), 18, 3, 10)
				var f := int(modal_t * 14.0 + idx * 3) % keys.size()
				c.draw_circle(ctr + Vector2(0, -20), 60, Color(1, 0.85, 0.2, 0.18))
				Ui.icon(c, keys[f], ctr + Vector2(0, -20), 96.0 + 8.0 * sin(modal_t * 30.0))
				Ui.ctext(c, ctr + Vector2(0, 100), "???", 30, Color(1, 1, 1, 0.7), 5)
			else:
				var kk := clampf((modal_t - 1.55) / 0.35, 0.0, 1.0)
				var tmp := b.hov
				b.hov = maxf(b.hov, 0.0)
				var save_t := modal_t
				modal_t = 0.5 + idx * 0.09
				_paint_card(c, b, i, card_info[idx], idx, Ui.ease_out_back(kk))
				modal_t = save_t
		else:
			_paint_button(c, b, i, true)

func _paint_pause(c: Control, vs: Vector2) -> void:
	var pw := 640.0
	var ph := 480.0
	var pr := Rect2(vs.x * 0.5 - pw * 0.5, vs.y * 0.5 - ph * 0.5, pw, ph)
	Ui.panel(c, pr, Color("14213d"), Color("ffb02e"), 22, 4, 14)
	Ui.ctext(c, Vector2(vs.x * 0.5, pr.position.y + 46), G.T("paused"), 50, Color("ffd43b"), 9)
	# current build
	var x := vs.x * 0.5 - (run.weapons.size() * 46.0) * 0.5
	for w in run.weapons:
		_slot(c, Vector2(x, pr.position.y + 92), w.icon(), w.level, w.evolved, true)
		x += 46.0
	x = vs.x * 0.5 - (run.passives.size() * 42.0) * 0.5
	for pid in run.passives:
		_slot(c, Vector2(x, pr.position.y + 142), Defs.PASSIVES[pid]["icon"], int(run.passives[pid]), false, false)
		x += 42.0
	var summary := "%s %s   •   %s %s   •   %s %s" % [G.T("survived"), G.fmt_time(run.t), G.T("kills"), G.fmt_num(run.kills), G.T("coins"), G.fmt_num(int(run.coins_run))]
	Ui.ctext(c, Vector2(vs.x * 0.5, pr.position.y + 212), summary, 18, Color("c8d8f0"), 4, false)
	for i in btns.size():
		_paint_button(c, btns[i], i)
	var hint := "%s   •   %s %s" % [G.hint_dash_str(), G.p_cancel(), G.T("resume")]
	Ui.ctext(c, Vector2(vs.x * 0.5, pr.position.y + pr.size.y - 24), hint, 14, Color(1, 1, 1, 0.45), 2, false)

func _paint_options_modal(c: Control, vs: Vector2) -> void:
	var pw := 580.0
	var ph := 570.0
	var pr := Rect2(vs.x * 0.5 - pw * 0.5, vs.y * 0.5 - ph * 0.5, pw, ph)
	Ui.panel(c, pr, Color("14213d"), Color("ffb02e"), 22, 4, 14)
	Ui.ctext(c, Vector2(vs.x * 0.5, pr.position.y + 44), G.T("options"), 42, Color("ffd43b"), 8)
	for i in btns.size():
		_paint_button(c, btns[i], i)
	var hint := "%s %s" % [G.p_cancel(), G.T("back")]
	Ui.ctext(c, Vector2(vs.x * 0.5, pr.position.y + pr.size.y - 18), hint, 14, Color(1, 1, 1, 0.45), 2, false)

func _paint_end(c: Control, vs: Vector2) -> void:
	var win := modal == M.WIN
	var pw := 600.0
	var ph := 610.0 if win else 548.0
	var pr := Rect2(vs.x * 0.5 - pw * 0.5, vs.y * 0.5 - ph * 0.5 - 6.0, pw, ph)
	var k := Ui.ease_out_back(clampf(modal_t / 0.4, 0.0, 1.0))
	c.draw_set_transform(pr.get_center(), 0.0, Vector2(k, k))
	var rr := Rect2(-pr.size * 0.5, pr.size)
	Ui.panel(c, rr, Color("14213d"), Color("ffd43b") if win else Color("ff7a5a"), 24, 4, 16)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if k < 0.99:
		return
	var top := pr.position.y
	var title := G.T("victory") if win else G.T("game_over")
	Ui.ctext(c, Vector2(vs.x * 0.5, top + 52), title, 50 if win else 38, Color("ffd43b") if win else Color("ff9a7a"), 9)
	Ui.ctext(c, Vector2(vs.x * 0.5, top + 92), G.T("victory_sub") if win else G.T("game_over_sub"), 19, Color("c8d8f0"), 4, false)
	var rows := [
		[G.T("survived"), G.fmt_time(result["time"]), "ic_cafe"],
		[G.T("kills"), G.fmt_num(int(result["kills"])), "skull"],
		[G.T("level_reached"), str(int(result["level"])), "ic_cursinho"],
		[G.T("coins_earned"), "+" + G.fmt_num(int(result["coins"])), "coin"],
	]
	var ry := top + 130.0
	for i in rows.size():
		var rk := clampf((modal_t - 0.35 - i * 0.12) / 0.25, 0.0, 1.0)
		var xo := (1.0 - rk) * 60.0
		var row_r := Rect2(pr.position.x + 40 + xo, ry + i * 44.0, pw - 80, 38)
		Ui.panel(c, row_r, Color(0.08, 0.13, 0.24, 0.9 * rk), Color(0.2, 0.3, 0.5, 0.6 * rk), 10, 2, 0)
		Ui.icon(c, rows[i][2], row_r.position + Vector2(24, 19), 28, Color(1, 1, 1, rk))
		Ui.text(c, row_r.position + Vector2(48, 27), rows[i][0], 18, Color(0.85, 0.92, 1.0, rk), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 0, false)
		Ui.text(c, row_r.position + Vector2(row_r.size.x - 220, 28), rows[i][1], 24, Color(1.0, 0.95, 0.7, rk), HORIZONTAL_ALIGNMENT_RIGHT, 206.0, 4)
	if bool(result.get("record", false)) and modal_t > 1.0:
		var s := 1.0 + 0.06 * sin(clock * 9.0)
		Ui.ctext(c, Vector2(vs.x * 0.5, ry + 4 * 44.0 + 22), G.T("record"), int(28 * s), Color("ff5fd2"), 6)
	for i in btns.size():
		_paint_button(c, btns[i], i)
	if win and modal_t > 0.8:
		Ui.ctext(c, Vector2(vs.x * 0.5, pr.position.y + pr.size.y - 12), G.L(["Feito por Eduardo Braga  •  edubraga7.itch.io/capivara-caos", "Made by Eduardo Braga  •  edubraga7.itch.io/capivara-caos"]), 13, Color(1, 1, 1, 0.65), 3, false)
