-- PostgreSQL Database Setup for User and Order Services

-- Create Users Table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Orders Table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Create Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

-- Insert Sample User Data
INSERT INTO users (email, password, name) VALUES
('user1@example.com', 'password123', 'John Doe'),
('user2@example.com', 'password123', 'Jane Smith'),
('user3@example.com', 'password123', 'Bob Johnson');

-- Insert Sample Order Data
INSERT INTO orders (user_id, product_id, quantity, status, total_amount) VALUES
(1, 1, 2, 'COMPLETED', 2599.98),
(1, 2, 1, 'PENDING', 799.99),
(2, 3, 3, 'COMPLETED', 599.97);
