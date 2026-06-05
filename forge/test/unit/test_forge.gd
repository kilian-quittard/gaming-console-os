extends "res://addons/gut/test.gd"
# Tests unitaires FORGE (logique pure : tuiles, pentes).

var app


func before_each() -> void:
	app = add_child_autofree(preload("res://scripts/common/forge/ForgeApp.gd").new())


func test_palette_coverage() -> void:
	# chaque tuile de la palette a un nom et une couleur
	for t in app.PALETTE:
		assert_true(app.NAMES.has(t), "NAMES couvre la tuile %s" % t)
		assert_true(app.COLORS.has(t), "COLORS couvre la tuile %s" % t)


func test_is_slope() -> void:
	assert_true(app._is_slope(app.SLOPE_R), "SLOPE_R est une pente")
	assert_false(app._is_slope(app.GROUND), "GROUND n'est pas une pente")


func test_slope_surface_45() -> void:
	var c := Vector2i(0, 5)
	# 45° montant à droite : bas à gauche (lx=0), haut à droite (lx=CELL)
	assert_eq(app._slope_surface(app.SLOPE_R, c, 0.0), float((c.y + 1) * app.CELL))
	assert_eq(app._slope_surface(app.SLOPE_R, c, float(app.CELL)), float(c.y * app.CELL))


func test_under_slope() -> void:
	app.grid.clear()
	app.grid[Vector2i(3, 4)] = app.SLOPE_R
	app.grid[Vector2i(3, 5)] = app.GROUND
	assert_true(app._under_slope(Vector2i(3, 5)), "case sous une pente = remplissage")
	app.grid.clear()
	app.grid[Vector2i(7, 5)] = app.GROUND
	assert_false(app._under_slope(Vector2i(7, 5)), "sol isolé n'est pas sous une pente")
