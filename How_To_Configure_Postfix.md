# Configuration de Postfix avec Relay Gmail  

======================================================================  

Ce guide détaille le processus d'intégration de Postfix avec le relay Gmail pour assurer des notifications e-mail dans GitLab.  

---  

### Prérequis
- Accès à https://myaccount.google.com/security-checkup.
- Un compte Google.  

### Remarques
- Assurez-vous d'activer "Autoriser les applications moins sécurisées" sur votre compte Google avant de commencer le processus.  

---  

### Étape 1 : Autoriser l'application sur votre compte Google  

1. Accéder à [https://myaccount.google.com/security-checkup](https://myaccount.google.com/security-checkup).
2. Activer **"Autoriser les applications moins sécurisées"**.  

### Étape 2 : Générer un code d'application  
1. Sur la même page, recherchez **"Mot de passe de l'application"**.  
2. Choisissez **"Autre (nom personnalisé)"**, donnez un nom (ex. "Postfix Relay").  
3. Copiez le code généré.  
4. Utilisez le code généré comme mot de passe dans votre fichier de configuration Postfix.  

### Étape 3 : Configuration de Postfix avec le Relay Gmail  

1. Ouvrir le fichier de configuration Postfix :
   
   ```bash
   sudo nano /etc/postfix/main.cf
   ```  

2. Ajoutez ou modifiez les lignes suivantes :
   
   ```bash
   relayhost = [smtp.gmail.com]:587
   smtp_use_tls = yes
   smtp_sasl_auth_enable = yes
   smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
   smtp_sasl_security_options = noanonymous
   ```  

3. Créez le fichier :
   
   `/etc/postfix/sasl_passwd`  
   
insérer le code suivant en adaptant celui-ci à votre usage
   
   ```bash
   [smtp.gmail.com]:587  votre.email@gmail.com:code-généré
   ```  

4. Sécurisez le fichier :
   
   ```bash
   sudo chmod 600 /etc/postfix/sasl_passwd
   ```  

5. Exécutez :
   
   ```bash
   sudo postmap /etc/postfix/sasl_passwd
   ```  

6. Redémarrez Postfix :
   
   ```bash
   sudo systemctl restart postfix 
   ```  

### Étape 4 : Configurer GitLab avec le Relay Gmail  

1. Ouvrez le fichier de configuration GitLab :
   
   ```bash
   sudo nano /etc/gitlab/gitlab.rb
   ```  

2. Ajoutez ou modifiez les lignes suivantes :
   
   ```bash
   gitlab_rails['smtp_enable'] = true
   gitlab_rails['smtp_address'] = "smtp.gmail.com"
   gitlab_rails['smtp_port'] = 587
   gitlab_rails['smtp_user_name'] = "votre.email@gmail.com"
   gitlab_rails['smtp_password'] = "code-généré"
   gitlab_rails['smtp_domain'] = "example.com"
   gitlab_rails['smtp_authentication'] = "login"
   gitlab_rails['smtp_enable_starttls_auto']
   ```  

3. Reconfigurez GitLab :
   
   ```bash
   sudo gitlab-ctl reconfigure
   ```
