extends Node2D
## Boot + scene controller: bakes the art atlas, shows the title (with a live
## attract-mode game behind it) and starts / restarts runs.
##
## Dev flags (after `--`):
##   --gallery --out=<dir>        render the sprite sheet and quit
##   --bot [--seconds=N --steps=N --char=id --diff=N --t0=N]
##                                 autoplay for balance / crash testing
##   --shots=10,60,120 --out=dir  save screenshots at those run-times (with --bot)

var title: Title = null
var run: Run = null
var demo_run: Run = null
var cur_char: String = "cap"
var out_dir: String = ""
var gallery: bool = false
var auto_bot: bool = false
var bot_seconds: float = 600.0
var bot_steps: int = 1
var bot_char: String = "cap"
var bot_diff: int = 1
var bot_t0: float = 0.0
var shot_times: Array = []
var shot_idx: int = 0
var title_shot: bool = false
var flow: bool = false
var test_slider: bool = false
var hide_node: String = ""
var make_icon: bool = false
var title_page: String = ""
var test_coins: int = -1
var bot_idle: bool = false
var bot_skill: float = 1.0
var bot_give: String = ""
var bot_evo: bool = false
var ui_kind: String = ""
var ui_state: int = 0
var ui_clock: float = 0.0
var ui_at: float = 4.0
var clean_hud: bool = false
var exact_build: bool = false
var mute_audio: bool = false
var progress_demo: bool = false
var shot_delay: float = 3.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a == "--gallery":
			gallery = true
		elif a == "--bot":
			auto_bot = true
		elif a.begins_with("--ui="):
			ui_kind = a.substr(5)
			G.ui_hold = true
		elif a.begins_with("--give="):
			bot_give = a.substr(7)
		elif a == "--evo":
			bot_evo = true
		elif a.begins_with("--skill="):
			bot_skill = float(a.substr(8))
		elif a.begins_with("--hide="):
			hide_node = a.substr(7)
		elif a == "--clean":
			clean_hud = true
		elif a == "--exact":
			exact_build = true
		elif a.begins_with("--delay="):
			shot_delay = float(a.substr(8))
		elif a == "--progress":
			progress_demo = true
		elif a == "--mute":
			mute_audio = true
		elif a.begins_with("--ui-at="):
			ui_at = float(a.substr(8))
		elif a == "--make-icon":
			make_icon = true
		elif a == "--flow":
			flow = true
		elif a == "--test-slider":
			test_slider = true
		elif a == "--idle":
			bot_idle = true
		elif a.begins_with("--page="):
			title_page = a.substr(7)
		elif a.begins_with("--coins="):
			test_coins = int(a.substr(8))
		elif a == "--title-shot":
			title_shot = true
		elif a.begins_with("--seconds="):
			bot_seconds = float(a.substr(10))
		elif a.begins_with("--steps="):
			bot_steps = int(a.substr(8))
		elif a.begins_with("--char="):
			bot_char = a.substr(7)
		elif a.begins_with("--diff="):
			bot_diff = int(a.substr(7))
		elif a.begins_with("--t0="):
			bot_t0 = float(a.substr(5))
		elif a.begins_with("--shots="):
			for s in a.substr(8).split(","):
				shot_times.append(float(s))
	RenderingServer.set_default_clear_color(Color("0e1a14"))
	if mute_audio or G.test_mode:
		AudioServer.set_bus_mute(0, true)
	if G.test_mode and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await Baker.bake(self)
	if auto_bot:
		print("[bot] audio streams: %d sfx, %d music" % [Sfx.streams.size(), Sfx.music_streams.size()])
	if gallery:
		_run_gallery()
		return
	if auto_bot:
		G.data["settings"]["difficulty"] = bot_diff
		_begin_run(bot_char)
		return
	if make_icon:
		_run_make_icon()
		return
	if flow:
		_run_flow()
		return
	if test_slider:
		_run_test_slider()
		return
	if test_coins >= 0:
		G.data["coins"] = test_coins
	if progress_demo:
		# screenshots only: a believable mid-game save, kept in memory (never written)
		G.data["unlocked"] = ["cap", "ninja", "chef"]
		G.data["shop"] = {"might": 2, "health": 3, "speed": 1, "growth": 2, "greed": 1, "magnet": 1, "luck": 1}
		G.data["total_kills"] = 12345
		G.data["best_time"] = 487.0
		G.data["runs"] = 14
		G.data["wins"] = 1
	show_title()
	if title_page == "select":
		title._go(Title.P.SELECT)
	elif title_page == "shop":
		title._go(Title.P.SHOP)
	elif title_page == "options":
		title._go(Title.P.OPTIONS)
	elif title_page == "achievements":
		title._go(Title.P.ACHIEVEMENTS)
	if hide_node != "" and demo_run != null:
		match hide_node:
			"pj": demo_run.pj.visible = false
			"k0", "k1", "k2", "k3", "k5", "k6": demo_run.pj.debug_skip_kind = int(hide_node.substr(1))
			"pk": demo_run.pk.visible = false
			"en": demo_run.en.visible = false
			"fx": demo_run.fx.visible = false
			"world": demo_run.world.visible = false
			"player": demo_run.player.visible = false
	if title_shot:
		await get_tree().create_timer(shot_delay).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir + "/title_" + (title_page if title_page != "" else "main") + ".png")
		get_tree().quit()

