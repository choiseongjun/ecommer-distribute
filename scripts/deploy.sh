#!/bin/bash

# Deploy Script for Microservices Platform

echo "Deploying Microservices Platform..."

# Build all services
echo "Building all services..."
cd services/api-gateway && mvn clean package -DskipTests && cd ../..
cd services/user-service && mvn clean package -DskipTests && cd ../..
cd services/order-service && mvn clean package -DskipTests && cd ../..
cd services/product-service && mvn clean package -DskipTests && cd ../..
cd services/notification-service && mvn clean package -DskipTests && cd ../..
echo "Build completed!"

# Start infrastructure
echo "Starting infrastructure..."
docker-compose up -d consul postgres cassandra redis zookeeper kafka elasticsearch prometheus grafana jaeger
echo "Infrastructure started!"

# Wait for infrastructure to be ready
echo "Waiting for infrastructure to be ready..."
sleep 30

# Setup databases
echo "Setting up databases..."
bash scripts/setup.sh
echo "Databases setup completed!"

# Start microservices
echo "Starting microservices..."
docker-compose up -d
echo "Microservices started!"

echo "Deployment completed successfully!"
echo "Access the services:"
echo "- API Gateway: http://localhost:8080"
echo "- Consul: http://localhost:8500"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3000 (admin/admin)"
echo "- Jaeger: http://localhost:16686"
