class_name Enemies extends Node2D
## Owns every enemy: spawning, AI, spatial grid, damage, drawing.

const CELL := 80.0
const GW := 46                      # grid is GW x GW cells centred on the player
const MAX_LIST := 520

class EProj:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var r: float = 8.0
	var dmg: float = 8.0
	var life: float = 4.0
	var kind: int = 0               # 0 stink, 1 venom, 2 spit
	var age: float = 0.0

var run: Run
var player: Player
var list: Array[Enemy] = []
var bigs: Array[Enemy] = []
var eproj: Array[EProj] = []
var head := PackedInt32Array()
var nxt := PackedInt32Array()
var gx0: float = 0.0
var gy0: float = 0.0
var sep_phase: int = 0
var flash_layer: Node2D
var flash_layer_big: Node2D
var src_cache: Dictionary = {}
var shadow_src := Rect2()
var view_half := Vector2(640, 360)
var boss_ref: Enemy = null
var kills_in_window: int = 0
var spawn_r: float = 760.0

class FlashLayer extends Node2D:
	var en: Enemies
	var big: bool = false
	func _draw() -> void:
		en.draw_flash(self, big)

func setup(r: Run) -> void:
	run = r
	player = r.player
	head.resize(GW * GW)
	head.fill(-1)
	nxt.resize(MAX_LIST + 64)
	nxt.fill(-1)
	shadow_src = G.spr.get("shadow", Rect2())
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float strength = 0.78;\nvoid fragment() {\n\tvec4 t = texture(TEXTURE, UV);\n\tCOLOR = vec4(1.0, 1.0, 1.0, t.a * strength);\n}\n"
	flash_layer = _make_flash_layer(sh, 0.78, false)
	flash_layer_big = _make_flash_layer(sh, 0.26, true)   # bosses are hit constantly: keep their art readable
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _make_flash_layer(sh: Shader, strength: float, is_big: bool) -> Node2D:
	var fl := FlashLayer.new()
	fl.en = self
	fl.big = is_big
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", strength)
	fl.material = mat
	add_child(fl)
	return fl

func count() -> int:
	return list.size() + bigs.size()

# ------------------------------------------------------------- spawning
func spawn(id: String, p: Vector2, elite: bool = false) -> Enemy:
	var d: Dictionary = Defs.ENEMIES[id]
	var is_big: bool = d.get("big", false)
	if not is_big and list.size() >= MAX_LIST:
		return null
	var e := Enemy.new()
	e.id = id
	e.pos = p
	e.ai = Enemy.ai_from(d["ai"])
	var hpm := run.hp_mult()
	e.max_hp = float(d["hp"]) * hpm * (7.0 if elite else 1.0)
	if is_big:
		e.max_hp = float(d["hp"]) * run.boss_hp_mult()
	e.hp = e.max_hp
	e.spd = float(d["spd"]) * run.spd_mult() * (0.9 if elite else 1.0)
	e.dmg = float(d["dmg"]) * run.dmg_mult() * (1.25 if elite else 1.0)
	e.r = float(d["r"]) * (1.35 if elite else 1.0)
	e.xp = float(d["xp"]) * (1.0 + 0.035 * run.t / 60.0) * (6.0 if elite else 1.0)
	e.scale_f = float(d["size"]) * (1.4 if elite else 1.0)
	e.frames = int(d["frames"])
	e.fps = float(d["fps"])
	e.elite = elite
	e.big = is_big
	e.phase = randf() * TAU
	e.anim = randf() * 3.0
	e.name_pair = d["name"]
	if not src_cache.has(id):
		var arr: Array = []
		for f in e.frames:
			arr.append(G.spr.get(Art.sprite_key(d["spr"], f, e.frames), Rect2()))
		src_cache[id] = arr
	e.src = src_cache[id]
	if e.src.size() > 0:
		e.wsize = (e.src[0] as Rect2).size * 0.5
	e.dir = (player.position - p).normalized()
	match e.ai:
		Enemy.AI.SWOOP:
			e.dir = (player.position + player.vel * 0.7 - p).normalized()
		Enemy.AI.DASH, Enemy.AI.HOP, Enemy.AI.CHARGE, Enemy.AI.LEAP:
			e.t1 = randf_range(1.0, 2.4)
		Enemy.AI.SHOOT:
			e.t1 = randf_range(1.2, 2.6)
		Enemy.AI.SNAKE:
			e.head_ang = e.dir.angle()
			e.t1 = 3.0
			e.t2 = 5.0
			_snake_init(e)
	if is_big:
		bigs.append(e)
	else:
		list.append(e)
	return e

