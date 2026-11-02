class_name Baker
## Renders every Art sprite once into a single 2x supersampled atlas texture.

const SCALE := 2.0
const ATLAS_W := 1100
const PAD := 3

class Painter extends Node2D:
	var sname := ""
	var frame := 0
	func _draw() -> void:
		Art.draw_sprite(self, sname, frame)

static func bake(host: Node) -> void:
	var placed: Array = []   # [key, x, y, w, h, name, frame]
	var x := PAD
	var y := PAD
	var row_h := 0
	for s in Art.SPRITES:
		var w: int = s[1]
		var h: int = s[2]
		for f in int(s[3]):
			if x + w + PAD > ATLAS_W:
				x = PAD
				y += row_h + PAD
				row_h = 0
			placed.append([Art.sprite_key(s[0], f, s[3]), x, y, w, h, s[0], f])
			x += w + PAD
			row_h = maxi(row_h, h)
	var total_h := y + row_h + PAD
	var px_w := int(ATLAS_W * SCALE)
	var px_h := int(total_h * SCALE)

	if DisplayServer.get_name() == "headless":
		# no renderer: keep layout so rect lookups work, but skip the GPU bake
		G.tex = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
		G.spr.clear()
		G.spr_logic.clear()
		for p in placed:
			G.spr[p[0]] = Rect2(p[1] * SCALE, p[2] * SCALE, p[3] * SCALE, p[4] * SCALE)
			G.spr_logic[p[0]] = Vector2(p[3], p[4])
		return

	var vp := SubViewport.new()
	vp.size = Vector2i(px_w, px_h)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var root := Node2D.new()
	root.scale = Vector2(SCALE, SCALE)
	vp.add_child(root)
	for p in placed:
		var pn := Painter.new()
		pn.sname = p[5]
		pn.frame = p[6]
		pn.position = Vector2(p[1] + p[3] * 0.5, p[2] + p[4] * 0.5)
		root.add_child(pn)
	host.add_child(vp)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

	var img: Image = vp.get_texture().get_image()
	if img == null or img.is_empty():
		img = Image.create(px_w, px_h, false, Image.FORMAT_RGBA8)
	else:
		img.convert(Image.FORMAT_RGBA8)
		img.fix_alpha_edges()
	img.generate_mipmaps()
	G.tex = ImageTexture.create_from_image(img)
	G.spr.clear()
	G.spr_logic.clear()
	for p in placed:
		G.spr[p[0]] = Rect2(p[1] * SCALE, p[2] * SCALE, p[3] * SCALE, p[4] * SCALE)
		G.spr_logic[p[0]] = Vector2(p[3], p[4])
	vp.queue_free()
