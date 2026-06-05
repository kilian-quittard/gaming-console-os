extends "res://addons/gut/test.gd"
# Tests unitaires FORGE — données de tuiles + collision pentes (template plateformer).

var tmpl


class FakeApp extends Node:
	var grid := {}


func before_each() -> void:
	tmpl = add_child_autofree(PlatformerTemplate.new())


func test_palette_coverage() -> void:
	for t in tmpl.palette():
		assert_true(tmpl.NAMES.has(t), "NAMES couvre la tuile %s" % t)
		assert_true(tmpl.COLORS.has(t), "COLORS couvre la tuile %s" % t)


func test_is_slope() -> void:
	assert_true(tmpl._is_slope(tmpl.SLOPE_R), "SLOPE_R est une pente")
	assert_false(tmpl._is_slope(tmpl.GROUND), "GROUND n'est pas une pente")


func test_slope_surface_45() -> void:
	var c := Vector2i(0, 5)
	assert_eq(tmpl._slope_surface(tmpl.SLOPE_R, c, 0.0), float((c.y + 1) * tmpl.CELL))
	assert_eq(tmpl._slope_surface(tmpl.SLOPE_R, c, float(tmpl.CELL)), float(c.y * tmpl.CELL))


func test_under_slope() -> void:
	var fake := FakeApp.new()
	tmpl.app = fake
	fake.grid = {Vector2i(3, 4): tmpl.SLOPE_R, Vector2i(3, 5): tmpl.GROUND}
	assert_true(tmpl._under_slope(Vector2i(3, 5)), "case sous une pente = remplissage")
	fake.grid = {Vector2i(7, 5): tmpl.GROUND}
	assert_false(tmpl._under_slope(Vector2i(7, 5)), "sol isolé n'est pas sous une pente")
	fake.free()
