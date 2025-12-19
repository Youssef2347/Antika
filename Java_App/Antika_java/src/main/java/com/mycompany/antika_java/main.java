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
        User s_user = new User("salma","salma@gmail.com","password2");
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
        }
    }
}
