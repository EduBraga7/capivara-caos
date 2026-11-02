class_name Art
## Procedural vector art. Every sprite is drawn with CanvasItem primitives and
## baked into one atlas (see Baker). Coordinates: origin = sprite centre, y down.

const OUT := Color("2a1810")
const WHITE := Color(1, 1, 1)

# [name, cell_w, cell_h, frames] (logical pixels; the atlas is rendered at 2x)
const SPRITES := [
	["shadow", 72, 28, 1],
	["mosquito", 64, 64, 2],
	["barata", 80, 64, 2],
	["rato", 88, 64, 2],
	["pombo", 88, 80, 2],
	["sapo", 104, 88, 2],
	["gamba", 104, 88, 2],
	["voadora", 104, 88, 2],
	["jacare", 300, 150, 2],
	["onca", 250, 130, 2],
	["gem1", 28, 28, 1], ["gem2", 32, 32, 1], ["gem3", 38, 38, 1], ["gem4", 46, 46, 1],
	["coin", 28, 28, 1],
	["melancia", 44, 40, 1],
	["ima", 44, 44, 1],
	["rojao", 36, 52, 1],
	["bau", 60, 52, 1],
	["orange", 34, 34, 1],
	["flipflop", 52, 52, 1],
	["cheese", 34, 34, 1],
	["bird", 48, 44, 2],
	["mudball", 30, 30, 1],
	["heart", 34, 34, 1],
	["skull", 34, 34, 1],
	["ic_orange", 60, 60, 1], ["ic_flipflop", 60, 60, 1], ["ic_cheese", 60, 60, 1], ["ic_repellent", 60, 60, 1],
	["ic_thunder", 60, 60, 1], ["ic_mud", 60, 60, 1], ["ic_vuvuzela", 60, 60, 1], ["ic_birds", 60, 60, 1],
	["ic_guarana", 60, 60, 1], ["ic_cafe", 60, 60, 1], ["ic_tenis", 60, 60, 1], ["ic_marmita", 60, 60, 1],
	["ic_capa", 60, 60, 1], ["ic_coco", 60, 60, 1], ["ic_ima", 60, 60, 1], ["ic_fermento", 60, 60, 1],
	["ic_xerox", 60, 60, 1], ["ic_cursinho", 60, 60, 1], ["ic_trevo", 60, 60, 1], ["ic_cofrinho", 60, 60, 1],
	["ic_heart", 60, 60, 1], ["ic_reroll", 60, 60, 1], ["ic_coins", 60, 60, 1],
	["flower", 30, 30, 4], ["tuft", 40, 30, 2], ["mushroom", 30, 30, 1], ["rock", 44, 30, 2], ["reed", 44, 56, 1], ["lily", 48, 34, 1],
]

static var glow_tex: Texture2D = null

static func glow() -> Texture2D:
	if glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		glow_tex = t
	return glow_tex

# ================================================================ toolkit
static func ell(c: CanvasItem, p: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	var n := 30 if maxf(rx, ry) > 16.0 else 20
	var pts := PackedVector2Array()
	pts.resize(n)
	var cs := cos(rot)
	var sn := sin(rot)
	for i in n:
		var a := TAU * float(i) / float(n)
		var x := cos(a) * rx
		var y := sin(a) * ry
		pts[i] = Vector2(p.x + x * cs - y * sn, p.y + x * sn + y * cs)
	c.draw_colored_polygon(pts, col)

static func flat(c: CanvasItem, p: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, ol: float = 2.0) -> void:
	ell(c, p, rx + ol, ry + ol, OUT, rot)
	ell(c, p, rx, ry, col, rot)

static func blob(c: CanvasItem, p: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, ol: float = 2.0) -> void:
	ell(c, p, rx + ol, ry + ol, OUT, rot)
	ell(c, p, rx, ry, col.darkened(0.3), rot)
	ell(c, p + Vector2(-rx * 0.06, -ry * 0.14).rotated(rot), rx * 0.94, ry * 0.84, col, rot)
	ell(c, p + Vector2(-rx * 0.28, -ry * 0.42).rotated(rot), rx * 0.34, ry * 0.19, col.lightened(0.42), rot)

static func poly(c: CanvasItem, pts: PackedVector2Array, col: Color, ol: float = 2.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, OUT, ol * 2.0, true)
	c.draw_colored_polygon(pts, col)

static func limb(c: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, ol: float = 1.6) -> void:
	var ow := w + ol * 2.0
	var aa := w < 5.0
	c.draw_line(a, b, OUT, ow, aa)
	c.draw_circle(a, ow * 0.5, OUT)
	c.draw_circle(b, ow * 0.5, OUT)
	c.draw_line(a, b, col, w, aa)
	c.draw_circle(a, w * 0.5, col)
	c.draw_circle(b, w * 0.5, col)

static func curve(c: CanvasItem, pts: PackedVector2Array, w: float, col: Color, ol: float = 1.6) -> void:
	c.draw_polyline(pts, OUT, w + ol * 2.0, true)
	c.draw_circle(pts[0], (w + ol * 2.0) * 0.5, OUT)
	c.draw_circle(pts[pts.size() - 1], (w + ol * 2.0) * 0.5, OUT)
	c.draw_polyline(pts, col, w, true)
	c.draw_circle(pts[0], w * 0.5, col)
	c.draw_circle(pts[pts.size() - 1], w * 0.5, col)

static func eye(c: CanvasItem, p: Vector2, r: float, look: Vector2 = Vector2(0.45, 0.0), brow: float = 0.0, iris: Color = Color("1a1010")) -> void:
	c.draw_circle(p, r + 1.3, OUT)
	c.draw_circle(p, r, WHITE)
	var pp := p + look * r * 0.38
	c.draw_circle(pp, r * 0.58, iris)
	c.draw_circle(pp + Vector2(-r * 0.2, -r * 0.22), r * 0.22, WHITE)
	if brow != 0.0:
		var a := p + Vector2(-r * 1.3, -r * (1.25 + brow * 0.5))
		var b := p + Vector2(r * 1.3, -r * (1.25 - brow * 0.9))
		c.draw_line(a, b, OUT, maxf(1.6, r * 0.7), true)

static func heart_pts(p: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var t := TAU * float(i) / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(p + Vector2(x, y) * (s / 17.0))
	return pts

static func star4(c: CanvasItem, p: Vector2, r: float, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rr := r if i % 2 == 0 else r * 0.28
		pts.append(p + Vector2.from_angle(rot + TAU * float(i) / 8.0) * rr)
	c.draw_colored_polygon(pts, col)

static func sprite_key(name: String, f: int, frames: int) -> String:
	return name if frames == 1 else "%s_%d" % [name, f]

static func draw_sprite(c: CanvasItem, name: String, f: int) -> void:
	match name:
		"shadow": s_shadow(c)
		"mosquito": s_mosquito(c, f)
		"barata": s_barata(c, f)
		"rato": s_rato(c, f)
		"pombo": s_pombo(c, f)
		"sapo": s_sapo(c, f)
		"gamba": s_gamba(c, f)
		"voadora": s_voadora(c, f)
		"jacare": s_jacare(c, f)
		"onca": s_onca(c, f)
		"gem1": s_gem(c, Color("29d3c2"), 8.5)
		"gem2": s_gem(c, Color("7be04a"), 10.0)
		"gem3": s_gem(c, Color("a266ff"), 12.0)
		"gem4": s_gem(c, Color("ffd43b"), 15.0)
		"coin": s_coin(c)
		"melancia": s_melancia(c)
		"ima": s_ima(c, 1.0)
		"rojao": s_rojao(c)
		"bau": s_bau(c)
		"orange": s_orange(c)
		"flipflop": s_flipflop(c)
		"cheese": s_cheese(c)
		"bird": s_bird(c, f)
		"mudball": s_mudball(c)
		"heart": s_heart(c, 1.0)
		"skull": s_skull(c)
		"ic_orange": c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.85, 1.85)); s_orange(c)
		"ic_flipflop": c.draw_set_transform(Vector2.ZERO, 0.6, Vector2(1.15, 1.15)); s_flipflop(c)
		"ic_cheese": c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.75, 1.75)); s_cheese(c)
		"ic_repellent": i_repellent(c)
		"ic_thunder": i_thunder(c)
		"ic_mud": i_mud(c)
		"ic_vuvuzela": i_vuvuzela(c)
		"ic_birds": c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.5, 1.5)); s_bird(c, 0)
		"ic_guarana": i_guarana(c)
		"ic_cafe": i_cafe(c)
		"ic_tenis": i_tenis(c)
		"ic_marmita": i_marmita(c)
		"ic_capa": i_capa(c)
		"ic_coco": i_coco(c)
		"ic_ima": c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.3, 1.3)); s_ima(c, 1.0)
		"ic_fermento": i_fermento(c)
		"ic_xerox": i_xerox(c)
		"ic_cursinho": i_cursinho(c)
		"ic_trevo": i_trevo(c)
		"ic_cofrinho": i_cofrinho(c)
		"ic_heart": c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.5, 1.5)); s_heart(c, 1.0)
		"ic_reroll": i_reroll(c)
		"ic_coins": c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.9, 1.9)); s_coin(c)
		"flower": s_flower(c, f)
		"tuft": s_tuft(c, f)
		"mushroom": s_mushroom(c)
		"rock": s_rock(c, f)
		"reed": s_reed(c)
		"lily": s_lily(c)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ============================================================== enemies
