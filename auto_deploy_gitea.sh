#!/bin/bash
####################################################################################
#
# Script d'installation automatique de Gitea
# Auteur: Guilhem Schlosser
# Date de création: Decembre 2023
# Usage: installation automatisé via fichier de réponse anaconda-ks.cfg
# Distribution: CentOS 9
# Nom du script: auto_deploy_gitea.sh
#
# Ce script installe et configure automatiquement Gitea sur CentOS 9.
# Il prend en compte les recommandations officielles d'installation de Gitea.
#
# Why: simplement parce que Gitlab demande trop de ressources
####################################################################################
# PID Shell script
echo "PID of this script: $$"
#Name of script
echo "The name of the script is : $0"
#####################################################################
# Prevent execution: test Os & Print information system
if [ -f /etc/redhat-release ] ; then
	cat /etc/redhat-release
else
	echo "Distribution is not supported"
	exit 1
fi
#####################################################################
# Récupération du nom d'hôte
DOMAIN=$(hostname)

# Variables
GITEA_VERSION="1.21.1"
GITEA_ARCH="linux-amd64"
GITEA_USER="git"
GITEA_HOME="/home/$GITEA_USER"
GITEA_CUSTOM="/var/lib/gitea"
GITEA_PORT="3000"
MYSQL_USER="gitea"
MYSQL_PASSWORD="rootme"
MYSQL_DATABASE="gitea"

# Création de l'utilisateur Git
groupadd --system $GITEA_USER
adduser \
   --system \
   --shell /bin/bash \
   --comment 'Git Version Control' \
   --gid $GITEA_USER \
   --home-dir $GITEA_HOME \
   --create-home \
   $GITEA_USER

# Téléchargement et extraction de Gitea
mkdir -p $GITEA_CUSTOM
chown $GITEA_USER:$GITEA_USER $GITEA_CUSTOM
wget -O gitea https://dl.gitea.io/gitea/$GITEA_VERSION/gitea-$GITEA_VERSION-$GITEA_ARCH
chmod +x gitea
mv gitea $GITEA_CUSTOM/gitea

# Copier le fichier d'exemple vers le fichier renommé
cp "$GITEA_CUSTOM/gitea/gitea.example.ini" "$GITEA_CUSTOM/gitea/gitea.$DOMAIN.ini"

# Ajouter l'extension .bak au fichier d'exemple
mv "$GITEA_CUSTOM/gitea/gitea.example.ini" "$GITEA_CUSTOM/gitea/gitea.example.ini.bak"

# Remplacer dynamiquement le placeholder DOMAIN dans le fichier renommé
sed -i "s/;DOMAIN           = localhost/DOMAIN           = $DOMAIN/g" "$GITEA_CUSTOM/gitea/gitea.$DOMAIN.ini"

# Copier le fichier renommé dans le répertoire de configuration principal
cp "$GITEA_CUSTOM/gitea/gitea.$DOMAIN.ini" "$GITEA_CUSTOM/gitea/custom/conf/app.ini"

sed -i "s/DB_TYPE  = sqlite3/DB_TYPE  = mysql/g" "$GITEA_CUSTOM/gitea/custom/conf/app.ini"
sed -i "s/PATH     = data/gitea.db/PATH     = $GITEA_CUSTOM/gitea/data/gitea.db/g" "$GITEA_CUSTOM/gitea/custom/conf/app.ini"
sed -i "s/;DOMAIN           = localhost/DOMAIN           = $DOMAIN/g" "$GITEA_CUSTOM/gitea/custom/conf/app.ini"
sed -i "s/HTTP_PORT        = 3000/HTTP_PORT        = $GITEA_PORT/g" "$GITEA_CUSTOM/gitea/custom/conf/app.ini"

# Configuration SMTP (commentée par défaut)
# Contenu de la configuration SMTP
SMTP_CONFIG="
#[mailer]
#ENABLED        = true
#HOST           = smtp.gmail.com:465 ; Remove this line for Gitea >= 1.18.0
#SMTP_ADDR      = smtp.gmail.com
#SMTP_PORT      = 465
#FROM           = example.user@gmail.com
#USER           = example.user
#PASSWD         = `***`
#PROTOCOL       = smtps
"

# Emplacement du fichier app.ini
APP_INI="$GITEA_CUSTOM/gitea/custom/conf/app.ini"

# Vérifier si la configuration SMTP est déjà présente dans app.ini
if ! grep -q "\[mailer\]" "$APP_INI"; then
  # Ajouter la configuration SMTP commentée
  echo "$SMTP_CONFIG" >> "$APP_INI"
fi

# Création de la base de données MySQL/MariaDB
mysql -u root -p -e "CREATE DATABASE $MYSQL_DATABASE CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';"
mysql -u root -p -e "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
mysql -u root -p -e "GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'localhost';"
mysql -u root -p -e "FLUSH PRIVILEGES;"

# Restriction des droits sur les fichiers et répertoires
chown -R $GITEA_USER:$GITEA_USER "$GITEA_CUSTOM/gitea/custom/conf/app.ini"
chmod 600 "$GITEA_CUSTOM/gitea/custom/conf/app.ini"

chown -R $GITEA_USER:$GITEA_USER "$GITEA_CUSTOM/gitea/data"
chmod 700 "$GITEA_CUSTOM/gitea/data"

chown $GITEA_USER:$GITEA_USER "$GITEA_CUSTOM/gitea/gitea"
chmod 700 "$GITEA_CUSTOM/gitea/gitea"

# Configuration du répertoire de travail de Gitea
export GITEA_WORK_DIR=$GITEA_CUSTOM

# Création du fichier de service pour systemd
tee /etc/systemd/system/gitea.service <<EOL
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target
After=mysql.service

[Service]
###
# Modifiez ces deux valeurs et décommentez-les si vous avez des dépôts avec beaucoup de fichiers et que vous obtenez une erreur HTTP 500.
###
#LimitMEMLOCK=infinity
#LimitNOFILE=4096
RestartSec=2s
Type=simple
User=$GITEA_USER
Group=$GITEA_USER
WorkingDirectory=$GITEA_CUSTOM
ExecStart=$GITEA_CUSTOM/gitea/gitea web -c $GITEA_CUSTOM/gitea/custom/conf/app.ini
Restart=always
Environment=USER=$GITEA_USER HOME=$GITEA_HOME GITEA_WORK_DIR=$GITEA_WORK_DIR

[Install]
WantedBy=multi-user.target
EOL

# Active et démarre le service Gitea
systemctl enable --now gitea
