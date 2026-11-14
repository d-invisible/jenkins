package com.paperlive.practice3;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class GreetingServiceTest {
    private final GreetingService greetingService = new GreetingService();

    @Test
    void greetsAProvidedName() {
        assertEquals(
                "Hello, Maya! Practice 3 is running on Tomcat.",
                greetingService.greeting("Maya")
        );
    }

    @Test
    void usesADefaultWhenNameIsMissing() {
        assertEquals(
                "Hello, Tomcat learner! Practice 3 is running on Tomcat.",
                greetingService.greeting("  ")
        );
    }
}

