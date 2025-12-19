/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.antika_java;

import com.mycompany.antika_java.database.user_db_logic;
import com.mycompany.antika_java.entity.User;
/**
 *
 * @author hp
 */
public class main {
    public static void main(String[] args){
        User user = new User("salma","salma@gmail.com","password2");
        user_db_logic udl = new user_db_logic();
        if(udl.signUp(user)){
            System.out.println("user signed up successfuly");
        }
        else{
            System.out.println("sign up failed");
        }
    }
}
