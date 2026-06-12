extends RefCounted
class_name GfxStyles
# STYLES GRAPHIQUES RÉTRO (GB/GBC/SNES/GBA) : skin couleur (shader sur le monde),
# pixelisation (post-process plein écran derrière l'UI), bande de sélection à
# gauche et transition (wipe) au changement. Le mode vit dans level_props.gfx.

const DEFAULT_MODE := 4   # SPARK = rendu brut sans filtre (style par défaut)
const STYLES := [
	{"name": "SPARK", "mode": 4, "sw": Color("f39c12"), "px": 1.0},
	{"name": "GB",   "mode": 1, "sw": Color("8bac0f"), "px": 4.0},
	{"name": "GBC",  "mode": 2, "sw": Color("f8b800"), "px": 3.0},
	{"name": "SNES", "mode": 0, "sw": Color("7878f8"), "px": 1.0},
	{"name": "GBA",  "mode": 3, "sw": Color("3cbc8c"), "px": 2.0},
]
const TRANS_DUR := 0.5
const PIX_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float px = 1.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	if (px > 1.0) {
		vec2 res = vec2(textureSize(screen, 0));
		vec2 block = vec2(px) / res;
		uv = (floor(SCREEN_UV / block) + 0.5) * block;
	}
	COLOR = texture(screen, uv);
}
"""
const GFX_SHADER := """
shader_type canvas_item;
uniform int mode = 0;
void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 o = c.rgb;
	if (mode == 1) {
		// GB : vert 4 teintes (DMG)
		float q = clamp(floor(l * 4.0) / 3.0, 0.0, 1.0);
		o = mix(vec3(0.058, 0.219, 0.058), vec3(0.607, 0.737, 0.058), q);
	} else if (mode == 2) {
		// GBC : postérisé + couleurs vives
		o = clamp(floor(c.rgb * 6.0) / 5.0 * 1.08, 0.0, 1.0);
	} else if (mode == 0) {
		// SNES : vibrant (saturation + contraste boostés, CRT punchy)
		o = clamp(mix(vec3(l), c.rgb, 1.35), 0.0, 1.0);
		o = clamp((o - 0.5) * 1.12 + 0.5, 0.0, 1.0);
	} else if (mode == 3) {
		// GBA : délavé mais clair = léger désaturé + boost luminosité
		o = mix(c.rgb, vec3(l), 0.16);
		o *= vec3(1.07, 1.08, 1.0);
		o = clamp(o, 0.0, 1.0);
	}
	COLOR = vec4(o, c.a);
}
"""

var app                          # ForgeApp
var mat: ShaderMaterial          # skin couleur (posé sur le template/monde)
var pix_rect: ColorRect          # post-process pixelisation (enfant de l'app)
var trans_t := 0.0               # transition (wipe) restante
var pending := -1                # mode à appliquer à mi-balayage


func _init(forge_app) -> void:
	app = forge_app
	var sh := Shader.new(); sh.code = GFX_SHADER
	mat = ShaderMaterial.new(); mat.shader = sh
	var psh := Shader.new(); psh.code = PIX_SHADER
	var pmat := ShaderMaterial.new(); pmat.shader = psh
	pix_rect = ColorRect.new()
	pix_rect.material = pmat
	pix_rect.show_behind_parent = true
	pix_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pix_rect.visible = false
	app.add_child(pix_rect)


# pose le skin sur le monde (template) + remet la pixelisation au-dessus
func attach_world(tmpl: Node) -> void:
	tmpl.material = mat
	app.move_child(pix_rect, app.get_child_count() - 1)


func apply() -> void:
	var mode := int(app.level_props.get("gfx", DEFAULT_MODE))
	mat.set_shader_parameter("mode", mode)
	var px := 1.0
	for s in STYLES:
		if int(s["mode"]) == mode: px = float(s["px"])
	pix_rect.material.set_shader_parameter("px", px)
	pix_rect.visible = px > 1.0


func set_mode(mode: int) -> void:
	if mode == int(app.level_props.get("gfx", DEFAULT_MODE)) and trans_t <= 0.0: return
	pending = mode               # appliqué à mi-balayage (caché par le wipe)
	trans_t = TRANS_DUR
	app._play("coin")
	app.queue_redraw()


# avance la transition ; renvoie true tant qu'un redraw est nécessaire
func process(delta: float) -> bool:
	if trans_t <= 0.0: return false
	trans_t -= delta
	if pending >= 0 and trans_t <= TRANS_DUR * 0.5:
		app.level_props["gfx"] = pending; pending = -1
		apply(); app._redraw_world()
	return true


# clic sur la bande de styles ; true si consommé
func click(pos: Vector2) -> bool:
	var rects := strip_rects()
	for i in rects.size():
		if (rects[i] as Rect2).has_point(pos):
			set_mode(int(STYLES[i]["mode"]))
			return true
	return false


func strip_rects() -> Array:
	var out := []
	var y0: float = float(app.TOPBAR) + 12.0
	for i in STYLES.size():
		out.append(Rect2(Vector2(6, y0 + i * 50.0), Vector2(46, 44)))
	return out


func resize(vp: Vector2) -> void:
	if pix_rect.visible:
		pix_rect.size = vp; pix_rect.position = Vector2.ZERO


func draw_strip() -> void:
	var f := ThemeDB.fallback_font
	var rects := strip_rects()
	var cur: int = int(app.level_props.get("gfx", DEFAULT_MODE))
	var panel := Rect2(Vector2(2, app.TOPBAR + 6), Vector2(54, rects.size() * 50.0 + 8.0))
	app.draw_rect(panel, Color(13.0 / 255, 17.0 / 255, 23.0 / 255, 0.85))
	for i in rects.size():
		var r: Rect2 = rects[i]
		var st: Dictionary = STYLES[i]
		var active := int(st["mode"]) == cur
		app.draw_rect(r, st["sw"])
		app.draw_rect(r, Color("f39c12") if active else Color(0, 0, 0, 0.4), false, 3.0 if active else 1.0)
		app._text(f, Vector2(r.position.x + 4, r.position.y + 28), str(st["name"]), Color("11161f"), 12)


func draw_transition(vp: Vector2) -> void:
	if trans_t <= 0.0: return
	var f := ThemeDB.fallback_font
	var t: float = 1.0 - clampf(trans_t / TRANS_DUR, 0.0, 1.0)   # 0 → 1
	var col := Color("11161b")
	# 1re moitié : le voile avance (gauche→droite). 2de moitié : il se retire.
	var cover := Rect2(Vector2.ZERO, Vector2(0, vp.y))
	if t < 0.5:
		cover = Rect2(Vector2.ZERO, Vector2((t / 0.5) * vp.x, vp.y))
	else:
		var x: float = ((t - 0.5) / 0.5) * vp.x
		cover = Rect2(Vector2(x, 0), Vector2(vp.x - x, vp.y))
	app.draw_rect(cover, col)
	var edge_x: float = cover.position.x + cover.size.x if t < 0.5 else cover.position.x
	app.draw_rect(Rect2(Vector2(edge_x - 3, 0), Vector2(6, vp.y)), Color("f39c12"))
	var mode := pending if pending >= 0 else int(app.level_props.get("gfx", DEFAULT_MODE))
	var nm := ""
	for s in STYLES:
		if int(s["mode"]) == mode: nm = str(s["name"])
	if nm != "" and cover.size.x > vp.x * 0.4:
		app._text(f, Vector2(vp.x * 0.5 - 28, vp.y * 0.5), nm, Color("ecf0f1"), 28)
