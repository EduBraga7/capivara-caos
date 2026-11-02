class_name Projs extends Node2D
## All player-side projectiles: motion, collision, drawing.

var run: Run
var list: Array[Proj] = []
var glow_layer: Node2D
var debug_skip_kind: int = -1

class GlowLayer extends Node2D:
	var pj: Projs
	func _draw() -> void:
		pj.draw_glow(self)

func setup(r: Run) -> void:
	run = r
	glow_layer = GlowLayer.new()
	glow_layer.pj = self
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = m
	add_child(glow_layer)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func make(kind: int) -> Proj:
	var p := Proj.new()
	p.kind = kind
	list.append(p)
	return p

func clear() -> void:
	for p in list:
		p.w = null
	list.clear()

# ----------------------------------------------------------------- update
func update(dt: float) -> void:
	for w in run.weapons:
		w.update(dt)
	var i := list.size() - 1
	while i >= 0:
		var p: Proj = list[i]
		_step(p, dt)
		if p.dead:
			list.remove_at(i)
		i -= 1
	queue_redraw()
	glow_layer.queue_redraw()

func _hit(p: Proj, e: Enemy, mult: float = 1.0) -> void:
	var pl := run.player
	var crit := run.rng.randf() < pl.crit
	var d := p.dmg * mult * (2.0 if crit else 1.0)
	run.en.damage(e, d, p.pos, p.kb, crit, p.c if p.kind == Proj.K.BOOM else 0.0)

func _step(p: Proj, dt: float) -> void:
	match p.kind:
		Proj.K.BULLET: _step_bullet(p, dt)
		Proj.K.BOOM: _step_boom(p, dt)
		Proj.K.ORBIT: _step_orbit(p, dt)
		Proj.K.BIRD: _step_bird(p, dt)
		Proj.K.ZONE: _step_zone(p, dt)
		Proj.K.BOLT: _step_bolt(p, dt)
		Proj.K.WAVE:
			p.age += dt
			p.life -= dt
			if p.life <= 0.0:
				p.dead = true
		Proj.K.MUDBALL: _step_mudball(p, dt)

func _step_bullet(p: Proj, dt: float) -> void:
	p.age += dt
	p.life -= dt
	p.pos += p.vel * dt
	p.rot += p.spin * dt
	if p.tex == "orange" and fmod(p.age, 0.05) < dt:
		run.fx.emit(p.pos, Vector2.ZERO, 0.28, 3.5, Color(1.0, 0.65, 0.15, 0.7), 0, -9.0, 1.0)
	if p.life <= 0.0:
		if p.evo and p.tex == "orange":
			_explode_orange(p)
		p.dead = true
		return
	var hitlist := run.en.query_circle(p.pos, p.r)
	for e in hitlist:
		if p.hits.has(e.uid):
			continue
		p.hits[e.uid] = true
		_hit(p, e)
		if p.evo and p.tex == "orange":
			_explode_orange(p)
			p.dead = true
			return
		if p.pierce <= 0:
			p.dead = true
			run.fx.burst(p.pos, Color(1.0, 0.7, 0.2), 4, 110.0, 0.3, 3.0)
			return
		p.pierce -= 1

func _explode_orange(p: Proj) -> void:
	var rad := 82.0
	for e in run.en.query_circle(p.pos, rad):
		run.en.damage(e, p.dmg * 0.6, p.pos, 170.0)
	run.fx.ring(p.pos, 8.0, rad, 0.3, Color(1.0, 0.7, 0.2, 0.8), 4.0)
	run.fx.burst(p.pos, Color(1.0, 0.65, 0.15), 14, 240.0, 0.5, 4.0)
	run.fx.puff(p.pos, Color(1.0, 0.8, 0.4, 0.6), 4)
	for k in 6:
		var s := make(Proj.K.BULLET)
		s.pos = p.pos
		s.vel = Vector2.from_angle(TAU * float(k) / 6.0 + p.rot) * 400.0
		s.dmg = p.dmg * 0.35
		s.r = 6.0
		s.life = 0.45
		s.pierce = 1
		s.tex = "seed"
		s.w = p.w
	Sfx.play("explosion", -12.0, 1.4)

