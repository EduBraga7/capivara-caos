class_name Run extends Node2D
## One play session: owns the player, managers, timeline, upgrades and flow.

signal finished(action: String)     # "menu" | "again"

enum S { INTRO, PLAY, LEVELUP, CHEST, PAUSE, OVER, WIN }

const DIFF_HP: Array[float] = [0.8, 1.0, 1.3]
const DIFF_DMG: Array[float] = [0.7, 1.0, 1.25]
const DIFF_SPAWN: Array[float] = [0.8, 1.0, 1.25]
const DIFF_COINS: Array[float] = [1.0, 1.0, 1.5]
const TOD := [
	[0.0, Color(1.0, 0.96, 0.9)], [90.0, Color(1, 1, 1)], [300.0, Color(1.0, 0.99, 0.94)],
	[390.0, Color(1.0, 0.8, 0.62)], [430.0, Color(1.0, 0.72, 0.66)], [470.0, Color(0.8, 0.7, 0.94)], [560.0, Color(0.58, 0.63, 0.92)],
	[620.0, Color(0.5, 0.56, 0.9)],
]
const KILL_COL := {
	"mosquito": Color("a03030"), "barata": Color("8a4a1f"), "rato": Color("9b9ba8"), "pombo": Color("8f9fbf"),
	"sapo": Color("79ab3e"), "gamba": Color("55555f"), "voadora": Color("b8481f"), "jacare": Color("4a8a43"),
	"onca": Color("eeaa38"), "sucuri": Color("5da13a"),
}
const MILESTONES := [100, 500, 1000, 2000, 4000]

var state: int = S.INTRO
var demo: bool = false
var bot_ctrl: bool = false
var fixed_dt: float = 0.0
var invulnerable: bool = false
var char_id: String = "cap"
var diff: int = 1
var rng := RandomNumberGenerator.new()

# progress
var t: float = 0.0
var kills: int = 0
var coins_run: float = 0.0
var level: int = 1
var xp: float = 0.0
var xp_need: float = 5.0
var pending_levels: int = 0
var rerolls_left: int = 0
var revives_left: int = 0
var endless: bool = false
var stat_damage: float = 0.0
var stat_dodges: int = 0
var weapons: Array[Weapon] = []
var passives: Dictionary = {}
var choices: Array = []
var chest_rewards: Array = []

# timeline
var event_idx: int = 0
var elite_idx: int = 0
var spawn_acc: float = 0.0
var calm_until: float = 0.0
var next_endless_event: float = 0.0
var milestone_idx: int = 0
var last_dodge_t: float = -9.0
var boss_alive: bool = false
var end_timer: float = -1.0
var end_victory: bool = false
var coins_banked: int = 0

# feel
var hitstop_t: float = 0.0
var slowmo_t: float = 0.0
var slowmo_scale: float = 1.0
var trauma: float = 0.0
var cam_pos := Vector2.ZERO
var zoom_target: float = 1.0
var view := Vector2(1280, 720)
var real_dt: float = 0.016
var time_alive: float = 0.0
var unpause_cooldown: float = 0.0

# bot state
var bot_move := Vector2.ZERO
var bot_dash: bool = false
var bot_wander := Vector2.RIGHT
var bot_wander_t: float = 0.0
var bot_side: float = 1.0
var bot_log_t: float = 0.0
var bot_idle: bool = false
var bot_skill: float = 1.0
var hurt_count: int = 0
var sim_steps: int = 1
var start_t0: float = 0.0
var start_give: String = ""
var start_evo: bool = false
var start_exact: bool = false
var cam_bias := Vector2.ZERO

# nodes
var player: Player
var world: World
var en: Enemies
var pj: Projs
var pk: Pickups
var fx: Fx
var hud: Hud
var cam: Camera2D
var ground: ColorRect
var ground_mat: ShaderMaterial
var canvas_mod: CanvasModulate

func _ready() -> void:
	rng.randomize()
	if not demo:
		diff = int(G.setting("difficulty"))
	else:
		diff = 0
	player = Player.new()
	player.run = self
	world = World.new()
	en = Enemies.new()
	pj = Projs.new()
	pk = Pickups.new()
	fx = Fx.new()
	hud = Hud.new()
	cam = Camera2D.new()
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	ground = ColorRect.new()
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/ground.gdshader")
	ground.material = ground_mat
	ground.color = Color.WHITE
	add_child(ground)
	world.setup(self, rng.randi())
	add_child(world)
	fx.setup(self)
	add_child(fx.decal_layer)
	pk.setup(self)
	add_child(pk)
	en.setup(self)
	add_child(en)
	pj.setup(self)
	add_child(pj)
	add_child(player)
	add_child(fx)
	add_child(cam)
	cam.make_current()
	add_child(hud)
	hud.setup(self)
	begin()

