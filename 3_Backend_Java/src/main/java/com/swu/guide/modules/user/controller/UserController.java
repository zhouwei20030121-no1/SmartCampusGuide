package com.swu.guide.modules.user.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.user.entity.User;
import com.swu.guide.modules.user.entity.dto.LoginDTO;
import com.swu.guide.modules.user.entity.dto.RegisterDTO;
import com.swu.guide.modules.user.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/user")
public class UserController {

    @Autowired
    private UserService userService;

    /**
     * 1. 用户/管理员登录接口
     */
    @PostMapping("/login")
    public Result<String> login(@RequestBody LoginDTO loginDTO) {
        String token = userService.login(loginDTO);
        return Result.ok(token); 
    }

    /**
     * 2. 用户注册接口（对接前端登录页的注册功能，已修复注册成管理员的Bug）
     */
    @PostMapping("/register")
    public Result<String> register(@RequestBody RegisterDTO dto) {
        userService.register(dto);
        return Result.ok("注册成功");
    }

    /**
     * 3. 获取所有用户列表接口（对接后台用户管理表格）
     */
    @GetMapping("/list")
    public Result<List<User>> list() {
        return Result.ok(userService.list());
    }

    /**
     * 4. 新增或更新用户接口（对接后台用户管理弹窗的保存动作）
     */
    @PostMapping("/save")
    public Result<Void> save(@RequestBody User user) {
        // 如果是编辑操作且密码输入框留空，则不覆盖原本的旧密码
        if (user.getId() != null && (user.getPassword() == null || user.getPassword().isEmpty())) {
            User oldUser = userService.getById(user.getId());
            user.setPassword(oldUser.getPassword());
        }
        userService.saveOrUpdate(user);
        return Result.ok();
    }

    /**
     * 5. 删除用户接口（对接后台用户管理表格的删除动作）
     */
    @DeleteMapping("/delete/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        userService.removeById(id);
        return Result.ok();
    }

    /**
     * 6. 获取当前登录的用户信息（对接前端个人中心面板）
     * 前端可以通过传入用户的 id 来获取详情数据
     */
    @GetMapping("/info/{id}")
    public Result<User> getUserInfo(@PathVariable Long id) {
        User user = userService.getById(id);
        if (user != null) {
            // 安全起见，不把密码返回给前端
            user.setPassword(null);
        }
        return Result.ok(user);
    }

    /**
     * 7. 根据账号获取当前登录的用户信息（备用方案）
     * 如果前端在登录后没有保存ID，只保存了输入的账号，可以调用此接口拉取个人面板数据
     */
    @GetMapping("/infoByAccount")
    public Result<User> getInfoByAccount(@RequestParam String account) {
        User user = userService.lambdaQuery()
                .eq(User::getUsername, account)
                .or().eq(User::getCampusId, account)
                .or().eq(User::getPhone, account)
                .one();
        if (user != null) {
            user.setPassword(null); // 脱敏
        }
        return Result.ok(user);
    }
}