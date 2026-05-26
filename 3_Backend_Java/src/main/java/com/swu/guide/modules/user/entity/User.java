package com.swu.guide.modules.user.entity;

import com.baomidou.mybatisplus.annotation.FieldStrategy;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("sys_user")
public class User {

    @TableId(type = IdType.AUTO)
    private Long id;
    private String username;
    private String realName;
    private String campusId;
    private String password;
    private String phone;
    private String email;
    
    /**
     * 角色: 0普通用户, 1系统管理员, 2内容运营人员
     */
    private Integer role;
    private String preferences;
    
    /**
     * 账号状态: 0正常, 1禁用/封禁
     */
    private Integer status;

    /**
     * 注册时间：禁止插入时拼接，完全交给数据库生成
     */
    @TableField(value = "created_at", insertStrategy = FieldStrategy.NEVER)
    private LocalDateTime createdAt;
}