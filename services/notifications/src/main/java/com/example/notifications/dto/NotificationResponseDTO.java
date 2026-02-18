package com.example.notifications.dto;

import com.example.notifications.model.Notification;
import com.example.notifications.model.NotificationType;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class NotificationResponseDTO {
    private Long id;
    private Long userId;
    private Long orderId;
    private String message;
    private NotificationType type;
    private Boolean isRead;
    private LocalDateTime createdAt;
    
    public static NotificationResponseDTO fromEntity(Notification notification) {
        return new NotificationResponseDTO(
            notification.getId(),
            notification.getUserId(),
            notification.getOrderId(),
            notification.getMessage(),
            notification.getType(),
            notification.getIsRead(),
            notification.getCreatedAt()
        );
    }
}
