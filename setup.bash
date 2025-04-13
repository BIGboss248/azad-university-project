#!/bin/bash

# One command setup run
# curl -s https://raw.githubusercontent.com/BIGboss248/azad-university-project/refs/heads/main/setup.bash | bash

sudo apt update && sudo apt install make git nginx
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot

git clone https://github.com/BIGboss248/azad-university-project.git

pwd=$(pwd)"/azad-university-project"
cd $pwd

# Function to generate a random string
generate_random_string() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 16
}

# Prompt user for domain and Cloudflare API token
read -p "Enter your domain: " domain
read -p "Enter your Cloudflare API token: " cloudflare_token

# Generate random strings for WordPress_db_user and WordPress_Pass
db_user=$(generate_random_string)
db_pass=$(generate_random_string)

# Remove existing .env file and create a new one
env_file=$(pwd)"/WordPress/.env"
if [ -f "$env_file" ]; then
  rm "$env_file"
  echo ".env file removed."
fi

# Create a new .env file with the required variables
cat <<EOL > "$env_file"
WordPress_db_user=$db_user
WordPress_Pass=$db_pass
EOL

echo "New .env file created successfully at $env_file."


makefile=$(pwd)"/Makefile"
if [ -f $makefile ]; then
  make docker
  make certbot_nginx CLOUDFLARE_API_TOKEN=$cloudflare_token DOMAIN=$domain
else
  echo "Error: Makefile not found!"
  exit 1
fi

sudo rm -rf /etc/nginx/conf.d/*
sudo rm -rf /etc/nginx/nginx.conf
sudo touch /etc/nginx/nginx.conf
sudo bash -c 'cat <<EOL > /etc/nginx/nginx.conf
events { 
  worker_connections 1024;
}

http {
  # HTTP to HTTPS redirection
  server {
    listen 80;
    server_name '"$domain"';
    # Set webroot for certbot to issue certificates
    location /.well-known/acme-challenge/ {
      root /var/www/certbot;
    }
  }

  # HTTPS server with reverse proxy
  server {
    listen 443 ssl;
    server_name '"$domain"';
    # Certificates issued by certbot
    ssl_certificate /etc/letsencrypt/live/'"$domain"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$domain"'/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384";

    location / {
      proxy_pass http://172.18.0.2:80;
      proxy_set_header Host $host;
      # Forward client IP
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
}
EOL'

sudo systemctl restart nginx
compose=$(pwd)"/WordPress/docker-compose.yml"
sudo docker compose -f $compose up -d
