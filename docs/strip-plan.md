# SPARK — Plan de "console-isation" (strip + lockdown)

But : passer de l'image **dev** (bureau dispo, pratique pour développer) à l'image **produit**
(boote direct sur SPARK, pas d'accès bureau/terminal). À faire **par étapes, validé sur PC physique (GPU)**.

## Fait (image dev, sûr)
- Frontend SPARK dans l'image (`/usr/lib/spark`, launcher, entrée bureau).
- Session gaming `spark-session` (gamescope + boucle), session Wayland sélectionnable (pas défaut).
- Lean sûr : `cups` masqué (pas d'impression), `vm.swappiness=10`.

## À faire — phase HARDWARE (PC physique, vrai GPU)
1. **Session gamescope par défaut au boot** (au lieu du bureau) — testé d'abord en sélection manuelle.
2. **Auto-login** vers la session SPARK (display manager → autologin user → spark-session).
3. **Verrouillage** : retirer/masquer l'accès bureau + terminal (TTY), désactiver le switch session pour l'utilisateur final.
4. **Réglage hardware** : profil TDP (pousser 54W+ branché), courbe ventilo, allocation UMA iGPU.
5. **Boucle retour** validée : quitter jeu/app → refocus SPARK.

## À faire — image PRODUIT (séparée de l'image dev)
6. Variante d'image "produit" : bureau retiré/inaccessible + lockdown complet.
   Garder une image "dev" avec bureau pour continuer à développer.
7. Switch GAMING↔TRAVAIL = bascule session gamescope ↔ bureau (modèle Steam Deck) — voir idée Kilian.

## Pourquoi pas tout maintenant
- Image immuable (rpm-ostree/ublue) = fragile au retrait de paquets (peut casser le boot).
- La session gamescope + le lockdown ne s'affichent/valident **que sur GPU réel** (la VM sans GPU = écran noir, Vulkan absent).
- Donc : strip lourd + lockdown = **après** avoir un 2e SSD / APU physique pour tester.
