#!/bin/bash

sudo apt update && sudo apt install make git nginx

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
  make certbot_nginx CLOUDFLARE_API_TOKEN=$cloudflare_token DOMAIN=$domain
else
  echo "Error: Makefile not found!"
  exit 1
fi

compose=$(pwd)"/WordPress/docker-compose.yml"
sudo docker compose -f $compose up -d