func _step_boom(p: Proj, dt: float) -> void:
	p.age += dt
	p.rot += p.spin * dt
	var pl := run.player.position
	if p.a == 0.0:
		var k := clampf(p.age / p.b, 0.0, 1.0)
		p.pos += p.vel * (1.0 - 0.92 * k * k) * dt
		if p.age >= p.b:
			p.a = 1.0
			p.b = 0.0
	else:
		p.b += dt
		var to := pl - p.pos
		var d := to.length()
		if d < 30.0:
			p.dead = true
			return
		p.pos += to / d * (360.0 + 800.0 * p.b) * dt
	if fmod(p.age, 0.06) < dt:
		run.fx.emit(p.pos, Vector2.ZERO, 0.22, 4.0, Color(1.0, 0.9, 0.4, 0.55), 0, -12.0, 1.0)
	for e in run.en.query_circle(p.pos, p.r):
		if float(p.hits.get(e.uid, -1.0)) <= p.age:
			p.hits[e.uid] = p.age + p.tick_rate
			_hit(p, e)

func _step_orbit(p: Proj, dt: float) -> void:
	p.age += dt
	p.life -= dt
	p.ang += p.spin * dt
	var pl := run.player.position
	p.pos = pl + Vector2.from_angle(p.ang) * p.rad
	p.rot += dt * 4.0
	if p.life <= 0.0:
		p.dead = true
		run.fx.burst(p.pos, Color(1.0, 0.85, 0.4), 5, 90.0, 0.35, 3.0)
		return
	if p.hits.size() > 40:
		for k in p.hits.keys():
			if float(p.hits[k]) < p.age:
				p.hits.erase(k)
	for e in run.en.query_circle(p.pos, p.r):
		if float(p.hits.get(e.uid, -1.0)) <= p.age:
			p.hits[e.uid] = p.age + p.tick_rate
			var crit := run.rng.randf() < run.player.crit
			run.en.damage(e, p.dmg * (2.0 if crit else 1.0), pl, p.kb + 120.0, crit)

func _step_bird(p: Proj, dt: float) -> void:
	p.age += dt
	var pl := run.player
	var sp: float = float(p.w.st["spd"]) if p.w != null else 440.0
	match p.st:
		0:
			p.ang += dt * (1.6 + p.a)
			var tp := pl.position + Vector2.from_angle(p.ang) * (64.0 + 12.0 * sin(p.age * 3.0 + p.a * 9.0)) + Vector2(0, -16)
			var old := p.pos
			p.pos = p.pos.lerp(tp, 1.0 - exp(-9.0 * dt))
			p.vel = p.pos - old
			p.c -= dt
			if p.c <= 0.0:
				var tg := run.en.nearest(pl.position, 440.0)
				if tg != null:
					p.st = 1
					p.tvec = tg.pos
					p.b = 0.85
					p.hits.clear()
					Sfx.play("tweet", -12.0, 1.0 + randf() * 0.4)
				else:
					p.c = 0.25
		1:
			var dv := p.tvec - p.pos
			var d := dv.length()
			if d > 1.0:
				p.pos += dv / d * sp * dt
				p.vel = dv
			p.b -= dt
			for e in run.en.query_circle(p.pos, p.r):
				if float(p.hits.get(e.uid, -1.0)) <= p.age:
					p.hits[e.uid] = p.age + 0.35
					_hit(p, e)
			if d < 16.0 or p.b <= 0.0:
				p.st = 2
				if p.evo:
					run.fx.burst(p.pos, Color(1.0, 0.9, 0.3), 8, 160.0, 0.5, 3.0)
					for e in run.en.query_circle(p.pos, 60.0):
						run.en.damage(e, p.dmg * 0.7, p.pos, 120.0)
		2:
			var tp2 := pl.position + Vector2(0, -16)
			var dv2 := tp2 - p.pos
			var d2 := dv2.length()
			if d2 > 1.0:
				p.pos += dv2 / d2 * sp * 1.3 * dt
				p.vel = dv2
			if d2 < 46.0:
				p.st = 0
				p.c = (p.w.cd() if p.w != null else 1.0) * randf_range(0.7, 1.2)

func _step_zone(p: Proj, dt: float) -> void:
	p.age += dt
	p.life -= dt
	p.tick -= dt
	if p.life <= 0.0:
		p.dead = true
		return
	if p.tick <= 0.0:
		p.tick = p.tick_rate
		for e in run.en.query_circle(p.pos, p.rad):
			run.en.damage(e, p.dmg, p.pos, 0.0)
			e.slow = maxf(e.slow, 0.8)
		if p.evo and run.player.position.distance_to(p.pos) < p.rad:
			run.player.heal(1.4)

