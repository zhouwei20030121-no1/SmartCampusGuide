package com.swu.guide.modules.user.entity.dto;

import lombok.Data;

@Data
public class RegisterDTO {
    private String username;
    private String password;
    private String campusId;
    private String phone;
    // 增加 role 字段，接收前端传来的角色信息
    private Integer role; 
}