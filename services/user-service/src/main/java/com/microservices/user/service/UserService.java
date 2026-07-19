package com.microservices.user.service;

import com.microservices.user.entity.User;
import com.microservices.user.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.List;
import java.util.Optional;

@Service
public class UserService {

    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    private static final String USER_CACHE_PREFIX = "user:";
    private static final Duration CACHE_TTL = Duration.ofMinutes(30);

    public User createUser(User user) {
        User savedUser = userRepository.save(user);
        cacheUser(savedUser);
        return savedUser;
    }

    public Optional<User> getUserById(Long id) {
        String cacheKey = USER_CACHE_PREFIX + id;
        User cachedUser = (User) redisTemplate.opsForValue().get(cacheKey);
        
        if (cachedUser != null) {
            return Optional.of(cachedUser);
        }
        
        Optional<User> user = userRepository.findById(id);
        user.ifPresent(this::cacheUser);
        return user;
    }

    public Optional<User> getUserByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    public User updateUser(Long id, User userDetails) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        user.setEmail(userDetails.getEmail());
        user.setName(userDetails.getName());
        if (userDetails.getPassword() != null) {
            user.setPassword(userDetails.getPassword());
        }
        user.setUpdatedAt(java.time.LocalDateTime.now());
        
        User updatedUser = userRepository.save(user);
        cacheUser(updatedUser);
        return updatedUser;
    }

    public void deleteUser(Long id) {
        userRepository.deleteById(id);
        redisTemplate.delete(USER_CACHE_PREFIX + id);
    }

    private void cacheUser(User user) {
        String cacheKey = USER_CACHE_PREFIX + user.getId();
        redisTemplate.opsForValue().set(cacheKey, user, CACHE_TTL);
    }
}
