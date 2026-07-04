extends RefCounted
class_name ScreenArt
# Renderer PARTAGÉ des écrans de jeu (titre, etc.).
# Une seule source de vérité : éditeur d'écran (ForgeApp), mini-preview du dashboard, runtime (GameShell).
#
# Deux systèmes de coordonnées :
#   - DÉCO (pinceau pixel) : coords entières de case, à la résolution de grille de l'écran.
#   - TAMPONS / PANNEAUX / TEXTES (vectoriel propre) : coords NORMALISÉES 0..1,
#     donc indépendantes de la grille -> ne bougent pas quand on change la taille de grille.

# Tailles de grille déco au choix.
const GRID_SIZES := [Vector2(16, 9), Vector2(32, 18), Vector2(64, 36)]
const GRID_NAMES := ["Large", "Moyenne", "Fine"]

# Palette de décoration / tampons / panneaux — 8 couleurs.
const DECO := [
	Color("ffffff"), Color("11161f"), Color("e74c3c"), Color("e67e22"),
	Color("f1c40f"), Color("2ecc71"), Color("3498db"), Color("9b59b6")
]

# Formes de tampon.
enum { SQUARE, CIRCLE, TRIANGLE, STAR, DIAMOND }
const SHAPE_COUNT := 5
const SHAPE_NAMES := ["Carré", "Cercle", "Triangle", "Étoile", "Losange"]

# Éléments de texte de l'écran titre + positions/tailles par défaut (centre normalisé, scale = fraction de hauteur).
const TITLE_TEXTS := ["brand", "title", "subtitle", "prompt"]
const DEFAULTS := {
	"brand":    {"nx": 0.5, "ny": 0.16, "scale": 0.045},
	"title":    {"nx": 0.5, "ny": 0.36, "scale": 0.11},
	"subtitle": {"nx": 0.5, "ny": 0.50, "scale": 0.034},
	"prompt":   {"nx": 0.5, "ny": 0.72, "scale": 0.05},
}


static func empty_screen() -> Dictionary:
	return {
		"accent": "3498db", "bg": 0, "bg_grad": false,
		"grid": 1, "grid_show": true, "subtitle": "",
		"deco": {}, "stamps": [], "panels": [], "texts": {},
	}


static func grid_dims(data: Dictionary) -> Vector2:
	return GRID_SIZES[clampi(int(data.get("grid", 1)), 0, GRID_SIZES.size() - 1)]


# ---- coord normalisée (0..1) -> pixel ----
static func np(rect: Rect2, nx: float, ny: float) -> Vector2:
	return rect.position + Vector2(nx, ny) * rect.size


# ---- déco : case (gx,gy) -> pixel, à la résolution dims ----
static func cell_px(rect: Rect2, dims: Vector2) -> Vector2:
	return rect.size / dims


static func cell_p(rect: Rect2, gx: int, gy: int, dims: Vector2) -> Vector2:
	return rect.position + Vector2(float(gx) / dims.x, float(gy) / dims.y) * rect.size


# ============================================================ TITRE
# ctx attendu : {accent:Color, bg:Color, title_text:String, subtitle:String, anim_t:float}
static func draw_title(ci: CanvasItem, rect: Rect2, data: Dictionary, ctx: Dictionary) -> void:
	_draw_bg(ci, rect, data, ctx)
	_draw_deco(ci, rect, data)
	_draw_panels(ci, rect, data)
	_draw_stamps(ci, rect, data)

	var accent: Color = ctx.get("accent", Color("3498db"))
	var f := ThemeDB.fallback_font
	var anim_t: float = ctx.get("anim_t", 0.0)

	_text(ci, f, rect, data, "brand", "SPARK", accent)
	_text(ci, f, rect, data, "title", String(ctx.get("title_text", "MON JEU")).to_upper(), Color.WHITE)
	var sub := String(ctx.get("subtitle", ""))
	if sub != "":
		_text(ci, f, rect, data, "subtitle", sub, Color(1, 1, 1, 0.78))
	if fmod(anim_t, 1.0) < 0.65:
		_text(ci, f, rect, data, "prompt", "▶  APPUYER SUR A", Color.WHITE)


