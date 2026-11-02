class_name Ui
## Tiny immediate-mode UI helpers shared by the HUD and the menus.

static var _cache: Dictionary = {}
static var _vignette: Texture2D = null
static var _shade_h: Texture2D = null

static func sb(bg: Color, border: Color, radius: int = 16, bw: int = 3, shadow: int = 8) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d|%d" % [bg.to_html(true), border.to_html(true), radius, bw, shadow]
	if _cache.has(key):
		return _cache[key]
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.38)
		s.shadow_offset = Vector2(0, 4)
	_cache[key] = s
	return s

static func panel(c: CanvasItem, r: Rect2, bg: Color, border: Color, radius: int = 16, bw: int = 3, shadow: int = 8) -> void:
	c.draw_style_box(sb(bg, border, radius, bw, shadow), r)

static func text(c: CanvasItem, pos: Vector2, s: String, size: int, col: Color = Color("fff3dc"), align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 5, bold: bool = true) -> void:
	var f: Font = G.title_font if bold else G.body_font
	if outline > 0:
		c.draw_string_outline(f, pos, s, align, width, size, outline, Color(0.12, 0.07, 0.04, col.a))
	c.draw_string(f, pos, s, align, width, size, col)

static func ctext(c: CanvasItem, center: Vector2, s: String, size: int, col: Color = Color("fff3dc"), outline: int = 5, bold: bool = true) -> void:
	text(c, Vector2(center.x - 600.0, center.y + size * 0.35), s, size, col, HORIZONTAL_ALIGNMENT_CENTER, 1200.0, outline, bold)

## Single line, shrunk until it fits max_w.
static func fit(c: CanvasItem, center: Vector2, s: String, max_w: float, size: int, col: Color = Color("fff3dc"), outline: int = 4) -> void:
	var sz := size
	while sz > 12 and G.title_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > max_w:
		sz -= 1
	ctext(c, center, s, sz, col, outline)

static func wrap(c: CanvasItem, pos: Vector2, s: String, width: float, size: int, col: Color, max_lines: int = 4, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	c.draw_multiline_string(G.body_font, pos, s, align, width, size, max_lines, col)

static func icon(c: CanvasItem, key: String, center: Vector2, size: float, tint: Color = Color.WHITE) -> void:
	var r: Rect2 = G.spr.get(key, Rect2())
	if r.size.x <= 0.0:
		r = G.spr.get(key + "_0", Rect2())
	if r.size.x <= 0.0 or G.tex == null:
		return
	var aspect := r.size.y / r.size.x
	var sz := Vector2(size, size * aspect) if aspect <= 1.0 else Vector2(size / aspect, size)
	c.draw_texture_rect_region(G.tex, Rect2(center - sz * 0.5, sz), r, tint)

static func pill(c: CanvasItem, center: Vector2, s: String, bg: Color, text_col: Color = Color.WHITE, size: int = 14) -> void:
	var tw := G.body_font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x + 16.0
	var h := float(size) + 10.0
	panel(c, Rect2(center.x - tw * 0.5, center.y - h * 0.5, tw, h), bg, bg.darkened(0.25), int(h * 0.5), 1, 0)
	text(c, Vector2(center.x - tw * 0.5, center.y + size * 0.35), s, size, text_col, HORIZONTAL_ALIGNMENT_CENTER, tw, 0, true)

static func slider(c: CanvasItem, r: Rect2, ratio: float, fill_col: Color = Color("ffd43b"), active: bool = false, hov: float = 0.0) -> void:
	bar(c, r, ratio, fill_col, Color(0.06, 0.09, 0.16, 0.88), int(r.size.y * 0.5))
	var knob_x := r.position.x + 3.0 + (r.size.x - 6.0) * clampf(ratio, 0.0, 1.0)
	var knob_y := r.position.y + r.size.y * 0.5
	var r_outer := r.size.y * (0.8 if active else (0.65 + 0.06 * hov))
	var r_inner := r.size.y * (0.62 if active else (0.5 + 0.05 * hov))
	var base_kc := fill_col.lightened(0.25).lerp(Color("7af0dc"), hov * 0.4)
	var kc := Color("ffd43b") if active else base_kc
	c.draw_circle(Vector2(knob_x, knob_y), r_outer, Color("2a1810"))
	c.draw_circle(Vector2(knob_x, knob_y), r_inner, kc)

static func bar(c: CanvasItem, r: Rect2, ratio: float, fill: Color, back: Color = Color(0.08, 0.1, 0.16, 0.85), radius: int = 8) -> void:
	c.draw_style_box(sb(back, Color(0.04, 0.05, 0.08, 0.95), radius, 2, 0), r)
	var w := maxf(0.0, (r.size.x - 4.0) * clampf(ratio, 0.0, 1.0))
	if w > 1.0:
		c.draw_style_box(sb(fill, fill.darkened(0.25), maxi(2, radius - 2), 0, 0), Rect2(r.position + Vector2(2, 2), Vector2(w, r.size.y - 4.0)))

static func vignette() -> Texture2D:
	if _vignette == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 1)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 1.0)
		t.width = 256
		t.height = 256
		_vignette = t
	return _vignette

static func shade_h() -> Texture2D:
	if _shade_h == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_LINEAR
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(1, 0)
		t.width = 256
		t.height = 4
		_shade_h = t
	return _shade_h

static func ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