func begin() -> void:
	player.setup(self, char_id)
	var cd: Dictionary = Defs.CHARACTERS[char_id]
	add_weapon(cd["weapon"])
	rerolls_left = int(G.meta_bonus("reroll"))
	revives_left = int(G.meta_bonus("revival"))
	recalc_stats()
	player.hp = player.max_hp
	xp_need = Defs.xp_need(1)
	if demo:
		invulnerable = true
		bot_ctrl = true
		for wid in ["flipflop", "cheese", "thunder", "birds"]:
			add_weapon(wid)
		for w in weapons:
			for i in rng.randi_range(1, 3):
				w.level_up()
		recalc_stats()
	cam_pos = player.position
	view = get_viewport_rect().size
	if not demo:
		Sfx.music("battle")
		cam.zoom = Vector2(1.25, 1.25)
	else:
		t = 40.0
	state = S.PLAY
	if G.test_mode:
		bot_ctrl = true
		hud.set_bot(true)
	if start_t0 > 0.0:
		debug_fastforward(start_t0)
	if start_give != "":
		debug_give(start_give, start_evo)

func debug_give(spec: String, evo: bool) -> void:
	for part in spec.split(","):
		var kv := part.split(":")
		var wid := kv[0]
		var lv := int(kv[1]) if kv.size() > 1 else 1
		if Defs.PASSIVES.has(wid):
			for i in lv:
				add_passive(wid)
			continue
		var w := get_weapon(wid)
		if w == null and Defs.WEAPONS.has(wid):
			w = add_weapon(wid)
		if w == null:
			continue
		while w.level < lv:
			w.level_up()
		if evo and w.is_max():
			w.evolve()
	recalc_stats()

func debug_ui(kind: String) -> void:
	match kind:
		"levelup":
			pending_levels = 1
			_begin_levelup()
		"chest":
			open_chest(2)
		"pause":
			set_paused()
		"options":
			set_paused()
			hud._open_options()
		"over":
			player.hp = 0.0
			player_down()
		"win":
			_victory()

## Test helper: jump to a later point of the run with a plausible build.
func debug_fastforward(t0: float) -> void:
	t = t0
	while event_idx < Defs.EVENTS.size() and float(Defs.EVENTS[event_idx]["t"]) < t0:
		event_idx += 1
	while elite_idx < Defs.ELITE_TIMES.size() and Defs.ELITE_TIMES[elite_idx] < t0:
		elite_idx += 1
	var target_level := 1 + int(t0 / 24.0)
	while level < target_level:
		level += 1
		if start_exact:
			continue
		var picks := build_choices(3)
		var best: Dictionary = picks[0]
		for c in picks:
			if c["type"] == "wup" or c["type"] == "wnew":
				best = c
				break
		apply_choice(best)
	xp_need = Defs.xp_need(level)
	player.hp = player.max_hp
	print("[bot] fast-forward t=%d level=%d weapons=%d passives=%d" % [int(t0), level, weapons.size(), passives.size()])

# ------------------------------------------------------------- scaling
func minutes() -> float:
	return t / 60.0

func hp_mult() -> float:
	var m := minutes()
	return (1.0 + 0.30 * m + 0.04 * m * m) * DIFF_HP[diff]

func boss_hp_mult() -> float:
	return DIFF_HP[diff] * (1.0 + 0.02 * minutes())

func dmg_mult() -> float:
	return (1.0 + 0.045 * minutes()) * DIFF_DMG[diff]

func spd_mult() -> float:
	return 1.0 + 0.018 * minf(minutes(), 14.0)

func enemy_cap() -> int:
	var c: float = (28.0 + t * 0.42) * DIFF_SPAWN[diff]
	if demo:
		c = maxf(c, 55.0)
	if boss_alive:
		c *= 0.55
	return mini(int(c), 340)

