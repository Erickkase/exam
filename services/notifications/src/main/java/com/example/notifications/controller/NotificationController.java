package com.example.notifications.controller;

import com.example.notifications.dto.NotificationRequestDTO;
import com.example.notifications.dto.NotificationResponseDTO;
import com.example.notifications.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {
    
    private final NotificationService notificationService;
    
    // CREATE
    @PostMapping
    public ResponseEntity<NotificationResponseDTO> createNotification(@RequestBody NotificationRequestDTO request) {
        NotificationResponseDTO response = notificationService.createNotification(request);
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }
    
    // READ - Get by ID
    @GetMapping("/{id}")
    public ResponseEntity<NotificationResponseDTO> getNotificationById(@PathVariable Long id) {
        NotificationResponseDTO response = notificationService.getNotificationById(id);
        return ResponseEntity.ok(response);
    }
    
    // READ - Get all
    @GetMapping
    public ResponseEntity<List<NotificationResponseDTO>> getAllNotifications() {
        List<NotificationResponseDTO> response = notificationService.getAllNotifications();
        return ResponseEntity.ok(response);
    }
    
    // UPDATE
    @PutMapping("/{id}")
    public ResponseEntity<NotificationResponseDTO> updateNotification(
            @PathVariable Long id,
            @RequestBody NotificationRequestDTO request) {
        NotificationResponseDTO response = notificationService.updateNotification(id, request);
        return ResponseEntity.ok(response);
    }
    
    // DELETE
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteNotification(@PathVariable Long id) {
        notificationService.deleteNotification(id);
        return ResponseEntity.noContent().build();
    }
}