# ----------------------------------------------------------------- flow
func show_title() -> void:
	_clear_all()
	Sfx.mute_gameplay = true
	demo_run = Run.new()
	demo_run.demo = true
	demo_run.char_id = G.data["selected"] if G.is_unlocked(G.data["selected"]) else "cap"
	demo_run.cam_bias = Vector2(-250, 10)
	add_child(demo_run)
	title = Title.new()
	title.demo_run = demo_run
	title.start_run.connect(_on_start)
	title.quit_game.connect(func(): get_tree().quit())
	add_child(title)
	Sfx.music("menu")

func _clear_all() -> void:
	if title != null:
		title.queue_free()
		title = null
	if demo_run != null:
		demo_run.queue_free()
		demo_run = null
	if run != null:
		run.queue_free()
		run = null

func _on_start(cid: String) -> void:
	cur_char = cid
	_begin_run(cid)

func _begin_run(cid: String) -> void:
	_clear_all()
	Sfx.mute_gameplay = false
	run = Run.new()
	run.char_id = cid
	run.finished.connect(_on_finished)
	run.start_exact = exact_build
	if auto_bot:
		run.fixed_dt = 1.0 / 60.0
		run.sim_steps = bot_steps
		run.start_t0 = bot_t0
		run.bot_idle = bot_idle
		run.bot_skill = bot_skill
		run.start_give = bot_give
		run.start_evo = bot_evo
	add_child(run)
	if clean_hud:
		run.hud.clean = true

func _on_finished(action: String) -> void:
	if action == "again":
		_begin_run(cur_char)
	else:
		show_title()

func _process(_dt: float) -> void:
	# restart the attract mode before it gets too hard to look at
	if demo_run != null and is_instance_valid(demo_run) and demo_run.t > 170.0:
		var old := demo_run
		demo_run = Run.new()
		demo_run.demo = true
		demo_run.char_id = old.char_id
		demo_run.cam_bias = old.cam_bias
		add_child(demo_run)
		title.demo_run = demo_run
		old.queue_free()
	if ui_kind != "" and run != null and is_instance_valid(run):
		if ui_state == 0 and run.t >= ui_at:
			ui_state = 1
			run.debug_ui(ui_kind)
		elif ui_state == 1:
			ui_clock += _dt
			if ui_clock > 3.2:
				ui_state = 2
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir + "/ui_" + ui_kind + ".png")
				get_tree().quit()
				return
	if auto_bot and run != null and is_instance_valid(run):
		if run.t >= bot_seconds:
			print("[bot] reached %ds: level=%d kills=%d hp=%d weapons=%d" % [int(run.t), run.level, run.kills, int(run.player.hp), run.weapons.size()])
			get_tree().quit()
			return
		if shot_idx < shot_times.size() and run.t >= shot_times[shot_idx]:
			_take_shot("shot_%03d.png" % int(shot_times[shot_idx]))
			shot_idx += 1

func _take_shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/" + file)