# ----------------------------------------------------------------- loop
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if fixed_dt > 0.0:
		dt = fixed_dt
	real_dt = dt
	view = get_viewport_rect().size
	en.view_half = view * 0.5 / cam.zoom
	pk.view_half = en.view_half
	world.view_half = en.view_half
	en.spawn_r = en.view_half.length() + 70.0
	var sim_dt := dt
	if hitstop_t > 0.0:
		hitstop_t -= dt
		sim_dt = 0.0
	elif slowmo_t > 0.0:
		slowmo_t -= dt
		sim_dt = dt * slowmo_scale
	if unpause_cooldown > 0.0:
		unpause_cooldown = maxf(0.0, unpause_cooldown - delta)
	if state == S.PLAY:
		if not demo and unpause_cooldown <= 0.0 and Input.is_action_just_pressed("pause"):
			set_paused()
		else:
			var steps := sim_steps if fixed_dt > 0.0 else 1
			for _s in steps:
				if state == S.PLAY:
					_sim(sim_dt)
	elif state == S.OVER or state == S.WIN:
		# let the world breathe behind the end screen
		fx.update(sim_dt * 0.5)
	if end_timer > 0.0:
		end_timer -= dt
		if end_timer <= 0.0:
			if end_victory:
				state = S.WIN
				hud.show_win(_result(true))
			else:
				state = S.OVER
				hud.show_over(_result(false))
	_camera(dt)
	_ground_update()
	hud.tick(minf(delta, 0.05))

func _sim(dt: float) -> void:
	t += dt
	time_alive += dt
	var input := Vector2.ZERO
	if bot_ctrl:
		Bot.think(self)
		input = bot_move
		if bot_dash:
			player.try_dash()
	else:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if unpause_cooldown <= 0.0 and Input.is_action_just_pressed("dash"):
			player.try_dash()
	player.update(dt, input)
	player.in_water = world.water_at(player.position)
	if not demo:
		if t >= 180.0:
			G.unlock_achievement("survive_3")
		if t >= 360.0:
			G.unlock_achievement("survive_6")
		if t >= 600.0:
			G.unlock_achievement("survive_10")
	world.update(dt)
	_timeline(dt)
	en.update(dt)
	pj.update(dt)
	pk.update(dt)
	fx.update(dt)
	_ambient(dt)
	_log_bot(dt)
	trauma = maxf(0.0, trauma - dt * 1.4)
	if player.hp < player.max_hp * 0.3 and state == S.PLAY and not demo:
		hud.low_hp = minf(1.0, hud.low_hp + dt * 2.0)
	else:
		hud.low_hp = maxf(0.0, hud.low_hp - dt * 2.0)

func _ambient(dt: float) -> void:
	var night := clampf((minutes() - 7.2) / 1.5, 0.0, 1.0)
	if night > 0.05 and rng.randf() < 3.0 * dt * night:
		var p := cam_pos + Vector2(rng.randf_range(-view.x, view.x) * 0.5, rng.randf_range(-view.y, view.y) * 0.5)
		fx.emit(p, Vector2(rng.randf_range(-12, 12), rng.randf_range(-14, 4)), rng.randf_range(2.0, 3.5), rng.randf_range(5.0, 8.0), Color(1.0, 0.95, 0.5, 0.8), 3, 0.0, 0.4)

func _tod() -> Color:
	var tt := t
	var a: Array = TOD[0]
	for i in range(1, TOD.size()):
		var b: Array = TOD[i]
		if tt <= float(b[0]):
			var k := (tt - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1], k)
		a = b
	return TOD[TOD.size() - 1][1]

func _log_bot(dt: float) -> void:
	if not G.test_mode:
		return
	bot_log_t -= dt
	if bot_log_t <= 0.0:
		bot_log_t = 5.0 if fixed_dt > 0.0 and sim_steps == 1 else 30.0
		print("[bot] t=%s lvl=%d kills=%d hp=%d/%d enemies=%d weapons=%d passives=%d fps=%d proc=%.1fms draws=%d prims=%d hurts=%d" % [G.fmt_time(t), level, kills, int(player.hp), int(player.max_hp), en.count(), weapons.size(), passives.size(), Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), hurt_count])

# --------------------------------------------------------------- camera
func _camera(dt: float) -> void:
	var look := player.vel * 0.12
	var target := player.position + look + cam_bias
	cam_pos = cam_pos.lerp(target, 1.0 - exp(-9.0 * dt))
	var sk := 1.0
	match int(G.setting("shake")):
		0: sk = 0.0
		2: sk = 0.45
	var tt := Time.get_ticks_msec() * 0.001
	var amp := trauma * trauma * 22.0 * sk
	var off := Vector2(sin(tt * 71.3) + sin(tt * 113.7) * 0.6, cos(tt * 83.1) + cos(tt * 97.9) * 0.6) * amp
	cam.global_position = cam_pos + off
	var z := cam.zoom.x
	z = lerpf(z, zoom_target, 1.0 - exp(-3.0 * dt))
	cam.zoom = Vector2(z, z)

func _ground_update() -> void:
	var center := cam.get_screen_center_position()
	var sz := view / cam.zoom.x + Vector2(120, 120)
	ground.size = sz
	ground.position = center - sz * 0.5
	ground_mat.set_shader_parameter("cam_pos", center)
	ground_mat.set_shader_parameter("view_size", sz)
	canvas_mod.color = _tod()

