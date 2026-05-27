package com.swu.guide.modules.user.entity.dto;

import lombok.Data;

@Data
public class LoginDTO {
    private String account;
    private String password;
    private Integer role; // 增加角色控制字段，对接前端的登录选择
}