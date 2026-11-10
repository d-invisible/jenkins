package com.paperlive.practice;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executors;

public final class App {
    private static final int DEFAULT_PORT = 8080;

    private App() {
    }

    public static void main(String[] args) throws IOException {
        int port = readPort();
        GreetingService greetingService = new GreetingService();
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);

        server.createContext("/", exchange -> {
            if (!"/".equals(exchange.getRequestURI().getPath())) {
                respond(exchange, 404, "Not found\n");
                return;
            }
            String name = queryParameters(exchange).get("name");
            respond(exchange, 200, greetingService.greeting(name) + "\n");
        });
        server.createContext("/health", exchange -> respond(exchange, 200, "UP\n"));
        server.setExecutor(Executors.newCachedThreadPool());
        server.start();

        System.out.printf("practice-1 is listening on http://localhost:%d%n", port);
    }

    private static int readPort() {
        String configuredPort = System.getenv().getOrDefault("PORT", String.valueOf(DEFAULT_PORT));
        try {
            int port = Integer.parseInt(configuredPort);
            if (port < 1 || port > 65_535) {
                throw new IllegalArgumentException("PORT must be between 1 and 65535");
            }
            return port;
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("PORT must be a number", exception);
        }
    }

    private static Map<String, String> queryParameters(HttpExchange exchange) {
        Map<String, String> parameters = new HashMap<>();
        String query = exchange.getRequestURI().getRawQuery();
        if (query == null || query.isBlank()) {
            return parameters;
        }

        for (String pair : query.split("&")) {
            String[] parts = pair.split("=", 2);
            String key = URLDecoder.decode(parts[0], StandardCharsets.UTF_8);
            String value = parts.length == 2
                    ? URLDecoder.decode(parts[1], StandardCharsets.UTF_8)
                    : "";
            parameters.put(key, value);
        }
        return parameters;
    }

    private static void respond(HttpExchange exchange, int status, String response) throws IOException {
        byte[] body = response.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=utf-8");
        exchange.sendResponseHeaders(status, body.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(body);
        }
    }
}

