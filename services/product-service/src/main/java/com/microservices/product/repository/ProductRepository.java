package com.microservices.product.repository;

import com.microservices.product.entity.Product;
import org.springframework.data.cassandra.repository.AllowFiltering;
import org.springframework.data.cassandra.repository.CassandraRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ProductRepository extends CassandraRepository<Product, UUID> {
    
    @AllowFiltering
    List<Product> findByCategory(String category);
    
    @AllowFiltering
    List<Product> findByNameContaining(String name);
}
