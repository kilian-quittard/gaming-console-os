extends RefCounted
class_name Launcher
# LANCEMENT des jeux externes — décide COMMENT démarrer un titre selon l'OS.
#
# Le shell ne sait pas lancer un .exe : c'est la couche session qui traduit une
# entrée du catalogue en commande réelle.
#   - natif Linux  → le binaire directement (chemin absolu ou commande du PATH)
#   - Windows      → via umu-run (Proton hors Steam, préinstallé sur Bazzite)
#   - dev Windows  → le .exe tel quel, pour que l'itération locale continue
#
# umu-run ne prend pas d'arguments de config : tout passe par l'environnement
# (GAMEID pour les protonfixes, WINEPREFIX, PROTONPATH). OS.create_process() ne
# sait pas passer d'env → on lance `env VAR=… umu-run jeu.exe`, ce qui évite
# aussi de polluer l'environnement du shell.
#
# plan() est pur (aucun process lancé) et injectable via `env` pour les tests :
#   env = {"os": "Linux", "which": Callable, "exists": Callable}

const PREFIX_DIR := "user://prefixes/"   # un WINEPREFIX par jeu
const UMU := "umu-run"


# Traduit une entrée `launch` du catalogue en commande exécutable.
# Retourne { ok, path, args, runtime, error } — `error` est prêt à afficher.
static func plan(launch: Dictionary, title: String, env: Dictionary = {}) -> Dictionary:
	var os_name: String = env.get("os", OS.get_name())
	var which: Callable = env.get("which", Callable(Launcher, "_which"))
	var exists: Callable = env.get("exists", Callable(Launcher, "_exists"))

	var exe := String(launch.get("exe", "")).strip_edges()
	var args := Array(String(launch.get("args", "")).split(" ", false))
	if exe == "":
		return _fail("pas de binaire déclaré dans le catalogue")

	var runtime := _runtime_for(launch, exe, os_name)
	if os_name == "Windows":
		# Machine de dev : on lance le .exe directement, pas de Proton.
		if not exists.call(exe):
			return _fail("pas installé sur cette machine (démo)")
		return {"ok": true, "path": exe, "args": args, "runtime": "native", "error": ""}

	if runtime == "proton":
		return _plan_proton(exe, args, launch, title, which, exists)
	return _plan_native(exe, args, which, exists)


# --- natif -------------------------------------------------------------------

static func _plan_native(exe: String, args: Array, which: Callable, exists: Callable) -> Dictionary:
	var path := _locate(exe, which, exists)
	if path == "":
		return _fail("pas installé sur cette machine (démo)")
	return {"ok": true, "path": path, "args": args, "runtime": "native", "error": ""}


# --- Proton (umu-run) --------------------------------------------------------

static func _plan_proton(exe: String, args: Array, launch: Dictionary, title: String,
		which: Callable, exists: Callable) -> Dictionary:
	if not exists.call(exe):
		return _fail("pas installé sur cette machine (démo)")
	var umu := String(which.call(UMU))
	if umu == "":
		return _fail("umu-run introuvable — Proton indisponible")
	var envp := String(which.call("env"))
	if envp == "":
		envp = "/usr/bin/env"

	# GAMEID sert aux protonfixes (correctifs connus par jeu) ; sans identifiant
	# de store on dérive un id stable du titre — umu tourne sans correctif.
	var gameid := String(launch.get("gameid", "")).strip_edges()
	if gameid == "":
		gameid = "umu-" + slug(title)

	var cmd := ["GAMEID=" + gameid, "WINEPREFIX=" + prefix_for(title)]
	var proton := String(launch.get("proton", "")).strip_edges()
	if proton != "":
		cmd.append("PROTONPATH=" + proton)   # sinon umu prend UMU-Proton par défaut
	cmd.append(umu)
	cmd.append(exe)
	cmd.append_array(args)
	return {"ok": true, "path": envp, "args": cmd, "runtime": "proton", "error": ""}


# Chaque jeu a son préfixe Wine : une install cassée n'en casse pas une autre.
static func prefix_for(title: String) -> String:
	return ProjectSettings.globalize_path(PREFIX_DIR + slug(title))


# Crée le dossier du préfixe (umu le peuple au premier lancement).
static func ensure_prefix(title: String) -> void:
	DirAccess.make_dir_recursive_absolute(prefix_for(title))


static func slug(title: String) -> String:
	var out := ""
	for c in title.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	return out.strip_edges().trim_prefix("-").trim_suffix("-")


# --- helpers -----------------------------------------------------------------

# Un .exe reste un .exe même si le catalogue le déclare "native" (erreur de
# saisie fréquente) : sous Linux il passe par Proton dans tous les cas.
static func _runtime_for(launch: Dictionary, exe: String, os_name: String) -> String:
	var declared := String(launch.get("runtime", "")).strip_edges().to_lower()
	if exe.to_lower().ends_with(".exe") and os_name != "Windows":
		return "proton"
	if declared == "proton" or declared == "native":
		return declared
	return "native"


# Chemin absolu/relatif → tel quel ; nom nu ("supertuxkart") → cherché dans PATH.
static func _locate(exe: String, which: Callable, exists: Callable) -> String:
	if exe.contains("/") or exe.contains("\\"):
		return exe if exists.call(exe) else ""
	return String(which.call(exe))


static func _which(cmd: String) -> String:
	var sep := ";" if OS.get_name() == "Windows" else ":"
	for dir in OS.get_environment("PATH").split(sep, false):
		var path := String(dir).path_join(cmd)
		if _exists(path):
			return path
	return ""


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "path": "", "args": [], "runtime": "", "error": reason}