func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func hitstop(sec: float) -> void:
	hitstop_t = maxf(hitstop_t, sec)

func slowmo(sec: float, scale: float) -> void:
	slowmo_t = sec
	slowmo_scale = scale

func announce(text: String, col: Color = Color.WHITE, dur: float = 2.0) -> void:
	hud.announce(text, col, dur)

# ------------------------------------------------------------- timeline
func _timeline(dt: float) -> void:
	# scripted events
	if not endless and event_idx < Defs.EVENTS.size() and t >= float(Defs.EVENTS[event_idx]["t"]):
		_do_event(Defs.EVENTS[event_idx])
		event_idx += 1
	if elite_idx < Defs.ELITE_TIMES.size() and t >= Defs.ELITE_TIMES[elite_idx] and not endless:
		elite_idx += 1
		_spawn_elite()
	if endless and t >= next_endless_event:
		next_endless_event = t + 32.0
		var id := Defs.pick_weighted(Defs.wave_pool(t), rng)
		_ring(id, 30 + int(minutes() * 3.0))
		if rng.randf() < 0.6:
			_spawn_elite()
		announce(G.L(["Mais uma onda!", "Another wave!"]), Color("ff9a1f"), 1.6)
	# continuous spawning
	if t < calm_until:
		return
	spawn_acc += dt
	var interval: float = maxf(0.1, 0.66 - t / 900.0) / DIFF_SPAWN[diff]
	if demo:
		interval *= 0.4
	if endless:
		interval *= maxf(0.45, 1.0 - (t - 600.0) / 900.0)
	var guard := 0
	while spawn_acc >= interval and guard < 6:
		guard += 1
		spawn_acc -= interval
		if en.count() >= enemy_cap():
			spawn_acc = 0.0
			break
		var batch := 1 + int(t / 110.0)
		var pool := Defs.wave_pool(t)
		for i in batch:
			_spawn_wave_enemy(Defs.pick_weighted(pool, rng))

func _spawn_wave_enemy(id: String) -> void:
	var p := en.ring_pos()
	if id == "rato":
		var n := rng.randi_range(2, 4)
		for i in n:
			en.spawn(id, p + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)))
	else:
		en.spawn(id, p)

func _spawn_elite() -> void:
	var pool := Defs.wave_pool(t).duplicate()
	var id := Defs.pick_weighted(pool, rng)
	if id == "pombo":
		id = "sapo"
	var e := en.spawn(id, en.ring_pos(), true)
	if e != null:
		announce(G.L(["Elite à vista!", "Elite incoming!"]), Color("ff5555"), 1.6)
		Sfx.play("warning", -4.0)

func _ring(id: String, n: int) -> void:
	var cnt := int(n * DIFF_SPAWN[diff])
	for i in cnt:
		var a := TAU * float(i) / float(cnt)
		en.spawn(id, player.position + Vector2.from_angle(a) * (en.spawn_r * 0.9))

func _line(id: String, n: int) -> void:
	var side := rng.randf() * TAU
	var dirv := Vector2.from_angle(side)
	var perp := Vector2(-dirv.y, dirv.x)
	var base := player.position + dirv * (en.spawn_r * 0.95)
	var cnt := int(n * DIFF_SPAWN[diff])
	for i in cnt:
		en.spawn(id, base + perp * (float(i) - cnt * 0.5) * 42.0)

func _do_event(ev: Dictionary) -> void:
	var msg: String = G.L(ev["msg"])
	if G.test_mode:
		print("[bot] event %s at %s (%d enemies)" % [ev["kind"], G.fmt_time(t), en.count()])
	match ev["kind"]:
		"ring":
			_ring(ev["id"], ev["n"])
			announce(msg, Color("ffb02e"), 2.2)
			Sfx.play("warning", -2.0)
		"line", "flock":
			_line(ev["id"], ev["n"])
			announce(msg, Color("ffb02e"), 2.2)
			Sfx.play("warning", -2.0)
		"boss":
			_spawn_boss(ev["id"], msg, G.L(ev["sub"]))
		"calm":
			calm_until = t + 12.0
			announce(msg, Color("8fd3ff"), 3.0)
			pk.drop_item(player.position + Vector2(140, -60), Pickups.Kind.CHEST, 1)

