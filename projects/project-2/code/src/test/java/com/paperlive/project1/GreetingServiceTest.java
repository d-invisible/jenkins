package com.paperlive.project1;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GreetingServiceTest {
    private final GreetingService greetingService = new GreetingService();

    @Test
    void greetsAProvidedName() {
        assertEquals(
                "Hello, Maya! Project 1 is running.",
                greetingService.greeting("Maya")
        );
    }

    @Test
    void usesADefaultForABlankName() {
        assertEquals(
                "Hello, Spring Boot learner! Project 1 is running.",
                greetingService.greeting("  ")
        );
    }
}

