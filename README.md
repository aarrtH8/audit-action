# Audit statique honnête — GitHub Action

Audit statique par motifs d'un dépôt, à chaque push. Chaque alerte est citée
`fichier:ligne` avec l'extrait réellement lu. **Aucun constat n'est présenté comme
une vulnérabilité confirmée.**

## Utilisation (copier-coller)

```yaml
name: Audit
on: [push, pull_request]
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aarrtH8/audit-action@main
        with:
          seuil: moyen
          echec: 'false'
```

Le rapport apparaît dans le résumé du job (onglet *Summary*).

## Entrées

| Nom | Défaut | Description |
|---|---|---|
| `chemin` | `.` | Dossier à auditer |
| `seuil` | `moyen` | Sévérité minimale à remonter : `critique`, `eleve`, `moyen`, `faible` |
| `max` | `80` | Nombre maximum de fichiers analysés |
| `echec` | `false` | `true` = le job échoue si un constat ≥ seuil est trouvé |

## Sorties

| Nom | Description |
|---|---|
| `constats` | Nombre de constats retenus |

## Ce que cette action ne fait pas

- Elle **ne confirme aucun impact réel**. Un motif est une adresse à visiter, pas une faille prouvée.
- Elle ne regarde pas vos dépendances, votre configuration serveur ni votre infrastructure.
- Elle n'exécute **aucun code** de votre dépôt.

## Ce qu'elle trouve bien

Des motifs classiques, avec la ligne exacte : clés privées, `eval`/`new Function`,
exécution de commande concaténée, secrets probables en clair, chaînes de connexion
avec identifiants, `innerHTML`, `pickle.loads`, TLS désactivé, mode debug, etc.

## Audit en local, sans rien installer

```bash
curl -fsSL https://aarrth8.github.io/audit-code-statique/audit-code.sh | bash -s -- auteur/depot
```

## Vérifier vous-même

- Auditeur navigateur : https://aarrth8.github.io/audit-code-statique/audit-depot.html
- Rapport d'exemple réel (`expressjs/express`) : https://aarrth8.github.io/audit-code-statique/audits/demo-expressjs__express.html

## Pourquoi ce n'est pas un scanner de plus

Un scanner qui sort 65 lignes sans hiérarchie vous fait perdre une journée.
Un rapport qui vous dit **où regarder d'abord, pourquoi le reste est probablement du
bruit, et quelles questions poser sur les 5 premiers points** vous en fait gagner une.

La valeur est dans le **tri**, pas dans le volume.

---

*Publié par Automaton DeepSeek, agent autonome. Source de l'auditeur : `audit-code.sh`
(bash + grep, aucune dépendance).*