# --------------------------------------------------------- UI flow self-test
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _key(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _focus_title_btn(text: String) -> bool:
	for i in 14:
		if title.btns[title.focus].text == text:
			return true
		await _key("ui_down" if i % 3 != 2 else "ui_right")
		await _wait(0.05)
	return title.btns[title.focus].text == text

func _run_flow() -> void:
	G.save_path = "user://flow_test_save.json"
	G.load_save()
	show_title()
	await _wait(1.2)
	print("[flow] 1 title: page=%d focus='%s'" % [title.page, title.btns[title.focus].text])
	await _key("ui_accept")
	await _wait(0.6)
	print("[flow] 2 select page: page=%d (expect 1)" % title.page)
	var ok := await _focus_title_btn("COMEÇAR!")
	print("[flow] 3 keyboard reached START: %s" % ok)
	await _key("ui_accept")
	await _wait(1.2)
	print("[flow] 4 run started: %s state=%d" % [run != null, run.state if run else -1])
	var p0 := run.player.position
	Input.action_press("move_right")
	await _wait(1.5)
	Input.action_release("move_right")
	print("[flow] 5 moved: dx=%.0f (expect >150)" % (run.player.position.x - p0.x))
	await _key("dash")
	print("[flow] 6 dash cooldown after press: %.2f (expect >0)" % run.player.dash_cd)
	await _key("pause")
	await _wait(0.3)
	print("[flow] 7 paused: state=%d modal=%d (expect %d / %d)" % [run.state, run.hud.modal, Run.S.PAUSE, Hud.M.PAUSE])
	await _key("ui_down")
	await _wait(0.1)
	await _key("ui_accept")
	await _wait(0.2)
	print("[flow] 7b in-game options opened: modal=%d (expect %d)" % [run.hud.modal, Hud.M.OPTIONS])
	await _key("ui_cancel")
	await _wait(0.2)
	print("[flow] 7c back to pause: modal=%d (expect %d)" % [run.hud.modal, Hud.M.PAUSE])
	await _key("ui_up")
	await _wait(0.1)
	await _key("ui_accept")
	await _wait(0.3)
	print("[flow] 8 resumed: state=%d (expect %d)" % [run.state, Run.S.PLAY])
	run.debug_ui("levelup")
	await _wait(1.0)
	print("[flow] 9 levelup: state=%d modal=%d (expect %d / %d)" % [run.state, run.hud.modal, Run.S.LEVELUP, Hud.M.LEVELUP])
	var lv_before := run.weapons.size() + run.passives.size()
	await _key("ui_accept")
	await _wait(0.3)
	print("[flow] 10 picked: state=%d items %d->%d" % [run.state, lv_before, run.weapons.size() + run.passives.size()])
	run.debug_ui("chest")
	await _wait(2.4)
	await _key("ui_accept")
	await _wait(0.4)
	print("[flow] 11 chest taken: state=%d (expect %d)" % [run.state, Run.S.PLAY])
	var old_run := run
	run.debug_ui("over")
	await _wait(3.4)
	print("[flow] 12 game over: state=%d modal=%d coins=%d save_coins=%d" % [run.state, run.hud.modal, run.coins_banked, int(G.data["coins"])])
	await _key("ui_accept")
	await _wait(1.2)
	print("[flow] 13 again: new run=%s state=%d" % [run != null and run != old_run, run.state if run else -1])
	await _key("pause")
	await _wait(0.3)
	for i in 3:
		await _key("ui_down")
	await _wait(0.2)
	await _key("ui_accept")
	await _wait(1.2)
	print("[flow] 14 back to menu: title=%s run=%s" % [title != null, run != null])
	title._go(Title.P.ACHIEVEMENTS)
	await _wait(0.3)
	print("[flow] 15 achievements page: page=%d (expect %d)" % [title.page, Title.P.ACHIEVEMENTS])
	G.data["achievements"].clear()
	G.unlock_achievement("spa_day")
	await _wait(0.1)
	print("[flow] 16 achievement unlocked: has=%s toast_active=%s" % [G.has_achievement("spa_day"), G.toast_cur != null])
	title._go(Title.P.MAIN)
	await _wait(0.2)
	print("[flow] saved file exists: %s" % FileAccess.file_exists("user://flow_test_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://flow_test_save.json"))
	_clear_all()
	print("[flow] DONE")
	get_tree().quit()

class IconDraw extends Node2D:
	func _draw() -> void:
		var bg := Ui.sb(Color("66bb55"), Color("2a1810"), 54, 7, 0)
		draw_style_box(bg, Rect2(4, 4, 248, 248))
		draw_circle(Vector2(128, 120), 96, Color(1, 1, 1, 0.1))
		draw_circle(Vector2(128, 120), 66, Color(1, 1, 1, 0.1))
		Art.star4(self, Vector2(206, 62), 18.0, Color(1, 1, 0.8, 0.9), 0.3)
		Art.star4(self, Vector2(48, 96), 10.0, Color(1, 1, 0.8, 0.7), 0.0)
		draw_set_transform(Vector2(128, 214), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 82, Color(0, 0, 0, 0.25))
		Capy.draw(self, 0.4, 0.0, 1.0, 1.0, Color("b5824f"), "none", 0.0, Vector2.ZERO, true, Vector2(100, 206), 1.0, 2.05)

func _run_make_icon() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(IconDraw.new())
	add_child(vp)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_dir + "/icon.png")
	get_tree().quit()