func _snake_init(e: Enemy) -> void:
	var n := 20
	e.parts.resize(n)
	e.part_r.resize(n)
	for i in n:
		var k := float(i) / float(n - 1)
		e.part_r[i] = lerpf(40.0, 17.0, pow(k, 0.8)) if i > 0 else 40.0
	e.trail.resize(0)
	for i in 90:
		e.trail.append(e.pos - Vector2.from_angle(e.head_ang) * float(i) * 6.0)
	_snake_fill_parts(e)

func _snake_fill_parts(e: Enemy) -> void:
	var n := e.parts.size()
	var ti := 0
	var acc := 0.0
	e.parts[0] = e.pos
	var spacing := 27.0
	var next_d := spacing
	for i in range(1, e.trail.size()):
		var seg := e.trail[i - 1].distance_to(e.trail[i])
		if seg <= 0.0001:
			continue
		while acc + seg >= next_d and ti < n - 1:
			var f := (next_d - acc) / seg
			ti += 1
			e.parts[ti] = e.trail[i - 1].lerp(e.trail[i], f)
			next_d += spacing
		acc += seg
		if ti >= n - 1:
			break

func ring_pos() -> Vector2:
	var a := randf() * TAU
	return player.position + Vector2.from_angle(a) * (spawn_r + randf() * 60.0)

# ---------------------------------------------------------------- queries
func nearest(p: Vector2, maxd: float = 1e9) -> Enemy:
	var best: Enemy = null
	var bd := maxd * maxd
	for e in list:
		if e.dead:
			continue
		var d := e.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			best = e
	for e in bigs:
		if e.dead:
			continue
		var d2 := e.pos.distance_squared_to(p) - e.r * e.r
		if d2 < bd:
			bd = maxf(d2, 0.0)
			best = e
	return best

