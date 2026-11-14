package com.paperlive.project1;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class GreetingController {
    private final GreetingService greetingService;

    public GreetingController(GreetingService greetingService) {
        this.greetingService = greetingService;
    }

    @GetMapping("/")
    public Map<String, String> home() {
        return Map.of(
                "application", "project-1",
                "message", "Spring Boot CI/CD practice app"
        );
    }

    @GetMapping("/api/hello")
    public Map<String, String> hello(@RequestParam(required = false) String name) {
        return Map.of("message", greetingService.greeting(name));
    }
}

