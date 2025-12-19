/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.antika_java.entity;

/**
 *
 * @author hp
 */
public class Item {
    private int id;
    private int user_id;
    private String name;
    private String description;
    private String imagepath;
    
    //constructor
    public Item(int user_id,String name, String description){
        this.user_id = user_id;
        this.name = name;
        this.description = description;
    }
    //empty constructor
    public Item(){};
    
    //getters and setters
     public int getid() {
        return id;
    }
     
     public int getUserId() {
        return user_id;
    }

    public String getname() {
        return name;
    }

    public void setname(String name) {
        this.name = name;
    }

    public String getdescription() {
        return description;
    }

    public void setdescription(String description) {
        this.description = description;
    }

    public String getimagePath() {
        return imagepath;
    }

    public void setimagePath(String imagepath) {
        this.imagepath = imagepath;
    }

    public void setId(int aInt) {
        throw new UnsupportedOperationException("Not supported yet."); // Generated from nbfs://nbhost/SystemFileSystem/Templates/Classes/Code/GeneratedMethodBody
    }

    public void setUserId(int aInt) {
        throw new UnsupportedOperationException("Not supported yet."); // Generated from nbfs://nbhost/SystemFileSystem/Templates/Classes/Code/GeneratedMethodBody
    }
}