static func _draw_bg(ci: CanvasItem, rect: Rect2, data: Dictionary, ctx: Dictionary) -> void:
	var base: Color = ctx.get("bg", Color("1b2838"))
	if bool(data.get("bg_grad", false)):
		var top := base.lightened(0.18)
		var bot := base.darkened(0.30)
		var p0 := rect.position
		var pts := PackedVector2Array([
			p0, p0 + Vector2(rect.size.x, 0),
			p0 + rect.size, p0 + Vector2(0, rect.size.y)])
		ci.draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
	else:
		ci.draw_rect(rect, base)


static func _draw_deco(ci: CanvasItem, rect: Rect2, data: Dictionary) -> void:
	var deco: Dictionary = data.get("deco", {})
	var dims := grid_dims(data)
	var cs := cell_px(rect, dims)
	for k in deco:
		var parts: PackedStringArray = String(k).split(",")
		if parts.size() != 2: continue
		var ci_idx := int(deco[k]) % DECO.size()
		ci.draw_rect(Rect2(cell_p(rect, int(parts[0]), int(parts[1]), dims), cs), DECO[ci_idx])


static func _draw_panels(ci: CanvasItem, rect: Rect2, data: Dictionary) -> void:
	var panels: Array = data.get("panels", [])
	for p in panels:
		var pr := Rect2(
			np(rect, float(p.get("nx", 0.3)), float(p.get("ny", 0.4))),
			Vector2(float(p.get("nw", 0.4)), float(p.get("nh", 0.2))) * rect.size)
		var col_idx := int(p.get("col", 1)) % DECO.size()
		var col: Color = DECO[col_idx]; col.a = float(p.get("alpha", 0.9))
		var rad := float(p.get("radius", 0.25)) * minf(pr.size.x, pr.size.y) * 0.5
		if bool(p.get("outline", false)):
			draw_round_rect_outline(ci, pr, col, rad, 3.0)
		else:
			draw_round_rect(ci, pr, col, rad)


static func _draw_stamps(ci: CanvasItem, rect: Rect2, data: Dictionary) -> void:
	var stamps: Array = data.get("stamps", [])
	for s in stamps:
		var center := np(rect, float(s.get("nx", 0.5)), float(s.get("ny", 0.5)))
		var size := float(s.get("size", 0.12)) * rect.size.y
		var col_idx := int(s.get("col", 0)) % DECO.size()
		var col: Color = DECO[col_idx]; col.a = float(s.get("alpha", 1.0))
		if bool(s.get("outline", false)):
			draw_shape_outline(ci, int(s.get("shape", 0)), center, size, col, 3.0)
		else:
			draw_shape(ci, int(s.get("shape", 0)), center, size, col)


# ---------------- formes (remplies) ----------------
static func draw_shape(ci: CanvasItem, shape: int, center: Vector2, size: float, col: Color) -> void:
	ci.draw_colored_polygon(_shape_points(shape, center, size), col)


static func draw_shape_outline(ci: CanvasItem, shape: int, center: Vector2, size: float, col: Color, w: float) -> void:
	if shape == CIRCLE:
		ci.draw_arc(center, size * 0.5, 0, TAU, 48, col, w)
		return
	var pts := _shape_points(shape, center, size)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w)


