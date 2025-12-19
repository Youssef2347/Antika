/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.antika_java.service;
import com.mycompany.antika_java.database.DatabaseManager;
import com.mycompany.antika_java.entity.Item;

import java.sql.*;
/**
 *
 * @author hp
 */
public class ItemService {
     public int createItem(Item item) {

        String sql = """
            INSERT INTO images (user_id, name, description)
            VALUES (?, ?, ?)
        """;

        try (Connection con = DatabaseManager.getConnection();
             PreparedStatement ps =
                     con.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {

            ps.setInt(1, item.getUserId());
            ps.setString(2, item.getname());
            ps.setString(3, item.getdescription());

            ps.executeUpdate();

            ResultSet rs = ps.getGeneratedKeys();
            if (rs.next()) {
                return rs.getInt(1); // item_id
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
        return -1;
    }
}
