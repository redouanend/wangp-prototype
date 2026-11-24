#!/usr/bin/env bash
# Relève l'occupation du GPU pendant une génération, pour chiffrer le coût (durée × prix horaire).
# Usage : ./scripts/mesurer.sh nom-du-test   (lance-le juste avant de cliquer sur « Generate »,
# arrête-le avec Ctrl+C à la fin). Résultat : mesures/<nom>-<date>.csv
set -euo pipefail
nom="${1:-essai}"; mkdir -p mesures
f="mesures/${nom}-$(date +%Y%m%d-%H%M%S).csv"
echo "Relevé dans $f (Ctrl+C pour arrêter)"
nvidia-smi --query-gpu=timestamp,name,utilization.gpu,memory.used,memory.total,power.draw \
  --format=csv -l 2 -i "${GPU_ID:-0}" | tee "$f"
