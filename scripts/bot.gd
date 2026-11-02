class_name Bot
## Tiny steering AI. Drives the title-screen attract mode and the automated
## balance tests (--bot). Kites enemies, collects pickups, dodges projectiles.

static func think(run: Run) -> void:
	if run.bot_idle:
		run.bot_move = Vector2.ZERO
		run.bot_dash = false
		return
	var pl := run.player
	var pos := pl.position
	var steer := Vector2.ZERO
	var danger := 0.0
	var nearest_d := 1e9
	for e in run.en.query_circle(pos, 210.0):
		var dv := pos - e.pos
		var d := maxf(dv.length() - e.r, 6.0)
		var w := 7000.0 / (d * d) * (1.6 if e.big else 1.0) * run.bot_skill
		steer += dv.normalized() * w
		danger += w
		nearest_d = minf(nearest_d, d)
	for p in run.en.eproj:
		var dv2 := pos - p.pos
		var d2 := dv2.length()
		if d2 < 190.0:
			steer += dv2.normalized() * (4000.0 / maxf(d2 * d2, 100.0))
			danger += 1.0
	# pickups
	var pick := Vector2.ZERO
	var best := 1e12
	for k in run.pk.list:
		var dv3: Vector2 = k.pos - pos
		var dd := dv3.length_squared()
		var bias := 1.0
		if k.kind == Pickups.Kind.CHEST or k.kind == Pickups.Kind.HEAL:
			bias = 0.25
		dd *= bias
		if dd < best and dd < 520.0 * 520.0:
			best = dd
			pick = dv3.normalized()
	var calm := danger < 1.6 * maxf(run.bot_skill, 0.3)
	if pick != Vector2.ZERO:
		steer += pick * (2.2 if calm else 0.5)
	# wander / orbit so the bot never stalls
	run.bot_wander_t -= 1.0 / 60.0
	if run.bot_wander_t <= 0.0:
		run.bot_wander_t = randf_range(1.2, 3.0)
		run.bot_wander = Vector2.from_angle(randf() * TAU)
	steer += run.bot_wander * ((0.8 if calm else 0.15) + (1.0 - run.bot_skill) * 1.6)
	if steer.length() < 0.05:
		steer = run.bot_wander
	var dirv := steer.normalized()
	# slide along the threat instead of pure retreat
	if danger > 3.0:
		var tang := Vector2(-dirv.y, dirv.x) * run.bot_side
		dirv = (dirv + tang * 0.45).normalized()
	run.bot_move = dirv
	run.bot_dash = run.bot_skill > 0.45 and danger > 7.0 and nearest_d < 40.0 and pl.dash_ready()
