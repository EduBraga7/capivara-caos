class_name Pickups extends Node2D
## XP gems, coins, health, magnet, bombs and chests lying on the ground.

enum Kind { GEM, COIN, HEAL, MAGNET, BOMB, CHEST }

const MAX_GEMS := 240

class Pick:
	var kind: int = Kind.GEM
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var value: float = 1.0
	var age: float = 0.0
	var magnet: bool = false
	var mspeed: float = 0.0
	var phase: float = 0.0
	var ttl: float = -1.0
	var tier: int = 1

class GlowLayer extends Node2D:
	var pk: Pickups
	func _draw() -> void:
		pk.draw_glow(self)

var run: Run
var player: Player
var list: Array[Pick] = []
var gem_count: int = 0
var chain: int = 0
var chain_t: float = 0.0
var glow_layer: Node2D
var last_magnet_t: float = -999.0
var last_bomb_t: float = -999.0
var view_half := Vector2(640, 360)

func setup(r: Run) -> void:
	run = r
	player = r.player
	glow_layer = GlowLayer.new()
	glow_layer.pk = self
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = m
	add_child(glow_layer)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func clear() -> void:
	list.clear()
	gem_count = 0

static func tier_for(v: float) -> int:
	if v < 3.0:
		return 1
	if v < 8.0:
		return 2
	if v < 25.0:
		return 3
	return 4

func _pop(p: Pick, speed: float = 150.0) -> void:
	p.vel = Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.4, speed)

func drop_gem(at: Vector2, value: float) -> void:
	if gem_count >= MAX_GEMS:
		# merge into a nearby gem so the screen never drowns in pickups
		var best: Pick = null
		var bd := 1e12
		for k in list:
			if k.kind == Kind.GEM:
				var d := k.pos.distance_squared_to(at)
				if d < bd:
					bd = d
					best = k
		if best != null:
			best.value += value
			best.tier = tier_for(best.value)
			return
	var p := Pick.new()
	p.kind = Kind.GEM
	p.pos = at
	p.value = value
	p.tier = tier_for(value)
	p.phase = randf() * TAU
	_pop(p, 90.0)
	list.append(p)
	gem_count += 1

func drop_coin(at: Vector2, value: float = 1.0) -> void:
	var p := Pick.new()
	p.kind = Kind.COIN
	p.pos = at
	p.value = value
	p.phase = randf() * TAU
	_pop(p, 170.0)
	list.append(p)

func drop_item(at: Vector2, kind: int, value: float = 1.0) -> void:
	var p := Pick.new()
	p.kind = kind
	p.pos = at
	p.value = value
	p.phase = randf() * TAU
	p.ttl = 30.0 if kind != Kind.CHEST else -1.0
	_pop(p, 120.0)
	list.append(p)
	if kind == Kind.CHEST:
		Sfx.play("pop", -4.0, 0.7)

func magnet_all() -> void:
	for k in list:
		if k.kind == Kind.GEM or k.kind == Kind.COIN:
			k.magnet = true
			k.mspeed = 300.0

func chests() -> Array[Pick]:
	var out: Array[Pick] = []
	for k in list:
		if k.kind == Kind.CHEST:
			out.append(k)
	return out

# ----------------------------------------------------------------- update
func update(dt: float) -> void:
	var pp := player.position
	var mr := player.pickup_r
	var mr2 := mr * mr
	chain_t -= dt
	if chain_t <= 0.0:
		chain = 0
	var i := list.size() - 1
	while i >= 0:
		var k := list[i]
		k.age += dt
		if k.ttl > 0.0:
			k.ttl -= dt
			if k.ttl <= 0.0:
				list.remove_at(i)
				i -= 1
				continue
		if k.vel.length_squared() > 1.0:
			k.pos += k.vel * dt
			k.vel *= maxf(0.0, 1.0 - 6.0 * dt)
		var d2 := k.pos.distance_squared_to(pp)
		if k.kind == Kind.CHEST:
			if d2 < 46.0 * 46.0:
				list.remove_at(i)
				run.open_chest(int(k.value))
		else:
			if not k.magnet and d2 < mr2:
				k.magnet = true
			if k.magnet:
				k.mspeed += 1700.0 * dt
				var d := sqrt(d2)
				if d < 22.0:
					_collect(k)
					if k.kind == Kind.GEM:
						gem_count -= 1
					list.remove_at(i)
					i -= 1
					continue
				k.pos += (pp - k.pos) / maxf(d, 0.01) * (240.0 + k.mspeed) * dt
		i -= 1
	queue_redraw()
	glow_layer.queue_redraw()

