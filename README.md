# ELO COURSE

Classement ELO des coureurs sur route et en trail dans les départements de la Sarthe, de la Mayenne et du Maine-et-Loire.

## Architecture

- `index.html` : application web principale (interface, profils, classements et outils coureurs).
- `worker.js` : Cloudflare Worker qui sert les pages publiques et les fiches SEO.
- `wrangler.jsonc` : configuration Cloudflare Workers et de ses fichiers statiques.
- `.assetsignore` : fichiers et dossiers du dépôt qui ne doivent pas être publiés comme ressources statiques.
- Supabase : stockage principal des données du site, dans la table `site_data` (ligne `id = 1`, colonne `data`).

Le site lit les données publiées depuis Supabase. Le fichier historique `donnees.json` reste dans le dépôt pour archivage et dépannage, mais il n'est pas nécessaire au fonctionnement normal du site et doit être exclu des ressources statiques Cloudflare.

## Développement local

Prérequis : Node.js et npm.

Depuis la racine du dépôt :

```bash
npx wrangler dev
```

Wrangler démarre le Worker localement avec les ressources statiques configurées dans `wrangler.jsonc`.

## Déploiement

Le déploiement Cloudflare est une opération distincte d'une modification ou d'une fusion GitHub.

Après validation explicite de la version à publier :

```bash
npx wrangler deploy
```

Ne pas lancer cette commande sans accord préalable du responsable du site.

## Données et sécurité

- La clé Supabase `sb_publishable_...` utilisée par le navigateur et le Worker est une clé publique, pas un mot de passe administrateur.
- La sécurité des données dépend notamment des politiques Row Level Security (RLS) et des droits accordés aux fonctions RPC Supabase.
- Ne jamais placer de clé `service_role`, de mot de passe ou de secret privé dans `index.html`, `worker.js` ou un autre fichier public.
- Ne pas réimporter automatiquement `donnees.json` dans Supabase : `site_data` est la source de données de référence du site.
- Toute modification de schéma ou de politique Supabase doit être examinée séparément du code du site.

## Fichiers volumineux

`donnees.json` est un export historique volumineux. Il n'est pas appelé par `index.html` ni par `worker.js` dans le fonctionnement actuel. Il est donc exclu du paquet de ressources statiques pour éviter de le transmettre inutilement aux visiteurs. Le fichier reste versionné dans GitHub.

## Vérifications avant publication

1. Vérifier le chargement des données Supabase et l'affichage des classements.
2. Tester les pages d'accueil, profil coureur, course et les parcours de connexion.
3. Vérifier les fonctions de l'espace organisateur et les formulaires.
4. Contrôler les journaux Cloudflare et les erreurs de console.
5. Obtenir l'accord explicite avant toute fusion ou tout déploiement en production.
