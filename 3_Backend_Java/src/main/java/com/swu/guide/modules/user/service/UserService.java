package com.swu.guide.modules.user.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.user.entity.User;
import com.swu.guide.modules.user.entity.dto.LoginDTO;
import com.swu.guide.modules.user.entity.dto.RegisterDTO;

public interface UserService extends IService<User> {
    String login(LoginDTO loginDTO);

    User register(RegisterDTO dto);
}