static func _shape_points(shape: int, center: Vector2, size: float) -> PackedVector2Array:
	var h := size * 0.5
	match shape:
		SQUARE:
			return PackedVector2Array([
				center + Vector2(-h, -h), center + Vector2(h, -h),
				center + Vector2(h, h), center + Vector2(-h, h)])
		CIRCLE:
			var pc := PackedVector2Array()
			for i in 32:
				var a := i * TAU / 32.0
				pc.append(center + Vector2(cos(a), sin(a)) * h)
			return pc
		TRIANGLE:
			return PackedVector2Array([
				center + Vector2(0, -h), center + Vector2(h, h), center + Vector2(-h, h)])
		STAR:
			var ps := PackedVector2Array()
			for i in 10:
				var ang := -PI / 2.0 + i * PI / 5.0
				var rr := h if i % 2 == 0 else h * 0.42
				ps.append(center + Vector2(cos(ang), sin(ang)) * rr)
			return ps
		DIAMOND:
			return PackedVector2Array([
				center + Vector2(0, -h), center + Vector2(h, 0),
				center + Vector2(0, h), center + Vector2(-h, 0)])
	return PackedVector2Array()


# ---------------- rectangle à coins arrondis ----------------
static func draw_round_rect(ci: CanvasItem, r: Rect2, col: Color, rad: float) -> void:
	rad = clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
	if rad < 1.0:
		ci.draw_rect(r, col); return
	# corps en croix + 4 coins arrondis
	ci.draw_rect(Rect2(r.position + Vector2(rad, 0), Vector2(r.size.x - 2 * rad, r.size.y)), col)
	ci.draw_rect(Rect2(r.position + Vector2(0, rad), Vector2(r.size.x, r.size.y - 2 * rad)), col)
	var c00 := r.position + Vector2(rad, rad)
	var c10 := r.position + Vector2(r.size.x - rad, rad)
	var c11 := r.position + Vector2(r.size.x - rad, r.size.y - rad)
	var c01 := r.position + Vector2(rad, r.size.y - rad)
	ci.draw_circle(c00, rad, col); ci.draw_circle(c10, rad, col)
	ci.draw_circle(c11, rad, col); ci.draw_circle(c01, rad, col)


static func draw_round_rect_outline(ci: CanvasItem, r: Rect2, col: Color, rad: float, w: float) -> void:
	rad = clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
	if rad < 1.0:
		ci.draw_rect(r, col, false, w); return
	var x0 := r.position.x; var y0 := r.position.y
	var x1 := r.position.x + r.size.x; var y1 := r.position.y + r.size.y
	ci.draw_line(Vector2(x0 + rad, y0), Vector2(x1 - rad, y0), col, w)
	ci.draw_line(Vector2(x1, y0 + rad), Vector2(x1, y1 - rad), col, w)
	ci.draw_line(Vector2(x1 - rad, y1), Vector2(x0 + rad, y1), col, w)
	ci.draw_line(Vector2(x0, y1 - rad), Vector2(x0, y0 + rad), col, w)
	ci.draw_arc(Vector2(x0 + rad, y0 + rad), rad, PI, PI * 1.5, 12, col, w)
	ci.draw_arc(Vector2(x1 - rad, y0 + rad), rad, PI * 1.5, TAU, 12, col, w)
	ci.draw_arc(Vector2(x1 - rad, y1 - rad), rad, 0, PI * 0.5, 12, col, w)
	ci.draw_arc(Vector2(x0 + rad, y1 - rad), rad, PI * 0.5, PI, 12, col, w)


static func _text(ci: CanvasItem, f: Font, rect: Rect2, data: Dictionary, key: String, s: String, col: Color) -> void:
	var d := text_props(data, key)
	var size := maxi(8, int(d.scale * rect.size.y))
	var pos := np(rect, d.nx, d.ny)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, Vector2(pos.x - w * 0.5, pos.y + size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# props de texte avec fallback sur les défauts ; renvoie {nx,ny,scale}
static func text_props(data: Dictionary, key: String) -> Dictionary:
	var def: Dictionary = DEFAULTS.get(key, {"nx": 0.5, "ny": 0.5, "scale": 0.05})
	var texts: Dictionary = data.get("texts", {})
	var o: Dictionary = texts.get(key, {})
	return {
		"nx": float(o.get("nx", def.nx)),
		"ny": float(o.get("ny", def.ny)),
		"scale": float(o.get("scale", def.scale)),
	}
