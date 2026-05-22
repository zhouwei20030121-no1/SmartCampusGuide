package com.swu.guide.modules.route.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.route.entity.RoutePlan;
import com.swu.guide.modules.route.service.RoutePlanService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/route")
public class RoutePlanController {

    private final RoutePlanService routePlanService;

    public RoutePlanController(RoutePlanService routePlanService) {
        this.routePlanService = routePlanService;
    }

    @PostMapping("/plan")
    public Result<RoutePlan> plan(@RequestBody Map<String, Object> params) {
        Long userId = Long.valueOf(params.get("userId").toString());
        String name = params.get("name").toString();
        @SuppressWarnings("unchecked")
        List<Long> spotIds = ((List<Integer>) params.get("spotIds")).stream()
                .map(Long::valueOf).collect(java.util.stream.Collectors.toList());
        return Result.ok(routePlanService.planRoute(userId, name, spotIds));
    }

    @GetMapping("/user/{userId}")
    public Result<List<RoutePlan>> getUserRoutes(@PathVariable Long userId) {
        return Result.ok(routePlanService.getUserRoutes(userId));
    }

    @GetMapping("/{id}")
    public Result<RoutePlan> getById(@PathVariable Long id) {
        return Result.ok(routePlanService.getById(id));
    }
}
