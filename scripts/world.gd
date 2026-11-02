class_name World extends Node2D
## Procedural, infinite decoration: ponds (healing water) + flowers, rocks, reeds...

const CHUNK := 900.0
const DECOR_CELL := 116.0

var run: Run
var chunks: Dictionary = {}     # Vector2i -> Array of pond dicts
var time: float = 0.0
var seed_v: int = 1337
var view_half := Vector2(640, 360)

func setup(r: Run, s: int) -> void:
	run = r
	seed_v = s
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _hash(x: int, y: int, s: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791) ^ seed_v
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7fffffff

func _rf(h: int, shift: int) -> float:
	return float((h >> shift) & 1023) / 1023.0

func _ponds_for(cx: int, cy: int) -> Array:
	var key := Vector2i(cx, cy)
	if chunks.has(key):
		return chunks[key]
	var arr: Array = []
	var h := _hash(cx, cy, 11)
	if h % 100 < 34:
		var c := Vector2((cx + 0.2 + 0.6 * _rf(h, 3)) * CHUNK, (cy + 0.2 + 0.6 * _rf(h, 13)) * CHUNK)
		if c.length() > 330.0:
			var rad := 105.0 + 95.0 * _rf(h, 5)
			var pts := PackedVector2Array()
			var inner := PackedVector2Array()
			var shore := PackedVector2Array()
			var n := 22
			var rot := _rf(h, 9) * TAU
			for i in n:
				var a := TAU * float(i) / float(n)
				var hh := _hash(cx * 31 + i, cy * 17 + i * 3, 29)
				var rr := rad * (0.82 + 0.3 * _rf(hh, 2)) * (1.0 + 0.16 * sin(a * 2.0 + rot))
				var v := Vector2(cos(a) * rr, sin(a) * rr * 0.78)
				pts.append(c + v)
				shore.append(c + v * 1.1 + v.normalized() * 6.0)
				inner.append(c + v * 0.72)
			arr.append({"c": c, "r": rad * 0.82, "pts": pts, "inner": inner, "shore": shore, "h": h})
	chunks[key] = arr
	return arr

func water_at(p: Vector2) -> bool:
	var cx := int(floor(p.x / CHUNK))
	var cy := int(floor(p.y / CHUNK))
	for yy in range(cy - 1, cy + 2):
		for xx in range(cx - 1, cx + 2):
			for pd in _ponds_for(xx, yy):
				var d: Vector2 = p - pd["c"]
				var rr: float = pd["r"]
				if d.x * d.x + (d.y / 0.78) * (d.y / 0.78) < rr * rr:
					return true
	return false

func _near_pond(p: Vector2, margin: float) -> bool:
	var cx := int(floor(p.x / CHUNK))
	var cy := int(floor(p.y / CHUNK))
	for yy in range(cy - 1, cy + 2):
		for xx in range(cx - 1, cx + 2):
			for pd in _ponds_for(xx, yy):
				var d: Vector2 = p - pd["c"]
				var rr: float = float(pd["r"]) * 1.25 + margin
				if d.x * d.x + (d.y / 0.78) * (d.y / 0.78) < rr * rr:
					return true
	return false

func update(dt: float) -> void:
	time += dt
	queue_redraw()

func _draw() -> void:
	if G.tex == null:
		return
	var cp := run.cam_pos
	var x0 := cp.x - view_half.x - 220.0
	var x1 := cp.x + view_half.x + 220.0
	var y0 := cp.y - view_half.y - 220.0
	var y1 := cp.y + view_half.y + 220.0
	# ponds
	var cx0 := int(floor(x0 / CHUNK))
	var cx1 := int(floor(x1 / CHUNK))
	var cy0 := int(floor(y0 / CHUNK))
	var cy1 := int(floor(y1 / CHUNK))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			for pd in _ponds_for(cx, cy):
				_draw_pond(pd)
	# decor
	var ix0 := int(floor(x0 / DECOR_CELL))
	var ix1 := int(floor(x1 / DECOR_CELL))
	var iy0 := int(floor(y0 / DECOR_CELL))
	var iy1 := int(floor(y1 / DECOR_CELL))
	for iy in range(iy0, iy1 + 1):
		for ix in range(ix0, ix1 + 1):
			var h := _hash(ix, iy, 7)
			if h % 100 >= 34:
				continue
			var p := Vector2((ix + _rf(h, 4)) * DECOR_CELL, (iy + _rf(h, 14)) * DECOR_CELL)
			if _near_pond(p, 14.0):
				continue
			var kind := (h >> 20) % 12
			var key := ""
			var sc := 1.0
			match kind:
				0, 1, 2, 3: key = "flower_%d" % (kind % 4)
				4, 5, 6: key = "tuft_%d" % (kind % 2)
				7: key = "mushroom"
				8: key = "rock_0"
				9: key = "rock_1"
				10: key = "tuft_1"
				11: key = "flower_%d" % ((h >> 6) % 4)
			var s: Rect2 = G.spr.get(key, Rect2())
			if s.size.x <= 0.0:
				continue
			var sz := s.size * 0.5 * sc
			draw_texture_rect_region(G.tex, Rect2(p - sz * 0.5, sz), s)

func _draw_pond(pd: Dictionary) -> void:
	var c: Vector2 = pd["c"]
	draw_colored_polygon(pd["shore"], Color(0.62, 0.5, 0.3, 0.9))
	draw_colored_polygon(pd["pts"], Color(0.2, 0.62, 0.8))
	draw_colored_polygon(pd["inner"], Color(0.16, 0.5, 0.72, 0.9))
	var rr: float = float(pd["r"])
	for i in 3:
		var ph := fmod(time * 0.35 + float(i) / 3.0 + float(pd["h"] % 7) * 0.13, 1.0)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.78))
		draw_arc(Vector2.ZERO, rr * (0.15 + 0.7 * ph), 0.0, TAU, 32, Color(1, 1, 1, 0.5 * (1.0 - ph)), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var h: int = pd["h"]
	var lily: Rect2 = G.spr.get("lily", Rect2())
	if lily.size.x > 0.0:
		for k in 3:
			var a := _rf(h, 3 + k * 3) * TAU
			var pos := c + Vector2(cos(a), sin(a) * 0.78) * rr * (0.2 + 0.4 * _rf(h, 5 + k * 2))
			var sz := lily.size * 0.5
			draw_texture_rect_region(G.tex, Rect2(pos - sz * 0.5 + Vector2(0, sin(time * 1.5 + k) * 1.5), sz), lily)
	var reed: Rect2 = G.spr.get("reed", Rect2())
	if reed.size.x > 0.0:
		for k in 4:
			var a2 := _rf(h, 2 + k * 4) * TAU
			var pos2 := c + Vector2(cos(a2), sin(a2) * 0.78) * rr * 1.18
			var sz2 := reed.size * 0.5
			draw_texture_rect_region(G.tex, Rect2(pos2 - Vector2(sz2.x * 0.5, sz2.y * 0.9), sz2), reed)
