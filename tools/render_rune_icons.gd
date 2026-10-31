extends SceneTree
## Renders every rune GLB (assets/runes/<colour>_g<grade>.glb) into a UI icon: the real 3D voxel rune the towers
## carry, not a drawn cube. Isometric 3/4 view, warm key + cool fill + strong rim light, 4x supersampled on a
## transparent background, then post: soft bloom from the bright voxels, a dark carved outline for readability on
## the coloured grade backgrounds, Lanczos downscale to 112 px (= 56 px @2x like every other UI texture).
## Run (needs a real renderer, e.g. under gamescope):
##   gamescope --backend headless -w 640 -h 640 -- godot --path . --script tools/render_rune_icons.gd -- [out_dir]
## Writes <out_dir>/rune_<id>_g<grade>.png (default assets/ui) and <out_dir>/../rune_renders_sheet.png for review.

const RUNES := {"fire": "ates", "ice": "buz", "electric": "elektrik", "poison": "zehir", "water": "su",
	"stone": "tas", "light": "isik", "blood": "kan", "meteor": "meteor", "volcano": "volkan", "golem": "golem",
	"hive": "kovan", "mana": "mana"}
const SS := 336                  # render size (3x of the 112 px output)
const OUT := 112

var vp: SubViewport
var cam: Camera3D
var holder: Node3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://assets/ui")
	_setup()
	_run.call_deferred(out_dir)


func _setup() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(SS, SS)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8C93A8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()           # warm key, upper left front
	key.light_color = Color("#FFF1DC")
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-50, -35, 0)
	vp.add_child(key)
	var fill := DirectionalLight3D.new()          # cool fill from the right
	fill.light_color = Color("#9FC2FF")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-15, 110, 0)
	vp.add_child(fill)
	var rim := DirectionalLight3D.new()           # rim from behind: bright edges like loot on a pedestal
	rim.light_color = Color("#E8F6FF")
	rim.light_energy = 1.1
	rim.rotation_degrees = Vector3(-20, 160, 0)
	vp.add_child(rim)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)


func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	if n is MeshInstance3D and n.mesh != null:
		var b: AABB = t * n.mesh.get_aabb()
		acc[0] = b if acc[0] == null else (acc[0] as AABB).merge(b)
	for c in n.get_children():
		_aabb(c, t, acc)


func _load(rel: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path("res://assets/" + rel), st) != OK:
		return null
	return doc.generate_scene(st)


func _run(out_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var sheet := Image.create(OUT * 5, OUT * RUNES.size(), false, Image.FORMAT_RGBA8)
	var row := 0
	for rid in RUNES:
		for g in range(1, 6):
			for c in holder.get_children():
				c.queue_free()
			var m := _load("runes/%s_g%d.glb" % [RUNES[rid], g])
			if m == null:
				push_error("missing rune model %s g%d" % [rid, g])
				continue
			holder.add_child(m)
			var acc := [null]
			_aabb(m, Transform3D.IDENTITY, acc)
			var box: AABB = acc[0]
			var ctr := box.get_center()
			# isometric 3/4 view; the frame fits the model's bounding sphere so every grade keeps its own size feel
			var radius := box.size.length() * 0.5
			cam.size = radius * 2.0 * 1.12
			var dir := Vector3(1.0, 0.82, 1.0).normalized()
			cam.position = ctr + dir * (radius * 4.0 + 2.0)
			cam.look_at(ctr, Vector3.UP)
			cam.near = 0.05
			cam.far = radius * 10.0 + 10.0
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var icon := _post(img)
			icon.save_png("%s/rune_%s_g%d.png" % [out_dir, rid, g])
			sheet.blit_rect(icon, Rect2i(0, 0, OUT, OUT), Vector2i((g - 1) * OUT, row * OUT))
		row += 1
	sheet.save_png(out_dir.path_join("../rune_renders_sheet.png") if out_dir.ends_with("assets/ui") else out_dir.path_join("rune_renders_sheet.png"))
	print("RUNE ICONS rendered %d runes x 5 grades -> %s" % [RUNES.size(), out_dir])
	quit()


## Post: bloom (bright voxels bleed light), carved outline, downscale.
func _post(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	# bloom: bright pass, blurred by a down/up resample, added on top (alpha follows the glow)
	var bright := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			var k := clampf((l - 0.62) * 2.6, 0.0, 1.0) * c.a
			bright.set_pixel(x, y, Color(c.r, c.g, c.b, k))
	var blur: Image = bright.duplicate()
	blur.resize(w / 12, h / 12, Image.INTERPOLATE_BILINEAR)
	blur.resize(w, h, Image.INTERPOLATE_CUBIC)
	# outline: alpha dilated by ~2.5 output px, drawn in carved-dark under the model
	var r := 8
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			mask[y * w + x] = 1 if src.get_pixel(x, y).a > 0.3 else 0
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var hit := false
			if mask[y * w + x] == 0:
				for dy in range(-r, r + 1, 2):
					var yy := y + dy
					if yy < 0 or yy >= h:
						continue
					for dx in range(-r, r + 1, 2):
						var xx := x + dx
						if xx >= 0 and xx < w and dx * dx + dy * dy <= r * r and mask[yy * w + xx] == 1:
							hit = true
							break
					if hit:
						break
			var base := Color(0.063, 0.059, 0.078, 0.92) if hit else Color(0, 0, 0, 0)
			var c := src.get_pixel(x, y)
			if c.a > 0.0:
				base = Color(base.lerp(Color(c.r, c.g, c.b, 1.0), c.a), maxf(base.a, c.a))
			var gl := blur.get_pixel(x, y)
			var ga := gl.a * 0.85
			if ga > 0.003:
				base = Color(minf(base.r + gl.r * ga, 1.0), minf(base.g + gl.g * ga, 1.0), minf(base.b + gl.b * ga, 1.0), maxf(base.a, ga * 0.9))
			out.set_pixel(x, y, base)
	out.resize(OUT, OUT, Image.INTERPOLATE_LANCZOS)
	return out
