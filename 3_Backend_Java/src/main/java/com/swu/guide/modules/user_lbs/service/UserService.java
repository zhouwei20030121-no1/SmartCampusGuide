package com.swu.guide.modules.user_lbs.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.user_lbs.entity.User;

public interface UserService extends IService<User> {

    User login(String account, String password);

    void register(User user);
}
