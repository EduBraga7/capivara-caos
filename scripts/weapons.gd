class_name Weapons
## Factory + the eight weapon behaviours. Projectile motion lives in Projs.

static func create(r: Run, wid: String) -> Weapon:
	var w: Weapon
	match wid:
		"orange": w = WOrange.new()
		"flipflop": w = WFlipflop.new()
		"cheese": w = WCheese.new()
		"repellent": w = WRepellent.new()
		"thunder": w = WThunder.new()
		"mud": w = WMud.new()
		"vuvuzela": w = WVuvuzela.new()
		"birds": w = WBirds.new()
		_: w = Weapon.new()
	w.setup(r, wid)
	return w

# ------------------------------------------------------------- orange
class WOrange extends Weapon:
	func update(dt: float) -> void:
		timer -= dt
		if timer > 0.0:
			return
		var pl := run.player
		var n := amt()
		var targets := run.en.nearest_n(pl.position, n, 780.0)
		if targets.is_empty():
			return
		timer = cd()
		for i in n:
			var tgt: Enemy = targets[i] if i < targets.size() else targets[0]
			var dir := (tgt.pos - pl.position).normalized()
			if i >= targets.size():
				var k := i - targets.size() + 1
				dir = dir.rotated(0.17 * k * (1.0 if k % 2 == 1 else -1.0))
			var p := run.pj.make(Proj.K.BULLET)
			p.pos = pl.position + dir * 22.0
			p.vel = dir * float(st["spd"])
			p.dmg = dmg()
			p.r = 10.0 * area()
			p.scale_f = 1.0 + (area() - 1.0) * 0.6
			p.life = float(st["dur"])
			p.pierce = int(st["pierce"])
			p.kb = float(st["kb"])
			p.tex = "orange"
			p.spin = 9.0
			p.evo = evolved
			p.w = self
		Sfx.play("shoot", -9.0, 1.0 + randf() * 0.15)

# ------------------------------------------------------------ flipflop
class WFlipflop extends Weapon:
	func update(dt: float) -> void:
		timer -= dt
		if timer > 0.0:
			return
		var pl := run.player
		var tgt := run.en.nearest(pl.position, 650.0)
		if tgt == null:
			return
		timer = cd()
		var n := amt()
		var base := (tgt.pos - pl.position).angle()
		for i in n:
			var a := base
			if evolved:
				a = base + TAU * float(i) / float(n)
			else:
				a = base + (float(i) - (n - 1) * 0.5) * 0.5
			var p := run.pj.make(Proj.K.BOOM)
			p.pos = pl.position
			p.vel = Vector2.from_angle(a) * float(st["spd"])
			p.dmg = dmg()
			p.r = 20.0 * area()
			p.scale_f = 1.0 * area()
			p.pierce = 999
			p.kb = float(st["kb"])
			p.a = 0.0
			p.b = float(st["dur"])
			p.life = 6.0
			p.tex = "flipflop"
			p.spin = 15.0
			p.tick_rate = 0.5
			p.c = 0.6 if evolved else 0.0
			p.evo = evolved
			p.w = self
		Sfx.play("swish", -8.0, 1.0)

# -------------------------------------------------------------- cheese
class WCheese extends Weapon:
	var procs: Array[Proj] = []

	func update(dt: float) -> void:
		var alive: Array[Proj] = []
		for p in procs:
			if not p.dead:
				alive.append(p)
		procs = alive
		if procs.is_empty():
			timer -= dt
			if timer <= 0.0:
				_spawn_ring()
				timer = cd()

	func on_rebuild() -> void:
		# refresh live buns so upgrades apply immediately
		for p in procs:
			p.dmg = dmg()
			p.spin = float(st["spd"])

	func _spawn_ring() -> void:
		var n := amt()
		var base_r := 96.0 * area()
		var rings: Array = [[n, base_r, 1.0]]
		if evolved:
			var inner := maxi(2, n / 2)
			rings = [[inner, base_r * 0.62, 1.0], [n - inner, base_r * 1.25, -1.0]]
		var off := randf() * TAU
		for rg in rings:
			var cnt: int = rg[0]
			for i in cnt:
				var p := run.pj.make(Proj.K.ORBIT)
				p.ang = off + TAU * float(i) / float(cnt)
				p.rad = rg[1]
				p.spin = float(st["spd"]) * float(rg[2])
				p.dmg = dmg()
				p.r = 14.0 * (1.0 + (area() - 1.0) * 0.5)
				p.scale_f = 1.0 + (area() - 1.0) * 0.5
				p.life = float(st["dur"])
				p.max_life = p.life
				p.kb = float(st["kb"])
				p.tick_rate = 0.45
				p.tex = "cheese"
				p.w = self
				p.pos = run.player.position + Vector2.from_angle(p.ang) * p.rad
				procs.append(p)
		Sfx.play("pop", -8.0, 0.8)

