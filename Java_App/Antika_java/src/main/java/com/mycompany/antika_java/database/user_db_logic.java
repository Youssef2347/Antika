/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.antika_java.database;

import com.mycompany.antika_java.entity.User;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
/**
 *
 * @author hp
 */
public class user_db_logic {
    private Connection con;
    public user_db_logic() {
        DatabaseManager db = new DatabaseManager();
        con = db.getConnection();
        if (con == null) {
            System.out.println("Database connection failed!");
        }
    }
    //user sign up
   public boolean signUp(User user) {
    if (con == null) {
        System.out.println("Cannot sign up, connection is null!");
        return false;
    }
    try {
        String query = "INSERT INTO users (username, password, email) VALUES (?, ?, ?)";
        PreparedStatement ps = con.prepareStatement(query);
        ps.setString(1, user.getusername());
        ps.setString(2, user.getpassword());
        ps.setString(3, user.getemail());
        ps.executeUpdate();
        return true;
    } catch (SQLException e) {
        e.printStackTrace();
    }
    return false;
   }
   
   //ouser log in
   public User login(String username, String password){
       if(con == null){
            System.out.println("Cannot log in, connection is null!");
            return null;
       }
       try{
           String query = "SELECT * FROM users WHERE username =? AND password =?";
           PreparedStatement ps = con.prepareStatement(query);
           ps.setString(1, username);
           ps.setString(2, password);
           ResultSet rs = ps.executeQuery();
          if(rs.next()){
              //user is indeed found
              return new User(rs.getString("username"),rs.getString("email"),
              rs.getString("password"));
          }
          else{
              return null;
          }
       }
       catch(SQLException e){
           e.printStackTrace();
           return null;
       }
   }
}
