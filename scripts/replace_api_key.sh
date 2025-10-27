#!/bin/bash

# Get the API key from the config file
API_KEY=$(grep "googleMapsApiKey" lib/config/app_config.dart | cut -d"'" -f2)

# Replace the placeholder in index.html
sed -i '' "s/GOOGLE_MAPS_API_KEY/$API_KEY/g" web/index.html

echo "API key replaced in index.html" 