func nearest_n(p: Vector2, n: int, maxd: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var ds: Array[float] = []
	var lim := maxd * maxd
	for e in list:
		if e.dead:
			continue
		var d := e.pos.distance_squared_to(p)
		if d > lim:
			continue
		if out.size() < n:
			var i := out.size()
			out.append(e)
			ds.append(d)
			while i > 0 and ds[i - 1] > ds[i]:
				var td := ds[i]; ds[i] = ds[i - 1]; ds[i - 1] = td
				var te := out[i]; out[i] = out[i - 1]; out[i - 1] = te
				i -= 1
		elif d < ds[n - 1]:
			out[n - 1] = e
			ds[n - 1] = d
			var j := n - 1
			while j > 0 and ds[j - 1] > ds[j]:
				var td2 := ds[j]; ds[j] = ds[j - 1]; ds[j - 1] = td2
				var te2 := out[j]; out[j] = out[j - 1]; out[j - 1] = te2
				j -= 1
	for e in bigs:
		if not e.dead and out.size() < n and e.pos.distance_squared_to(p) < lim:
			out.append(e)
	return out

func query_circle(p: Vector2, rad: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var reach := rad + 26.0
	var x0 := maxi(0, int((p.x - reach - gx0) / CELL))
	var x1 := mini(GW - 1, int((p.x + reach - gx0) / CELL))
	var y0 := maxi(0, int((p.y - reach - gy0) / CELL))
	var y1 := mini(GW - 1, int((p.y + reach - gy0) / CELL))
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var i := head[cy * GW + cx]
			while i >= 0:
				var e: Enemy = list[i]
				if not e.dead:
					var rr := rad + e.r
					if e.pos.distance_squared_to(p) <= rr * rr:
						out.append(e)
				i = nxt[i]
	for e in bigs:
		if not e.dead and e.overlaps(p, rad):
			out.append(e)
	return out

func random_visible(n: int, maxd: float) -> Array[Enemy]:
	var cand: Array[Enemy] = []
	var lim := maxd * maxd
	for e in list:
		if not e.dead and e.pos.distance_squared_to(player.position) < lim:
			cand.append(e)
	for e in bigs:
		if not e.dead:
			cand.append(e)
	cand.shuffle()
	return cand.slice(0, n)

# ----------------------------------------------------------------- damage
func damage(e: Enemy, amount: float, from: Vector2 = Vector2.ZERO, kbf: float = 0.0, crit: bool = false, stun: float = 0.0) -> void:
	if e.dead:
		return
	e.hp -= amount
	e.flash = 0.09 if not e.big else 0.05
	if kbf > 0.0 and not e.big:
		var dv := (e.pos - from)
		if dv.length_squared() < 0.01:
			dv = Vector2.from_angle(randf() * TAU)
		e.kb += dv.normalized() * kbf * (0.45 if e.elite else 1.0)
	if stun > 0.0 and not e.big:
		e.stun = maxf(e.stun, stun * (0.4 if e.elite else 1.0))
	run.stat_damage += amount
	run.fx.dmg_number(e.pos + Vector2(randf_range(-8, 8), -e.r - 6), amount, crit)
	if crit:
		run.shake(0.12)
	if e.hp <= 0.0:
		kill(e)
	else:
		Sfx.play("hit", -9.0, 1.0 + randf() * 0.2)
		if randf() < 0.5:
			run.fx.spark(e.pos, Color("fff3c0"), 2)

func kill(e: Enemy) -> void:
	if e.dead:
		return
	e.dead = true
	run.on_kill(e)

func clear_screen(radius: float) -> void:
	for e in list:
		if not e.dead and e.pos.distance_to(player.position) < radius:
			damage(e, 99999.0, player.position, 0.0)
	for e in bigs:
		if not e.dead and e.pos.distance_to(player.position) < radius:
			damage(e, e.max_hp * 0.12, player.position, 0.0)

func melt_all() -> void:
	eproj.clear()
	for e in list:
		if not e.dead:
			e.dead = true
			run.on_kill(e, true)

# ----------------------------------------------------------------- update
func update(dt: float) -> void:
	# compact dead enemies first so grid indices stay valid for the whole frame
	var i := list.size() - 1
	while i >= 0:
		if list[i].dead:
			list[i] = list[list.size() - 1]
			list.pop_back()
		i -= 1
	i = bigs.size() - 1
	while i >= 0:
		if bigs[i].dead:
			if bigs[i] == boss_ref:
				boss_ref = null
			bigs.remove_at(i)
		i -= 1
	if nxt.size() < list.size() + 8:
		nxt.resize(list.size() + 64)
	_rebuild_grid()
	var pp := player.position
	var far2 := (spawn_r * 1.7) * (spawn_r * 1.7)
	sep_phase = (sep_phase + 1) % 3
	for idx in list.size():
		var e: Enemy = list[idx]
		_ai(e, dt, pp)
		if e.pos.distance_squared_to(pp) > far2:
			e.pos = ring_pos()
			e.kb = Vector2.ZERO
			if e.ai == Enemy.AI.SWOOP:
				e.dir = (pp - e.pos).normalized()
		if idx % 3 == sep_phase:
			_separate(idx, e, dt * 3.0)
	for e in bigs:
		_ai(e, dt, pp)
	_update_eproj(dt, pp)
	_contact(pp)

func _rebuild_grid() -> void:
	gx0 = player.position.x - GW * CELL * 0.5
	gy0 = player.position.y - GW * CELL * 0.5
	head.fill(-1)
	for i in list.size():
		var e: Enemy = list[i]
		var cx := int((e.pos.x - gx0) / CELL)
		var cy := int((e.pos.y - gy0) / CELL)
		if cx < 0 or cy < 0 or cx >= GW or cy >= GW:
			nxt[i] = -1
			continue
		var ci := cy * GW + cx
		nxt[i] = head[ci]
		head[ci] = i

func _separate(idx: int, e: Enemy, dt: float) -> void:
	var cx := int((e.pos.x - gx0) / CELL)
	var cy := int((e.pos.y - gy0) / CELL)
	if cx < 1 or cy < 1 or cx >= GW - 1 or cy >= GW - 1:
		return
	var push := Vector2.ZERO
	var n := 0
	for yy in range(cy - 1, cy + 2):
		for xx in range(cx - 1, cx + 2):
			var j := head[yy * GW + xx]
			while j >= 0:
				if j != idx:
					var o: Enemy = list[j]
					var dv := e.pos - o.pos
					var rr := (e.r + o.r) * 0.85
					var d2 := dv.length_squared()
					if d2 < rr * rr:
						if d2 < 0.01:
							dv = Vector2.from_angle(randf() * TAU)
							d2 = 1.0
						var dl := sqrt(d2)
						push += dv / dl * (rr - dl)
						n += 1
						if n >= 6:
							break
				j = nxt[j]
			if n >= 6:
				break
		if n >= 6:
			break
	if n > 0:
		e.pos += push * minf(1.0, 6.0 * dt) * 0.5

# -------------------------------------------------------------------- AI
func _ai(e: Enemy, dt: float, pp: Vector2) -> void:
	e.age += dt
	e.anim += dt
	if e.flash > 0.0:
		e.flash -= dt
	if e.kb.length_squared() > 4.0:
		e.pos += e.kb * dt
		e.kb *= maxf(0.0, 1.0 - 9.0 * dt)
	var to := pp - e.pos
	var d := to.length()
	var dirv := to / d if d > 0.001 else Vector2.ZERO
	var sp := e.spd
	if e.slow > 0.0:
		e.slow -= dt
		sp *= 0.5
	if e.stun > 0.0:
		e.stun -= dt
		return
	match e.ai:
		Enemy.AI.CHASE:
			e.pos += dirv * sp * dt
			e.face = 1.0 if dirv.x >= 0.0 else -1.0
		Enemy.AI.WEAVE:
			var perp := Vector2(-dirv.y, dirv.x)
			e.pos += (dirv + perp * sin(e.age * 5.5 + e.phase) * 0.7) * sp * dt
			e.face = 1.0 if dirv.x >= 0.0 else -1.0
		Enemy.AI.SWOOP:
			e.pos += e.dir * sp * dt
			e.face = 1.0 if e.dir.x >= 0.0 else -1.0
		Enemy.AI.DASH:
			match e.st:
				0:
					e.pos += dirv * sp * dt
					e.face = 1.0 if dirv.x >= 0.0 else -1.0
					e.t1 -= dt
					if e.t1 <= 0.0 and d < 420.0:
						e.st = 1
						e.t2 = 0.5
				1:
					e.t2 -= dt
					e.dir = dirv
					e.pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 40.0 * dt
					e.flash = 0.04 if int(e.age * 20.0) % 2 == 0 else 0.0
					e.face = 1.0 if dirv.x >= 0.0 else -1.0
					if e.t2 <= 0.0:
						e.st = 2
						e.t2 = 0.55
						Sfx.play("swish", -8.0, 1.4)
				2:
					e.t2 -= dt
					e.pos += e.dir * sp * 3.8 * dt
					if e.t2 <= 0.0:
						e.st = 0
						e.t1 = randf_range(1.8, 3.0)
		Enemy.AI.HOP:
			match e.st:
				0:
					e.pos += dirv * sp * 0.5 * dt
					e.face = 1.0 if dirv.x >= 0.0 else -1.0
					e.t1 -= dt
					if e.t1 <= 0.0:
						e.st = 1
						e.t2 = 0.35
				1:
					e.t2 -= dt
					e.dir = dirv
					if e.t2 <= 0.0:
						e.st = 2
						e.t2 = 0.42
				2:
					e.t2 -= dt
					e.pos += e.dir * sp * 6.2 * dt
					if e.t2 <= 0.0:
						e.st = 0
						e.t1 = randf_range(0.7, 1.4)
						run.fx.puff(e.pos + Vector2(0, e.r * 0.6), Color(0.85, 0.8, 0.6, 0.5), 4)
		Enemy.AI.SHOOT:
			e.face = 1.0 if dirv.x >= 0.0 else -1.0
			if d > 300.0:
				e.pos += dirv * sp * dt
			elif d < 220.0:
				e.pos -= dirv * sp * 0.7 * dt
			else:
				e.pos += Vector2(-dirv.y, dirv.x) * sp * 0.5 * dt * sin(e.phase)
			e.t1 -= dt
			if e.t1 <= 0.0 and d < 520.0:
				e.t1 = randf_range(2.4, 3.4)
				var pr := EProj.new()
				pr.pos = e.pos
				pr.vel = dirv * 190.0
				pr.dmg = e.dmg
				pr.r = 11.0
				pr.life = 4.0
				pr.kind = 0
				eproj.append(pr)
				Sfx.play("stink", -8.0)
		Enemy.AI.CHARGE:
			_ai_charge(e, dt, dirv, d, sp)
		Enemy.AI.LEAP:
			_ai_leap(e, dt, dirv, d, sp)
		Enemy.AI.SNAKE:
			_ai_snake(e, dt, pp, to, d, sp)

func _ai_charge(e: Enemy, dt: float, dirv: Vector2, d: float, sp: float) -> void:
	match e.st:
		0:
			e.pos += dirv * sp * dt
			e.face = 1.0 if dirv.x >= 0.0 else -1.0
			e.t1 -= dt
			if e.t1 <= 0.0:
				e.st = 1
				e.t2 = 0.9
				Sfx.play("boss_roar", -6.0, 1.3)
		1:
			e.t2 -= dt
			e.dir = dirv
			e.face = 1.0 if dirv.x >= 0.0 else -1.0
			e.anim += dt * 6.0
			if e.t2 <= 0.0:
				e.st = 2
				e.t2 = 0.85
		2:
			e.t2 -= dt
			e.pos += e.dir * 430.0 * dt
			run.fx.puff(e.pos + Vector2(-e.face * 80.0, 30.0), Color(0.7, 0.6, 0.4, 0.5), 1)
			if e.t2 <= 0.0:
				e.st = 3
				e.t2 = 0.9
				run.shake(0.35)
		3:
			e.t2 -= dt
			if e.t2 <= 0.0:
				e.st = 0
				e.t1 = randf_range(3.2, 4.4)

func _ai_leap(e: Enemy, dt: float, dirv: Vector2, d: float, sp: float) -> void:
	match e.st:
		0:
			e.pos += dirv * sp * dt
			e.face = 1.0 if dirv.x >= 0.0 else -1.0
			e.t1 -= dt
			if e.t1 <= 0.0:
				e.st = 1
				e.t2 = 0.5
				Sfx.play("boss_roar", -6.0, 1.7)
		1:
			e.t2 -= dt
			e.dir = (run.player.position + run.player.vel * 0.35 - e.pos).normalized()
			e.face = 1.0 if e.dir.x >= 0.0 else -1.0
			if e.t2 <= 0.0:
				e.st = 2
				e.t2 = 0.5
		2:
			e.t2 -= dt
			e.pos += e.dir * 560.0 * dt
			if e.t2 <= 0.0:
				e.st = 3
				e.t2 = 0.8
				run.shake(0.3)
				run.fx.ring(e.pos, 20.0, 120.0, 0.35, Color(1, 0.8, 0.4, 0.6), 4.0)
		3:
			e.t2 -= dt
			if e.t2 <= 0.0:
				e.st = 0
				e.t1 = randf_range(2.4, 3.2)

func _ai_snake(e: Enemy, dt: float, pp: Vector2, to: Vector2, d: float, sp: float) -> void:
	e.enraged = e.hp < e.max_hp * 0.5
	var turn := 2.1 if e.enraged else 1.6
	var spd_now := sp * (1.2 if e.enraged else 1.0)
	var want := to.angle()
	var diff := wrapf(want - e.head_ang, -PI, PI)
	match e.st:
		0:
			e.head_ang += clampf(diff, -turn * dt, turn * dt)
			e.t1 -= dt
			e.t2 -= dt
			if e.t1 <= 0.0:
				e.st = 1
				e.t1 = 0.95
				Sfx.play("boss_roar", -3.0, 0.8)
			elif e.t2 <= 0.0:
				e.t2 = 5.5 if not e.enraged else 3.8
				_venom_ring(e, 14 if not e.enraged else 20)
		1:
			e.t1 -= dt
			e.head_ang += clampf(diff, -turn * 2.5 * dt, turn * 2.5 * dt)
			spd_now = 25.0
			if e.t1 <= 0.0:
				e.st = 2
				e.t1 = 0.75
		2:
			e.t1 -= dt
			spd_now = 560.0
			if e.t1 <= 0.0:
				e.st = 0
				e.t1 = 4.2 if not e.enraged else 2.9
				run.shake(0.5)
	var fwd := Vector2.from_angle(e.head_ang)
	e.pos += fwd * spd_now * dt
	e.face = 1.0 if fwd.x >= 0.0 else -1.0
	if e.trail.size() == 0 or e.trail[0].distance_squared_to(e.pos) > 16.0:
		e.trail.insert(0, e.pos)
		if e.trail.size() > 140:
			e.trail.resize(140)
	else:
		e.trail[0] = e.pos
	_snake_fill_parts(e)

func _venom_ring(e: Enemy, n: int) -> void:
	var off := randf() * TAU
	for k in n:
		var pr := EProj.new()
		pr.pos = e.pos
		pr.vel = Vector2.from_angle(off + TAU * float(k) / float(n)) * 210.0
		pr.dmg = e.dmg * 0.7
		pr.r = 11.0
		pr.life = 4.5
		pr.kind = 1
		eproj.append(pr)
	Sfx.play("stink", -4.0, 0.7)

func _update_eproj(dt: float, pp: Vector2) -> void:
	var i := eproj.size() - 1
	while i >= 0:
		var p: EProj = eproj[i]
		p.pos += p.vel * dt
		p.life -= dt
		p.age += dt
		var rr := p.r + player.radius
		if p.pos.distance_squared_to(pp) <= rr * rr:
			player.hurt(p.dmg, p.pos)
			p.life = 0.0
			run.fx.puff(p.pos, Color(0.5, 0.9, 0.3, 0.6) if p.kind == 0 else Color(0.8, 0.3, 1.0, 0.6), 6)
		if p.life <= 0.0:
			eproj.remove_at(i)
		i -= 1

func _contact(pp: Vector2) -> void:
	var pr := player.radius
	if player.is_dashing():
		# bulldoze the crowd while dashing
		for e in query_circle(pp, pr + 26.0):
			if not e.big:
				e.kb += (e.pos - pp).normalized() * 520.0
	for idx in list.size():
		var e: Enemy = list[idx]
		if e.dead:
			continue
		var rr := e.r + pr
		if e.pos.distance_squared_to(pp) <= rr * rr:
			if player.inv_dash > 0.0:
				run.perfect_dodge(e)
			else:
				player.hurt(e.dmg, e.pos)
	for e in bigs:
		if e.dead:
			continue
		if e.overlaps(pp, pr * 0.8):
			if player.inv_dash > 0.0:
				run.perfect_dodge(e)
			else:
				player.hurt(e.dmg, e.closest_part(pp))

# ------------------------------------------------------------------- draw
func _process(_dt: float) -> void:
	queue_redraw()
	flash_layer.queue_redraw()
	flash_layer_big.queue_redraw()

func _visible(p: Vector2, margin: float) -> bool:
	return absf(p.x - run.cam_pos.x) < view_half.x + margin and absf(p.y - run.cam_pos.y) < view_half.y + margin

func _draw() -> void:
	var tex := G.tex
	if tex == null:
		return
	# shadows
	for e in list:
		if e.dead or not _visible(e.pos, 60.0):
			continue
		var sw := e.wsize.x * e.scale_f * 0.62
		var sh := sw * 0.34
		draw_texture_rect_region(tex, Rect2(e.pos.x - sw * 0.5, e.pos.y + e.r * 0.55 - sh * 0.5, sw, sh), shadow_src, Color(1, 1, 1, 0.8))
	for e in bigs:
		if not e.dead and e.parts.size() == 0:
			var sw2 := e.wsize.x * e.scale_f * 0.5
			draw_texture_rect_region(tex, Rect2(e.pos.x - sw2 * 0.5, e.pos.y + e.r * 0.65, sw2, sw2 * 0.3), shadow_src, Color(1, 1, 1, 0.8))
	# elite aura
	for e in list:
		if e.elite and not e.dead and _visible(e.pos, 80.0):
			var pulse := 0.65 + 0.35 * sin(e.age * 6.0)
			draw_texture_rect(Art.glow(), Rect2(e.pos - Vector2(e.r * 2.2, e.r * 2.2), Vector2(e.r * 4.4, e.r * 4.4)), false, Color(1.0, 0.2, 0.2, 0.45 * pulse))
	# bodies
	for e in list:
		if e.dead or not _visible(e.pos, 60.0):
			continue
		_draw_body(e, tex, false)
	for e in bigs:
		if e.dead:
			continue
		if e.parts.size() > 0:
			_draw_snake(e)
		else:
			_draw_body(e, tex, false)
	# enemy projectiles
	for p in eproj:
		var col := Color(0.55, 0.95, 0.3) if p.kind == 0 else Color(0.8, 0.35, 1.0)
		draw_texture_rect(Art.glow(), Rect2(p.pos - Vector2(p.r * 2.4, p.r * 2.4), Vector2(p.r * 4.8, p.r * 4.8)), false, Color(col.r, col.g, col.b, 0.5))
		draw_circle(p.pos, p.r + 1.5, Color("2a1810"))
		draw_circle(p.pos, p.r, col)
		draw_circle(p.pos + Vector2(-3, -3), p.r * 0.35, Color(1, 1, 1, 0.7))

func _body_rect(e: Enemy) -> Rect2:
	var pop := minf(1.0, 0.35 + e.age * 3.2)
	var w := e.wsize.x * e.scale_f * pop
	var h := e.wsize.y * e.scale_f * pop
	var sy := 1.0
	var sx := 1.0
	var lift := 0.0
	if e.ai == Enemy.AI.HOP:
		if e.st == 1:
			sy = 0.8
			sx = 1.15
		elif e.st == 2:
			sy = 1.2
			sx = 0.88
			lift = -22.0 * sin(clampf((0.42 - e.t2) / 0.42, 0.0, 1.0) * PI)
	elif e.ai == Enemy.AI.WEAVE or e.ai == Enemy.AI.DASH or e.ai == Enemy.AI.SWOOP:
		lift = -4.0 * sin(e.age * 9.0 + e.phase)
	elif e.ai == Enemy.AI.CHASE:
		sy = 1.0 + 0.05 * sin(e.age * 12.0 + e.phase)
	w *= sx
	h *= sy
	return Rect2(e.pos.x - w * 0.5, e.pos.y - h * 0.5 + lift, w, h)

func _frame_src(e: Enemy) -> Rect2:
	var fr := 0
	if e.frames > 1:
		fr = int(e.anim * e.fps) % e.frames
		if e.ai == Enemy.AI.HOP:
			fr = 1 if e.st == 2 else 0
		elif e.ai == Enemy.AI.LEAP:
			fr = 1 if e.st == 2 else 0
		elif e.ai == Enemy.AI.CHARGE:
			fr = 1 if (e.st == 1 or e.st == 2) else 0
	return e.src[fr]

func _draw_body(e: Enemy, tex: Texture2D, flash: bool) -> void:
	if e.src.size() == 0:
		return
	var rect := _body_rect(e)
	var s: Rect2 = _frame_src(e)
	if e.face < 0.0:
		s = Rect2(s.position.x, s.position.y, -s.size.x, s.size.y)
	var col := Color(1, 1, 1, 1)
	if e.slow > 0.0 and not flash:
		col = Color(0.78, 0.65, 0.5, 1)
	draw_texture_rect_region(tex, rect, s, col)

func draw_flash(layer: Node2D, only_big: bool) -> void:
	var tex := G.tex
	if tex == null:
		return
	if not only_big:
		for e in list:
			if e.flash > 0.0 and not e.dead and _visible(e.pos, 60.0):
				var s: Rect2 = _frame_src(e)
				if e.face < 0.0:
					s = Rect2(s.position.x, s.position.y, -s.size.x, s.size.y)
				layer.draw_texture_rect_region(tex, _body_rect(e), s)
		return
	for e in bigs:
		if e.flash > 0.0 and not e.dead and e.parts.size() == 0:
			var s2: Rect2 = _frame_src(e)
			if e.face < 0.0:
				s2 = Rect2(s2.position.x, s2.position.y, -s2.size.x, s2.size.y)
			layer.draw_texture_rect_region(tex, _body_rect(e), s2)

func _draw_snake(e: Enemy) -> void:
	var base := Color("5da13a")
	if e.enraged:
		base = Color("a1543a")
	for i in range(e.parts.size() - 1, 0, -1):
		var c := base.lerp(Color.WHITE, 0.22 if e.flash > 0.0 else 0.0)
		Art.draw_snake_body(self, e.parts[i], e.part_r[i], i, c)
	var mouth := 0.0
	if e.st == 1:
		mouth = clampf(1.0 - e.t1 / 0.95, 0.0, 1.0)
	elif e.st == 2:
		mouth = 1.0
	var hc := base.lerp(Color.WHITE, 0.22 if e.flash > 0.0 else 0.0)
	Art.draw_snake_head(self, e.parts[0], e.head_ang, e.part_r[0], mouth, e.age, hc, e.enraged)
