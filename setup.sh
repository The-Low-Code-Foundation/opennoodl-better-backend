#!/bin/bash
set -e

echo "Welcome to the Parse Server Backend Setup!"

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo "Error: Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to generate htpasswd string
generate_htpasswd() {
    local username=$1
    local password=$2
    local salt=$(openssl rand -base64 3)
    local hash=$(openssl passwd -apr1 -salt "$salt" "$password")
    echo "$username:$hash"
}

# Function to check if a service is running
check_service() {
    local service=$1
    local max_attempts=30
    local attempt=1

    echo "Checking $service service..."
    while ! docker-compose ps | grep $service | grep "Up" > /dev/null; do
        if [ $attempt -ge $max_attempts ]; then
            echo "Error: $service failed to start after $max_attempts attempts."
            exit 1
        fi
        echo "Waiting for $service to start... (Attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    echo "$service is up and running."
}

# Check if Docker is running before proceeding
check_docker

# Prompt for setup type
read -p "Are you setting up for local development? (yes/no): " is_local

if [ "$is_local" = "yes" ]; then
    domain_name="localhost"
    protocol="http"
    echo "Setting up for local development with domain: $domain_name"
else
    # Prompt for domain name
    read -p "Enter your domain name (without subdomains, e.g., example.com): " domain_name
    domain_name=${domain_name:-example.com}
    protocol="https"

    # Prompt for Traefik ACME email
    read -p "Enter your email for Let's Encrypt certificates: " traefik_acme_email
    traefik_acme_email=${traefik_acme_email:-admin@example.com}
fi

# Prompt for other necessary information
read -p "Enter Parse App ID (default: myAppId): " parse_app_id
parse_app_id=${parse_app_id:-myAppId}

read -p "Enter Parse Master Key (default: myMasterKey): " parse_master_key
parse_master_key=${parse_master_key:-myMasterKey}

read -p "Enter Parse Dashboard Username (default: admin): " dashboard_user
dashboard_user=${dashboard_user:-admin}

read -s -p "Enter Parse Dashboard Password (default: password): " dashboard_password
echo
dashboard_password=${dashboard_password:-password}

read -p "Enter MinIO bucket name (default: parse-bucket): " minio_bucket_name
MINIO_BUCKET_NAME=${minio_bucket_name:-parse-bucket}

read -p "Enter MinIO root user (default: minio): " minio_root_user
MINIO_ROOT_USER=${minio_root_user:-minio}

read -s -p "Enter MinIO root password (default: minio123): " minio_root_password
echo
MINIO_ROOT_PASSWORD=${minio_root_password:-minio123}

# Generate a random encryption key for N8N
n8n_encryption_key=$(openssl rand -hex 32)

# Generate Traefik dashboard credentials
traefik_dashboard_user="admin"
read -s -p "Enter Traefik Dashboard Password (default: password): " traefik_dashboard_password
echo
traefik_dashboard_password=${traefik_dashboard_password:-password}
traefik_dashboard_auth=$(generate_htpasswd "$traefik_dashboard_user" "$traefik_dashboard_password" | sed -e s/\\$/\\$\\$/g)

# Update .env file
cat > .env << EOL
DOMAIN_NAME=$domain_name
PARSE_APP_ID=$parse_app_id
PARSE_MASTER_KEY=$parse_master_key
PARSE_SERVER_DATABASE_URI=mongodb://mongo:27017/parse
PARSE_SERVER_URL=$protocol://parse.$domain_name/parse
PARSE_PUBLIC_SERVER_URL=$protocol://parse.$domain_name/parse

REDIS_URL=redis://redis:6379

PARSE_DASHBOARD_USER_ID=$dashboard_user
PARSE_DASHBOARD_USER_PASSWORD=$dashboard_password

MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
MINIO_BUCKET_NAME=$MINIO_BUCKET_NAME

N8N_ENCRYPTION_KEY=$n8n_encryption_key

