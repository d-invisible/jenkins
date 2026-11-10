package com.paperlive.practice;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GreetingServiceTest {
    private final GreetingService greetingService = new GreetingService();

    @Test
    void greetsAProvidedName() {
        assertEquals(
                "Hello, Maya! Your Java app is running.",
                greetingService.greeting("Maya")
        );
    }

    @Test
    void usesADefaultWhenNameIsMissing() {
        assertEquals(
                "Hello, Jenkins learner! Your Java app is running.",
                greetingService.greeting("  ")
        );
    }
}

