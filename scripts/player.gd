class_name Player extends Node2D
## The capybara: movement, dash, health, stats container and drawing.

const BASE_SPEED := 205.0
const DASH_SPEED := 920.0
const DASH_TIME := 0.17
const DRAW_SCALE := 0.74

var run: Run
var vel := Vector2.ZERO
var face: float = 1.0
var hp: float = 100.0
var max_hp: float = 100.0
var radius: float = 15.0
var inv: float = 0.0
var inv_dash: float = 0.0
var dash_t: float = 0.0
var dash_cd: float = 0.0
var dash_cd_max: float = 1.7
var dash_dir := Vector2.RIGHT
var anim: float = 0.0
var flash: float = 0.0
var blink_timer: float = 2.5
var blink: float = 0.0
var spring := Vector2.ZERO
var spring_v := Vector2.ZERO
var squash := Vector2.ONE
var char_id: String = "cap"
var body_col := Color("b5824f")
var hat: String = "none"
var in_water: bool = false
var move_input := Vector2.ZERO
var idle_t: float = 0.0
var dead: bool = false
var afterimage_t: float = 0.0

# --- stats written by Run.recalc_stats()
var might: float = 1.0
var cdm: float = 1.0
var speed_mult: float = 1.0
var armor: float = 0.0
var regen: float = 0.0
var pickup_r: float = 85.0
var area: float = 1.0
var amount_bonus: int = 0
var growth: float = 1.0
var luck: float = 0.0
var greed: float = 1.0
var crit: float = 0.05
var dashcd_mult: float = 1.0

func setup(r: Run, cid: String) -> void:
	run = r
	char_id = cid
	var d: Dictionary = Defs.CHARACTERS[cid]
	body_col = d["body"]
	hat = d["hat"]
	hp = max_hp

func is_dashing() -> bool:
	return dash_t > 0.0

func dash_ready() -> bool:
	return dash_cd <= 0.0 and dash_t <= 0.0

func try_dash() -> void:
	if not dash_ready() or dead:
		return
	var d := move_input
	if d.length() < 0.2:
		d = Vector2(face, 0.0)
	dash_dir = d.normalized()
	dash_t = DASH_TIME
	inv_dash = 0.32
	dash_cd = dash_cd_max * dashcd_mult
	squash = Vector2(1.35, 0.72)
	if absf(dash_dir.x) > 0.2:
		face = signf(dash_dir.x)
	Sfx.play("dash", -6.0)
	run.fx.puff(position + Vector2(0, 18), Color(0.9, 0.85, 0.7, 0.6), 5)
	run.shake(0.1)

func update(dt: float, input: Vector2) -> void:
	anim += dt
	move_input = input
	if dash_cd > 0.0:
		dash_cd -= dt
	if inv > 0.0:
		inv -= dt
	if inv_dash > 0.0:
		inv_dash -= dt
	if flash > 0.0:
		flash -= dt
	if dash_t > 0.0:
		dash_t -= dt
		position += dash_dir * DASH_SPEED * dt
		vel = dash_dir * DASH_SPEED * 0.5
		afterimage_t -= dt
		if afterimage_t <= 0.0:
			afterimage_t = 0.035
			run.fx.emit(position + Vector2(0, 14), Vector2.ZERO, 0.28, 16.0, Color(1.0, 0.8, 0.5, 0.4), 4, -30.0, 1.0)
	else:
		var spd_w := 1.0
		if in_water:
			spd_w = 1.12
		var target := input * BASE_SPEED * speed_mult * spd_w
		vel = vel.move_toward(target, 2600.0 * dt)
		position += vel * dt
	if input.length() > 0.12:
		idle_t = 0.0
		if absf(input.x) > 0.12:
			face = signf(input.x)
	else:
		idle_t += dt
	# regen (water doubles as a spa)
	var rg := regen + (1.6 if in_water else 0.0)
	if rg > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + rg * dt)
	# blink
	blink_timer -= dt
	if blink_timer <= 0.0:
		blink = 0.14
		blink_timer = randf_range(1.8, 4.0)
	if blink > 0.0:
		blink -= dt
	# orange jiggle spring + squash relax
	spring_v += (-spring * 260.0 - spring_v * 14.0) * dt - Vector2(vel.x * 0.05, vel.y * 0.02 - 2.0 * sin(anim * 13.0) * vel.length() * 0.004)
	spring += spring_v * dt
	if spring.length() > 9.0:
		spring = spring.normalized() * 9.0
	squash = squash.lerp(Vector2.ONE, minf(1.0, 14.0 * dt))
	# modulate: invulnerability flicker / hurt flash
	var a := 1.0
	if inv > 0.0 and fmod(inv, 0.14) < 0.07:
		a = 0.45
	if flash > 0.0:
		modulate = Color(2.6, 2.0, 2.0, 1.0)
	else:
		modulate = Color(1, 1, 1, a)
	queue_redraw()

func hurt(raw: float, from: Vector2) -> bool:
	if dead or inv > 0.0 or inv_dash > 0.0 or run.invulnerable or run.state != Run.S.PLAY:
		return false
	var d := maxf(1.0, raw - armor)
	hp -= d
	inv = 0.6
	flash = 0.12
	squash = Vector2(0.78, 1.28)
	var away := (position - from)
	if away.length_squared() > 0.01:
		vel += away.normalized() * 300.0
	run.on_player_hurt(d)
	if hp <= 0.0:
		run.player_down()
	return true

func heal(x: float) -> void:
	hp = minf(max_hp, hp + x)

func _draw() -> void:
	if G.tex == null:
		return
	var sh: Rect2 = G.spr.get("shadow", Rect2())
	if sh.size.x > 0.0:
		var sw := 74.0
		draw_texture_rect_region(G.tex, Rect2(-sw * 0.5, 22.0 - 12.0, sw, sw * 0.34), sh, Color(1, 1, 1, 0.85))
	# soft ring so the hero never gets lost in the crowd
	draw_set_transform(Vector2(0, 21), 0.0, Vector2(1.0, 0.38))
	draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 40, Color(1.0, 0.97, 0.85, 0.28 + 0.1 * sin(anim * 3.0)), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var walk := clampf(vel.length() / (BASE_SPEED * 0.8), 0.0, 1.0)
	var sleepy := idle_t > 4.0
	var bl := 1.0 if (blink > 0.0 or sleepy) else 0.0
	Capy.draw(self, anim, walk, squash.x, squash.y, body_col, hat, bl, spring, char_id == "cap", Vector2(0, 22), face, DRAW_SCALE)
	if sleepy:
		var zt := fmod(anim, 2.4) / 2.4
		draw_string(G.title_font, Vector2(26 * face, -18 - zt * 26), "z", HORIZONTAL_ALIGNMENT_CENTER, -1, int(16 + 8 * zt), Color(1, 1, 1, 1.0 - zt))