TRAEFIK_ACME_EMAIL=$traefik_acme_email
TRAEFIK_DASHBOARD_AUTH=$traefik_dashboard_auth
EOL

# Update parse-config.json
cat > parse-config.json << EOL
{
  "appId": "$parse_app_id",
  "masterKey": "$parse_master_key",
  "databaseURI": "mongodb://mongo:27017/parse",
  "serverURL": "$protocol://0.0.0.0:1337/parse",
  "publicServerURL": "$protocol://parse.$domain_name/parse",
  "cloud": "/parse-server/cloud/main.js",
  "mountPath": "/parse",
  "filesAdapter": {
    "module": "@parse/s3-files-adapter",
    "options": {
      "bucket": "$MINIO_BUCKET_NAME",
      "directAccess": true,
      "baseUrl": "$protocol://minio.$domain_name/$MINIO_BUCKET_NAME",
      "s3overrides": {
        "endpoint": "http://minio:9000",
        "accessKey": "$MINIO_ROOT_USER",
        "secretKey": "$MINIO_ROOT_PASSWORD",
        "s3ForcePathStyle": true,
        "signatureVersion": "v4"
      }
    }
  },
  "cacheAdapter": {
    "module": "parse-server/lib/Adapters/Cache/RedisCacheAdapter",
    "options": {
      "url": "redis://redis:6379"
    }
  },
  "allowClientClassCreation": false,
  "allowExpiredAuthDataToken": true,
  "masterKeyIps": ["0.0.0.0/0"]
}
EOL

# Update parse-dashboard-config.json
cat > parse-dashboard-config.json << EOL
{
  "apps": [{
    "serverURL": "$protocol://parse.$domain_name/parse",
    "appId": "$parse_app_id",
    "masterKey": "$parse_master_key",
    "appName": "MyApp"
  }],
  "users": [{
    "user": "$dashboard_user",
    "pass": "$dashboard_password"
  }],
  "trustProxy": 1,
  "allowInsecureHTTP": true
}
EOL

# Prune unused Docker objects
echo "Pruning unused Docker objects..."
docker system prune -f
docker volume prune -f

# Create the web network if it doesn't exist
echo "Checking if web network exists..."
if ! docker network ls | grep -q "web"; then
    echo "Creating web network..."
    docker network create web
else
    echo "Web network already exists."
fi

# Build and start the services
echo "Building and starting Docker services..."
if docker-compose up --build -d; then
    echo "Your Parse Server backend is now running!"
    echo "Access your services at:"
    echo "Parse Server: $protocol://parse.$domain_name/parse"
    echo "Parse Dashboard: $protocol://dashboard.$domain_name"
    echo "n8n: $protocol://n8n.$domain_name"
    echo "MinIO API: $protocol://minio.$domain_name"
    echo "MinIO Console: $protocol://minio-console.$domain_name"
    echo "Traefik Dashboard: $protocol://traefik.$domain_name (User: $traefik_dashboard_user)"
    echo "Dozzle: $protocol://dozzle.$domain_name"
else
    echo "Error: Failed to build and start Docker services. Please check the error messages above."
    exit 1
fi

# Check each service
check_service "traefik"
check_service "parse-server"
check_service "parse-dashboard"
check_service "n8n"
check_service "minio"
check_service "mongo"
check_service "redis"
check_service "dozzle"

# Create MinIO bucket if it doesn't exist
echo "Creating MinIO bucket if it doesn't exist..."
docker-compose exec -T minio mkdir -p /data/${MINIO_BUCKET_NAME}

echo "All services are up and running. Setup completed successfully!"

if [ "$is_local" = "yes" ]; then
    echo "For local development, add the following entries to your /etc/hosts file:"
    echo "127.0.0.1 parse.$domain_name dashboard.$domain_name n8n.$domain_name minio.$domain_name minio-console.$domain_name traefik.$domain_name dozzle.$domain_name"
else
    echo "Remember to set up your DNS to point all subdomains to your server's IP address."
fi