package com.swu.guide.modules.user.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.user.entity.User;

import java.util.Map;

public interface UserService extends IService<User> {
    Map<String, Object> login(String username, String password);
    User register(String username, String password, String studentId, String phone);
}