static func s_shadow(c: CanvasItem) -> void:
	for i in 7:
		var k := float(i) / 6.0
		ell(c, Vector2.ZERO, 30.0 * (1.0 - k * 0.7), 9.0 * (1.0 - k * 0.7), Color(0, 0, 0, 0.1))

static func s_mosquito(c: CanvasItem, f: int) -> void:
	var anchor := Vector2(2, -3)
	var angs: Array = [-1.15, -2.05] if f == 0 else [-0.3, -2.85]
	for a in angs:
		var ctr: Vector2 = anchor + Vector2.from_angle(a) * 9.5
		ell(c, ctr, 11.6, 4.7, Color(0.1, 0.12, 0.2, 0.5), a)
		ell(c, ctr, 10.4, 3.7, Color(0.9, 0.97, 1.0, 0.85), a)
	var lw := 1.6 if f == 0 else -1.6
	var lc := Color("3b2a2a")
	limb(c, Vector2(-2, 4), Vector2(-10 + lw, 15), 1.5, lc, 0.9)
	limb(c, Vector2(1, 4.5), Vector2(-lw, 16.5), 1.5, lc, 0.9)
	limb(c, Vector2(4, 4), Vector2(10 + lw, 14.5), 1.5, lc, 0.9)
	blob(c, Vector2(-8, 2.5), 8.6, 4.8, Color("584444"), 0.28, 1.8)
	ell(c, Vector2(-9.5, 4.3), 4.6, 1.5, Color(0.85, 0.12, 0.12, 0.95), 0.28)
	blob(c, Vector2(2, 0), 5.8, 5.2, Color("6a5252"), 0.0, 1.8)
	blob(c, Vector2(9.5, -0.5), 4.4, 4.2, Color("584444"), 0.0, 1.8)
	c.draw_circle(Vector2(11, -2), 2.4, Color("ff2a2a"))
	c.draw_circle(Vector2(10.3, -2.8), 0.8, WHITE)
	limb(c, Vector2(13, 1), Vector2(23, 4.5), 1.5, OUT, 0.7)

static func s_barata(c: CanvasItem, f: int) -> void:
	var leg := Color("5a2c12")
	var sw := 3.0 if f == 0 else -3.0
	for i in 3:
		var x := -9.0 + 8.0 * i
		var s := sw if i % 2 == 0 else -sw
		limb(c, Vector2(x, 6), Vector2(x - 5 + s, 19), 2.6, leg, 1.4)
		limb(c, Vector2(x + 2, 6), Vector2(x + 8 - s, 18), 2.6, leg, 1.4)
	curve(c, PackedVector2Array([Vector2(21, -3), Vector2(28, -13), Vector2(37, -16)]), 1.6, leg, 1.0)
	curve(c, PackedVector2Array([Vector2(21, -1), Vector2(31, -6), Vector2(40, -5)]), 1.6, leg, 1.0)
	blob(c, Vector2(-2, 2), 17.0, 11.0, Color("a0541f"), 0.0, 2.2)
	c.draw_line(Vector2(-14, -2), Vector2(10, -5), Color("5a2c12"), 1.8, true)
	blob(c, Vector2(17, 0.5), 6.5, 6.0, Color("6b3515"), 0.0, 2.0)
	eye(c, Vector2(20, -2), 2.5, Vector2(0.6, 0.2), 0.8)

static func s_rato(c: CanvasItem, f: int) -> void:
	var tail := PackedVector2Array([Vector2(-17, 5), Vector2(-27, 2), Vector2(-34, -5), Vector2(-39, -6)])
	curve(c, tail, 2.8, Color("e9a0a8"), 1.5)
	var sw := 4.0 if f == 0 else -4.0
	limb(c, Vector2(-8, 7), Vector2(-9 + sw, 16), 4.0, Color("73737f"), 1.5)
	limb(c, Vector2(8, 7), Vector2(9 - sw, 16), 4.0, Color("73737f"), 1.5)
	blob(c, Vector2(-3, 2), 17.0, 10.5, Color("9b9ba8"), 0.0, 2.2)
	ell(c, Vector2(-1, 8), 11.0, 3.2, Color("c9c9d4"))
	blob(c, Vector2(14, 1.5), 9.5, 7.8, Color("a6a6b3"), 0.0, 2.0)
	blob(c, Vector2(9, -7), 5.2, 5.4, Color("e9a0a8"), 0.0, 1.8)
	c.draw_circle(Vector2(23.5, 3), 2.7, Color("ff7a90"))
	eye(c, Vector2(17, -1.5), 2.3, Vector2(0.5, 0.2), 0.7, Color("a01020"))
	c.draw_line(Vector2(22, 4), Vector2(31, 1), Color(0.15, 0.1, 0.1, 0.8), 1.0, true)
	c.draw_line(Vector2(22, 5.5), Vector2(31, 7), Color(0.15, 0.1, 0.1, 0.8), 1.0, true)

