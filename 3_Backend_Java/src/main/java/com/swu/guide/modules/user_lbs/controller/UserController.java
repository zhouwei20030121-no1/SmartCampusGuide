package com.swu.guide.modules.user_lbs.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.user_lbs.entity.User;
import com.swu.guide.modules.user_lbs.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/user")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @PostMapping("/login")
    public Result<User> login(@RequestBody User loginUser) {
        User user = userService.login(loginUser.getPhone(), loginUser.getPassword());
        return Result.ok(user);
    }

    @PostMapping("/register")
    public Result<Void> register(@RequestBody User user) {
        userService.register(user);
        return Result.ok();
    }

    @GetMapping("/{id}")
    public Result<User> getById(@PathVariable Long id) {
        return Result.ok(userService.getById(id));
    }
}
