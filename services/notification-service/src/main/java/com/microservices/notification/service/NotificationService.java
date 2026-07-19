package com.microservices.notification.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.microservices.notification.entity.Notification;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

@Service
public class NotificationService {

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    @Autowired
    private JavaMailSender mailSender;
    
    @Autowired
    private ObjectMapper objectMapper;

    private static final String NOTIFICATION_QUEUE = "notifications";
    private static final String NOTIFICATION_HISTORY_PREFIX = "notification:";

    @KafkaListener(topics = "orders", groupId = "notification-service-group")
    public void handleOrderEvent(String eventJson) {
        try {
            Map<String, Object> event = objectMapper.readValue(eventJson, Map.class);
            String eventType = (String) event.get("eventType");
            Long userId = ((Number) event.get("userId")).longValue();
            
            if ("ORDER_CREATED".equals(eventType)) {
                sendNotification(userId, "ORDER", "주문 생성 알림", 
                    "주문이 성공적으로 생성되었습니다. 주문 ID: " + event.get("orderId"));
            } else if ("ORDER_STATUS_UPDATED".equals(eventType)) {
                String status = (String) event.get("status");
                sendNotification(userId, "ORDER", "주문 상태 변경 알림", 
                    "주문 상태가 " + status + "(으)로 변경되었습니다.");
            }
        } catch (Exception e) {
            System.err.println("Failed to process order event: " + e.getMessage());
        }
    }

    public void sendNotification(Long userId, String type, String subject, String message) {
        Notification notification = new Notification(
            userId.toString(), type, subject, message
        );
        
        // Redis에 대기열 추가
        redisTemplate.opsForList().rightPush(NOTIFICATION_QUEUE, notification);
        
        // 알림 처리
        processNotification(notification);
    }

    private void processNotification(Notification notification) {
        try {
            if ("EMAIL".equals(notification.getType()) || "ORDER".equals(notification.getType())) {
                sendEmail(notification);
            }
            
            notification.setStatus("SENT");
            notification.setSentAt(LocalDateTime.now());
            
            // 히스토리 저장
            String historyKey = NOTIFICATION_HISTORY_PREFIX + notification.getRecipient();
            redisTemplate.opsForList().leftPush(historyKey, notification);
            redisTemplate.expire(historyKey, 30, TimeUnit.DAYS);
            
        } catch (Exception e) {
            notification.setStatus("FAILED");
            System.err.println("Failed to send notification: " + e.getMessage());
        }
    }

    private void sendEmail(Notification notification) {
        try {
            String toEmail = notification.getRecipient();
            if (toEmail != null && !toEmail.contains("@")) {
                toEmail = "user_" + toEmail + "@example.com";
            }
            SimpleMailMessage mailMessage = new SimpleMailMessage();
            mailMessage.setTo(toEmail);
            mailMessage.setSubject(notification.getSubject());
            mailMessage.setText(notification.getMessage());
            
            mailSender.send(mailMessage);
        } catch (Throwable e) {
            System.err.println("SMTP server unavailable, skipping email transmission: " + e.getMessage());
        }
    }

    public List<Object> getNotificationHistory(String recipient) {
        String historyKey = NOTIFICATION_HISTORY_PREFIX + recipient;
        Long size = redisTemplate.opsForList().size(historyKey);
        if (size != null && size > 0) {
            return redisTemplate.opsForList().range(historyKey, 0, size - 1);
        }
        return List.of();
    }
}