static func s_pombo(c: CanvasItem, f: int) -> void:
	poly(c, PackedVector2Array([Vector2(-14, 1), Vector2(-30, -4), Vector2(-31, 8), Vector2(-14, 8)]), Color("6b7a99"), 1.8)
	limb(c, Vector2(-2, 11), Vector2(-4, 19), 2.2, Color("ff8fa3"), 1.0)
	limb(c, Vector2(5, 11), Vector2(7, 19), 2.2, Color("ff8fa3"), 1.0)
	blob(c, Vector2(0, 2), 16.0, 11.5, Color("8f9fbf"), 0.0, 2.2)
	ell(c, Vector2(7, 6), 8.0, 5.0, Color("b9c6de"))
	blob(c, Vector2(10, -4.5), 7.5, 5.0, Color("7a5fa8"), -0.3, 1.8)
	blob(c, Vector2(14, -10), 7.6, 7.2, Color("9aa9c9"), 0.0, 2.0)
	poly(c, PackedVector2Array([Vector2(20, -11), Vector2(29, -8), Vector2(20, -6)]), Color("ffb02e"), 1.4)
	eye(c, Vector2(16.5, -11.5), 2.7, Vector2(0.5, 0.1), 0.6, Color("ff8a00"))
	if f == 0:
		blob(c, Vector2(-5, -8), 14.0, 5.5, Color("a9b6d2"), -0.55, 1.9)
	else:
		blob(c, Vector2(-5, 8), 14.0, 5.5, Color("a9b6d2"), 0.55, 1.9)

static func s_sapo(c: CanvasItem, f: int) -> void:
	var dk := Color("4f7a2a")
	if f == 0:
		blob(c, Vector2(-13, 12), 11.0, 8.0, Color("5f8f33"), -0.3, 2.0)
		limb(c, Vector2(14, 12), Vector2(19, 19), 6.0, Color("5f8f33"), 1.6)
	else:
		limb(c, Vector2(-14, 8), Vector2(-30, 17), 8.0, Color("5f8f33"), 1.8)
		limb(c, Vector2(14, 10), Vector2(30, 6), 6.0, Color("5f8f33"), 1.6)
	blob(c, Vector2(0, 3), 24.0, 16.5, Color("79ab3e"), 0.0, 2.4)
	ell(c, Vector2(3, 10), 16.0, 6.5, Color("d2e58f"))
	for w in [Vector2(-12, -2), Vector2(-4, 4), Vector2(10, -1), Vector2(16, 6), Vector2(-17, 7)]:
		c.draw_circle(w, 2.6, dk)
	c.draw_line(Vector2(-9, 4.5), Vector2(8, 7), OUT, 2.2, true)
	c.draw_line(Vector2(8, 7), Vector2(24, 3), OUT, 2.2, true)
	for ex in [Vector2(9, -13), Vector2(-2, -14)]:
		blob(c, ex, 7.2, 6.8, Color("79ab3e"), 0.0, 1.9)
		c.draw_circle(ex + Vector2(0.5, 0), 4.6, Color("f4e46a"))
		ell(c, ex + Vector2(1, 0.5), 3.4, 1.8, Color("1a1010"))
		c.draw_line(ex + Vector2(-5, -4), ex + Vector2(5, -1.5), OUT, 2.0, true)

static func s_gamba(c: CanvasItem, f: int) -> void:
	var dk := Color("34343f")
	blob(c, Vector2(-27, -8), 12.5, 19.0, dk, -0.45, 2.0)
	ell(c, Vector2(-27, -10), 4.4, 14.0, Color("f2f2f7"), -0.45)
	var sw := 4.5 if f == 0 else -4.5
	limb(c, Vector2(-10, 9), Vector2(-11 + sw, 20), 5.5, dk, 1.6)
	limb(c, Vector2(12, 9), Vector2(13 - sw, 20), 5.5, dk, 1.6)
	blob(c, Vector2(-2, 2), 21.0, 12.5, Color("43434f"), 0.0, 2.2)
	ell(c, Vector2(-4, -6), 17.0, 3.4, Color("f2f2f7"))
	blob(c, Vector2(20, 2), 10.5, 8.5, Color("43434f"), 0.0, 2.0)
	blob(c, Vector2(28, 4.5), 5.6, 4.4, Color("e8e8ee"), 0.0, 1.6)
	c.draw_circle(Vector2(33, 3.5), 2.2, OUT)
	blob(c, Vector2(15, -7), 4.0, 4.4, Color("43434f"), 0.0, 1.6)
	eye(c, Vector2(23, -0.5), 2.5, Vector2(0.5, 0.2), 0.8)

static func s_voadora(c: CanvasItem, f: int) -> void:
	var leg := Color("5a1f10")
	var sw := 3.5 if f == 0 else -3.5
	for i in 3:
		var x := -10.0 + 9.0 * i
		var s := sw if i % 2 == 0 else -sw
		limb(c, Vector2(x, 7), Vector2(x - 6 + s, 20), 2.8, leg, 1.4)
		limb(c, Vector2(x + 2, 7), Vector2(x + 9 - s, 19), 2.8, leg, 1.4)
	curve(c, PackedVector2Array([Vector2(23, -3), Vector2(31, -15), Vector2(42, -18)]), 1.7, leg, 1.0)
	curve(c, PackedVector2Array([Vector2(23, -1), Vector2(34, -7), Vector2(45, -6)]), 1.7, leg, 1.0)
	if f == 1:
		for a in [-0.95, -2.1]:
			var ctr: Vector2 = Vector2(-2, -6) + Vector2.from_angle(a) * 14.0
			ell(c, ctr, 17.0, 7.0, Color(0.3, 0.1, 0.0, 0.5), a)
			ell(c, ctr, 15.8, 6.0, Color(1.0, 0.78, 0.35, 0.78), a)
	blob(c, Vector2(-2, 2), 19.0, 12.0, Color("b8481f"), 0.0, 2.3)
	c.draw_line(Vector2(-16, -3), Vector2(13, -6), Color("5a1f10"), 1.8, true)
	blob(c, Vector2(19, 0.5), 7.5, 6.8, Color("6a2412"), 0.0, 2.0)
	eye(c, Vector2(22, -2.2), 3.0, Vector2(0.6, 0.2), 1.0, Color("ff2a2a"))

