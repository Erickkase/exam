package com.example.orders.dto;

import com.example.orders.model.Order;
import com.example.orders.model.OrderStatus;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class OrderResponseDTO {
    private Long id;
    private Long userId;
    private BigDecimal total;
    private OrderStatus status;
    private LocalDateTime createdAt;
    
    public static OrderResponseDTO fromEntity(Order order) {
        return new OrderResponseDTO(
            order.getId(),
            order.getUserId(),
            order.getTotal(),
            order.getStatus(),
            order.getCreatedAt()
        );
    }
}
