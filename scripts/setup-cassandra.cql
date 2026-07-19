-- Cassandra Keyspace and Table Setup for Product Service

-- Create Keyspace
CREATE KEYSPACE IF NOT EXISTS product_keyspace 
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- Use Keyspace
USE product_keyspace;

-- Create Products Table
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY,
    name TEXT,
    description TEXT,
    price DECIMAL,
    stock INT,
    category TEXT,
    created_at TIMESTAMP
);

-- Create Secondary Index for Category
CREATE INDEX IF NOT EXISTS ON products (category);

-- Create Secondary Index for Name (for search)
CREATE INDEX IF NOT EXISTS ON products (name);

-- Insert Sample Data
INSERT INTO products (id, name, description, price, stock, category, created_at)
VALUES (uuid(), 'Laptop', 'High-performance laptop', 1299.99, 50, 'Electronics', toTimestamp(now()));

INSERT INTO products (id, name, description, price, stock, category, created_at)
VALUES (uuid(), 'Smartphone', 'Latest smartphone model', 799.99, 100, 'Electronics', toTimestamp(now()));

INSERT INTO products (id, name, description, price, stock, category, created_at)
VALUES (uuid(), 'Headphones', 'Noise-cancelling headphones', 199.99, 200, 'Electronics', toTimestamp(now()));

INSERT INTO products (id, name, description, price, stock, category, created_at)
VALUES (uuid(), 'T-Shirt', 'Cotton t-shirt', 29.99, 500, 'Clothing', toTimestamp(now()));

INSERT INTO products (id, name, description, price, stock, category, created_at)
VALUES (uuid(), 'Jeans', 'Denim jeans', 59.99, 300, 'Clothing', toTimestamp(now()));
