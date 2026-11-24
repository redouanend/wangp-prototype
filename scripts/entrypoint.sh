#!/usr/bin/env bash
# Lance l'interface de WanGP. Les modèles (ckpts), les vidéos produites et les caches vont dans
# /data, un dossier de l'hôte : ils survivent à un redéploiement et ne sont téléchargés qu'une fois.
set -euo pipefail
mkdir -p /data/ckpts /data/outputs /data/cache /data/settings
cd /opt/wangp
# WanGP range ses modèles dans ./ckpts et ses vidéos dans ./outputs : on les redirige vers /data.
for d in ckpts outputs settings; do
  if [ ! -L "$d" ]; then rm -rf "$d"; ln -s "/data/$d" "$d"; fi
done
cat /opt/WANGP_VERSION
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || true
exec python wgp.py --listen --server-port 7860 \
  --profile "${WANGP_PROFILE:-4}" --attention "${WANGP_ATTENTION:-sage}" ${WANGP_EXTRA_ARGS:-}