func _spawn_boss(id: String, msg: String, sub: String) -> void:
	var p := player.position + Vector2.from_angle(rng.randf() * TAU) * (en.spawn_r * 0.8)
	var e := en.spawn(id, p)
	if e == null:
		return
	en.boss_ref = e
	boss_alive = true
	if id == "sucuri":
		e.boss = true
		zoom_target = 0.82
		Sfx.music("boss")
	hud.banner(msg, sub, Color("ff4d4d"))
	shake(0.6)
	slowmo(0.7, 0.35)
	Sfx.play("boss_roar", 0.0, 0.7)

# ----------------------------------------------------------- kill / drops
func on_kill(e: Enemy, silent: bool = false) -> void:
	if silent:
		return
	kills += 1
	if not demo:
		G.unlock_achievement("first_blood")
	var col: Color = KILL_COL.get(e.id, Color("c0c0c0"))
	if not silent:
		fx.burst(e.pos, col, 7 if not e.big else 40, 190.0 if not e.big else 480.0, 0.45, 3.2)
		fx.puff(e.pos, Color(col.r, col.g, col.b, 0.5), 2)
		fx.decal(e.pos + Vector2(0, e.r * 0.4), col.darkened(0.25), e.r * 1.1)
		if e.big:
			fx.big_explosion(e.pos, col)
			Sfx.play("kill_big", 0.0)
			shake(0.7)
		else:
			Sfx.play("kill", -10.0, 1.0 + randf() * 0.25)
	pk.drop_gem(e.pos, e.xp)
	var luck := player.luck
	if rng.randf() < 0.05 * (1.0 + luck):
		pk.drop_coin(e.pos + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10)), 1.0)
	var r := rng.randf()
	if r < 0.0035 * (1.0 + luck):
		pk.drop_item(e.pos, Pickups.Kind.HEAL)
	elif r < 0.0055 and t - pk.last_magnet_t > 45.0:
		pk.drop_item(e.pos, Pickups.Kind.MAGNET)
	elif r < 0.0068 and t - pk.last_bomb_t > 80.0:
		pk.drop_item(e.pos, Pickups.Kind.BOMB)
	if e.elite:
		pk.drop_item(e.pos, Pickups.Kind.CHEST, 1)
		for i in 6:
			pk.drop_coin(e.pos, 1.0)
		announce(G.L(["Elite derrotado!", "Elite down!"]), Color("ffd43b"), 1.2)
	if e.big:
		pk.drop_item(e.pos + Vector2(40, 0), Pickups.Kind.CHEST, 2)
		for i in 14:
			pk.drop_coin(e.pos, 1.0)
		boss_alive = false
		if not demo:
			if e.id == "jacare":
				G.unlock_achievement("boss_jacare")
			elif e.id == "onca":
				G.unlock_achievement("boss_onca")
			elif e.id == "sucuri" or e.boss:
				G.unlock_achievement("boss_sucuri")
		if e.boss or e.id == "sucuri":
			zoom_target = 1.0
			_victory()
		else:
			Sfx.music("battle")
	# milestones
	while milestone_idx < MILESTONES.size() and kills >= MILESTONES[milestone_idx]:
		var key := "milestone%d" % MILESTONES[milestone_idx]
		hud.milestone(G.T(key))
		milestone_idx += 1

func _victory() -> void:
	if not demo and diff >= 2:
		G.unlock_achievement("win_chaos")
	pending_levels = 0
	en.melt_all()
	fx.confetti(player.position, 60)
	fx.flash(0.8, Color(1, 1, 0.9))
	slowmo(1.4, 0.3)
	Sfx.play("win")
	Sfx.stop_music(1.0)
	end_victory = true
	end_timer = 1.8
	state = S.PLAY   # keep sim alive for the celebration
	invulnerable = true

func bomb() -> void:
	announce(G.T("bomb"), Color("ff6b6b"), 1.0)
	fx.flash(0.7, Color(1, 0.95, 0.8))
	fx.ring(player.position, 10.0, 900.0, 0.7, Color(1, 0.7, 0.3, 0.8), 8.0)
	for i in 5:
		fx.burst(player.position + Vector2.from_angle(randf() * TAU) * randf_range(60, 400), Color.from_hsv(randf(), 0.7, 1.0), 14, 240.0, 0.7, 4.0)
	shake(0.7)
	Sfx.play("explosion", 0.0, 0.8)
	en.clear_screen(900.0)

func perfect_dodge(e: Enemy) -> void:
	if t - last_dodge_t < 0.9:
		return
	last_dodge_t = t
	stat_dodges += 1
	if not demo:
		G.unlock_achievement("perfect_dodge")
	slowmo(0.55, 0.3)
	fx.ring(player.position, 10.0, 230.0, 0.45, Color(0.4, 0.9, 1.0, 0.9), 5.0)
	fx.glow_burst(player.position, Color(0.4, 0.9, 1.0, 0.8), 6, 180.0)
	fx.text(player.position + Vector2(0, -56), G.T("dodge"), Color("6fe3ff"), 28, 1.0)
	add_xp(2.0 + level * 0.25)
	Sfx.play("dodge", -2.0)

