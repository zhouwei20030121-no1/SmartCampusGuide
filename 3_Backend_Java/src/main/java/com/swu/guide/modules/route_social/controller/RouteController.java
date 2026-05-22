package com.swu.guide.modules.route_social.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.route_social.entity.RoutePlan;
import com.swu.guide.modules.route_social.service.RouteService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/route")
@RequiredArgsConstructor
public class RouteController {

    private final RouteService routeService;

    @GetMapping
    public Result<List<RoutePlan>> listByUser(@RequestParam Long userId) {
        return Result.ok(routeService.lambdaQuery()
                .eq(RoutePlan::getUserId, userId).list());
    }

    @PostMapping
    public Result<Void> save(@RequestBody RoutePlan route) {
        routeService.save(route);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        routeService.removeById(id);
        return Result.ok();
    }
}
