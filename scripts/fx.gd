class_name Fx extends Node2D
## Juice: particles, floating numbers, rings, lightning, decals, screen flash.

const MAX_P := 800

class Floater:
	var text := ""
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life: float = 0.7
	var max_life: float = 0.7
	var col := Color.WHITE
	var size: int = 18
	var pop: float = 1.0

class Ring:
	var pos := Vector2.ZERO
	var r0: float = 0.0
	var r1: float = 50.0
	var life: float = 0.3
	var max_life: float = 0.3
	var col := Color.WHITE
	var width: float = 3.0

class Bolt:
	var pts := PackedVector2Array()
	var life: float = 0.25
	var max_life: float = 0.25
	var col := Color.WHITE

class DecalMark:
	var pos := Vector2.ZERO
	var size: float = 20.0
	var col := Color.WHITE
	var life: float = 8.0
	var max_life: float = 8.0

class GlowLayer extends Node2D:
	var fx: Fx
	func _draw() -> void:
		fx.draw_glow(self)

class DecalLayer extends Node2D:
	var fx: Fx
	func _draw() -> void:
		fx.draw_decals(self)

var run: Run
var n: int = 0
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat32Array()
var maxl := PackedFloat32Array()
var size := PackedFloat32Array()
var grow := PackedFloat32Array()
var drag := PackedFloat32Array()
var grav := PackedFloat32Array()
var col := PackedColorArray()
var kind := PackedInt32Array()
var rot := PackedFloat32Array()
var vrot := PackedFloat32Array()
var floaters: Array[Floater] = []
var rings: Array[Ring] = []
var bolts: Array[Bolt] = []
var decals: Array[DecalMark] = []
var glow_layer: GlowLayer
var decal_layer: DecalLayer
var flash_a: float = 0.0
var flash_col := Color.WHITE
var font: Font

func _init() -> void:
	pos.resize(MAX_P)
	vel.resize(MAX_P)
	life.resize(MAX_P)
	maxl.resize(MAX_P)
	size.resize(MAX_P)
	grow.resize(MAX_P)
	drag.resize(MAX_P)
	grav.resize(MAX_P)
	col.resize(MAX_P)
	kind.resize(MAX_P)
	rot.resize(MAX_P)
	vrot.resize(MAX_P)

func setup(r: Run) -> void:
	run = r
	font = G.title_font
	glow_layer = GlowLayer.new()
	glow_layer.fx = self
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = m
	add_child(glow_layer)
	decal_layer = DecalLayer.new()
	decal_layer.fx = self

func clear() -> void:
	n = 0
	floaters.clear()
	rings.clear()
	bolts.clear()
	decals.clear()

# --------------------------------------------------------------- emitters
func emit(p: Vector2, v: Vector2, lf: float, sz: float, c: Color, k: int = 0, gr: float = 0.0, dr: float = 2.0, gv: float = 0.0) -> void:
	if n >= MAX_P:
		return
	var i := n
	n += 1
	pos[i] = p
	vel[i] = v
	life[i] = lf
	maxl[i] = lf
	size[i] = sz
	grow[i] = gr
	drag[i] = dr
	grav[i] = gv
	col[i] = c
	kind[i] = k
	rot[i] = randf() * TAU
	vrot[i] = randf_range(-9.0, 9.0)

func burst(p: Vector2, c: Color, count: int, speed: float, lf: float = 0.5, sz: float = 3.0) -> void:
	for i in count:
		var a := randf() * TAU
		var s := speed * randf_range(0.35, 1.0)
		emit(p, Vector2.from_angle(a) * s, lf * randf_range(0.6, 1.0), sz * randf_range(0.6, 1.2), c, 0, -sz * 1.4 / maxf(lf, 0.1), 2.6)

func spark(p: Vector2, c: Color, count: int) -> void:
	for i in count:
		var a := randf() * TAU
		emit(p, Vector2.from_angle(a) * randf_range(180.0, 380.0), randf_range(0.14, 0.26), 2.4, c, 2, 0.0, 5.0)

func puff(p: Vector2, c: Color, count: int) -> void:
	for i in count:
		emit(p + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Vector2(randf_range(-30, 30), randf_range(-45, -5)), randf_range(0.45, 0.8), randf_range(9.0, 16.0), c, 4, 16.0, 2.0)

