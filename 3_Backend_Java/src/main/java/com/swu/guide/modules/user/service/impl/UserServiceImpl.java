package com.swu.guide.modules.user.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.user.entity.User;
import com.swu.guide.modules.user.mapper.UserMapper;
import com.swu.guide.modules.user.service.UserService;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, User> implements UserService {

    @Override
    public Map<String, Object> login(String username, String password) {
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(User::getUsername, username).eq(User::getPassword, password);
        User user = baseMapper.selectOne(wrapper);
        if (user == null) throw new RuntimeException("用户名或密码错误");
        String token = UUID.randomUUID().toString();
        Map<String, Object> result = new HashMap<>();
        result.put("token", token);
        result.put("user", user);
        return result;
    }

    @Override
    public User register(String username, String password, String studentId, String phone) {
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(User::getUsername, username);
        if (baseMapper.selectCount(wrapper) > 0) throw new RuntimeException("用户名已存在");
        User user = new User();
        user.setUsername(username);
        user.setPassword(password);
        user.setStudentId(studentId);
        user.setPhone(phone);
        user.setRole("user");
        baseMapper.insert(user);
        return user;
    }
}