static func s_jacare(c: CanvasItem, f: int) -> void:
	var gr := Color("4a8a43")
	var gd := Color("2f6a30")
	# tail
	var tail := [[-108, 14, 9], [-90, 10, 13], [-70, 7, 18], [-48, 4, 23]]
	for t in tail:
		blob(c, Vector2(t[0], t[1]), t[2], t[2] * 0.8, gr, 0.0, 2.4)
	# legs
	limb(c, Vector2(-34, 24), Vector2(-40, 50), 17.0, gd, 2.4)
	limb(c, Vector2(26, 24), Vector2(34, 50), 17.0, gd, 2.4)
	for tx in [-48.0, -40.0, -32.0, 26.0, 34.0, 42.0]:
		c.draw_circle(Vector2(tx, 53), 3.2, Color("f2efe0"))
	# body
	blob(c, Vector2(-14, 4), 66.0, 30.0, gr, 0.0, 2.8)
	ell(c, Vector2(-10, 22), 52.0, 8.0, Color("c7de8a"))
	for i in 9:
		var x := -64.0 + 12.5 * i
		poly(c, PackedVector2Array([Vector2(x - 5, -23), Vector2(x, -35), Vector2(x + 5, -23)]), gd, 1.8)
	for i in 5:
		ell(c, Vector2(-44.0 + 20.0 * i, -6), 7.0, 4.0, gd, 0.2)
	# head / jaws
	var jaw := 0.0 if f == 0 else 0.42
	var pivot := Vector2(40, 12)
	var lower := PackedVector2Array([Vector2(36, 8), Vector2(124, 10), Vector2(128, 20), Vector2(40, 24)])
	var lw := PackedVector2Array()
	for p in lower:
		lw.append(pivot + (p - pivot).rotated(jaw))
	poly(c, lw, Color("3f7a3a"), 2.4)
	for i in 6:
		var tp: Vector2 = pivot + (Vector2(60.0 + 11.0 * i, 9.5) - pivot).rotated(jaw)
		poly(c, PackedVector2Array([tp + Vector2(-3, 0), tp + Vector2(3, 0), tp + Vector2(0, -8).rotated(jaw)]), Color("f8f4e6"), 1.0)
	poly(c, PackedVector2Array([Vector2(28, -22), Vector2(124, -8), Vector2(126, 8), Vector2(34, 10)]), gr, 2.6)
	for i in 6:
		var tx := 62.0 + 11.0 * i
		poly(c, PackedVector2Array([Vector2(tx - 3, 8.5 - i * 0.0), Vector2(tx + 3, 8.5), Vector2(tx, 15)]), Color("f8f4e6"), 1.0)
	c.draw_circle(Vector2(120, -6), 3.0, OUT)
	blob(c, Vector2(46, -22), 10.0, 9.0, gr, 0.0, 2.2)
	c.draw_circle(Vector2(48, -22), 7.0, Color("ffe14a"))
	c.draw_circle(Vector2(48, -22), 7.0, Color(1, 1, 1, 0.0))
	ell(c, Vector2(49, -22), 2.0, 5.5, OUT)
	c.draw_line(Vector2(38, -32), Vector2(58, -25), OUT, 3.4, true)

static func s_onca(c: CanvasItem, f: int) -> void:
	var yel := Color("eeaa38")
	var dk := Color("c98524")
	var spots := Color("4a2a0e")
	# tail
	curve(c, PackedVector2Array([Vector2(-62, 2), Vector2(-84, -8), Vector2(-98, -30), Vector2(-92, -48)]), 9.0, yel, 2.2)
	c.draw_circle(Vector2(-92, -48), 5.0, spots)
	# legs
	if f == 0:
		limb(c, Vector2(-40, 14), Vector2(-52, 40), 14.0, dk, 2.2)
		limb(c, Vector2(-24, 16), Vector2(-24, 44), 13.0, dk, 2.2)
		limb(c, Vector2(26, 16), Vector2(30, 44), 13.0, dk, 2.2)
		limb(c, Vector2(40, 12), Vector2(50, 38), 14.0, dk, 2.2)
	else:
		limb(c, Vector2(-40, 12), Vector2(-78, 34), 14.0, dk, 2.2)
		limb(c, Vector2(-24, 14), Vector2(-60, 40), 13.0, dk, 2.2)
		limb(c, Vector2(26, 12), Vector2(62, 30), 13.0, dk, 2.2)
		limb(c, Vector2(40, 8), Vector2(78, 24), 14.0, dk, 2.2)
	blob(c, Vector2(-10, 2), 58.0, 26.0, yel, 0.0, 2.8)
	ell(c, Vector2(-8, 18), 44.0, 7.0, Color("f7dc9a"))
	for sp in [Vector2(-44, -8), Vector2(-26, -14), Vector2(-8, -10), Vector2(10, -14), Vector2(28, -8), Vector2(-34, 6), Vector2(-14, 6), Vector2(6, 4), Vector2(24, 8), Vector2(-50, 8), Vector2(40, -2)]:
		ell(c, sp, 6.5, 5.0, spots, 0.3)
		ell(c, sp, 3.0, 2.2, yel, 0.3)
	# head
	blob(c, Vector2(54, -8), 25.0, 21.0, Color("f2b444"), 0.0, 2.6)
	blob(c, Vector2(42, -28), 7.0, 8.0, Color("f2b444"), 0.0, 2.0)
	blob(c, Vector2(62, -28), 7.0, 8.0, Color("f2b444"), 0.0, 2.0)
	ell(c, Vector2(42, -28), 3.0, 4.0, Color("ff9aa8"))
	ell(c, Vector2(62, -28), 3.0, 4.0, Color("ff9aa8"))
	blob(c, Vector2(70, -1), 13.0, 10.0, Color("fbeccd"), 0.0, 2.0)
	poly(c, PackedVector2Array([Vector2(76, -8), Vector2(86, -7), Vector2(81, -1)]), Color("ff8fa3"), 1.4)
	if f == 1:
		poly(c, PackedVector2Array([Vector2(64, 5), Vector2(84, 6), Vector2(74, 17)]), Color("d8203a"), 1.6)
		poly(c, PackedVector2Array([Vector2(68, 5), Vector2(71, 5), Vector2(69, 11)]), Color("ffffff"), 0.8)
		poly(c, PackedVector2Array([Vector2(78, 6), Vector2(81, 6), Vector2(80, 12)]), Color("ffffff"), 0.8)
	else:
		c.draw_line(Vector2(64, 6), Vector2(82, 6), OUT, 2.0, true)
	eye(c, Vector2(58, -14), 5.0, Vector2(0.5, 0.2), 0.9, Color("3aa040"))
	c.draw_line(Vector2(44, -14), Vector2(50, -8), spots, 2.0, true)
	c.draw_line(Vector2(46, -2), Vector2(52, 4), spots, 2.0, true)

# =============================================================== pickups
static func s_gem(c: CanvasItem, col: Color, r: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.8, -r * 0.35), Vector2(r * 0.62, r * 0.5), Vector2(0, r), Vector2(-r * 0.62, r * 0.5), Vector2(-r * 0.8, -r * 0.35)])
	poly(c, pts, col.darkened(0.15), 1.8)
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, -r * 0.85), Vector2(r * 0.62, -r * 0.3), Vector2(0, r * 0.05), Vector2(-r * 0.62, -r * 0.3)]), col.lightened(0.25))
	c.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.55, -r * 0.28), Vector2(0, r * 0.05), Vector2(-r * 0.05, r * 0.8), Vector2(-r * 0.5, r * 0.42)]), col)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.3, -r * 0.6), Vector2(-r * 0.05, -r * 0.62), Vector2(-r * 0.2, -r * 0.3)]), Color(1, 1, 1, 0.75))

