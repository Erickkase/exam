package com.example.notifications.dto;

import com.example.notifications.model.NotificationType;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class NotificationRequestDTO {
    private Long userId;
    private Long orderId;
    private String message;
    private NotificationType type;
}