func _collect(k: Pick) -> void:
	match k.kind:
		Kind.GEM:
			run.add_xp(k.value)
			chain += 1
			chain_t = 0.5
			Sfx.play("gem", -12.0, 1.0 + minf(chain, 14) * 0.05, 0.0)
		Kind.COIN:
			run.add_coins(k.value)
			Sfx.play("coin", -9.0)
		Kind.HEAL:
			player.heal(player.max_hp * 0.4)
			run.fx.text(player.position + Vector2(0, -50), G.T("heal"), Color("7be04a"), 24, 1.1)
			run.fx.burst(player.position, Color("7be04a"), 12, 180.0, 0.6, 3.5)
			Sfx.play("heal", -4.0)
		Kind.MAGNET:
			magnet_all()
			last_magnet_t = run.t
			run.announce(G.T("magnet"), Color("4dd2ff"), 0.8)
			run.fx.ring(player.position, 20.0, 600.0, 0.6, Color(0.3, 0.8, 1.0, 0.7), 6.0)
			Sfx.play("magnet", -3.0)
		Kind.BOMB:
			last_bomb_t = run.t
			run.bomb()

# ------------------------------------------------------------------- draw
func _vis(p: Vector2) -> bool:
	return absf(p.x - run.cam_pos.x) < view_half.x + 40.0 and absf(p.y - run.cam_pos.y) < view_half.y + 40.0

func _key(k: Pick) -> String:
	match k.kind:
		Kind.GEM: return "gem%d" % k.tier
		Kind.COIN: return "coin"
		Kind.HEAL: return "melancia"
		Kind.MAGNET: return "ima"
		Kind.BOMB: return "rojao"
		Kind.CHEST: return "bau"
	return "coin"

func _draw() -> void:
	if G.tex == null:
		return
	var sh: Rect2 = G.spr.get("shadow", Rect2())
	for k in list:
		if not _vis(k.pos):
			continue
		var blink := 1.0
		if k.ttl > 0.0 and k.ttl < 5.0:
			blink = 0.4 + 0.6 * absf(sin(k.age * 12.0))
		var s: Rect2 = G.spr.get(_key(k), Rect2())
		if s.size.x <= 0.0:
			continue
		var bob := sin(k.age * 4.0 + k.phase) * 2.5
		var sc := 1.0
		if k.kind == Kind.GEM:
			sc = 1.0 + 0.08 * sin(k.age * 7.0 + k.phase)
		elif k.kind == Kind.COIN:
			sc = 1.0
		elif k.kind == Kind.CHEST:
			sc = 1.0 + 0.06 * sin(k.age * 5.0)
		var sz := s.size * 0.5 * sc
		if k.kind == Kind.COIN:
			var spin := absf(cos(k.age * 5.0 + k.phase))
			sz.x *= 0.35 + 0.65 * spin
		if k.kind != Kind.GEM:
			var sw := sz.x * 0.9
			draw_texture_rect_region(G.tex, Rect2(k.pos.x - sw * 0.5, k.pos.y + sz.y * 0.32, sw, sw * 0.32), sh, Color(1, 1, 1, 0.6))
		draw_texture_rect_region(G.tex, Rect2(k.pos + Vector2(-sz.x * 0.5, -sz.y * 0.5 + bob), sz), s, Color(1, 1, 1, blink))

func draw_glow(layer: Node2D) -> void:
	var g := Art.glow()
	for k in list:
		if not _vis(k.pos):
			continue
		var col := Color(0.3, 1.0, 0.9, 0.35)
		var rr := 18.0
		match k.kind:
			Kind.GEM:
				var cs := [Color(0.2, 0.9, 0.85, 0.4), Color(0.5, 1.0, 0.3, 0.4), Color(0.7, 0.4, 1.0, 0.45), Color(1.0, 0.85, 0.2, 0.55)]
				col = cs[k.tier - 1]
				rr = 14.0 + 3.0 * k.tier
			Kind.COIN:
				col = Color(1.0, 0.85, 0.2, 0.35)
			Kind.CHEST:
				col = Color(1.0, 0.8, 0.2, 0.5 + 0.3 * sin(k.age * 5.0))
				rr = 46.0
			_:
				col = Color(1.0, 1.0, 1.0, 0.3)
				rr = 26.0
		layer.draw_texture_rect(g, Rect2(k.pos - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, col)
