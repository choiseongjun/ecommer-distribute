package com.microservices.gateway.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

import java.util.HashMap;
import java.util.Map;

@RestController
public class FallbackController {

    @RequestMapping("/fallback/users")
    public Mono<Map<String, String>> userFallback() {
        Map<String, String> response = new HashMap<>();
        response.put("service", "user-service");
        response.put("status", "fallback");
        response.put("message", "User service is temporarily unavailable. Please try again later.");
        return Mono.just(response);
    }

    @RequestMapping("/fallback/orders")
    public Mono<Map<String, String>> orderFallback() {
        Map<String, String> response = new HashMap<>();
        response.put("service", "order-service");
        response.put("status", "fallback");
        response.put("message", "Order service is temporarily unavailable. Please try again later.");
        return Mono.just(response);
    }

    @RequestMapping("/fallback/products")
    public Mono<Map<String, String>> productFallback() {
        Map<String, String> response = new HashMap<>();
        response.put("service", "product-service");
        response.put("status", "fallback");
        response.put("message", "Product service is temporarily unavailable. Please try again later.");
        return Mono.just(response);
    }

    @RequestMapping("/fallback/notifications")
    public Mono<Map<String, String>> notificationFallback() {
        Map<String, String> response = new HashMap<>();
        response.put("service", "notification-service");
        response.put("status", "fallback");
        response.put("message", "Notification service is temporarily unavailable. Please try again later.");
        return Mono.just(response);
    }
}
