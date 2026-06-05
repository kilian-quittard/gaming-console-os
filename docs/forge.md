# FORGE — création de jeux sur SPARK (scope)

FORGE = **le cœur de SPARK** : créer des jeux à la manette, jouer les créations des autres
(modèle Mario Maker / Dreams / Roblox). C'est l'aimant/exclu que personne d'autre n'offre.

## Niveaux d'outil (du simple au pro)
1. **FORGE Lite 2D** ⭐ (priorité, prototype en cours) — éditeur de plateformer **à la Mario Maker**,
   **100% manette**, canapé. Tu poses des tuiles, tu testes, tu joues.
2. **FORGE Lite 3D** (plus tard) — à la Dreams, simplifié, manette.
3. **FORGE Pro** (plus tard) — Godot desktop complet (clavier/souris) pour les ambitieux.

## Lite 2D — MVP (ce que fait le prototype)
- **Grille de tuiles** (plateformer).
- **Curseur** déplacé au **stick gauche / D-pad** (clavier flèches en fallback PC).
- **Palette de tuiles** : Sol, Spawn joueur, Pièce, Ennemi, Arrivée.
- **Placer** (A) / **Effacer** (B).
- **Changer de tuile** (gâchettes L/R ou X/Y).
- **Tester** (Start) → bascule en mode Jeu : joueur avec gravité, saut, collisions sol,
  ramasse pièces, meurt sur ennemi, gagne sur Arrivée.
- **Retour éditeur** (Start / B).

## Contrôles manette (Lite 2D)
| Action | Manette | Clavier (fallback) |
|---|---|---|
| Déplacer curseur / joueur | Stick gauche + D-pad | Flèches |
| Placer tuile / Sauter | A | Espace / Entrée |
| Effacer tuile | B | Suppr |
| Tuile précédente/suivante | L1 / R1 | A / E |
| Tester / Retour éditeur | Start | Tab |
| Vider la grille | Select | Retour arrière |

## Hors scope MVP (plus tard)
Sauvegarde/chargement fichier, partage en ligne (UGC), plusieurs écrans/mondes, ennemis IA
avancés, sprites custom, son, physique fine. MVP = **prouver que c'est fun + faisable manette**.

## Pourquoi ça d'abord
FORGE justifie la console (seul vrai différenciateur). Le prototype 2D = **non bloqué par le
hardware** (Godot tourne sur le PC de dev) → on valide le pari central tout de suite.

Voir [[project-forge]], [[project-direction]].