func _step_bolt(p: Proj, dt: float) -> void:
	p.age += dt
	p.life -= dt
	if p.life > 0.0:
		return
	p.dead = true
	var top := p.pos + Vector2(randf_range(-60, 60), -760.0)
	run.fx.lightning(top, p.pos, Color(1.0, 0.95, 0.5))
	run.fx.ring(p.pos, 10.0, p.rad, 0.32, Color(1.0, 0.95, 0.5, 0.85), 5.0)
	run.fx.burst(p.pos, Color(1.0, 0.95, 0.5), 10, 260.0, 0.4, 3.5)
	run.fx.flash(0.35, Color(1, 1, 0.8))
	var struck: Dictionary = {}
	for e in run.en.query_circle(p.pos, p.rad):
		struck[e.uid] = true
		var crit := run.rng.randf() < run.player.crit
		run.en.damage(e, p.dmg * (2.0 if crit else 1.0), p.pos, p.kb, crit, 0.25)
	run.shake(0.12)
	Sfx.play("zap", -6.0, 0.9 + randf() * 0.3)
	var cur := p.pos
	for k in p.chain:
		var nx: Enemy = null
		for e in run.en.query_circle(cur, 260.0):
			if not struck.has(e.uid):
				nx = e
				break
		if nx == null:
			break
		struck[nx.uid] = true
		run.fx.lightning(cur, nx.pos, Color(0.8, 0.9, 1.0))
		run.en.damage(nx, p.dmg * 0.7, cur, 120.0, false, 0.2)
		cur = nx.pos

func _step_mudball(p: Proj, dt: float) -> void:
	p.age += dt
	var t := clampf(p.age / p.max_life, 0.0, 1.0)
	var start := Vector2(p.a, p.b)
	p.pos = start.lerp(p.tvec, t) + Vector2(0, -sin(t * PI) * 70.0)
	if t >= 1.0:
		p.dead = true
		var w := p.w
		var z := make(Proj.K.ZONE)
		z.pos = p.tvec
		z.rad = 66.0 * w.area()
		z.dmg = w.dmg()
		z.life = float(w.st["dur"])
		z.max_life = z.life
		z.tick_rate = 0.4
		z.tick = 0.1
		z.evo = w.evolved
		z.w = w
		run.fx.burst(p.tvec, Color(0.55, 0.36, 0.2), 10, 150.0, 0.5, 4.0)
		run.fx.puff(p.tvec, Color(0.5, 0.35, 0.2, 0.6), 4)

# ------------------------------------------------------------------- draw
func _spr(key: String, p: Vector2, rot: float, sc: float, col: Color = Color.WHITE, flip: bool = false) -> void:
	var s: Rect2 = G.spr.get(key, Rect2())
	if s.size.x <= 0.0:
		return
	if flip:
		s = Rect2(s.position.x, s.position.y, -s.size.x, s.size.y)
	var sz := s.size * 0.5 * sc
	draw_set_transform(p, rot, Vector2.ONE)
	draw_texture_rect_region(G.tex, Rect2(-sz * 0.5, sz), s, col)