# -------------------------------------------------------------- player hp
func on_player_hurt(d: float) -> void:
	hurt_count += 1
	shake(0.35 + minf(d, 30.0) * 0.01)
	hitstop(0.045)
	Sfx.play("hurt", -2.0)
	fx.burst(player.position, Color(1.0, 0.35, 0.3), 8, 230.0, 0.5, 3.5)
	fx.text(player.position + Vector2(0, -40), "-%d" % int(d), Color("ff5050"), 24, 0.9)
	hud.hurt_flash = 1.0

func player_down() -> void:
	if revives_left > 0:
		revives_left -= 1
		player.hp = player.max_hp * 0.6
		player.inv = 2.5
		en.clear_screen(420.0)
		fx.ring(player.position, 10.0, 460.0, 0.6, Color(1, 0.9, 0.5, 0.9), 8.0)
		fx.confetti(player.position, 24)
		fx.flash(0.6, Color(1, 1, 0.8))
		announce(G.T("revived"), Color("ffd43b"), 1.8)
		Sfx.play("heal", 0.0, 0.8)
		return
	player.dead = true
	state = S.PLAY
	invulnerable = true
	Sfx.play("gameover")
	Sfx.stop_music(1.2)
	slowmo(1.2, 0.25)
	fx.big_explosion(player.position, Color("ff7a5a"))
	end_victory = false
	end_timer = 1.6

# ---------------------------------------------------------------- xp/coins
func add_xp(v: float) -> void:
	if end_timer > 0.0:
		return
	xp += v * player.growth
	var leveled := false
	while xp >= xp_need:
		xp -= xp_need
		level += 1
		xp_need = Defs.xp_need(level)
		pending_levels += 1
		leveled = true
		if not demo and level >= 20:
			G.unlock_achievement("level_20")
	if leveled and state == S.PLAY and not demo and not player.dead:
		_begin_levelup()
	elif leveled and demo:
		pending_levels = 0

func add_coins(v: float) -> void:
	coins_run += v * player.greed

func _begin_levelup() -> void:
	if pending_levels <= 0:
		return
	state = S.LEVELUP
	choices = build_choices(3)
	Sfx.play("levelup")
	Sfx.muffle(true)
	fx.ring(player.position, 10.0, 260.0, 0.5, Color(1.0, 0.9, 0.4, 0.9), 6.0)
	fx.confetti(player.position, 18)
	fx.text(player.position + Vector2(0, -60), G.T("level_up"), Color("ffd43b"), 30, 1.2)
	hud.show_levelup(choices, level - pending_levels + 1)

func choose(c: Dictionary) -> void:
	apply_choice(c)
	pending_levels -= 1
	Sfx.muffle(false)
	state = S.PLAY
	unpause_cooldown = 0.2
	Input.action_release("dash")
	if pending_levels > 0:
		_begin_levelup()

func reroll() -> void:
	if rerolls_left <= 0:
		return
	rerolls_left -= 1
	Sfx.play("reroll")
	choices = build_choices(3)
	hud.show_levelup(choices, level - pending_levels + 1, true)

# ---------------------------------------------------------------- upgrades
func get_weapon(id: String) -> Weapon:
	for w in weapons:
		if w.id == id:
			return w
	return null

func add_weapon(id: String) -> Weapon:
	var w := Weapons.create(self, id)
	weapons.append(w)
	if not demo and weapons.size() >= 6:
		G.unlock_achievement("arsenal")
	return w

func add_passive(id: String) -> void:
	passives[id] = int(passives.get(id, 0)) + 1
	recalc_stats()

func recalc_stats() -> void:
	var b: Dictionary = {}
	for pid in passives:
		var d: Dictionary = Defs.PASSIVES[pid]
		b[d["stat"]] = float(b.get(d["stat"], 0.0)) + float(d["per"]) * int(passives[pid])
	var cm: Dictionary = Defs.CHARACTERS[char_id]["mods"]
	var f := func(stat: String) -> float:
		return float(b.get(stat, 0.0)) + G.meta_bonus(stat) + float(cm.get(stat, 0.0))
	var p := player
	p.might = 1.0 + f.call("might")
	p.cdm = clampf(1.0 - f.call("cdr"), 0.3, 1.0)
	p.speed_mult = 1.0 + f.call("speed")
	var old_max := p.max_hp
	p.max_hp = 100.0 + f.call("maxhp")
	if old_max > 0.0 and p.max_hp > old_max:
		p.hp += p.max_hp - old_max
	p.hp = minf(p.hp, p.max_hp)
	p.armor = f.call("armor")
	p.regen = f.call("regen")
	p.pickup_r = 85.0 * (1.0 + f.call("magnet"))
	p.area = 1.0 + f.call("area")
	p.amount_bonus = int(b.get("amount", 0.0))
	p.growth = 1.0 + f.call("growth")
	p.luck = f.call("luck")
	p.greed = 1.0 + f.call("greed")
	p.crit = 0.05 + p.luck * 0.5
	p.dashcd_mult = 1.0 + float(cm.get("dashcd", 0.0))

