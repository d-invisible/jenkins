package com.paperlive.practice3;

public final class GreetingService {
    public String greeting(String name) {
        String cleanName = name == null ? "" : name.trim();
        if (cleanName.isEmpty()) {
            cleanName = "Tomcat learner";
        }
        return "Hello, " + cleanName + "! Practice 3 is running on Tomcat.";
    }
}