func confetti(p: Vector2, count: int) -> void:
	var cols := [Color("ff4d6d"), Color("ffd43b"), Color("4dd2ff"), Color("7be04a"), Color("c77dff"), Color("ff9a1f")]
	for i in count:
		var a := randf() * TAU
		emit(p, Vector2.from_angle(a) * randf_range(120.0, 460.0) + Vector2(0, -120), randf_range(0.9, 1.6), randf_range(3.5, 6.0), cols[randi() % cols.size()], 1, 0.0, 1.6, 420.0)

func glow_burst(p: Vector2, c: Color, count: int, speed: float) -> void:
	for i in count:
		emit(p, Vector2.from_angle(randf() * TAU) * speed * randf_range(0.3, 1.0), randf_range(0.3, 0.6), randf_range(10.0, 20.0), c, 3, -18.0, 2.5)

func ring(p: Vector2, r0: float, r1: float, lf: float, c: Color, w: float = 3.0) -> void:
	var r := Ring.new()
	r.pos = p
	r.r0 = r0
	r.r1 = r1
	r.life = lf
	r.max_life = lf
	r.col = c
	r.width = w
	rings.append(r)
	if rings.size() > 40:
		rings.pop_front()

func lightning(a: Vector2, b: Vector2, c: Color) -> void:
	var bl := Bolt.new()
	bl.col = c
	var d := b - a
	var len := d.length()
	var steps := maxi(3, int(len / 34.0))
	var dir := d / maxf(len, 1.0)
	var perp := Vector2(-dir.y, dir.x)
	bl.pts.append(a)
	for i in range(1, steps):
		var t := float(i) / float(steps)
		bl.pts.append(a.lerp(b, t) + perp * randf_range(-22.0, 22.0))
	bl.pts.append(b)
	bolts.append(bl)

func flash(a: float, c: Color) -> void:
	if not bool(G.data["settings"]["flashes"]):
		return
	flash_a = maxf(flash_a, a)
	flash_col = c

func decal(p: Vector2, c: Color, sz: float) -> void:
	if not _near_view(p):
		return
	var d := DecalMark.new()
	d.pos = p
	d.size = sz
	d.col = c
	d.life = randf_range(5.0, 8.0)
	d.max_life = d.life
	decals.append(d)
	if decals.size() > 70:
		decals.pop_front()

func _near_view(p: Vector2) -> bool:
	return p.distance_squared_to(run.cam_pos) < 900.0 * 900.0

func text(p: Vector2, s: String, c: Color, sz: int = 20, lf: float = 0.9) -> void:
	var f := Floater.new()
	f.text = s
	f.pos = p
	f.vel = Vector2(randf_range(-14, 14), -52)
	f.life = lf
	f.max_life = lf
	f.col = c
	f.size = sz
	floaters.append(f)
	if floaters.size() > 48:
		floaters.pop_front()

func dmg_number(p: Vector2, amount: float, crit: bool) -> void:
	if not bool(G.data["settings"]["numbers"]):
		return
	if floaters.size() > 30 and not crit and randf() < 0.6:
		return
	var v := int(round(amount))
	var s := str(v) if v < 10000 else "%.1fk" % (v / 1000.0)
	if crit:
		text(p, s + "!", Color("ffd43b"), 27, 0.85)
	else:
		text(p, s, Color("fff3dc"), 17, 0.6)

func big_explosion(p: Vector2, c: Color) -> void:
	burst(p, c, 40, 520.0, 1.0, 6.0)
	glow_burst(p, c, 14, 380.0)
	spark(p, Color.WHITE, 16)
	puff(p, Color(c.r, c.g, c.b, 0.5), 10)
	for i in 4:
		ring(p, 10.0, 160.0 + 90.0 * i, 0.5 + 0.15 * i, Color(c.r, c.g, c.b, 0.8), 6.0 - i)
	confetti(p, 30)

