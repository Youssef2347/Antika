/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.antika_java;

import com.mycompany.antika_java.database.user_db_logic;
import com.mycompany.antika_java.entity.Item;
import com.mycompany.antika_java.entity.User;
import com.mycompany.antika_java.service.ImageService;
import com.mycompany.antika_java.service.ItemService;
import java.sql.Connection;
import com.mycompany.antika_java.service.BidService;
import com.mycompany.antika_java.database.DatabaseManager;
import java.io.File;
/**
 *
 * @author hp
 */
public class main {
    public static void main(String[] args){
       /* User s_user = new User("salma","salma@gmail.com","password2");
        user_db_logic udl = new user_db_logic();
        if(udl.signUp(s_user)){
            System.out.println("user signed up successfuly");
        }
        else{
            System.out.println("sign up failed");
        }
        User l_user = udl.login("marive", "password");
        if(l_user != null){
            System.out.println("Login successful, Welcome! " + l_user.getusername());
        }
        else{
            System.out.println("Login Failed, check username or password");
        }*/
        /*try {
            int loggedInUserId = 1; // existing user in DB

            // 1️⃣ Create item
            Item item = new Item(
                    loggedInUserId,
                    "Test Antique",
                    "Just for testing"
            );

            ItemService itemService = new ItemService();
            int itemId = itemService.createItem(item);

            System.out.println("Created item with ID: " + itemId);

            // 2️⃣ Attach image
            ImageService imageService = new ImageService();
            File image = new File("C:\\Users\\hp\\Downloads\\test.png");

            imageService.saveItemImage(image, itemId);

            System.out.println("Image attached successfully");

        } catch (Exception e) {
            e.printStackTrace();
        }*/
        try {
            Connection conn = DatabaseManager.getConnection();
            BidService bidService = new BidService(conn);

            int imageId = 2; // the ID of the image to bid on

            // User 2 tries to bid 100
            boolean success1 = bidService.placeBid(3, imageId, 100.0);
            System.out.println("User 2 bid 100: " + (success1 ? "Accepted" : "Rejected"));

            // User 1 tries to bid 90 (should be rejected)
            boolean success2 = bidService.placeBid(1, imageId, 90.0);
            System.out.println("User 1 bid 90: " + (success2 ? "Accepted" : "Rejected"));

            // User 1 bids 150 (should be accepted)
            boolean success3 = bidService.placeBid(1, imageId, 150.0);
            System.out.println("User 1 bid 150: " + (success3 ? "Accepted" : "Rejected"));

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
