/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.antika_java.service;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 *
 * @author hp
 */
public class BidService {
    private Connection connection;

    public BidService(Connection connection) {
        this.connection = connection;
    }
    /**
     * Place a bid on an image.
     * @param userId The ID of the user placing the bid
     * @param imageId The ID of the image to bid on
     * @param amount The bid amount
     * @return true if the bid is successful, false otherwise
     * @throws SQLException
     */
    public boolean placeBid(int userId, int imageId, double amount)throws SQLException {
    // check if amount > current highest bid
    // insert new row in bids table
     // 1. Get current highest bid
        String getHighestBidSql = "SELECT MAX(bid_amount) AS highest_bid FROM bids WHERE image_id = ?";
        try (PreparedStatement ps = connection.prepareStatement(getHighestBidSql)) {
            ps.setInt(1, imageId);
            ResultSet rs = ps.executeQuery();
            double highestBid = 0;
            if (rs.next()) {
                highestBid = rs.getDouble("highest_bid");
            }
            // 2. Check if new bid is higher
            if (amount <= highestBid) {
                System.out.println("Bid too low! Current highest bid: " + highestBid);
                return false;
            }
             // 3. Insert new bid
            String insertBidSql = "INSERT INTO bids (image_id, user_id, bid_amount) VALUES (?, ?, ?)";
            try (PreparedStatement ps2 = connection.prepareStatement(insertBidSql)) {
                ps2.setInt(1, imageId);
                ps2.setInt(2, userId);
                ps2.setDouble(3, amount);
                ps2.executeUpdate();
                System.out.println("Bid placed successfully!");
                return true;
            }
        }
    }
}
