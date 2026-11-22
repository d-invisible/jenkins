package com.paperlive.project1;

import org.springframework.stereotype.Service;

@Service
public class GreetingService {
    public String greeting(String name) {
        String cleanName = name == null ? "" : name.trim();
        if (cleanName.isEmpty()) {
            cleanName = "Spring Boot learner";
        }
        return "Hello, " + cleanName + "! Project 1 is running.";
    }
}

