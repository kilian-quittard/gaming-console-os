# Catalogue SPARK — schéma & système d'onboarding

`frontend/catalogue/catalogue.json` = source du catalogue. Le frontend GAMING le lit au boot
(`_load_catalogue`) et construit : slot **Cartouche** + jeux du catalogue + **Store**.
L'aperçu (Y) affiche les vraies métadonnées (note, genre, taille, prix, description).

## Schéma d'un jeu
```json
{
  "title": "SuperTuxKart",
  "dev": "SuperTuxKart Team",
  "genre": "Course",
  "rating": 4.4,
  "size_gb": 1.3,
  "price": 0,
  "license": "Libre (GPL)",
  "desc": "Texte court affiché dans l'aperçu.",
  "launch": { "runtime": "native|proton", "exe": "binaire", "args": "", "fsr": "off|quality|balanced|performance", "res": "720p|900p|1080p" }
}
```

## `launch` = la fondation du système d'onboarding
C'est la **config par jeu** appliquée au lancement (sur GPU réel / hardware) :
- `runtime` : `native` (jeu Linux) ou `proton` (build Windows via Proton, **sans portage**).
- `exe` / `args` : quoi lancer.
- `fsr` / `res` : profil upscaling/rendu par jeu (rendu bas → FSR → sortie écran).

Le **test Proton + certif** ("tourne bien sur SPARK") se fait plus tard sur PC physique :
lancer le build, vérifier, ajuster `launch`, marquer certifié. Proton fait tourner ~90% des
jeux Windows ; ce schéma stocke juste la recette par jeu.

## Seed actuel = jeux LIBRES (plomberie + démo)
SuperTuxKart, Mindustry, 0 A.D., Veloren, Xonotic. But : prouver la chaîne + démo de pitch.
**Ce n'est pas l'offre commerciale** — le vrai catalogue attirant = **Steam (biblio de l'user,
gratuit, massif)** + **indés signés** (partenariats) + abo. Voir [[project-business-model]].

## Étapes suivantes
- Médias réels (captures/trailer) par jeu (champ à ajouter : `media`).
- Backend serveur (comptes, paiement, licences, CDN) quand jeux payants.
- Intégration Steam (lister/lancer la biblio de l'utilisateur).
- Câblage du lancement réel (applique `launch` via la session, sur hardware).
