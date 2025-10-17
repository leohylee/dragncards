#!/bin/bash

echo "🚀 Starting DragnCards..."

cd /Users/leo/Projects/dragncards

# Stop any existing containers
echo "Stopping existing containers..."
docker-compose down 2>/dev/null

# Start all services
echo "Starting backend and frontend..."
docker-compose up -d

echo ""
echo "✅ DragnCards is starting!"
echo ""
echo "Services:"
echo "  - Backend:  http://localhost:4000"
echo "  - Frontend: http://localhost:3000 (will take 10-30 minutes on first compile)"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To stop:"
echo "  cd /Users/leo/Projects/dragncards && docker-compose down"
