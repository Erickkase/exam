package com.example.orders.client;

import com.example.orders.dto.UserDTO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.client.HttpClientErrorException;

@Component
@Slf4j
public class UserServiceClient {
    
    private final RestTemplate restTemplate;
    private final String userServiceUrl;
    
    public UserServiceClient(
            RestTemplate restTemplate,
            @Value("${user.service.url}") String userServiceUrl) {
        this.restTemplate = restTemplate;
        this.userServiceUrl = userServiceUrl;
    }
    
    public UserDTO getUserById(Long userId) {
        try {
            String url = userServiceUrl + "/api/users/" + userId;
            log.info("Calling user service: {}", url);
            return restTemplate.getForObject(url, UserDTO.class);
        } catch (HttpClientErrorException.NotFound e) {
            log.error("User not found with id: {}", userId);
            throw new RuntimeException("User not found with id: " + userId);
        } catch (Exception e) {
            log.error("Error calling user service: {}", e.getMessage());
            throw new RuntimeException("Error validating user: " + e.getMessage());
        }
    }
}
