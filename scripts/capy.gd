class_name Capy
## Live-drawn hero capybara. Origin = ground contact point under the body, facing +x.
## Used by the player node, the title screen and the character cards.

static func draw(c: CanvasItem, t: float, walk: float, sx: float, sy: float, body: Color, hat: String, blink: float, spring: Vector2, orange: bool, origin: Vector2 = Vector2.ZERO, flip: float = 1.0, k: float = 1.0) -> void:
	var swing := sin(t * 13.0) * 8.0 * walk
	var bob := -absf(sin(t * 13.0)) * 3.0 * walk + sin(t * 2.2) * 0.9 * (1.0 - walk)
	var hb := Vector2(0, bob * 1.1)
	var dark := body.darkened(0.28)
	var mid := body.darkened(0.12)
	c.draw_set_transform(origin, 0.0, Vector2(sx * flip * k, sy * k))
	# back legs
	Art.limb(c, Vector2(-24, -12), Vector2(-24 + swing, -1), 9.5, dark, 2.0)
	Art.limb(c, Vector2(-13, -12), Vector2(-13 - swing, -1), 9.5, dark, 2.0)
	# nub tail
	c.draw_circle(Vector2(-38, -22 + bob), 3.6, Art.OUT)
	c.draw_circle(Vector2(-38, -22 + bob), 2.3, dark)
	# body
	Art.blob(c, Vector2(0, -24 + bob), 38.0, 17.5, body, 0.0, 2.6)
	Art.ell(c, Vector2(2, -14 + bob), 27.0, 6.0, body.lightened(0.3))
	Art.ell(c, Vector2(-6, -36.5 + bob), 24.0, 2.6, Color(dark.r, dark.g, dark.b, 0.4))
	# front legs
	Art.limb(c, Vector2(16, -12), Vector2(16 - swing, -1), 9.5, mid, 2.0)
	Art.limb(c, Vector2(28, -12), Vector2(28 + swing, -1), 9.5, mid, 2.0)
	# head: boxy skull + big muzzle
	Art.blob(c, Vector2(39, -31) + hb, 15.0, 13.5, body, 0.0, 2.6)
	Art.blob(c, Vector2(51, -26) + hb, 12.5, 10.5, mid, 0.0, 2.4)
	Art.ell(c, Vector2(61.5, -31.5) + hb, 3.6, 4.6, Color("2a1a12"), -0.2)
	c.draw_circle(Vector2(61, -33) + hb, 1.0, Color(1, 1, 1, 0.8))
	Art.ell(c, Vector2(44, -24) + hb, 4.4, 2.8, Color(1.0, 0.5, 0.58, 0.5))
	c.draw_line(Vector2(53, -19.5) + hb, Vector2(60, -21.5) + hb, Art.OUT, 1.8, true)
	# ear
	Art.blob(c, Vector2(30, -43) + hb, 4.8, 5.6, dark, 0.2, 1.8)
	Art.ell(c, Vector2(30, -42.5) + hb, 2.3, 3.0, Color("e8a8a8"), 0.2)
	# eye: dark pupil under a droopy, chill eyelid
	var ep := Vector2(43, -37.5) + hb
	if blink > 0.5:
		c.draw_line(ep + Vector2(-4.2, 0.4), ep + Vector2(4.2, -0.4), Art.OUT, 2.4, true)
	else:
		c.draw_circle(ep, 4.4, Art.OUT)
		c.draw_circle(ep, 3.5, Color("1a1010"))
		c.draw_circle(ep + Vector2(-1.1, -1.0), 1.2, Art.WHITE)
		c.draw_colored_polygon(PackedVector2Array([ep + Vector2(-6, -6), ep + Vector2(6, -6), ep + Vector2(6, -1.8), ep + Vector2(-6, -0.4)]), body)
		c.draw_line(ep + Vector2(-5, -0.4), ep + Vector2(5, -1.8), Art.OUT, 2.0, true)
	# hats / the famous orange
	var top := Vector2(37, -44) + hb
	match hat:
		"none":
			if orange:
				var o := top + Vector2(-1, -8.5) + spring
				Art.blob(c, o, 10.0, 9.6, Color("ff9a1f"), 0.0, 2.0)
				Art.flat(c, o + Vector2(3.5, -9.6), 4.6, 2.3, Color("5fbf3a"), -0.6, 1.5)
		"ninja":
			var w := sin(t * 9.0) * 2.5
			Art.poly(c, PackedVector2Array([top + Vector2(-12, 0), top + Vector2(-28, -5 + w), top + Vector2(-29, 1 + w), top + Vector2(-12, 4)]), Color("e23b3b"), 1.6)
			Art.poly(c, PackedVector2Array([top + Vector2(-12, 2), top + Vector2(-25, 8 - w), top + Vector2(-21, 12 - w), top + Vector2(-11, 6)]), Color("c92b2b"), 1.6)
			Art.limb(c, top + Vector2(-12, 3), top + Vector2(14, 1), 7.0, Color("e23b3b"), 1.8)
			c.draw_rect(Rect2(top + Vector2(-3, -1.5), Vector2(9, 5)), Color("c8c8d0"))
		"chef":
			Art.poly(c, PackedVector2Array([top + Vector2(-11, -1), top + Vector2(10, -1), top + Vector2(9, 6), top + Vector2(-10, 6)]), Color("f7f7f7"), 1.8)
			for p in [Vector2(-9, -7), Vector2(0, -13), Vector2(9, -7)]:
				Art.blob(c, top + p, 7.6, 7.0, Color("fbfbfb"), 0.0, 1.8)
		"goggles":
			Art.limb(c, top + Vector2(-13, 3), top + Vector2(14, 1), 4.0, Color("3a3a48"), 1.6)
			for p in [Vector2(-3, -6), Vector2(9, -7)]:
				c.draw_circle(top + p, 7.8, Art.OUT)
				c.draw_circle(top + p, 6.2, Color("3a3a48"))
				c.draw_circle(top + p, 4.8, Color("8fe0ff"))
				c.draw_circle(top + p + Vector2(-1.5, -1.8), 1.5, Art.WHITE)
		"crown":
			var cb := top + Vector2(0, 3)
			Art.poly(c, PackedVector2Array([cb + Vector2(-12, 0), cb + Vector2(-12, -12), cb + Vector2(-6, -6), cb + Vector2(0, -15), cb + Vector2(6, -6), cb + Vector2(12, -12), cb + Vector2(12, 0)]), Color("ffd43b"), 1.9)
			c.draw_circle(cb + Vector2(0, -4), 2.8, Color("e63946"))
			c.draw_circle(cb + Vector2(-7.5, -3), 1.6, Color("39a0ff"))
			c.draw_circle(cb + Vector2(7.5, -3), 1.6, Color("39d98a"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
