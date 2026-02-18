package com.example.orders.service;

import com.example.orders.client.UserServiceClient;
import com.example.orders.dto.OrderRequestDTO;
import com.example.orders.dto.OrderResponseDTO;
import com.example.orders.dto.UserDTO;
import com.example.orders.model.Order;
import com.example.orders.model.OrderStatus;
import com.example.orders.repository.OrderRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {
    
    private final OrderRepository orderRepository;
    private final UserServiceClient userServiceClient;
    
    @Transactional
    public OrderResponseDTO createOrder(OrderRequestDTO request) {
        // Validate user exists
        log.info("Validating user with id: {}", request.getUserId());
        UserDTO user = userServiceClient.getUserById(request.getUserId());
        log.info("User validated: {}", user.getEmail());
        
        // Create order
        Order order = new Order();
        order.setUserId(request.getUserId());
        order.setTotal(request.getTotal());
        order.setStatus(OrderStatus.PENDING);
        
        Order savedOrder = orderRepository.save(order);
        log.info("Order created with id: {}", savedOrder.getId());
        
        return OrderResponseDTO.fromEntity(savedOrder);
    }
    
    public OrderResponseDTO getOrderById(Long id) {
        Order order = orderRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Order not found with id " + id));
        return OrderResponseDTO.fromEntity(order);
    }
    
    public List<OrderResponseDTO> getAllOrders() {
        return orderRepository.findAll().stream()
            .map(OrderResponseDTO::fromEntity)
            .collect(Collectors.toList());
    }
    
    @Transactional
    public OrderResponseDTO updateOrder(Long id, OrderRequestDTO request) {
        Order order = orderRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Order not found with id: " + id));
        
        // Validate user exists
        UserDTO user = userServiceClient.getUserById(request.getUserId());
        
        order.setUserId(request.getUserId());
        order.setTotal(request.getTotal());
        
        Order updatedOrder = orderRepository.save(order);
        return OrderResponseDTO.fromEntity(updatedOrder);
    }
    
    @Transactional
    public void deleteOrder(Long id) {
        if (!orderRepository.existsById(id)) {
            throw new RuntimeException("Order not found with id: " + id);
        }
        orderRepository.deleteById(id);
    }
}
