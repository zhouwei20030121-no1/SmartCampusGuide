package com.swu.guide.modules.user.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.common.utils.JwtUtils;
import com.swu.guide.modules.user.entity.User;
import com.swu.guide.modules.user.entity.dto.LoginDTO;
import com.swu.guide.modules.user.entity.dto.RegisterDTO;
import com.swu.guide.modules.user.mapper.UserMapper;
import com.swu.guide.modules.user.service.UserService;
import org.springframework.stereotype.Service;

@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, User> implements UserService {

    @Override
    public String login(LoginDTO loginDTO) {
        String account = loginDTO.getAccount();
        String password = loginDTO.getPassword();

        LambdaQueryWrapper<User> queryWrapper = new LambdaQueryWrapper<>();
        queryWrapper.eq(User::getUsername, account)
                .or().eq(User::getCampusId, account)
                .or().eq(User::getPhone, account)
                .or().eq(User::getEmail, account);

        User user = this.getOne(queryWrapper);

        if (user == null) {
            throw new RuntimeException("用户不存在");
        }

        if (user.getStatus() != null && user.getStatus() == 1) {
            throw new RuntimeException("账号已被封禁");
        }

        if (!user.getPassword().equals(password)) {
            throw new RuntimeException("密码错误");
        }

        return JwtUtils.generateToken(user.getId(), user.getRole());
    }

    @Override
    public User register(RegisterDTO dto) {
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(User::getUsername, dto.getUsername());
        if (this.count(wrapper) > 0) {
            throw new RuntimeException("该账号已被注册");
        }

        User user = new User();
        user.setUsername(dto.getUsername());
        user.setPassword(dto.getPassword());
        user.setCampusId(dto.getCampusId());
        user.setPhone(dto.getPhone());

        // 【关键修复】：如果前端传了role就用前端的，否则默认设置为 0（普通用户），而非1（管理员）
        user.setRole(dto.getRole() != null ? dto.getRole() : 0);
        user.setStatus(0);

        this.save(user);
        return user;
    }
}