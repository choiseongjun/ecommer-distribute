package com.microservices.order.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microservices.order.entity.Order;
import com.microservices.order.repository.OrderRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
public class OrderService {

    @Autowired
    private OrderRepository orderRepository;
    
    @Autowired
    private KafkaTemplate<String, String> kafkaTemplate;
    
    @Autowired
    private ObjectMapper objectMapper;

    private static final String ORDER_TOPIC = "orders";

    @Transactional
    public Order createOrder(Order order) {
        Order savedOrder = orderRepository.save(order);
        publishOrderEvent(savedOrder, "ORDER_CREATED");
        return savedOrder;
    }

    public Optional<Order> getOrderById(Long id) {
        return orderRepository.findById(id);
    }

    public List<Order> getOrdersByUserId(Long userId) {
        return orderRepository.findByUserId(userId);
    }

    public List<Order> getOrdersByStatus(String status) {
        return orderRepository.findByStatus(status);
    }

    @Transactional
    public Order updateOrderStatus(Long id, String status) {
        Order order = orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Order not found"));
        
        order.setStatus(status);
        order.setUpdatedAt(java.time.LocalDateTime.now());
        
        Order updatedOrder = orderRepository.save(order);
        publishOrderEvent(updatedOrder, "ORDER_STATUS_UPDATED");
        return updatedOrder;
    }

    private void publishOrderEvent(Order order, String eventType) {
        try {
            Map<String, Object> event = new HashMap<>();
            event.put("eventType", eventType);
            event.put("orderId", order.getId());
            event.put("userId", order.getUserId());
            event.put("productId", order.getProductId());
            event.put("quantity", order.getQuantity());
            event.put("totalAmount", order.getTotalAmount());
            event.put("status", order.getStatus());
            event.put("timestamp", java.time.LocalDateTime.now().toString());
            
            String eventJson = objectMapper.writeValueAsString(event);
            kafkaTemplate.send(ORDER_TOPIC, eventJson);
        } catch (Exception e) {
            // Log error but don't fail the order creation
            System.err.println("Failed to publish order event: " + e.getMessage());
        }
    }
}
