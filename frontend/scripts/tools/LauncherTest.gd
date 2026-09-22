extends SceneTree
# SELFTEST du Launcher — vérifie les commandes produites SANS lancer de process,
# et surtout sans être sous Linux : l'OS, le PATH et l'existence des fichiers
# sont injectés. Permet de valider la plomberie Proton depuis la machine de dev.
#
#   Godot_v4.6-stable_win64_console.exe --path frontend --headless \
#       --script res://scripts/tools/LauncherTest.gd

var _fails := 0


func _init() -> void:
	# Faux environnement Linux : umu-run et env présents, jeux natifs dans /usr/bin.
	var linux := {
		"os": "Linux",
		"which": func(c: String) -> String:
			var known := {"umu-run": "/usr/bin/umu-run", "env": "/usr/bin/env",
				"supertuxkart": "/usr/bin/supertuxkart"}
			return String(known.get(c, "")),
		"exists": func(p: String) -> bool:
			return p.ends_with(".exe") or p.begins_with("/usr/"),
	}

	# 1. Jeu natif désigné par une commande nue → résolue via le PATH.
	var stk := Launcher.plan({"runtime": "native", "exe": "supertuxkart"}, "SuperTuxKart", linux)
	_check(stk.ok, "natif: plan ok")
	_check(stk.path == "/usr/bin/supertuxkart", "natif: binaire résolu dans le PATH")
	_check(stk.runtime == "native", "natif: pas de Proton")

	# 2. Jeu Windows → env VAR=… umu-run jeu.exe
	var cars := Launcher.plan(
		{"runtime": "proton", "exe": "/games/Cars/Cars.exe", "args": "-windowed"}, "Cars", linux)
	_check(cars.ok, "proton: plan ok")
	_check(cars.path == "/usr/bin/env", "proton: passe par env (umu lit sa config dans l'env)")
	_check(cars.args[0] == "GAMEID=umu-cars", "proton: GAMEID dérivé du titre")
	_check(String(cars.args[1]).begins_with("WINEPREFIX="), "proton: préfixe Wine dédié")
	_check(cars.args[2] == "/usr/bin/umu-run", "proton: umu-run résolu")
	_check(cars.args[3] == "/games/Cars/Cars.exe", "proton: exe passé à umu")
	_check(cars.args[4] == "-windowed", "proton: arguments du jeu conservés")

	# 3. PROTONPATH seulement si le catalogue le demande.
	var ge := Launcher.plan({"exe": "/games/X/x.exe", "proton": "GE-Proton"}, "X", linux)
	_check(ge.args[2] == "PROTONPATH=GE-Proton", "proton: PROTONPATH optionnel injecté")

	# 4. Catalogue qui ment ("native" sur un .exe) → Proton quand même sous Linux.
	var liar := Launcher.plan({"runtime": "native", "exe": "/games/Y/y.exe"}, "Y", linux)
	_check(liar.runtime == "proton", "proton: .exe déclaré natif corrigé")

	# 5. umu absent (base Bazzite trop vieille) → message clair, pas de crash.
	var no_umu := linux.duplicate()
	no_umu["which"] = func(c: String) -> String:
		return "/usr/bin/env" if c == "env" else ""
	var missing := Launcher.plan({"exe": "/games/Z/z.exe"}, "Z", no_umu)
	_check(not missing.ok and missing.error.contains("umu-run"), "proton: umu manquant signalé")

	# 6. Jeu non installé → message démo, pas d'échec de lancement.
	var absent := Launcher.plan({"runtime": "native", "exe": "/opt/nope/nope"}, "Nope", linux)
	_check(not absent.ok and absent.error.contains("démo"), "natif: absent → message démo")

	# 7. Machine de dev Windows : le .exe part tel quel.
	var win := {"os": "Windows", "which": func(_c: String) -> String: return "",
		"exists": func(_p: String) -> bool: return true}
	var dev := Launcher.plan({"runtime": "proton", "exe": "E:/Jeux/Cars.exe"}, "Cars", win)
	_check(dev.ok and dev.path == "E:/Jeux/Cars.exe" and dev.runtime == "native",
		"windows: lancement direct, dev local préservé")

	print("LauncherTest: %s" % ("OK" if _fails == 0 else "%d ÉCHEC(S)" % _fails))
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + label)
		print("  FAIL  %s" % label)
	else:
		print("  ok    %s" % label)