static func s_coin(c: CanvasItem) -> void:
	flat(c, Vector2.ZERO, 9.0, 9.0, Color("ffcf33"), 0.0, 1.8)
	c.draw_circle(Vector2.ZERO, 6.4, Color("e8a91a"))
	c.draw_circle(Vector2(-0.4, -0.4), 5.4, Color("ffe066"))
	c.draw_line(Vector2(0, -3.5), Vector2(0, 3.5), Color("c98a10"), 1.8, true)
	c.draw_line(Vector2(-2.3, -1.4), Vector2(2.3, -1.4), Color("c98a10"), 1.4, true)
	c.draw_line(Vector2(-2.3, 1.4), Vector2(2.3, 1.4), Color("c98a10"), 1.4, true)
	c.draw_arc(Vector2.ZERO, 7.6, 3.6, 4.5, 8, Color(1, 1, 1, 0.8), 1.4, true)

static func s_melancia(c: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI * float(i) / 16.0
		pts.append(Vector2(cos(a) * 17.0, sin(a) * 15.0 - 5.0))
	poly(c, pts, Color("3fa34d"), 2.0)
	var pts2 := PackedVector2Array()
	for i in 17:
		var a := PI * float(i) / 16.0
		pts2.append(Vector2(cos(a) * 14.0, sin(a) * 11.5 - 5.0))
	c.draw_colored_polygon(pts2, Color("ff5a6a"))
	var pts3 := PackedVector2Array()
	for i in 17:
		var a := PI * float(i) / 16.0
		pts3.append(Vector2(cos(a) * 15.0, sin(a) * 12.5 - 5.0))
	c.draw_polyline(pts3, Color("f4f7d2"), 1.8, true)
	for s in [Vector2(-7, 0), Vector2(0, 3), Vector2(7, 0), Vector2(-3, -3), Vector2(4, -3)]:
		ell(c, s + Vector2(0, -1), 1.3, 2.0, OUT, 0.5)

static func s_ima(c: CanvasItem, k: float) -> void:
	var r := 10.0 * k
	var pts := PackedVector2Array()
	for i in 19:
		var a := PI + PI * float(i) / 18.0
		pts.append(Vector2(cos(a) * r, sin(a) * r + 2.0))
	curve(c, pts, 8.0 * k, Color("e63946"), 2.0)
	for sx in [-1.0, 1.0]:
		var base := Vector2(sx * r, 2.0)
		limb(c, base, base + Vector2(0, 8.5 * k), 8.0 * k, Color("e63946"), 2.0)
		poly(c, PackedVector2Array([base + Vector2(-4.2 * k, 6.5 * k), base + Vector2(4.2 * k, 6.5 * k), base + Vector2(4.2 * k, 11.5 * k), base + Vector2(-4.2 * k, 11.5 * k)]), Color("f1f1f1"), 1.6)

static func s_rojao(c: CanvasItem) -> void:
	limb(c, Vector2(0, 8), Vector2(0, 22), 2.4, Color("c8a15a"), 1.2)
	poly(c, PackedVector2Array([Vector2(-6, -10), Vector2(6, -10), Vector2(6, 10), Vector2(-6, 10)]), Color("e63946"), 2.0)
	c.draw_rect(Rect2(-6, -2, 12, 4), Color("ffd43b"))
	poly(c, PackedVector2Array([Vector2(-6, -10), Vector2(6, -10), Vector2(0, -19)]), Color("ffd43b"), 1.8)
	c.draw_line(Vector2(0, -19), Vector2(2, -23), OUT, 1.6, true)
	star4(c, Vector2(3, -24), 5.0, Color("fff2a8"))

static func s_bau(c: CanvasItem) -> void:
	poly(c, PackedVector2Array([Vector2(-23, -4), Vector2(23, -4), Vector2(23, 18), Vector2(-23, 18)]), Color("a8642c"), 2.4)
	var lid := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		lid.append(Vector2(cos(a) * 23.0, sin(a) * 15.0 - 4.0))
	poly(c, lid, Color("c27a38"), 2.4)
	c.draw_rect(Rect2(-23, -5, 46, 4), Color("ffd43b"))
	c.draw_rect(Rect2(-9, -17, 4, 34), Color("ffd43b"))
	c.draw_rect(Rect2(5, -17, 4, 34), Color("ffd43b"))
	flat(c, Vector2(0, 3), 5.0, 5.5, Color("ffe066"), 0.0, 1.8)
	c.draw_circle(Vector2(0, 3), 1.6, OUT)

static func s_orange(c: CanvasItem) -> void:
	blob(c, Vector2.ZERO, 10.0, 10.0, Color("ff9a1f"), 0.0, 1.9)
	for p in [Vector2(-4, 3), Vector2(3, 5), Vector2(5, -2), Vector2(-2, -4)]:
		c.draw_circle(p, 0.7, Color("e0780a"))
	flat(c, Vector2(4.5, -11.5), 5.2, 2.6, Color("5fbf3a"), -0.55, 1.5)
	c.draw_circle(Vector2(0.5, -9.5), 1.5, Color("2f7a22"))

static func s_flipflop(c: CanvasItem) -> void:
	var sole := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		sole.append(Vector2(cos(a) * 9.0, sin(a) * 19.0 + (3.0 if sin(a) > 0.0 else 0.0) * 0.0))
	poly(c, sole, Color("ffd43b"), 2.0)
	ell(c, Vector2(0, 8), 7.0, 9.5, Color("ffe98a"))
	ell(c, Vector2(0, -12), 5.5, 5.0, Color("ffe98a"))
	var s1 := Color("1f73e0")
	limb(c, Vector2(-7, 2), Vector2(0, -9), 3.4, s1, 1.2)
	limb(c, Vector2(7, 2), Vector2(0, -9), 3.4, s1, 1.2)
	c.draw_line(Vector2(-5, 0), Vector2(0, -8), Color(1, 1, 1, 0.9), 1.0, true)
	c.draw_line(Vector2(5, 0), Vector2(0, -8), Color(1, 1, 1, 0.9), 1.0, true)
	c.draw_circle(Vector2(0, -9), 2.4, Color("fff"))

static func s_cheese(c: CanvasItem) -> void:
	blob(c, Vector2.ZERO, 11.0, 10.5, Color("f6b94a"), 0.0, 1.9)
	for p in [Vector2(-4, -3), Vector2(4, -4), Vector2(0, 3), Vector2(6, 3), Vector2(-6, 4)]:
		c.draw_circle(p, 1.7, Color("c98a1e"))
	for p in [Vector2(-1, -6), Vector2(-7, 0)]:
		c.draw_circle(p, 1.2, Color("fff0b0"))

static func s_bird(c: CanvasItem, f: int) -> void:
	var yel := Color("ffd23f")
	poly(c, PackedVector2Array([Vector2(-8, 1), Vector2(-17, -2), Vector2(-17, 6)]), Color("3fae49"), 1.4)
	blob(c, Vector2(0, 2), 9.5, 7.5, yel, 0.0, 1.8)
	blob(c, Vector2(8, -4), 5.8, 5.6, yel, 0.0, 1.8)
	poly(c, PackedVector2Array([Vector2(12, -5), Vector2(18, -3), Vector2(12, -2)]), Color("ff8a1f"), 1.2)
	eye(c, Vector2(9.5, -5.5), 1.9, Vector2(0.5, 0.2))
	if f == 0:
		blob(c, Vector2(-3, -5), 7.5, 3.4, Color("3fae49"), -0.7, 1.4)
	else:
		blob(c, Vector2(-3, 8), 7.5, 3.4, Color("3fae49"), 0.7, 1.4)

static func s_mudball(c: CanvasItem) -> void:
	blob(c, Vector2.ZERO, 8.5, 8.0, Color("8a5a34"), 0.0, 1.8)
	c.draw_circle(Vector2(-2, -2), 1.6, Color("b07a4a"))
	c.draw_circle(Vector2(3, 3), 1.2, Color("5a3a20"))

static func s_heart(c: CanvasItem, k: float) -> void:
	var pts := heart_pts(Vector2(0, 1), 20.0 * k)
	poly(c, pts, Color("ff4d6d"), 2.0)
	ell(c, Vector2(-5, -5) * k, 3.4 * k, 2.0 * k, Color(1, 1, 1, 0.8), -0.6)

static func s_skull(c: CanvasItem) -> void:
	blob(c, Vector2(0, -2), 11.0, 10.0, Color("f1ede0"), 0.0, 1.8)
	poly(c, PackedVector2Array([Vector2(-6, 6), Vector2(6, 6), Vector2(5, 13), Vector2(-5, 13)]), Color("f1ede0"), 1.6)
	ell(c, Vector2(-4.2, -2), 2.8, 3.2, OUT)
	ell(c, Vector2(4.2, -2), 2.8, 3.2, OUT)
	c.draw_line(Vector2(-2, 7), Vector2(-2, 12), OUT, 1.0, true)
	c.draw_line(Vector2(2, 7), Vector2(2, 12), OUT, 1.0, true)

# ================================================================= icons
static func i_repellent(c: CanvasItem) -> void:
	for p in [Vector2(14, -14), Vector2(22, -19), Vector2(21, -7), Vector2(25, -13)]:
		c.draw_circle(p, 5.0, Color(0.55, 0.95, 0.5, 0.55))
	poly(c, PackedVector2Array([Vector2(-11, -8), Vector2(9, -8), Vector2(9, 22), Vector2(-11, 22)]), Color("3aa8e8"), 2.2)
	c.draw_rect(Rect2(-11, 3, 20, 10), Color("f7f7f7"))
	c.draw_rect(Rect2(-11, -8, 20, 5), Color("e63946"))
	poly(c, PackedVector2Array([Vector2(-5, -14), Vector2(3, -14), Vector2(3, -8), Vector2(-5, -8)]), Color("f1f1f1"), 1.8)
	c.draw_line(Vector2(-2, 5), Vector2(-2, 11), OUT, 1.6, true)
	c.draw_line(Vector2(2, 5), Vector2(2, 11), OUT, 1.6, true)

static func i_thunder(c: CanvasItem) -> void:
	c.draw_texture_rect(glow(), Rect2(-28, -28, 56, 56), false, Color(1, 0.9, 0.3, 0.8))
	poly(c, PackedVector2Array([Vector2(5, -25), Vector2(-11, 3), Vector2(-1, 3), Vector2(-7, 25), Vector2(13, -6), Vector2(3, -6), Vector2(11, -25)]), Color("ffe14a"), 2.2)
	c.draw_line(Vector2(5, -21), Vector2(-5, 1), Color(1, 1, 1, 0.8), 1.6, true)

static func i_mud(c: CanvasItem) -> void:
	blob(c, Vector2(0, 9), 24.0, 12.0, Color("7a5230"), 0.0, 2.2)
	ell(c, Vector2(-2, 7), 16.0, 6.0, Color("97683d"))
	for b in [[Vector2(-8, 6), 4.0], [Vector2(6, 9), 3.0], [Vector2(0, 3), 2.4]]:
		c.draw_circle(b[0], b[1] + 1.0, OUT)
		c.draw_circle(b[0], b[1], Color("b8895a"))
	for d in [Vector2(-14, -8), Vector2(12, -12), Vector2(2, -16)]:
		blob(c, d, 3.2, 4.0, Color("7a5230"), 0.0, 1.4)

static func i_vuvuzela(c: CanvasItem) -> void:
	var a := Vector2(-22, 14)
	var b := Vector2(16, -9)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	poly(c, PackedVector2Array([a + n * 3.0, b + n * 13.0, b - n * 13.0, a - n * 3.0]), Color("ffd43b"), 2.2)
	var m := a.lerp(b, 0.45)
	poly(c, PackedVector2Array([m + n * 5.0, m + d * 5.0 + n * 7.0, m + d * 5.0 - n * 7.0, m - n * 5.0]), Color("2b2b2b"), 1.2)
	ell(c, b, 4.0, 13.5, Color("e8a91a"), atan2(d.y, d.x))
	ell(c, b + d * 0.8, 2.4, 10.5, OUT, atan2(d.y, d.x))
	for i in 3:
		var arc := PackedVector2Array()
		for k in 7:
			var t := -0.6 + 1.2 * float(k) / 6.0
			arc.append(b + d * (14.0 + i * 5.0) + n * (t * (8.0 + i * 3.0)))
		c.draw_polyline(arc, Color(1, 1, 1, 0.85 - i * 0.2), 2.0, true)

static func i_guarana(c: CanvasItem) -> void:
	poly(c, PackedVector2Array([Vector2(0, -12), Vector2(10, -22), Vector2(14, -14)]), Color("5fbf3a"), 1.8)
	blob(c, Vector2(0, 3), 17.0, 17.0, Color("e63946"), 0.0, 2.4)
	c.draw_circle(Vector2(0, 5), 9.0, Color("f7f2e2"))
	c.draw_circle(Vector2(1, 6), 5.2, Color("1a1010"))
	c.draw_circle(Vector2(-0.5, 4), 1.6, WHITE)

static func i_cafe(c: CanvasItem) -> void:
	for i in 3:
		var x := -8.0 + 8.0 * i
		c.draw_polyline(PackedVector2Array([Vector2(x, -10), Vector2(x + 3, -16), Vector2(x - 2, -21), Vector2(x + 2, -26)]), Color(1, 1, 1, 0.75), 2.2, true)
	limb(c, Vector2(15, 4), Vector2(21, 8), 4.0, Color("f7f2e2"), 1.8)
	poly(c, PackedVector2Array([Vector2(-17, -4), Vector2(17, -4), Vector2(13, 20), Vector2(-13, 20)]), Color("f7f2e2"), 2.2)
	ell(c, Vector2(0, -4), 17.0, 4.5, Color("5a3a22"))
	c.draw_rect(Rect2(-13, 7, 26, 4), Color("e63946"))
	flat(c, Vector2(0, 22), 20.0, 3.0, Color("d7d0c0"), 0.0, 1.6)

static func i_tenis(c: CanvasItem) -> void:
	poly(c, PackedVector2Array([Vector2(-22, 12), Vector2(-22, -6), Vector2(-9, -10), Vector2(-1, -17), Vector2(6, -12), Vector2(21, -1), Vector2(24, 12)]), Color("e63946"), 2.2)
	poly(c, PackedVector2Array([Vector2(-23, 12), Vector2(25, 12), Vector2(25, 19), Vector2(-23, 19)]), Color("f7f7f7"), 2.0)
	for i in 3:
		c.draw_line(Vector2(-2 + 5 * i, -11 + 3 * i), Vector2(1 + 5 * i, -6 + 3 * i), Color.WHITE, 2.0, true)
	c.draw_line(Vector2(-18, 4), Vector2(14, 4), Color("ffd43b"), 2.2, true)

static func i_marmita(c: CanvasItem) -> void:
	curve(c, PackedVector2Array([Vector2(-8, -10), Vector2(-8, -18), Vector2(8, -18), Vector2(8, -10)]), 3.0, Color("c8c8d0"), 1.6)
	poly(c, PackedVector2Array([Vector2(-20, -10), Vector2(20, -10), Vector2(20, 4), Vector2(-20, 4)]), Color("2a6fdb"), 2.2)
	poly(c, PackedVector2Array([Vector2(-20, 4), Vector2(20, 4), Vector2(20, 20), Vector2(-20, 20)]), Color("e8e8f0"), 2.2)
	flat(c, Vector2(0, 4), 3.5, 3.5, Color("ffd43b"), 0.0, 1.6)
	c.draw_line(Vector2(-16, 12), Vector2(16, 12), Color("c8c8d8"), 2.0, true)

static func i_capa(c: CanvasItem) -> void:
	poly(c, PackedVector2Array([Vector2(0, -20), Vector2(14, -8), Vector2(24, 20), Vector2(-24, 20), Vector2(-14, -8)]), Color("ffd43b"), 2.4)
	blob(c, Vector2(0, -12), 10.0, 8.0, Color("f5c518"), 0.0, 2.0)
	ell(c, Vector2(0, -9), 5.0, 4.0, Color("2a1810"))
	c.draw_line(Vector2(0, -3), Vector2(0, 19), Color("c9a20a"), 1.8, true)
	for y in [2.0, 9.0, 16.0]:
		c.draw_circle(Vector2(0, y), 1.8, OUT)

static func i_coco(c: CanvasItem) -> void:
	limb(c, Vector2(4, -4), Vector2(14, -24), 3.6, Color("f7f7f7"), 1.6)
	c.draw_line(Vector2(5, -8), Vector2(11, -21), Color("e63946"), 1.6, true)
	blob(c, Vector2(0, 5), 18.0, 17.0, Color("8a6a3a"), 0.0, 2.4)
	ell(c, Vector2(0, -6), 12.0, 4.5, Color("f1ede0"))
	for p in [Vector2(-5, 8), Vector2(5, 8), Vector2(0, 14)]:
		c.draw_circle(p, 2.3, Color("3a2614"))

static func i_ima(c: CanvasItem) -> void:
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.3, 1.3))
	s_ima(c, 1.0)

