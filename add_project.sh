#!/bin/bash

# Function to generate a random string
generate_random_string() {
    openssl rand -hex 8
}

# Check if this is the first project
if [ ! -f ".project_count" ]; then
    echo "1" > .project_count
    echo "Setting up the main infrastructure..."
    
    # Run the original setup script
    ./setup.sh

    # Modify docker-compose.yml to remove Parse Server
    sed -i '/parse-server:/,/^$/d' docker-compose.yml
    
    echo "Main infrastructure setup complete."
fi

# Get the project count and increment it
project_count=$(cat .project_count)
new_project_count=$((project_count + 1))
echo $new_project_count > .project_count

# Prompt for project name
read -p "Enter a name for your new project: " project_name
project_name=${project_name:-"project_$new_project_count"}

# Generate unique App ID and Master Key
app_id="app_$(generate_random_string)"
master_key="key_$(generate_random_string)"

# Create a new Parse Server configuration
cat > "parse-config-$project_name.json" << EOL
{
  "appId": "$app_id",
  "masterKey": "$master_key",
  "databaseURI": "mongodb://mongo:27017/$project_name",
  "serverURL": "http://0.0.0.0:1337/parse",
  "publicServerURL": "http://parse-$project_name.localhost/parse",
  "cloud": "/parse-server/cloud/main.js",
  "mountPath": "/parse",
  "filesAdapter": {
    "module": "@parse/s3-files-adapter",
    "options": {
      "bucket": "$project_name",
      "directAccess": true,
      "baseUrl": "http://minio.localhost/$project_name",
      "s3overrides": {
        "endpoint": "http://minio:9000",
        "accessKey": "${MINIO_ROOT_USER}",
        "secretKey": "${MINIO_ROOT_PASSWORD}",
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

# Add new Parse Server to docker-compose.yml
cat >> docker-compose.yml << EOL

parse-server-$project_name:
  build: 
    context: .
    dockerfile: Dockerfile-parse
  environment:
    PARSE_SERVER_APPLICATION_ID: $app_id
    PARSE_SERVER_MASTER_KEY: $master_key
    PARSE_SERVER_DATABASE_URI: mongodb://mongo:27017/$project_name
    PARSE_SERVER_URL: http://0.0.0.0:1337/parse
    PARSE_PUBLIC_SERVER_URL: http://parse-$project_name.localhost/parse
    PARSE_SERVER_CLOUD: /parse-server/cloud/main.js
    PARSE_SERVER_MOUNT_PATH: "/parse"
    MINIO_BUCKET_NAME: $project_name
  volumes:
    - ./parse-config-$project_name.json:/parse-server/parse-config.json
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.parse-$project_name.rule=Host(\`parse-$project_name.localhost\`)"
    - "traefik.http.services.parse-$project_name.loadbalancer.server.port=1337"
  networks:
    - web
    - internal
EOL

# Update Parse Dashboard configuration
if command -v jq >/dev/null 2>&1; then
  # Use jq to update the JSON file
  jq --arg url "http://parse-$project_name.localhost/parse" \
     --arg appId "$app_id" \
     --arg masterKey "$master_key" \
     --arg appName "$project_name" \
     '.apps += [{"serverURL": $url, "appId": $appId, "masterKey": $masterKey, "appName": $appName}]' \
     parse-dashboard-config.json > parse-dashboard-config.json.tmp && mv parse-dashboard-config.json.tmp parse-dashboard-config.json
else
  # Fallback method using sed (less robust but doesn't require jq)
  sed -i '' -e '/"apps": \[/a\
  {"serverURL": "http://parse-'"$project_name"'.localhost/parse", "appId": "'"$app_id"'", "masterKey": "'"$master_key"'", "appName": "'"$project_name"'"},
  ' parse-dashboard-config.json
fi

# Create MinIO bucket
docker-compose exec -T minio mc mb minio/$project_name

# Restart the necessary services
docker-compose up -d parse-dashboard parse-server-$project_name

echo "New project '$project_name' has been set up successfully!"
echo "Parse Server URL: http://parse-$project_name.localhost/parse"
echo "App ID: $app_id"
echo "Master Key: $master_key"
echo "You can now use these credentials in your Parse Dashboard to manage this project."

echo "Restarting Parse Dashboard to apply changes..."
docker-compose restart parse-dashboard