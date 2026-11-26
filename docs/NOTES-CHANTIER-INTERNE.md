# Notes de chantier — ELO COURSE
> Suivi technique interne au projet. Ne pas intégrer ces notes dans les pages publiques du site.

## Carnet d'entraînement — état et travaux à prévoir

### État actuel
- La page « Mes entraînements » enregistre encore les séances dans le stockage local du navigateur via `localStorage`.
- Les séances ne sont donc pas encore synchronisées entre appareils via le compte ELO COURSE.
- Elles ne sont pas encore partagées avec les autres coureurs.
- Le carnet permet d'ajouter, modifier et supprimer une séance.
- La durée doit conserver les secondes (ex. `38:42`) et l'allure doit être calculée et affichée en minutes:secondes par kilomètre.
- La demande de récompense ELOCOINS passe par la fonction Supabase `elocoins_reward_training_session`. Ne pas supposer qu'une récompense a été attribuée sans confirmation du serveur.

### À réaliser
1. Mettre en place la synchronisation sécurisée des séances avec le compte coureur dans Supabase.
2. Prévoir la récupération des séances après reconnexion et depuis un autre appareil.
3. Permettre au coureur de choisir quelles séances il souhaite partager avec la communauté.
4. Synchroniser les modifications et suppressions.
5. Préserver les séances déjà présentes dans le stockage local lors de la migration vers Supabase (prévoir une migration/import sans perte).
6. Garder une protection serveur contre les doubles récompenses : modifier une séance ne doit jamais recréditer les ELOCOINS ; supprimer puis recréer une séance ne doit pas permettre de contourner les règles de récompense.
7. Vérifier les règles de récompense et leur cohérence avec les règles ELOCOINS validées avant tout changement en production.

### Règles d'interface
- Ne pas afficher aux visiteurs de messages techniques du type « stockage local », « pas encore synchronisé », « non visible par les autres coureurs » ou « fonctionnalité en développement ».
- Garder ces informations dans ce fichier de suivi technique.
- L'interface publique doit rester propre et professionnelle, sans annoncer une fonctionnalité inachevée.
- Ne pas modifier les règles ELOCOINS, les données de production ou les règles sportives sans validation explicite.

### Correction de saisie déjà demandée
- Accepter les durées au format minutes:secondes, notamment `38:42` (et le format virgule déjà proposé).
- Ne pas arrondir la durée à la minute entière.
- Calculer l'allure à partir de la durée exacte et de la distance : pour 6,38 km en 38 min 42 s, afficher environ `6:04 /km`.
