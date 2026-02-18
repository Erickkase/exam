package com.example.notifications.service;

import com.example.notifications.dto.NotificationRequestDTO;
import com.example.notifications.dto.NotificationResponseDTO;
import com.example.notifications.model.Notification;
import com.example.notifications.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {
    
    private final NotificationRepository notificationRepository;
    
    @Transactional
    public NotificationResponseDTO createNotification(NotificationRequestDTO request) {
        Notification notification = new Notification();
        notification.setUserId(request.getUserId());
        notification.setOrderId(request.getOrderId());
        notification.setMessage(request.getMessage());
        notification.setType(request.getType());
        notification.setIsRead(false);
        
        Notification savedNotification = notificationRepository.save(notification);
        log.info("Notification created with id: {}", savedNotification.getId());
        
        return NotificationResponseDTO.fromEntity(savedNotification);
    }
    
    public NotificationResponseDTO getNotificationById(Long id) {
        Notification notification = notificationRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Notification not found with id " + id));
        return NotificationResponseDTO.fromEntity(notification);
    }
    
    public List<NotificationResponseDTO> getAllNotifications() {
        return notificationRepository.findAll().stream()
            .map(NotificationResponseDTO::fromEntity)
            .collect(Collectors.toList());
    }
    
    @Transactional
    public NotificationResponseDTO updateNotification(Long id, NotificationRequestDTO request) {
        Notification notification = notificationRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Notification not found with id: " + id));
        
        notification.setUserId(request.getUserId());
        notification.setOrderId(request.getOrderId());
        notification.setMessage(request.getMessage());
        notification.setType(request.getType());
        
        Notification updatedNotification = notificationRepository.save(notification);
        return NotificationResponseDTO.fromEntity(updatedNotification);
    }
    
    @Transactional
    public void deleteNotification(Long id) {
        if (!notificationRepository.existsById(id)) {
            throw new RuntimeException("Notification not found with id: " + id);
        }
        notificationRepository.deleteById(id);
    }
}