static func i_fermento(c: CanvasItem) -> void:
	for p in [Vector2(-8, -12), Vector2(6, -16), Vector2(14, -8)]:
		flat(c, p, 6.0, 6.0, Color("f7e8c4"), 0.0, 1.8)
	blob(c, Vector2(0, -6), 17.0, 12.0, Color("f7e8c4"), 0.0, 2.2)
	var bowl := PackedVector2Array()
	for i in 17:
		var a := PI * float(i) / 16.0
		bowl.append(Vector2(cos(a) * 22.0, sin(a) * 18.0 + 4.0))
	poly(c, bowl, Color("3aa8e8"), 2.4)
	c.draw_line(Vector2(-20, 10), Vector2(20, 10), Color("7fd0ff"), 2.0, true)

static func i_xerox(c: CanvasItem) -> void:
	poly(c, PackedVector2Array([Vector2(-12, -18), Vector2(10, -18), Vector2(10, 8), Vector2(-12, 8)]), Color("e8e8f0"), 2.2)
	poly(c, PackedVector2Array([Vector2(-5, -10), Vector2(17, -10), Vector2(17, 18), Vector2(-5, 18)]), Color("ffffff"), 2.2)
	for i in 4:
		c.draw_line(Vector2(-1, -5 + i * 5.5), Vector2(13, -5 + i * 5.5), Color("7a8aa8"), 1.8, true)
	c.draw_line(Vector2(-20, 22), Vector2(22, 22), Color("39d98a"), 3.0, true)