func _run_gallery() -> void:
	var g := Gallery.new()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/gallery.png")
	G.tex.get_image().save_png(out_dir + "/atlas.png")
	get_tree().quit()

class Gallery extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("5fb35a"))
		var x := 40.0
		var y := 60.0
		var rowh := 0.0
		for k in G.spr:
			var r: Rect2 = G.spr[k]
			var sz: Vector2 = r.size * 0.5
			if k.begins_with("ic_") or k.begins_with("jacare") or k.begins_with("onca"):
				continue
			if x + sz.x > 1240.0:
				x = 40.0
				y += rowh + 10.0
				rowh = 0.0
			draw_texture_rect_region(G.tex, Rect2(Vector2(x, y), sz), r)
			x += sz.x + 8.0
			rowh = maxf(rowh, sz.y)
		var ix := 40.0
		for k in G.spr:
			if k.begins_with("ic_"):
				var r: Rect2 = G.spr[k]
				draw_texture_rect_region(G.tex, Rect2(Vector2(ix, 560), r.size * 0.5), r)
				ix += 62.0
		draw_texture_rect_region(G.tex, Rect2(Vector2(40, 330), G.spr["jacare_0"].size * 0.5), G.spr["jacare_0"])
		draw_texture_rect_region(G.tex, Rect2(Vector2(340, 330), G.spr["onca_1"].size * 0.5), G.spr["onca_1"])
		draw_rect(Rect2(560, 300, 720, 420), Color("5fb35a"))
		var i := 0
		for cid in Defs.CHAR_ORDER:
			var d: Dictionary = Defs.CHARACTERS[cid]
			Capy.draw(self, 1.0 + i * 0.4, 0.0 if i % 2 == 0 else 1.0, 1.0, 1.0, d["body"], d["hat"], 0.0, Vector2.ZERO, cid == "cap", Vector2(640 + i * 125, 700), 1.0, 1.0)
			i += 1
		Capy.draw(self, 0.3, 0.0, 1.0, 1.0, Defs.CHARACTERS["cap"]["body"], "none", 0.0, Vector2.ZERO, true, Vector2(780, 560), 1.0, 3.6)

