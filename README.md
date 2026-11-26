# WanGP sur la machine de prototypage de l'EPF

Déploiement de [WanGP](https://github.com/deepbeepmeep/Wan2GP) (génération de vidéos avec les modèles Wan, sur un GPU modeste) dans un conteneur Docker, pour le cours **Cloud Open Source**.
Objectif du groupe : tester WanGP pour les petits dessins animés de Carrieretudes, et mesurer le temps de calcul pour chiffrer le coût (cloud AWS ou Azure, comparé à une machine sur site) sur l'hypothèse de **30 vidéos d'une minute par mois**.

## Ce que contient ce dépôt

| Fichier | Rôle |
|---|---|
| `Dockerfile` | Image CUDA 12.8 + Python 3.10 + PyTorch 2.10 + WanGP (+ Sage Attention), version de WanGP figée. |
| `docker-compose.yml` | Le service `wangp` : GPU, port local, dossier de données. |
| `.env.example` | Les réglages à copier dans `.env` (nom, port, GPU, dossier, profil mémoire). |
| `scripts/entrypoint.sh` | Lance l'interface web de WanGP avec les bons dossiers. |
| `scripts/mesurer.sh` | Relève l'utilisation du GPU pendant une génération, pour le chiffrage. |

## Règles de la machine partagée

- Tout porte le nom `COMPOSE_PROJECT_NAME` (par défaut `wangp-userd`) : conteneur, image, réseau. **Ne lance jamais** `docker system prune`, `docker rm` ou `docker stop` sur un conteneur qui n'est pas le tien ; utilise seulement `docker compose …` depuis ce dossier.
- L'interface n'écoute que sur `127.0.0.1` de la machine : on y accède par un tunnel SSH, personne d'autre ne la voit, et elle ne prend le port de personne.
- Un seul GPU : celui que l'enseignant vous a attribué (`GPU_ID`). Ne lance rien sur la carte d'Ollama ni sur celle du stagiaire.
- Les modèles sont gros (~15 à 20 Go pour Wan 2.2 5B, plusieurs dizaines de Go pour les 14B) et le home a peu de place : vérifie avant de télécharger, et commence par Wan 2.2 5B.
- Les tâches longues se lancent dans `tmux` (`tmux new -s wangp`, détacher : Ctrl+B puis D) pour survivre à une coupure SSH.

## 0. Se connecter

```bash
ssh userD@<adresse-de-la-machine>
```

Conseillé : une clé SSH plutôt que le mot de passe (`ssh-keygen -t ed25519` puis `ssh-copy-id userD@<adresse>` depuis ton ordinateur). Aucune adresse, mot de passe ou clé dans ce dépôt : il est public.

## 1. Vérifier la machine (une fois)

```bash
nvidia-smi                                   # GPU visibles, qui les utilise, pilote (≥ 570 pour CUDA 12.8)
docker run --rm --gpus '"device=0"' nvidia/cuda:12.8.1-base-ubuntu22.04 nvidia-smi   # Docker voit TON GPU (remplace 0 par GPU_ID)
free -h                                      # RAM : choisit le profil 1 ou 3
df -h /var/datalake/home/userD               # place libre dans ton home
id -u; id -g                                 # ton UID et ton GID, pour le .env
docker ps --format '{{.Names}}  {{.Ports}}'  # conteneurs et ports déjà pris par les autres
```

Si le pilote est plus ancien que 570, CUDA 12.8 ne marchera pas : il faut le faire mettre à jour par l'enseignant (WanGP actuel exige PyTorch 2.10).

## 2. Installer

```bash
cd /var/datalake/home/userD
git clone https://github.com/redouanend/wangp-prototype.git && cd wangp-prototype
cp .env.example .env
nano .env        # COMPOSE_PROJECT_NAME, WANGP_PORT libre, GPU_ID, DATA_DIR, HOST_UID/GID, WANGP_PROFILE
mkdir -p "$(grep ^DATA_DIR .env | cut -d= -f2)"
docker compose build          # 10 à 20 min la première fois
```

Profil mémoire (`WANGP_PROFILE`), d'après le script Docker de WanGP : **3** pour la L40S (48 Go de VRAM) sur une machine partagée, **1** si au moins 48 Go de RAM sont libres ; **2** entre 12 et 24 Go de VRAM, **4** en dessous.

## 3. Lancer et ouvrir l'interface

```bash
docker compose up -d
docker compose logs -f        # attendre « Running on http://0.0.0.0:7860 » (Ctrl+C pour quitter les logs)
```

Depuis ton ordinateur, ouvre un tunnel puis va sur http://localhost:7860 :

```bash
ssh -L 7860:127.0.0.1:7860 userD@<adresse-de-la-machine>
```

(Remplace le premier 7860 par un autre port si tu l'utilises déjà en local, et le second par `WANGP_PORT`.)

Les modèles se téléchargent au premier usage dans `DATA_DIR/ckpts`, les vidéos sortent dans `DATA_DIR/outputs`.

## 4. Mesurer (pour le chiffrage)

Pour chaque essai (même modèle, même durée de vidéo, même résolution) :

Premier essai conseillé : **Wan 2.2 5B, 720p, 5 s** (un plan), puis le même plan en 14B 480p.

1. `./scripts/mesurer.sh wan22-5b-720p-5s` dans un second terminal, puis lance la génération dans l'interface ;
2. à la fin, Ctrl+C : le relevé est dans `mesures/` ;
3. note dans un tableau : modèle, résolution, durée de la vidéo, temps de génération, VRAM maximale, GPU.

Le coût par minute de vidéo = temps de génération pour 1 min × prix horaire d'une machine GPU équivalente (AWS, Azure) ; à comparer à l'amortissement d'une machine sur site.

## 5. Arrêter, mettre à jour, (re)déployer

```bash
docker compose down                       # arrête et supprime TON conteneur (les données restent)
git pull && docker compose build && docker compose up -d   # redéploiement
```

**Figer la version** : WanGP change souvent. Pour des mesures comparables, mets un commit précis dans `.env` (`WANGP_REF=<commit>`) puis `docker compose build`. Le commit utilisé s'affiche au démarrage (`docker compose logs | head`).

**Tout retirer** (seulement tes affaires) :

```bash
docker compose down --rmi local
rm -rf "$(grep ^DATA_DIR .env | cut -d= -f2)"   # modèles et vidéos : attention, c'est définitif
```

## Dépannage

- `could not select device driver "nvidia"` : le NVIDIA Container Toolkit n'est pas configuré, à demander à l'enseignant.
- Erreur avec Sage Attention : mets `WANGP_ATTENTION=sdpa` dans `.env`, puis `docker compose up -d`.
- Option `--listen` inconnue (version de WanGP différente) : `docker compose run --rm --entrypoint python wangp wgp.py --help` pour voir les options, puis adapte `scripts/entrypoint.sh`.
- Manque de mémoire GPU : profil plus économe (`WANGP_PROFILE=4` ou `5`) ou modèle plus petit (Wan 2.2 5B).
- Erreur `no kernel image` ou `CUDA driver version is insufficient` : pilote trop ancien pour CUDA 12.8 (voir étape 1).
- Plus de place : `du -sh "$DATA_DIR"/*` puis supprime les modèles inutiles dans `ckpts/`.