static func i_cursinho(c: CanvasItem) -> void:
	poly(c, PackedVector2Array([Vector2(-18, -16), Vector2(18, -16), Vector2(18, 18), Vector2(-18, 18)]), Color("2a6fdb"), 2.4)
	c.draw_rect(Rect2(-18, 13, 36, 5), Color("f7f2e2"))
	c.draw_rect(Rect2(-12, -10, 24, 9), Color("f7f2e2"))
	c.draw_line(Vector2(-9, -6), Vector2(9, -6), Color("2a6fdb"), 1.8, true)
	poly(c, PackedVector2Array([Vector2(8, 4), Vector2(14, 4), Vector2(14, 24), Vector2(11, 20), Vector2(8, 24)]), Color("e63946"), 1.4)

static func i_trevo(c: CanvasItem) -> void:
	limb(c, Vector2(0, 4), Vector2(6, 22), 3.0, Color("2f7a22"), 1.4)
	for a in [-0.78, 0.78, 2.36, -2.36]:
		var ctr := Vector2.from_angle(a) * 8.5
		var pts := heart_pts(ctr, 17.0)
		var rot: float = a + PI / 2.0
		for i in pts.size():
			pts[i] = ctr + (pts[i] - ctr).rotated(rot + PI)
		poly(c, pts, Color("3fbf4a"), 1.8)
	c.draw_circle(Vector2.ZERO, 3.0, Color("2f9a3a"))