# ----------------------------------------------------------- repellent
class WRepellent extends Weapon:
	var spin_a: float = 0.0
	var pulse: float = 0.0

	func radius() -> float:
		return 92.0 * area()

	func update(dt: float) -> void:
		spin_a += dt * 1.4
		pulse = maxf(0.0, pulse - dt * 3.0)
		timer -= dt
		if timer > 0.0:
			return
		timer = cd()
		var pl := run.player
		var hit := run.en.query_circle(pl.position, radius())
		pulse = 1.0
		for e in hit:
			var d := dmg() * (2.0 if e.id == "mosquito" else 1.0)
			run.en.damage(e, d, pl.position, float(st["kb"]))
			if evolved:
				e.slow = maxf(e.slow, 1.2)
		if randf() < 0.5:
			var a := randf() * TAU
			run.fx.puff(pl.position + Vector2.from_angle(a) * radius() * randf(), Color(0.6, 1.0, 0.5, 0.5), 2)

	func draw(c: CanvasItem) -> void:
		var pl := run.player.position
		var r := radius()
		var col := Color(0.55, 0.95, 0.45) if not evolved else Color(0.85, 0.9, 0.55)
		c.draw_circle(pl, r, Color(col.r, col.g, col.b, 0.11 + 0.06 * pulse))
		c.draw_arc(pl, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.35 + 0.3 * pulse), 2.5, true)
		for i in 7:
			var a := spin_a + TAU * float(i) / 7.0
			var rr := r * (0.55 + 0.35 * sin(spin_a * 1.7 + i))
			c.draw_circle(pl + Vector2.from_angle(a) * rr, 7.0 + 3.0 * sin(spin_a * 2.0 + i * 2.0), Color(col.r, col.g, col.b, 0.16))

# ------------------------------------------------------------- thunder
class WThunder extends Weapon:
	func update(dt: float) -> void:
		timer -= dt
		if timer > 0.0:
			return
		var targets := run.en.random_visible(amt(), 600.0)
		if targets.is_empty():
			return
		timer = cd()
		for e in targets:
			var p := run.pj.make(Proj.K.BOLT)
			p.pos = e.pos + e.kb * 0.1
			p.rad = 62.0 * area()
			p.dmg = dmg()
			p.life = 0.38
			p.max_life = 0.38
			p.kb = float(st["kb"])
			p.chain = 3 if evolved else 0
			p.evo = evolved
			p.w = self

# ----------------------------------------------------------------- mud
class WMud extends Weapon:
	func update(dt: float) -> void:
		timer -= dt
		if timer > 0.0:
			return
		var pl := run.player
		if run.en.count() == 0:
			return
		timer = cd()
		var n := amt()
		var targets := run.en.random_visible(n, 440.0)
		for i in n:
			var tp: Vector2
			if i < targets.size():
				tp = targets[i].pos
			else:
				tp = pl.position + Vector2.from_angle(randf() * TAU) * randf_range(90.0, 220.0)
			var p := run.pj.make(Proj.K.MUDBALL)
			p.pos = pl.position
			p.tvec = tp
			p.a = pl.position.x
			p.b = pl.position.y
			p.life = 0.5
			p.max_life = 0.5
			p.w = self
		Sfx.play("mud", -8.0)

# ------------------------------------------------------------ vuvuzela
class WVuvuzela extends Weapon:
	func update(dt: float) -> void:
		timer -= dt
		if timer > 0.0:
			return
		var pl := run.player
		var tgt := run.en.nearest(pl.position, 320.0)
		if tgt == null:
			return
		timer = cd()
		var base := (tgt.pos - pl.position).angle()
		var n := amt()
		var reach := 235.0 * area()
		var half := deg_to_rad(40.0)
		var count := n
		if evolved:
			count = 1
			half = PI
		for i in count:
			var a := base + TAU * float(i) / float(count)
			_blast(pl.position, a, reach, half)
		Sfx.play("vuvu", -5.0, 1.0 + randf() * 0.05)
		run.shake(0.18)

	func _blast(origin: Vector2, a: float, reach: float, half: float) -> void:
		var wv := run.pj.make(Proj.K.WAVE)
		wv.pos = origin
		wv.rot = a
		wv.a = reach
		wv.b = half
		wv.life = 0.4
		wv.max_life = 0.4
		wv.evo = evolved
		for e in run.en.query_circle(origin, reach):
			var dv := e.pos - origin
			var diff := absf(wrapf(dv.angle() - a, -PI, PI))
			if diff <= half or dv.length() < 40.0:
				var crit := randf() < run.player.crit
				run.en.damage(e, dmg() * (2.0 if crit else 1.0), origin, float(st["kb"]), crit, 0.5)

# --------------------------------------------------------------- birds
class WBirds extends Weapon:
	var flock: Array[Proj] = []

	func update(_dt: float) -> void:
		var alive: Array[Proj] = []
		for p in flock:
			if not p.dead:
				alive.append(p)
		flock = alive
		var want := amt()
		while flock.size() < want:
			var p := run.pj.make(Proj.K.BIRD)
			p.ang = randf() * TAU
			p.pos = run.player.position + Vector2.from_angle(p.ang) * 60.0
			p.a = randf_range(0.3, 1.0)
			p.dmg = dmg()
			p.r = 13.0
			p.tex = "bird"
			p.w = self
			p.evo = evolved
			flock.append(p)

	func on_rebuild() -> void:
		for p in flock:
			p.dmg = dmg()
			p.evo = evolved
