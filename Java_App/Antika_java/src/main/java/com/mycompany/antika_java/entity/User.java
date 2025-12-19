/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.antika_java.entity;

/**
 *
 * @author hp
 */
public class User {
    private String username;
    private String email;
    private String password;
    
    //constructor
    public User(String username, String email, String password){
        this.username = username;
        this.email = email;
        this.password = password;
    }
    
    //getters
    public String getusername(){
        return username;
    }
    public String getemail(){
        return email;
    }
    public String getpassword(){
        return password;
    }
}
