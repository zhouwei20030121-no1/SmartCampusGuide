package com.swu.guide.modules.route.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.route.entity.UserRouteHistory;
import com.swu.guide.modules.route.service.UserRouteHistoryService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/route/history")
public class UserRouteHistoryController {

    private final UserRouteHistoryService userRouteHistoryService;

    public UserRouteHistoryController(UserRouteHistoryService userRouteHistoryService) {
        this.userRouteHistoryService = userRouteHistoryService;
    }

    @PostMapping
    public Result<UserRouteHistory> save(@RequestBody UserRouteHistory history) {
        try {
            return Result.ok(userRouteHistoryService.saveHistory(history));
        } catch (IllegalArgumentException ex) {
            return Result.fail(ex.getMessage());
        }
    }

    @GetMapping("/user/{userId}")
    public Result<List<UserRouteHistory>> listByUser(@PathVariable Long userId) {
        return Result.ok(userRouteHistoryService.listByUserId(userId));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        if (userRouteHistoryService.getById(id) == null) {
            return Result.fail("Route history not found");
        }
        userRouteHistoryService.removeById(id);
        return Result.ok();
    }
}
