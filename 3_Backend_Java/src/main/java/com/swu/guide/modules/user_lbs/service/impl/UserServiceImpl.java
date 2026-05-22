package com.swu.guide.modules.user_lbs.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.user_lbs.entity.User;
import com.swu.guide.modules.user_lbs.mapper.UserMapper;
import com.swu.guide.modules.user_lbs.service.UserService;
import org.springframework.stereotype.Service;

@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, User> implements UserService {

    @Override
    public User login(String account, String password) {
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(User::getPhone, account)
               .or()
               .eq(User::getUsername, account);
        User user = getOne(wrapper);
        if (user == null || !user.getPassword().equals(password)) {
            throw new RuntimeException("账号或密码错误");
        }
        return user;
    }

    @Override
    public void register(User user) {
        long count = count(new LambdaQueryWrapper<User>()
                .eq(User::getPhone, user.getPhone()));
        if (count > 0) {
            throw new RuntimeException("该手机号已注册");
        }
        save(user);
    }
}
