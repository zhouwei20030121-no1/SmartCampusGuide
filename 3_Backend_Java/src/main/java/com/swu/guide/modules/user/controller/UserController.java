package com.swu.guide.modules.user.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.user.entity.User;
import com.swu.guide.modules.user.service.UserService;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/user")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/login")
    public Result<Map<String, Object>> login(@RequestBody Map<String, String> params) {
        Map<String, Object> result = userService.login(params.get("username"), params.get("password"));
        return Result.ok(result);
    }

    @PostMapping("/register")
    public Result<User> register(@RequestBody Map<String, String> params) {
        User user = userService.register(
                params.get("username"), params.get("password"),
                params.get("studentId"), params.get("phone"));
        return Result.ok(user);
    }

    @GetMapping("/list")
    public Result<java.util.List<User>> list() {
        return Result.ok(userService.list());
    }

    @GetMapping("/{id}")
    public Result<User> getById(@PathVariable Long id) {
        return Result.ok(userService.getById(id));
    }
}