static func i_cofrinho(c: CanvasItem) -> void:
	flat(c, Vector2(0, -20), 6.5, 6.5, Color("ffcf33"), 0.0, 1.8)
	limb(c, Vector2(-12, 14), Vector2(-12, 22), 7.0, Color("ff8fb2"), 1.8)
	limb(c, Vector2(10, 14), Vector2(10, 22), 7.0, Color("ff8fb2"), 1.8)
	blob(c, Vector2(0, 5), 21.0, 16.0, Color("ff9fc0"), 0.0, 2.4)
	blob(c, Vector2(19, 6), 7.5, 6.5, Color("ffb3cc"), 0.0, 2.0)
	c.draw_circle(Vector2(18, 6), 1.3, OUT)
	c.draw_circle(Vector2(22, 6), 1.3, OUT)
	poly(c, PackedVector2Array([Vector2(7, -9), Vector2(14, -17), Vector2(15, -7)]), Color("ff8fb2"), 1.8)
	c.draw_circle(Vector2(10, 0), 2.0, OUT)
	c.draw_line(Vector2(-6, -9), Vector2(5, -9), OUT, 2.0, true)

static func i_reroll(c: CanvasItem) -> void:
	c.draw_set_transform(Vector2.ZERO, 0.35, Vector2.ONE)
	poly(c, PackedVector2Array([Vector2(-17, -17), Vector2(17, -17), Vector2(17, 17), Vector2(-17, 17)]), Color("f7f7f7"), 2.6)
	for p in [Vector2(-8, -8), Vector2(8, -8), Vector2(0, 0), Vector2(-8, 8), Vector2(8, 8)]:
		c.draw_circle(p, 3.2, Color("e63946"))

# ================================================================ decor
static func s_flower(c: CanvasItem, f: int) -> void:
	var cols := [Color("ffffff"), Color("ffe14a"), Color("ff7eb6"), Color("b58bff")]
	var col: Color = cols[f % 4]
	c.draw_line(Vector2(0, 2), Vector2(0, 11), Color("3a8a2c"), 1.8, true)
	for i in 5:
		ell(c, Vector2.from_angle(TAU * float(i) / 5.0) * 4.5 + Vector2(0, -2), 3.4, 2.6, col, TAU * float(i) / 5.0)
	c.draw_circle(Vector2(0, -2), 2.4, Color("ffb02e") if f != 1 else Color("e8841a"))

static func s_tuft(c: CanvasItem, f: int) -> void:
	var cols := [Color("3f9a3a"), Color("56b24a")]
	for i in 7:
		var x := -10.0 + 3.4 * i
		var h := 8.0 + 8.0 * (1.0 - absf(x) / 12.0) + (3.0 if (i + f) % 2 == 0 else 0.0)
		c.draw_line(Vector2(x, 8), Vector2(x + (x * 0.25), 8 - h), cols[(i + f) % 2], 2.2, true)

static func s_mushroom(c: CanvasItem) -> void:
	limb(c, Vector2(0, 6), Vector2(0, 11), 5.0, Color("f1ede0"), 1.5)
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		cap.append(Vector2(cos(a) * 10.0, sin(a) * 8.0 + 5.0))
	poly(c, cap, Color("e63946"), 1.8)
	for p in [Vector2(-4, 0), Vector2(3, -1), Vector2(0, -4)]:
		c.draw_circle(p, 1.5, Color.WHITE)

static func s_rock(c: CanvasItem, f: int) -> void:
	if f == 0:
		blob(c, Vector2(0, 3), 14.0, 9.0, Color("9aa0a8"), 0.0, 1.8)
		blob(c, Vector2(-11, 7), 6.0, 4.0, Color("8a9098"), 0.0, 1.5)
	else:
		blob(c, Vector2(0, 4), 9.0, 7.0, Color("a8aeb6"), 0.0, 1.8)
		blob(c, Vector2(10, 7), 7.0, 4.5, Color("8a9098"), 0.0, 1.5)

static func s_reed(c: CanvasItem) -> void:
	for i in 4:
		var x := -8.0 + 5.5 * i
		var h := 30.0 + 7.0 * sin(i * 1.7)
		c.draw_line(Vector2(x, 24), Vector2(x + (i - 1.5) * 2.0, 24 - h), Color("5fa83a"), 2.2, true)
		if i % 2 == 0:
			flat(c, Vector2(x + (i - 1.5) * 2.0, 24 - h), 2.6, 5.5, Color("7a4a24"), 0.0, 1.2)

static func s_lily(c: CanvasItem) -> void:
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 24:
		var a := 0.35 + (TAU - 0.7) * float(i) / 23.0
		pts.append(Vector2(cos(a) * 17.0, sin(a) * 9.5))
	poly(c, pts, Color("4fb35a"), 1.6)
	for i in 6:
		var a := TAU * float(i) / 6.0
		ell(c, Vector2(5, -3) + Vector2.from_angle(a) * 3.2, 3.0, 1.9, Color("ff9fc8"), a)
	c.draw_circle(Vector2(5, -3), 1.8, Color("ffd43b"))

# ================================================================== snake
static func draw_snake_body(c: CanvasItem, p: Vector2, r: float, idx: int, col: Color) -> void:
	blob(c, p, r, r * 0.94, col, 0.0, 3.0)
	var blotch := col.darkened(0.45)
	if idx % 2 == 0:
		ell(c, p + Vector2(0, -r * 0.18), r * 0.62, r * 0.38, blotch)
	else:
		ell(c, p + Vector2(0, r * 0.1), r * 0.45, r * 0.3, col.lightened(0.28))

static func draw_snake_head(c: CanvasItem, p: Vector2, ang: float, r: float, mouth: float, t: float, col: Color, enraged: bool) -> void:
	var fwd := Vector2.from_angle(ang)
	var side := Vector2(-fwd.y, fwd.x)
	# tongue
	var tl := r * (1.3 + 0.4 * sin(t * 18.0) * 0.5)
	var tb := p + fwd * r * 1.2
	var tt := tb + fwd * tl
	c.draw_line(tb, tt, Color("ff3355"), 3.0, true)
	c.draw_line(tt, tt + fwd * r * 0.4 + side * r * 0.3, Color("ff3355"), 2.4, true)
	c.draw_line(tt, tt + fwd * r * 0.4 - side * r * 0.3, Color("ff3355"), 2.4, true)
	blob(c, p, r * 1.25, r * 1.0, col, ang, 3.4)
	ell(c, p + fwd * r * 0.5, r * 0.65, r * 0.45, col.lightened(0.18), ang)
	if mouth > 0.05:
		var m := p + fwd * r * 1.0
		c.draw_colored_polygon(PackedVector2Array([m + side * r * 0.5, m + fwd * r * (0.6 + mouth * 0.6), m - side * r * 0.5]), Color("7a1020"))
		for s in [-1.0, 1.0]:
			c.draw_colored_polygon(PackedVector2Array([m + side * r * 0.45 * s, m + side * r * 0.35 * s + fwd * r * 0.5, m + side * r * 0.2 * s]), Color.WHITE)
	for s: float in [-1.0, 1.0]:
		var e := p + fwd * r * 0.35 + side * r * 0.55 * s
		c.draw_circle(e, r * 0.32, OUT)
		c.draw_circle(e, r * 0.26, Color("ff3b2e") if enraged else Color("ffe14a"))
		ell(c, e + fwd * r * 0.04, r * 0.12, r * 0.22, OUT, ang)
