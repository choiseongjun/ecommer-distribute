#!/bin/bash

# Setup Script for Microservices Platform

echo "Setting up Microservices Platform..."

# Wait for Cassandra to be ready
echo "Waiting for Cassandra to be ready..."
until docker exec cassandra cqlsh -e "DESCRIBE KEYSPACES" > /dev/null 2>&1; do
    echo "Cassandra is not ready yet. Waiting..."
    sleep 5
done
echo "Cassandra is ready!"

# Setup Cassandra Keyspace and Tables
echo "Setting up Cassandra keyspace and tables..."
docker exec -i cassandra cqlsh < scripts/setup-cassandra.cql
echo "Cassandra setup completed!"

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker exec postgres pg_isready -U admin > /dev/null 2>&1; do
    echo "PostgreSQL is not ready yet. Waiting..."
    sleep 5
done
echo "PostgreSQL is ready!"

# Setup PostgreSQL Database
echo "Setting up PostgreSQL database..."
docker exec -i postgres psql -U admin -d microservices < scripts/setup-database.sql
echo "PostgreSQL setup completed!"

# Create Kafka topics
echo "Creating Kafka topics..."
docker exec kafka kafka-topics --create --if-not-exists --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --topic orders
echo "Kafka topics created!"

echo "Setup completed successfully!"