func evolvable() -> Weapon:
	for w in weapons:
		if w.is_max() and not w.evolved and passives.has(w.def["evo"]["partner"]):
			return w
	return null

func build_choices(count: int, for_chest: bool = false) -> Array:
	var pool: Array = []
	var few := weapons.size() < 3
	for w in weapons:
		if not w.is_max():
			pool.append([3.2 if not for_chest else 3.0, {"type": "wup", "id": w.id}])
	for pid in passives:
		if int(passives[pid]) < int(Defs.PASSIVES[pid]["max"]):
			pool.append([2.4, {"type": "pup", "id": pid}])
	if weapons.size() < Defs.MAX_WEAPONS and not for_chest:
		for wid in Defs.WEAPON_ORDER:
			if get_weapon(wid) == null:
				pool.append([4.6 if few else 2.0, {"type": "wnew", "id": wid}])
	if passives.size() < Defs.MAX_PASSIVES and not for_chest:
		for pid in Defs.PASSIVE_ORDER:
			if not passives.has(pid):
				pool.append([1.9, {"type": "pnew", "id": pid}])
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for p in pool:
			total += p[0]
		var r := rng.randf() * total
		var pick := 0
		for i in pool.size():
			r -= pool[i][0]
			if r <= 0.0:
				pick = i
				break
		out.append(pool[pick][1])
		pool.remove_at(pick)
	if out.is_empty():
		out.append({"type": "heal"})
		out.append({"type": "coins"})
	elif out.size() < count and not for_chest:
		out.append({"type": "heal"} if out.size() % 2 == 0 else {"type": "coins"})
	return out

## Display data for one choice (used by the HUD cards).
func describe(c: Dictionary) -> Dictionary:
	var out := {"title": "", "desc": "", "icon": "ic_heart", "tag": "", "tag_col": Color.WHITE, "hint": ""}
	match c["type"]:
		"wnew":
			var d: Dictionary = Defs.WEAPONS[c["id"]]
			out["title"] = G.L(d["name"])
			out["desc"] = G.L(d["desc"])
			out["icon"] = d["icon"]
			out["tag"] = G.T("new")
			out["tag_col"] = Color("ff9a1f")
			out["hint"] = "%s %s" % [G.T("combines"), G.L(Defs.PASSIVES[d["evo"]["partner"]]["name"])]
		"wup":
			var w := get_weapon(c["id"])
			out["title"] = w.display_name()
			out["desc"] = Defs.level_text(w.id, w.level + 1)
			out["icon"] = w.icon()
			out["tag"] = "%s %d" % [G.T("level"), w.level + 1]
			out["tag_col"] = Color("4dd2ff")
			if w.level + 1 >= Defs.MAX_WEAPON_LEVEL:
				out["tag"] = "%s %d  MAX" % [G.T("level"), w.level + 1]
		"pnew":
			var d2: Dictionary = Defs.PASSIVES[c["id"]]
			out["title"] = G.L(d2["name"])
			out["desc"] = G.L(d2["desc"])
			out["icon"] = d2["icon"]
			out["tag"] = G.T("new")
			out["tag_col"] = Color("7be04a")
		"pup":
			var d3: Dictionary = Defs.PASSIVES[c["id"]]
			var lv := int(passives[c["id"]])
			out["title"] = G.L(d3["name"])
			out["desc"] = G.L(d3["desc"])
			out["icon"] = d3["icon"]
			out["tag"] = "%s %d" % [G.T("level"), lv + 1]
			out["tag_col"] = Color("3fd9a8")
		"evo":
			var w2 := get_weapon(c["id"])
			var evo: Dictionary = w2.def["evo"]
			out["title"] = G.L(evo["name"])
			out["desc"] = G.L(evo["desc"])
			out["icon"] = w2.icon()
			out["tag"] = G.T("evolution")
			out["tag_col"] = Color("ff5fd2")
		"heal":
			out["title"] = G.T("heal_item")
			out["desc"] = G.T("heal_desc")
			out["icon"] = "ic_heart"
			out["tag"] = "+"
			out["tag_col"] = Color("ff6b8b")
		"coins":
			out["title"] = G.T("coins_item")
			out["desc"] = G.T("coins_desc")
			out["icon"] = "ic_coins"
			out["tag"] = "+"
			out["tag_col"] = Color("ffd43b")
	return out

