#!/bin/bash

# CalCalCal Deployment Script for Hetzner VPS
# This script pulls the latest code and redeploys the Docker containers

set -e  # Exit on any error

echo "🚀 Starting CalCalCal deployment..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "docker-compose.production.yml" ]; then
    echo -e "${RED}❌ Error: docker-compose.production.yml not found${NC}"
    echo "Please run this script from the apps/backend/node directory"
    exit 1
fi

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${RED}❌ Error: .env.production not found${NC}"
    echo "Please create .env.production from .env.production.template"
    exit 1
fi

# Pull latest code from git
echo -e "${YELLOW}📥 Pulling latest code from GitHub...${NC}"
cd ../../..  # Go to repo root
git pull origin main
cd apps/backend/node

# Stop existing API container to avoid image conflicts
echo -e "${YELLOW}🛑 Stopping existing API container...${NC}"
docker-compose -f docker-compose.production.yml stop api || true
docker-compose -f docker-compose.production.yml rm -f api || true

# Build new Docker images
echo -e "${YELLOW}🔨 Building Docker images...${NC}"
docker-compose -f docker-compose.production.yml build --no-cache api

# Run database migrations (before restarting API)
echo -e "${YELLOW}🗄️  Running database migrations...${NC}"
# Ensure postgres is running
docker-compose -f docker-compose.production.yml up -d postgres
sleep 5  # Wait for postgres to be ready

# Run migrations using a temporary container
docker-compose -f docker-compose.production.yml run --rm \
    -e DATABASE_URL="postgresql://calcalcal:NeonGenezisEva02!@postgres:5432/calcalcal_production" \
    api npm run migrate

# Deploy updated containers
echo -e "${YELLOW}🔄 Starting containers...${NC}"
docker-compose -f docker-compose.production.yml up -d

# Wait for health check
echo -e "${YELLOW}⏳ Waiting for API to be healthy...${NC}"
sleep 10

# Check if API is responding
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ API is healthy!${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting for API... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 3
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ API health check failed after $MAX_RETRIES attempts${NC}"
    echo "Check logs with: docker-compose -f docker-compose.production.yml logs api"
    exit 1
fi

# Show running containers
echo -e "${GREEN}🎉 Deployment successful!${NC}"
echo ""
echo "Running containers:"
docker-compose -f docker-compose.production.yml ps

echo ""
echo "To view logs, run:"
echo "  docker-compose -f docker-compose.production.yml logs -f api"
echo ""
echo "To check status:"
echo "  docker-compose -f docker-compose.production.yml ps"
