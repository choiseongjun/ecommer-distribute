package com.microservices.notification.controller;

import com.microservices.notification.entity.Notification;
import com.microservices.notification.service.NotificationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    @Autowired
    private NotificationService notificationService;

    @PostMapping
    public ResponseEntity<String> sendNotification(@RequestBody Map<String, String> request) {
        Long userId = Long.parseLong(request.get("userId"));
        String type = request.get("type");
        String subject = request.get("subject");
        String message = request.get("message");
        
        notificationService.sendNotification(userId, type, subject, message);
        return ResponseEntity.ok("Notification sent successfully");
    }

    @GetMapping("/history/{userId}")
    public ResponseEntity<List<Object>> getNotificationHistory(@PathVariable String userId) {
        List<Object> history = notificationService.getNotificationHistory(userId);
        return ResponseEntity.ok(history);
    }
}
