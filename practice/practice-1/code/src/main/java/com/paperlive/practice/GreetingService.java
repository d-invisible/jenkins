package com.paperlive.practice;

public final class GreetingService {
    public String greeting(String name) {
        String cleanName = name == null ? "" : name.trim();
        if (cleanName.isEmpty()) {
            cleanName = "Jenkins learner";
        }
        return "Hello, " + cleanName + "! Your Java app is running.";
    }
}