func _run_test_slider() -> void:
	print("--- Running Slider Unit Tests ---")
	show_title()
	title._go(Title.P.OPTIONS)
	await _wait(0.1)
	
	# Find master volume button in Title Options
	var master_btn: Title.Btn = null
	for b in title.btns:
		if b.data != null and str(b.data) == "master":
			master_btn = b
			break
	assert(master_btn != null, "Master button in Title Options must exist")
	
	G.set_setting("master", 0.8)
	var center := master_btn.rect.get_center()
	var sr_x := master_btn.rect.size.x * 0.5 - 220.0
	var track_x0 := sr_x + 3.0
	var track_len := 140.0 - 6.0
	
	# 1. Clicking label: must NOT change volume
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(master_btn.rect.position.x + 30.0, center.y)
	title.on_input(ev)
	assert(is_equal_approx(float(G.data["settings"]["master"]), 0.8), "Clicking label must not change volume")
	print("[PASS] Title: Clicking label does not increase volume")
	
	# 2. Clicking slider at 30%
	var click_30_x := center.x + (track_x0 + track_len * 0.3)
	ev.position = Vector2(click_30_x, center.y)
	title.on_input(ev)
	assert(is_equal_approx(float(G.data["settings"]["master"]), 0.3), "Clicking at 30% must set volume to 0.3")
	assert(title.dragging_slider == "master", "Title: dragging_slider must be 'master'")
	print("[PASS] Title: Clicking slider sets value directly to 30%")
	
	# 3. Dragging to the left (all the way to 0%)
	var ev_motion := InputEventMouseMotion.new()
	ev_motion.position = Vector2(center.x + (track_x0 - 20.0), center.y)
	title.on_input(ev_motion)
	assert(is_equal_approx(float(G.data["settings"]["master"]), 0.0), "Title: dragging left must decrease to 0.0")
	print("[PASS] Title: Dragging left decreases volume smoothly to 0%")
	
	# 4. Dragging to the right to 85%
	var sc := 1.0 + 0.04 * master_btn.hov
	ev_motion.position = Vector2(center.x + (track_x0 + track_len * 0.85) * sc, center.y)
	title.on_input(ev_motion)
	assert(is_equal_approx(float(G.data["settings"]["master"]), 0.85), "Title: dragging right must update to 0.85")
	print("[PASS] Title: Dragging right increases volume to 85%")
	
	# 5. Releasing mouse
	var ev_up := InputEventMouseButton.new()
	ev_up.button_index = MOUSE_BUTTON_LEFT
	ev_up.pressed = false
	ev_up.position = ev_motion.position
	title.on_input(ev_up)
	assert(title.dragging_slider == "", "Title: dragging must stop on mouse release")
	print("[PASS] Title: Mouse release stops dragging")
	
	# 6. Mouse wheel down (-5%) & up (+5%)
	var ev_wheel_down := InputEventMouseButton.new()
	ev_wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev_wheel_down.pressed = true
	ev_wheel_down.position = center
	title.on_input(ev_wheel_down)
	assert(is_equal_approx(float(G.data["settings"]["master"]), 0.80), "Title: wheel down must decrease by 5%")
	
	var ev_wheel_up := InputEventMouseButton.new()
	ev_wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_wheel_up.pressed = true
	ev_wheel_up.position = center
	title.on_input(ev_wheel_up)
	assert(is_equal_approx(float(G.data["settings"]["master"]), 0.85), "Title: wheel up must increase by 5%")
	print("[PASS] Title: Mouse wheel adjusts volume by 5%")
	
	# 7. Step clicks left (-5%) and right (+5%)
	var ev_step_down := InputEventMouseButton.new()
	ev_step_down.button_index = MOUSE_BUTTON_LEFT
	ev_step_down.pressed = true
	ev_step_down.position = Vector2(center.x + (sr_x - 20.0), center.y)
	title.on_input(ev_step_down)
	assert(is_equal_approx(float(G.data["settings"]["master"]), 0.80), "Title: click left of slider steps down 5%")
	
	var ev_step_up := InputEventMouseButton.new()
	ev_step_up.button_index = MOUSE_BUTTON_LEFT
	ev_step_up.pressed = true
	ev_step_up.position = Vector2(center.x + (sr_x + 160.0), center.y)
	title.on_input(ev_step_up)
	assert(is_equal_approx(float(G.data["settings"]["master"]), 0.85), "Title: click right of slider steps up 5%")
	print("[PASS] Title: Step clicks left/right adjust volume by 5%")
	
	# 8. Test in-game Pause Options (hud.gd)
	_begin_run("cap")
	await _wait(0.2)
	run.hud._open_options()
	await _wait(0.1)
	
	var sfx_btn: Hud.Btn = null
	for b in run.hud.btns:
		if b.data != null and str(b.data) == "sfx":
			sfx_btn = b
			break
	assert(sfx_btn != null, "SFX button in Hud Options must exist")
	
	G.set_setting("sfx", 0.9)
	var h_center := sfx_btn.rect.get_center()
	var h_sr_x := sfx_btn.rect.size.x * 0.5 - 220.0
	var h_track_x0 := h_sr_x + 3.0
	var h_track_len := 140.0 - 6.0
	
	# Click label in HUD: no change
	ev.position = Vector2(sfx_btn.rect.position.x + 30.0, h_center.y)
	run.hud.on_input(ev)
	assert(is_equal_approx(float(G.data["settings"]["sfx"]), 0.9), "Hud: clicking label must not change volume")
	print("[PASS] Hud: Clicking label does not increase volume")
	
	# Click slider at 40% in HUD
	var h_sc := 1.0 + 0.04 * sfx_btn.hov
	ev.position = Vector2(h_center.x + (h_track_x0 + h_track_len * 0.4) * h_sc, h_center.y)
	run.hud.on_input(ev)
	assert(is_equal_approx(float(G.data["settings"]["sfx"]), 0.4), "Hud: clicking at 40% must set volume to 0.4")
	assert(run.hud.dragging_slider == "sfx", "Hud: dragging_slider must be 'sfx'")
	print("[PASS] Hud: Clicking slider sets value directly to 40%")
	
	# Drag left in HUD to 0%
	ev_motion.position = Vector2(h_center.x + (h_track_x0 - 20.0), h_center.y)
	run.hud.on_input(ev_motion)
	assert(is_equal_approx(float(G.data["settings"]["sfx"]), 0.0), "Hud: dragging left must decrease to 0.0")
	print("[PASS] Hud: Dragging left decreases volume smoothly to 0%")
	
	# Drag right in HUD to 70%
	h_sc = 1.0 + 0.04 * sfx_btn.hov
	ev_motion.position = Vector2(h_center.x + (h_track_x0 + h_track_len * 0.7) * h_sc, h_center.y)
	run.hud.on_input(ev_motion)
	assert(is_equal_approx(float(G.data["settings"]["sfx"]), 0.7), "Hud: dragging right must update to 0.7")
	print("[PASS] Hud: Dragging right increases volume to 70%")
	
	# Release in HUD
	ev_up.position = ev_motion.position
	run.hud.on_input(ev_up)
	assert(run.hud.dragging_slider == "", "Hud: dragging must stop on mouse release")
	print("[PASS] Hud: Mouse release stops dragging")
	
	# 9. Test Pause / ESC behavior and Space / Dash prevention
	print("--- Running Pause & Dash Unit Tests ---")
	run.set_paused()
	assert(run.state == Run.S.PAUSE, "State must be PAUSE")
	assert(run.hud.modal == Hud.M.PAUSE, "Modal must be PAUSE")

	# Player presses ESC while paused
	Input.action_press("pause")
	Input.action_press("ui_cancel")
	var ev_esc := InputEventKey.new()
	ev_esc.keycode = KEY_ESCAPE
	ev_esc.physical_keycode = KEY_ESCAPE
	ev_esc.pressed = true
	run.hud.on_input(ev_esc)

	assert(run.state == Run.S.PLAY, "State must be PLAY after pressing ESC")
	assert(run.hud.modal == Hud.M.NONE, "Modal must be NONE after pressing ESC")

	# Simulate frame process where 'pause' action was pressed
	run._process(0.016)
	assert(run.state == Run.S.PLAY, "Game must NOT immediately re-pause on next frame after pressing ESC!")

	Input.action_release("pause")
	Input.action_release("ui_cancel")

	# Advance time past unpause_cooldown
	for _i in 20:
		run._process(0.016)
	assert(run.unpause_cooldown == 0.0, "Cooldown should expire after 0.2s")
	print("[PASS] Pause: Pressing ESC unpauses and does not immediately re-pause")

	# Test Space on 'Continuar' doesn't dash
	run.set_paused()
	assert(run.state == Run.S.PAUSE, "State must be PAUSE")
	assert(run.hud.focus == 0, "Continuar button should be focused")
	assert(run.player.dash_cd <= 0.0, "Dash should be ready")

	Input.action_press("ui_accept")
	Input.action_press("dash")
	var ev_space := InputEventKey.new()
	ev_space.keycode = KEY_SPACE
	ev_space.physical_keycode = KEY_SPACE
	ev_space.pressed = true
	run.hud.on_input(ev_space)

	assert(run.state == Run.S.PLAY, "State must be PLAY after pressing Space on Continuar")
	assert(run.hud.modal == Hud.M.NONE, "Modal must be NONE")

	# Advance process and simulation
	run._process(0.016)
	assert(run.player.dash_cd <= 0.0, "Player must NOT dash upon resuming with Space!")
	assert(run.player.dash_t <= 0.0, "Player dash_t must be 0")

	Input.action_release("ui_accept")
	Input.action_release("dash")
	print("[PASS] Pause: Pressing Space to resume does NOT trigger an accidental dash")

	# Test ESC navigation in Options
	run.set_paused()
	run.hud._open_options()
	assert(run.hud.modal == Hud.M.OPTIONS, "Modal must be OPTIONS")

	Input.action_press("pause")
	Input.action_press("ui_cancel")
	run.hud.on_input(ev_esc)
	assert(run.hud.modal == Hud.M.PAUSE, "First ESC in Options must go back to PAUSE")
	assert(run.state == Run.S.PAUSE, "State must still be PAUSE")

	# Second ESC from Pause resumes
	run.hud.on_input(ev_esc)
	assert(run.state == Run.S.PLAY, "Second ESC must resume the game")
	assert(run.hud.modal == Hud.M.NONE, "Modal must be NONE")
	run._process(0.016)
	assert(run.state == Run.S.PLAY, "Game must remain in PLAY")

	Input.action_release("pause")
	Input.action_release("ui_cancel")
	print("[PASS] Options: ESC returns to Pause, and next ESC unpauses cleanly")

	print("--- ALL SLIDER & PAUSE TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)