# ------------------------------------------------------------------ update
func update(dt: float) -> void:
	var i := n - 1
	while i >= 0:
		life[i] -= dt
		if life[i] <= 0.0:
			n -= 1
			if i != n:
				pos[i] = pos[n]
				vel[i] = vel[n]
				life[i] = life[n]
				maxl[i] = maxl[n]
				size[i] = size[n]
				grow[i] = grow[n]
				drag[i] = drag[n]
				grav[i] = grav[n]
				col[i] = col[n]
				kind[i] = kind[n]
				rot[i] = rot[n]
				vrot[i] = vrot[n]
		else:
			var v := vel[i]
			v *= maxf(0.0, 1.0 - drag[i] * dt)
			v.y += grav[i] * dt
			vel[i] = v
			pos[i] += v * dt
			size[i] = maxf(0.0, size[i] + grow[i] * dt)
			rot[i] += vrot[i] * dt
		i -= 1
	i = floaters.size() - 1
	while i >= 0:
		var f := floaters[i]
		f.life -= dt
		f.pos += f.vel * dt
		f.vel *= maxf(0.0, 1.0 - 2.2 * dt)
		f.pop = maxf(1.0, f.pop - dt * 6.0)
		if f.life <= 0.0:
			floaters.remove_at(i)
		i -= 1
	i = rings.size() - 1
	while i >= 0:
		rings[i].life -= dt
		if rings[i].life <= 0.0:
			rings.remove_at(i)
		i -= 1
	i = bolts.size() - 1
	while i >= 0:
		bolts[i].life -= dt
		if bolts[i].life <= 0.0:
			bolts.remove_at(i)
		i -= 1
	i = decals.size() - 1
	while i >= 0:
		decals[i].life -= dt
		if decals[i].life <= 0.0:
			decals.remove_at(i)
		i -= 1
	flash_a = maxf(0.0, flash_a - dt * 3.0)
	queue_redraw()
	glow_layer.queue_redraw()
	decal_layer.queue_redraw()

# -------------------------------------------------------------------- draw
func _draw() -> void:
	for r in rings:
		var k := 1.0 - r.life / r.max_life
		var rr := lerpf(r.r0, r.r1, 1.0 - pow(1.0 - k, 2.2))
		var c := r.col
		c.a *= 1.0 - k
		draw_arc(r.pos, rr, 0.0, TAU, 48, c, r.width * (1.0 - 0.6 * k), true)
	var g := Art.glow()
	for i in n:
		var kd := kind[i]
		if kd == 3:
			continue
		var a := clampf(life[i] / maxl[i] * 2.2, 0.0, 1.0)
		var c2 := col[i]
		c2.a *= a
		match kd:
			0:
				draw_circle(pos[i], size[i], c2)
			1:
				var s := size[i]
				var rr2 := rot[i]
				var d1 := Vector2.from_angle(rr2) * s
				var d2 := Vector2.from_angle(rr2 + 1.5) * s * 0.55
				draw_colored_polygon(PackedVector2Array([pos[i] + d1 + d2, pos[i] - d1 + d2, pos[i] - d1 - d2, pos[i] + d1 - d2]), c2)
			2:
				draw_line(pos[i], pos[i] - vel[i] * 0.04, c2, size[i], true)
			4:
				var s2 := size[i]
				draw_texture_rect(g, Rect2(pos[i] - Vector2(s2, s2), Vector2(s2, s2) * 2.0), false, c2)
	for f in floaters:
		var k2 := 1.0 - f.life / f.max_life
		var a2 := clampf(f.life / f.max_life * 2.5, 0.0, 1.0)
		var sc := 1.0 + maxf(0.0, 0.5 - k2 * 3.0)
		var fs := int(f.size * sc)
		var c3 := f.col
		c3.a = a2
		var o := Color(0.1, 0.05, 0.03, a2)
		draw_string_outline(font, f.pos - Vector2(100, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 200.0, fs, 6, o)
		draw_string(font, f.pos - Vector2(100, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 200.0, fs, c3)

func draw_glow(layer: Node2D) -> void:
	var g := Art.glow()
	for i in n:
		if kind[i] != 3:
			continue
		var a := clampf(life[i] / maxl[i] * 2.0, 0.0, 1.0)
		var c := col[i]
		c.a *= a
		var s := size[i]
		layer.draw_texture_rect(g, Rect2(pos[i] - Vector2(s, s), Vector2(s, s) * 2.0), false, c)
	for b in bolts:
		var a2 := b.life / b.max_life
		var oc := Color(b.col.r, b.col.g, b.col.b, 0.55 * a2)
		layer.draw_polyline(b.pts, oc, 14.0 * a2 + 4.0, true)
		layer.draw_polyline(b.pts, Color(1, 1, 1, a2), 3.5, true)
	for r in rings:
		var k := 1.0 - r.life / r.max_life
		if k < 0.5:
			layer.draw_circle(r.pos, lerpf(r.r0, r.r1, k) * 0.6, Color(r.col.r, r.col.g, r.col.b, 0.12 * (1.0 - k * 2.0)))

func draw_decals(layer: Node2D) -> void:
	var g := Art.glow()
	for d in decals:
		var a := clampf(d.life / d.max_life * 1.6, 0.0, 1.0)
		var c := d.col
		c.a *= a * 0.55
		layer.draw_texture_rect(g, Rect2(d.pos - Vector2(d.size, d.size * 0.6), Vector2(d.size * 2.0, d.size * 1.2)), false, c)