func apply_choice(c: Dictionary) -> void:
	match c["type"]:
		"wnew":
			add_weapon(c["id"])
		"wup":
			get_weapon(c["id"]).level_up()
		"pnew", "pup":
			add_passive(c["id"])
		"evo":
			var w := get_weapon(c["id"])
			w.evolve()
			announce("%s  %s" % [G.T("evolution"), w.display_name()], Color("ff5fd2"), 2.6)
			fx.confetti(player.position, 50)
			fx.flash(0.6, Color(1, 0.9, 1))
			Sfx.play("evolve")
			if not demo:
				G.unlock_achievement("first_evo")
				var ev_cnt := 0
				for wep in weapons:
					if wep.evolved:
						ev_cnt += 1
				if ev_cnt >= 3:
					G.unlock_achievement("triple_evo")
		"heal":
			player.heal(player.max_hp * 0.4)
		"coins":
			coins_run += 40.0
	recalc_stats()
	Sfx.play("pop", -6.0, 1.2)

func open_chest(tier: int) -> void:
	chest_rewards.clear()
	var evo := evolvable()
	if evo != null:
		chest_rewards.append({"type": "evo", "id": evo.id})
	var extra := 1 if tier <= 1 else 3
	var picks := build_choices(extra + 2, true)
	for c in picks:
		if chest_rewards.size() >= extra + (1 if evo != null else 0):
			break
		if c["type"] != "heal" and c["type"] != "coins":
			chest_rewards.append(c)
	if chest_rewards.is_empty():
		chest_rewards.append({"type": "coins"})
		chest_rewards.append({"type": "heal"})
	state = S.CHEST
	Sfx.play("chest")
	Sfx.muffle(true)
	hud.show_chest(chest_rewards)

func take_chest() -> void:
	for c in chest_rewards:
		apply_choice(c)
	chest_rewards.clear()
	Sfx.muffle(false)
	state = S.PLAY
	unpause_cooldown = 0.2
	Input.action_release("dash")

# ------------------------------------------------------------- flow control
func set_paused() -> void:
	if state != S.PLAY:
		return
	state = S.PAUSE
	Sfx.muffle(true)
	hud.show_pause()

func resume() -> void:
	if state == S.PAUSE:
		state = S.PLAY
		Sfx.muffle(false)
		unpause_cooldown = 0.2
		Input.action_release("pause")
		Input.action_release("dash")

func continue_endless() -> void:
	endless = true
	invulnerable = false
	player.inv = 2.0
	state = S.PLAY
	end_timer = -1.0
	next_endless_event = t + 8.0
	Sfx.music("battle")
	boss_alive = false
	unpause_cooldown = 0.2
	Input.action_release("dash")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == S.PLAY and not demo and not G.test_mode:
		set_paused()

func _result(victory: bool) -> Dictionary:
	var bonus := int(t / 60.0 * 10.0) + (150 if victory else 0)
	var earned := int(round((coins_run + bonus) * DIFF_COINS[diff])) - coins_banked
	earned = maxi(0, earned)
	var best_before: float = float(G.data["best_time"])
	var record := t > best_before and not demo
	if not demo:
		coins_banked += earned
		G.data["coins"] = int(G.data["coins"]) + earned
		G.data["total_kills"] = int(G.data["total_kills"]) + kills
		G.data["runs"] = int(G.data["runs"]) + 1
		if victory:
			G.data["wins"] = int(G.data["wins"]) + 1
		G.data["best_time"] = maxf(best_before, t)
		G.data["best_kills"] = maxi(int(G.data["best_kills"]), kills)
		G.data["best_level"] = maxi(int(G.data["best_level"]), level)
		if int(G.data["coins"]) >= 1000:
			G.unlock_achievement("coins_1000")
		G.save()
	return {"time": t, "kills": kills, "level": level, "coins": earned, "victory": victory, "record": record, "dodges": stat_dodges, "damage": stat_damage, "char": char_id}

func request_finish(action: String) -> void:
	Sfx.muffle(false)
	finished.emit(action)

func _exit_tree() -> void:
	if pj != null:
		pj.clear()
	for w in weapons:
		if w is Weapons.WCheese:
			(w as Weapons.WCheese).procs.clear()
		w.run = null
	weapons.clear()
