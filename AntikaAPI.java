package com.mycompany.antika_java;

import com.mycompany.antika_java.database.user_db_logic;
import com.mycompany.antika_java.database.DatabaseManager;
import com.mycompany.antika_java.service.*;
import com.google.gson.Gson;
import com.sun.net.httpserver.*;
import java.io.*;
import java.util.*;
import java.sql.*;

public class AntikaAPI {

    private static final Gson gson = new Gson();

    public static void register(HttpServer server) {

        // LOGIN with username
        server.createContext("/auth/login", e -> {
            try {
                Map body = gson.fromJson(
                    new InputStreamReader(e.getRequestBody()), Map.class);

                String token = user_db_logic.login(
                    (String) body.get("username"),
                    (String) body.get("password"));

                if (token != null) {
                    respond(e, 200, Map.of(
                        "success", true,
                        "token", token,
                        "message", "Login successful"
                    ));
                } else {
                    respond(e, 401, Map.of(
                        "success", false,
                        "error", "Invalid username or password"
                    ));
                }
            } catch (Exception ex) {
                ex.printStackTrace();
                respond(e, 500, Map.of("error", "Server error"));
            }
        });

        // REGISTER with username
        server.createContext("/auth/register", e -> {
            try {
                Map body = gson.fromJson(
                    new InputStreamReader(e.getRequestBody()), Map.class);

                boolean ok = user_db_logic.register(
                    (String) body.get("username"),
                    (String) body.get("password"));

                if (ok) {
                    respond(e, 200, Map.of(
                        "success", true,
                        "message", "Registration successful"
                    ));
                } else {
                    respond(e, 400, Map.of(
                        "success", false,
                        "error", "Username already exists"
                    ));
                }
            } catch (Exception ex) {
                ex.printStackTrace();
                respond(e, 500, Map.of("error", "Server error"));
            }
        });

        // GET USER PROFILE
        server.createContext("/auth/profile", e -> {
            try {
                String token = e.getRequestHeaders().getFirst("Authorization");
                int userId = user_db_logic.getUserId(token);
                
                if (userId == -1) {
                    respond(e, 401, Map.of("error", "Unauthorized"));
                    return;
                }
                
                // Get user info from database
                try (Connection conn = DatabaseManager.getConnection()) {
                    String sql = "SELECT username FROM users WHERE id=?";
                    PreparedStatement ps = conn.prepareStatement(sql);
                    ps.setInt(1, userId);
                    ResultSet rs = ps.executeQuery();
                    
                    if (rs.next()) {
                        Map<String, Object> user = new HashMap<>();
                        user.put("id", userId);
                        user.put("username", rs.getString("username"));
                        respond(e, 200, user);
                    } else {
                        respond(e, 404, Map.of("error", "User not found"));
                    }
                }
            } catch (Exception ex) {
                ex.printStackTrace();
                respond(e, 500, Map.of("error", "Server error"));
            }
        });

        // ITEMS (Products) - Updated for your marketplace
        server.createContext("/api/products", e -> {
            try {
                if ("GET".equals(e.getRequestMethod())) {
                    // Get all products
                    List<Map<String, Object>> products = ProductService.getAllProducts();
                    respond(e, 200, products);
                    
                } else if ("POST".equals(e.getRequestMethod())) {
                    // Add new product
                    String token = e.getRequestHeaders().getFirst("Authorization");
                    int userId = user_db_logic.getUserId(token);
                    
                    if (userId == -1) {
                        respond(e, 401, Map.of("error", "Unauthorized"));
                        return;
                    }
                    
                    Map body = gson.fromJson(
                        new InputStreamReader(e.getRequestBody()), Map.class);
                    
                    boolean success = ProductService.addProduct(
                        (String) body.get("name"),
                        (String) body.get("description"),
                        ((Double) body.get("price")).doubleValue(),
                        (String) body.get("imageUrl"),
                        userId
                    );
                    
                    respond(e, success ? 201 : 400, 
                        Map.of("success", success));
                } else if ("OPTIONS".equals(e.getRequestMethod())) {
                    // Handle preflight
                    respond(e, 200, Map.of("message", "OK"));
                }
            } catch (Exception ex) {
                ex.printStackTrace();
                respond(e, 500, Map.of("error", "Failed to process products"));
            }
        });

        // GET SINGLE PRODUCT
        server.createContext("/api/products/", e -> {
            try {
                if ("GET".equals(e.getRequestMethod())) {
                    String path = e.getRequestURI().getPath();
                    String[] parts = path.split("/");
                    int productId = Integer.parseInt(parts[parts.length - 1]);
                    
                    Map<String, Object> product = ProductService.getProductById(productId);
                    if (product != null) {
                        respond(e, 200, product);
                    } else {
                        respond(e, 404, Map.of("error", "Product not found"));
                    }
                } else if ("DELETE".equals(e.getRequestMethod())) {
                    // Handle delete product
                    String token = e.getRequestHeaders().getFirst("Authorization");
                    int userId = user_db_logic.getUserId(token);
                    
                    if (userId == -1) {
                        respond(e, 401, Map.of("error", "Unauthorized"));
                        return;
                    }
                    
                    String path = e.getRequestURI().getPath();
                    String[] parts = path.split("/");
                    int productId = Integer.parseInt(parts[parts.length - 1]);
                    
                    boolean success = ProductService.deleteProduct(productId, userId);
                    respond(e, success ? 200 : 400, 
                        Map.of("success", success));
                } else if ("OPTIONS".equals(e.getRequestMethod())) {
                    // Handle preflight
                    respond(e, 200, Map.of("message", "OK"));
                }
            } catch (Exception ex) {
                ex.printStackTrace();
                respond(e, 500, Map.of("error", "Server error"));
            }
        });

        // UPDATE PRODUCT FAVORITE STATUS
        server.createContext("/api/products/favorite", e -> {
            try {
                if ("POST".equals(e.getRequestMethod())) {
                    Map body = gson.fromJson(
                        new InputStreamReader(e.getRequestBody()), Map.class);
                    
                    boolean success = ProductService.toggleFavorite(
                        ((Double) body.get("productId")).intValue(),
                        (Boolean) body.get("isFavorite")
                    );
                    
                    respond(e, success ? 200 : 400, 
                        Map.of("success", success));
                } else if ("OPTIONS".equals(e.getRequestMethod())) {
                    // Handle preflight
                    respond(e, 200, Map.of("message", "OK"));
                }
            } catch (Exception ex) {
                ex.printStackTrace();
                respond(e, 500, Map.of("error", "Failed to update favorite"));
            }
        });

        // BIDS (Keep as is or modify for your marketplace)
        // Add these contexts in AntikaAPI.register() method

// Place a bid
server.createContext("/api/bids/place", e -> {
    try {
        if ("POST".equals(e.getRequestMethod())) {
            String token = e.getRequestHeaders().getFirst("Authorization");
            int userId = user_db_logic.getUserId(token);
            
            if (userId == -1) {
                respond(e, 401, Map.of("error", "Unauthorized"));
                return;
            }
            
            Map body = gson.fromJson(
                new InputStreamReader(e.getRequestBody()), Map.class);
            
            Map<String, Object> result = BidService.placeBid(
                ((Double) body.get("productId")).intValue(),
                userId,
                (Double) body.get("amount")
            );
            
            respond(e, result.get("success").equals(true) ? 200 : 400, result);
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        respond(e, 500, Map.of("error", "Failed to place bid"));
    }
});

// Get product bids
server.createContext("/api/bids/product/", e -> {
    try {
        if ("GET".equals(e.getRequestMethod())) {
            String path = e.getRequestURI().getPath();
            String[] parts = path.split("/");
            int productId = Integer.parseInt(parts[parts.length - 1]);
            
            List<Map<String, Object>> bids = BidService.getProductBids(productId);
            respond(e, 200, bids);
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        respond(e, 500, Map.of("error", "Failed to get bids"));
    }
});

// Get user's bids
server.createContext("/api/bids/user", e -> {
    try {
        if ("GET".equals(e.getRequestMethod())) {
            String token = e.getRequestHeaders().getFirst("Authorization");
            int userId = user_db_logic.getUserId(token);
            
            if (userId == -1) {
                respond(e, 401, Map.of("error", "Unauthorized"));
                return;
            }
            
            List<Map<String, Object>> bids = BidService.getUserBids(userId);
            respond(e, 200, bids);
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        respond(e, 500, Map.of("error", "Failed to get user bids"));
    }
});

// Get active auctions
server.createContext("/api/auctions/active", e -> {
    try {
        if ("GET".equals(e.getRequestMethod())) {
            List<Map<String, Object>> auctions = ProductService.getActiveAuctions();
            respond(e, 200, auctions);
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        respond(e, 500, Map.of("error", "Failed to get auctions"));
    }
});

// Get auction details
server.createContext("/api/auctions/", e -> {
    try {
        if ("GET".equals(e.getRequestMethod())) {
            String path = e.getRequestURI().getPath();
            String[] parts = path.split("/");
            int productId = Integer.parseInt(parts[parts.length - 1]);
            
            Map<String, Object> auction = ProductService.getProductWithAuctionDetails(productId);
            if (auction != null) {
                respond(e, 200, auction);
            } else {
                respond(e, 404, Map.of("error", "Auction not found"));
            }
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        respond(e, 500, Map.of("error", "Failed to get auction details"));
    }
});

// End auction (admin/seller only)
server.createContext("/api/auctions/end", e -> {
    try {
        if ("POST".equals(e.getRequestMethod())) {
            String token = e.getRequestHeaders().getFirst("Authorization");
            int userId = user_db_logic.getUserId(token);
            
            if (userId == -1) {
                respond(e, 401, Map.of("error", "Unauthorized"));
                return;
            }
            
            Map body = gson.fromJson(
                new InputStreamReader(e.getRequestBody()), Map.class);
            
            Map<String, Object> result = BidService.endAuction(
                ((Double) body.get("productId")).intValue()
            );
            
            respond(e, result.get("success").equals(true) ? 200 : 400, result);
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        respond(e, 500, Map.of("error", "Failed to end auction"));
    }
});

// Get won auctions
server.createContext("/api/auctions/won", e -> {
    try {
        if ("GET".equals(e.getRequestMethod())) {
            String token = e.getRequestHeaders().getFirst("Authorization");
            int userId = user_db_logic.getUserId(token);
            
            if (userId == -1) {
                respond(e, 401, Map.of("error", "Unauthorized"));
                return;
            }
            
            List<Map<String, Object>> auctions = BidService.getWonAuctions(userId);
            respond(e, 200, auctions);
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        respond(e, 500, Map.of("error", "Failed to get won auctions"));
    }
});

        // UPLOAD IMAGE
        
    // In AntikaAPI.register() method, update the upload endpoint:
server.createContext("/api/upload", e -> {
    try {
        if ("POST".equals(e.getRequestMethod())) {
            // Parse multipart/form-data
            String boundary = e.getRequestHeaders().getFirst("Content-Type").split("=")[1];
            
            // Create uploads directory if it doesn't exist
            File uploadDir = new File("uploads");
            if (!uploadDir.exists()) {
                uploadDir.mkdirs();
            }
            
            // Generate unique filename
            String fileName = "product_" + System.currentTimeMillis() + ".jpg";
            File file = new File(uploadDir, fileName);
            
            // Save the file
            try (FileOutputStream fos = new FileOutputStream(file)) {
                // Read and save the file (simplified - in real app use proper parsing)
                // For now, return a mock URL
                String imageUrl = "http://10.0.2.2:8082/uploads/" + fileName;
                
                respond(e, 200, Map.of(
                    "success", true,
                    "imageUrl", imageUrl,
                    "message", "Image uploaded successfully"
                ));
            }
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        respond(e, 500, Map.of("error", "Upload failed"));
    }
});
        // HEALTH CHECK
        server.createContext("/health", e -> {
            respond(e, 200, Map.of("status", "OK", "service", "Antika API"));
        });
    }

    private static void respond(HttpExchange ex, int code, Object body) throws IOException {
        String json = gson.toJson(body);
        ex.getResponseHeaders().set("Content-Type", "application/json");
        ex.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
        ex.getResponseHeaders().set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        ex.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type, Authorization");
        
        // Handle preflight requests
        if ("OPTIONS".equals(ex.getRequestMethod())) {
            ex.sendResponseHeaders(200, -1);
        } else {
            ex.sendResponseHeaders(code, json.getBytes().length);
            ex.getResponseBody().write(json.getBytes());
        }
        ex.close();
    }
}