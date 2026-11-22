# ELO COURSE — Bandeau d’annonces

Cette branche ajoute un bandeau défilant public et un petit gestionnaire réservé au compte administrateur ELO COURSE.

## Fonctionnement
- Le visiteur voit le bandeau uniquement lorsqu'une annonce est active.
- Le compte administrateur peut publier ou remplacer le texte.
- « Interrompre le bandeau » vide le message et le masque complètement.
- L'état est conservé dans Supabase et relu automatiquement toutes les 12 secondes.
- Le module ne modifie pas les tables existantes de coureurs, courses ou résultats.

## Activation Supabase requise
Dans Supabase > SQL Editor, exécuter le contenu de `bandeau-annonces.sql`.

La table applique RLS : lecture publique, écriture réservée à l'UID administrateur déjà présent dans le site.

## Branchement
Le fichier `index.html` de cette branche charge automatiquement `bandeau-annonces.js` en fin de page.

## Sécurité / mise en ligne
Les changements sont isolés dans la branche `feature/bandeau-annonces`. Ils ne sont pas déployés en production et ne sont pas fusionnés dans `main`.
