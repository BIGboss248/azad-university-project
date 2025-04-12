#!/bin/bash

sudo apt update && sudo apt install make

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

# Update the .env file
env_file="WordPress\.env"
if [ -f "$env_file" ]; then
  sed -i "s/^WordPress_db_user=.*/WordPress_db_user=$db_user/" "$env_file"
  sed -i "s/^WordPress_Pass=.*/WordPress_Pass=$db_pass/" "$env_file"
  echo "Domain=$domain" >> "$env_file"
  echo "Cloudflare_API_Token=$cloudflare_token" >> "$env_file"
  echo "Environment variables updated successfully in $env_file."
else
  echo "Error: $env_file not found!"
  exit 1
fi

if [-f "./Makefile"]; then
  make certbot_nginx CLOUDFLARE_API_TOKEN=$cloudflare_token DOMAIN=$domain
else
  echo "Error: Makefile not found!"
  exit 1
fi