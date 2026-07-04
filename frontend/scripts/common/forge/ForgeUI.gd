extends RefCounted
class_name ForgeUI
# DESIGN SYSTEM du shell FORGE (thème "Indie Playful", 100% dessiné, zéro asset).
# Tokens (couleurs) + primitives (panneaux arrondis, chips, keycaps, avatars,
# header/footer). Helpers statiques : on passe le CanvasItem qui dessine.
# Le monde de jeu / l'éditeur ne passent PAS par ici — shell uniquement.

# ---------------- tokens
const BG_TOP := Color("141b30")
const BG_BOT := Color("1b2035")
const CARD := Color("212c49")
const CARD_ON := Color("2c3a63")
const MODAL_BG := Color("161e33")
const ACCENT := Color("f39c12")     # orange FORGE
const CYAN := Color("4fc3f7")       # import / infos
const GREEN := Color("2ecc71")      # créer / succès
const PURPLE := Color("b388ff")     # WORKSHOP / commu
const TXT := Color(1, 1, 1, 0.92)
const TXT_DIM := Color(1, 1, 1, 0.55)
const TXT_FAINT := Color(1, 1, 1, 0.32)

static var _sb_cache := {}


# StyleBoxFlat mise en cache (coins ronds + bord + ombre) — la base de tout
static func sb(bg_col: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0, shadow := 0) -> StyleBoxFlat:
	var key := "%s|%d|%s|%d|%d" % [bg_col.to_html(), radius, border.to_html(), bw, shadow]
	if _sb_cache.has(key):
		return _sb_cache[key]
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.4)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	_sb_cache[key] = s
	return s


# ---------------- fond du shell : dégradé vertical + halo doux derrière le titre
static func bg(c: CanvasItem, vp: Vector2) -> void:
	var steps := 18
	var band := vp.y / float(steps)
	for i in steps:
		c.draw_rect(Rect2(0, i * band, vp.x, band + 1.0), BG_TOP.lerp(BG_BOT, float(i) / float(steps - 1)))


static func glow(c: CanvasItem, center: Vector2, radius: float, col: Color) -> void:
	# halo discret : beaucoup de cercles à alpha minuscule = dégradé sans banding
	for i in 10:
		var t := float(i) / 9.0
		c.draw_circle(center, radius * (1.0 - t * 0.75), Color(col.r, col.g, col.b, col.a * 0.016 * (1.0 + t * 1.6)))


# ---------------- panneaux
# carte de liste/feed : fond arrondi, sélection = bord accent pulsé + ombre
static func card(c: CanvasItem, r: Rect2, on: bool, t: float, accent := ACCENT) -> void:
	if on:
		var pulse := 0.65 + 0.35 * (0.5 + 0.5 * sin(t * 5.0))
		c.draw_style_box(sb(CARD_ON, 12, Color(accent.r, accent.g, accent.b, pulse), 2, 8), r)
	else:
		c.draw_style_box(sb(CARD, 12, Color(1, 1, 1, 0.06), 1, 3), r)


# voile sombre + panneau modal arrondi ; renvoie le rect intérieur
static func modal(c: CanvasItem, vp: Vector2, w: float, h: float, accent: Color) -> Rect2:
	c.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.72))
	var r := Rect2(vp * 0.5 - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	c.draw_style_box(sb(MODAL_BG, 16, Color(accent.r, accent.g, accent.b, 0.85), 2, 14), r)
	return r


# ---------------- petits éléments
# pastille arrondie avec texte ; renvoie la largeur occupée
static func chip(c: CanvasItem, pos: Vector2, text: String, col: Color, fsize := 12) -> float:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 16.0
	var h := fsize + 10.0
	c.draw_style_box(sb(Color(col.r, col.g, col.b, 0.16), int(h * 0.5), Color(col.r, col.g, col.b, 0.4), 1), Rect2(pos, Vector2(w, h)))
	c.draw_string(f, pos + Vector2(8, h * 0.5 + fsize * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
	return w


# avatar créateur : disque couleur + anneau + initiale
static func avatar(c: CanvasItem, center: Vector2, radius: float, col: Color, letter: String) -> void:
	var f := ThemeDB.fallback_font
	c.draw_circle(center, radius + 1.5, Color(1, 1, 1, 0.18))
	c.draw_circle(center, radius, col)
	var fs := int(radius * 1.1)
	var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(f, center + Vector2(-w * 0.5, fs * 0.38), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("141b30"))


# touche façon "keycap" (A, B, X, ▲▼…) + libellé ; renvoie la largeur totale
static func keycap(c: CanvasItem, pos: Vector2, key: String, label: String) -> float:
	var f := ThemeDB.fallback_font
	var kw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
	var kh := 22.0
	c.draw_style_box(sb(Color(1, 1, 1, 0.10), 6, Color(1, 1, 1, 0.22), 1), Rect2(pos, Vector2(kw, kh)))
	c.draw_string(f, pos + Vector2(7, 16), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TXT)
	c.draw_string(f, pos + Vector2(kw + 6, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TXT_DIM)
	return kw + 6.0 + f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x


# rangée de hints centrée en bas : [["A","jouer"], ["B","retour"], ...]
static func footer(c: CanvasItem, vp: Vector2, hints: Array) -> void:
	var f := ThemeDB.fallback_font
	var total := 0.0
	for h in hints:
		total += f.get_string_size(String(h[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0 + 6.0 \
			+ f.get_string_size(String(h[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 26.0
	total -= 26.0
	var x := vp.x * 0.5 - total * 0.5
	var y := vp.y - 38.0
	for h in hints:
		x += keycap(c, Vector2(x, y), String(h[0]), String(h[1])) + 26.0


# ---------------- header d'écran : titre + barre accent + sous-titre
static func header(c: CanvasItem, vp: Vector2, title: String, sub: String, accent := ACCENT) -> void:
	var f := ThemeDB.fallback_font
	glow(c, Vector2(vp.x * 0.5, 54.0), 150.0, accent)
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	c.draw_string(f, Vector2(vp.x * 0.5 - w * 0.5, 66), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, TXT)
	c.draw_style_box(sb(accent, 2), Rect2(vp.x * 0.5 - 28, 80, 56, 4))
	if sub != "":
		var sw := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		c.draw_string(f, Vector2(vp.x * 0.5 - sw * 0.5, 108), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TXT_DIM)
