/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.antika_java.service;

import com.mycompany.antika_java.database.DatabaseManager;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.UUID;

/**
 *
 * @author hp
 */
public class ImageService {
    public void saveItemImage(File sourceImage, int itemId) throws Exception {

        File uploadDir = new File("uploads");
        if (!uploadDir.exists()) uploadDir.mkdir();

        String newName = UUID.randomUUID() + "_" + sourceImage.getName();
        Path target = Path.of("uploads", newName);

        Files.copy(sourceImage.toPath(), target);

        // Save path in DB
        String sql = "UPDATE images SET image_path=? WHERE id=?";

        try (Connection con = DatabaseManager.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, newName);
            ps.setInt(2, itemId);
            ps.executeUpdate();
        }
    }
}