func _draw() -> void:
	if G.tex == null:
		return
	for w in run.weapons:
		w.draw(self)
	# ground-level things first
	for p in list:
		if p.kind == Proj.K.ZONE:
			_draw_zone(p)
		elif p.kind == Proj.K.BOLT:
			_draw_bolt_warn(p)
	for p in list:
		if p.kind == debug_skip_kind:
			continue
		match p.kind:
			Proj.K.BULLET:
				if p.tex == "orange":
					_spr("orange", p.pos, p.rot, p.scale_f * 1.15)
				else:
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					draw_circle(p.pos, p.r, Color(1.0, 0.95, 0.7))
			Proj.K.BOOM:
				_spr("flipflop", p.pos, p.rot, p.scale_f * 1.1)
			Proj.K.ORBIT:
				_spr("cheese", p.pos, p.rot, p.scale_f * 1.3)
			Proj.K.BIRD:
				var fr := int(p.age * 14.0) % 2
				_spr("bird_%d" % fr, p.pos, clampf(p.vel.y * 0.004, -0.5, 0.5) * signf(p.vel.x), 1.05, Color.WHITE, p.vel.x < 0.0)
			Proj.K.WAVE:
				_draw_wave(p)
			Proj.K.MUDBALL:
				_spr("mudball", p.pos, p.age * 8.0, 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_zone(p: Proj) -> void:
	var fade := clampf(p.life / 0.6, 0.0, 1.0)
	var grow := clampf(p.age / 0.2, 0.0, 1.0)
	var rr := p.rad * (0.4 + 0.6 * grow)
	var base := Color(0.36, 0.24, 0.13, 0.82 * fade)
	var mid := Color(0.5, 0.34, 0.19, 0.9 * fade)
	if p.evo:
		base = Color(0.3, 0.5, 0.52, 0.8 * fade)
		mid = Color(0.4, 0.68, 0.7, 0.85 * fade)
	draw_set_transform(p.pos, 0.0, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, rr + 4.0, Color(0.1, 0.06, 0.03, 0.5 * fade))
	draw_circle(Vector2.ZERO, rr, base)
	draw_circle(Vector2(-rr * 0.06, -rr * 0.08), rr * 0.8, mid)
	for i in 5:
		var a := p.age * 0.9 + float(i) * 1.26
		var bp := Vector2.from_angle(a) * rr * (0.25 + 0.4 * fmod(float(i) * 0.37, 1.0))
		var bs := (rr * 0.07) * (0.5 + 0.5 * sin(p.age * 3.0 + i))
		draw_circle(bp, bs + 1.5, Color(0.1, 0.06, 0.03, 0.5 * fade))
		draw_circle(bp, bs, Color(0.75, 0.55, 0.33, 0.9 * fade) if not p.evo else Color(0.8, 0.95, 1.0, 0.9 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_bolt_warn(p: Proj) -> void:
	var k := 1.0 - clampf(p.life / p.max_life, 0.0, 1.0)
	var blink := 0.5 + 0.5 * sin(p.age * 40.0)
	draw_circle(p.pos, p.rad, Color(1.0, 0.95, 0.4, 0.08 + 0.1 * k))
	draw_arc(p.pos, p.rad, 0.0, TAU, 40, Color(1.0, 0.95, 0.5, 0.4 + 0.5 * blink), 2.5, true)
	draw_arc(p.pos, p.rad * (1.0 - k), 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 2.0, true)

func _draw_wave(p: Proj) -> void:
	var k := clampf(p.age / p.max_life, 0.0, 1.0)
	var a := 1.0 - k
	var half: float = p.b
	var full := half >= PI - 0.01
	for i in 4:
		var rr: float = p.a * (0.25 + 0.75 * k) * (1.0 - 0.18 * i)
		var col := Color(1.0, 0.92, 0.35, 0.8 * a) if i % 2 == 0 else Color(1.0, 1.0, 1.0, 0.7 * a)
		if full:
			draw_arc(p.pos, rr, 0.0, TAU, 48, col, 5.0 - i, true)
		else:
			draw_arc(p.pos, rr, p.rot - half, p.rot + half, 24, col, 5.0 - i, true)

func draw_glow(layer: Node2D) -> void:
	if G.tex == null:
		return
	var g := Art.glow()
	for w in run.weapons:
		w.draw_glow(layer)
	for p in list:
		if p.kind == debug_skip_kind:
			continue
		match p.kind:
			Proj.K.BULLET:
				if p.tex == "orange":
					var rr := p.r * 3.2
					layer.draw_texture_rect(g, Rect2(p.pos - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(1.0, 0.55, 0.1, 0.38))
			Proj.K.BOOM:
				var rr2 := p.r * 2.6
				layer.draw_texture_rect(g, Rect2(p.pos - Vector2(rr2, rr2), Vector2(rr2, rr2) * 2.0), false, Color(1.0, 0.9, 0.3, 0.2 if not p.evo else 0.45))
			Proj.K.ORBIT:
				var rr3 := p.r * 2.4
				layer.draw_texture_rect(g, Rect2(p.pos - Vector2(rr3, rr3), Vector2(rr3, rr3) * 2.0), false, Color(1.0, 0.8, 0.3, 0.15))
			Proj.K.BIRD:
				layer.draw_texture_rect(g, Rect2(p.pos - Vector2(20, 20), Vector2(40, 40)), false, Color(1.0, 0.9, 0.3, 0.3))
			Proj.K.BOLT:
				var k := 1.0 - clampf(p.life / p.max_life, 0.0, 1.0)
				layer.draw_texture_rect(g, Rect2(p.pos - Vector2(p.rad, p.rad) * 1.3, Vector2(p.rad, p.rad) * 2.6), false, Color(1.0, 0.95, 0.4, 0.25 * k))
