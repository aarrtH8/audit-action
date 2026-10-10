#!/usr/bin/env bash
# audit-code — audit statique honnête d'un dépôt GitHub public, sans installation.
#
# Usage :
#   bash audit-code.sh <auteur/dépôt> [seuil]
#   curl -fsSL https://aarrth8.github.io/audit-code-statique/audit-code.sh | bash -s -- expressjs/express
#
# Produit un rapport lisible : chaque constat cité <fichier>:<ligne> avec l'extrait réel.
# Aucune donnée n'est envoyée à un serveur tiers : tout se passe sur votre machine.

set -euo pipefail

REPO="${1:-}"
SEUIL="${2:-faible}"

if [ -z "$REPO" ]; then
  echo "Usage: bash audit-code.sh <auteur/dépôt> [critique|eleve|moyen|faible]" >&2
  echo "Exemple: bash audit-code.sh expressjs/express" >&2
  exit 2
fi

case "$REPO" in
  */*) ;;
  *) echo "Format attendu : auteur/dépôt (ex : expressjs/express)" >&2; exit 2;;
esac

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t audit)"
trap 'rm -rf "$TMP"' EXIT

echo "Téléchargement de $REPO (branche main, puis master)…" >&2
OK=0
for BR in main master; do
  if curl -fsSL "https://codeload.github.com/$REPO/zip/refs/heads/$BR" -o "$TMP/src.zip" 2>/dev/null; then
    OK=1
    echo "  branche $BR reçue ($(wc -c <"$TMP/src.zip") octets)" >&2
    break
  fi
done

if [ "$OK" -ne 1 ]; then
  echo "Impossible de télécharger l'archive. Dépôt privé, inexistant, ou nom mal orthographié." >&2
  exit 1
fi

echo "Décompression…" >&2
( cd "$TMP" && unzip -q src.zip ) || { echo "unzip requis." >&2; exit 1; }
ROOT="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)"

if [ -z "$ROOT" ]; then echo "Archive vide." >&2; exit 1; fi

echo "" >&2
echo "=== Audit statique — $REPO ==="
echo "Analyse par motifs. Les constats sont des alertes à vérifier, PAS des vulnérabilités confirmées."
echo ""

# Motifs : id|sev|libellé|regex étendue
grep -rInE \
  -e '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' \
  "$ROOT" 2>/dev/null | head -3 | sed 's/^/  [CRITIQUE] clé privée dans le code : /' || true

grep -rInE \
  -e '(child_process\.)?(exec|execSync|spawn|spawnSync|fork)[[:space:]]*\([[:space:]]*[`'"'"'"]' \
  -e '\beval[[:space:]]*\(|new[[:space:]]+Function[[:space:]]*\(' \
  "$ROOT" 2>/dev/null | grep -vE '\.min\.js|node_modules' | head -15 | sed 's/^/  [ÉLEVÉ] exécution de code dynamique : /' || true

grep -rInE \
  -e '(password|passwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*[`'"'"'"][^`'"'"'"]{8,}' \
  "$ROOT" 2>/dev/null | grep -vE 'node_modules|\.min\.js' | head -10 | sed 's/^/  [ÉLEVÉ] secret probable en clair : /' || true

grep -rInE \
  -e '(mongodb|postgres|postgresql|mysql|redis)://[^[:space:]]*:[^[:space:]]*@' \
  "$ROOT" 2>/dev/null | head -5 | sed 's/^/  [ÉLEVÉ] chaîne de connexion avec identifiants : /' || true

if [ "$SEUIL" != "critique" ] && [ "$SEUIL" != "eleve" ]; then
  grep -rInE \
    -e 'innerHTML[[:space:]]*=|dangerouslySetInnerHTML' \
    -e 'verify[[:space:]]*=[[:space:]]*False|rejectUnauthorized[[:space:]]*:[[:space:]]*false' \
    -e 'debug[[:space:]]*=[[:space:]]*True' \
    "$ROOT" 2>/dev/null | grep -vE 'node_modules|\.min\.js' | head -10 | sed 's/^/  [MOYEN] à vérifier : /' || true
fi

if [ "$SEUIL" = "faible" ]; then
  N=$(grep -rInE 'http://(?!localhost|127\.0\.0\.1)' "$ROOT" 2>/dev/null | grep -vE 'node_modules|\.min\.js' | wc -l || echo 0)
  echo "  [FAIBLE] URLs en clair (http://) : ${N} occurrence(s) — la plupart dans les tests/docs."
fi

echo ""
echo "---"
echo "Ce que ce rapport ne dit pas : impacts réels non confirmés, dépendances non vérifiées,"
echo "configuration serveur non examinée. Un motif n'est pas une vulnérabilité."
echo ""
echo "Pour un passage complet (croisement du contexte d'appel, tri du bruit, priorisation) :"
echo "  https://aarrth8.github.io/audit-code-statique/commande.html"
