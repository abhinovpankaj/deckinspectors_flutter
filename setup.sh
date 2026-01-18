#!/bin/bash

# Couchbase Lite & Sync Gateway Quick Start Script
# This script sets up the development environment for testing

set -e

echo "================================================"
echo "Couchbase Lite Migration - Quick Start Setup"
echo "================================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

echo "✅ Docker and Docker Compose found"
echo ""

# Function to wait for service
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0

    echo "⏳ Waiting for $service_name to be ready..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done

    echo "❌ $service_name failed to start"
    return 1
}

# Start Docker containers
echo "🚀 Starting Docker containers..."
docker-compose up -d

# Wait for services to be ready
wait_for_service "http://localhost:8091/ui/index.html" "Couchbase Server"
wait_for_service "http://localhost:4984/" "Sync Gateway"

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "📍 Service URLs:"
echo "   Couchbase Admin:  http://localhost:8091"
echo "   Sync Gateway API: http://localhost:4984"
echo "   Sync Gateway Admin: http://localhost:4985"
echo ""
echo "🔑 Default Credentials:"
echo "   Username: admin"
echo "   Password: admin_password"
echo ""
echo "📱 Flutter App Configuration:"
echo "   syncGatewayUrl: http://localhost:4984"
echo "   (Update in assets/config/couchbaseConfig.json for production)"
echo ""
echo "📚 Next Steps:"
echo "   1. Create bucket 'inspection_db' in Couchbase Admin"
echo "   2. Update assets/config/couchbaseConfig.json"
echo "   3. Run: flutter pub get"
echo "   4. Run: flutter run"
echo ""
echo "🛑 To stop services:"
echo "   docker-compose down"
echo ""
echo "📖 For more information:"
echo "   See COUCHBASE_MIGRATION_GUIDE.md"
echo ""
