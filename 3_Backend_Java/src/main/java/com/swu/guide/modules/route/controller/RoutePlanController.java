package com.swu.guide.modules.route.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.route.entity.RoutePlan;
import com.swu.guide.modules.route.service.RoutePlanService;
import com.swu.guide.modules.spot.entity.Spot;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/route")
public class RoutePlanController {

    private final RoutePlanService routePlanService;

    public RoutePlanController(RoutePlanService routePlanService) {
        this.routePlanService = routePlanService;
    }

    @GetMapping("/plan/list")
    public Result<Page<RoutePlan>> list(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        return Result.ok(routePlanService.searchRoutes(keyword, page, size));
    }

    @GetMapping("/plan/{id}")
    public Result<RoutePlan> getById(@PathVariable Long id) {
        RoutePlan routePlan = routePlanService.getDetailById(id);
        if (routePlan == null) {
            return Result.fail("Route plan not found");
        }
        return Result.ok(routePlan);
    }

    @PostMapping("/plan")
    public Result<RoutePlan> save(@RequestBody RoutePlan routePlan) {
        routePlan.setId(null);
        routePlanService.saveWithSpots(routePlan, routePlan.getSpotIds());
        return Result.ok(routePlanService.getDetailById(routePlan.getId()));
    }

    @PutMapping("/plan/{id}")
    public Result<RoutePlan> update(@PathVariable Long id, @RequestBody RoutePlan routePlan) {
        if (routePlanService.getById(id) == null) {
            return Result.fail("Route plan not found");
        }

        routePlan.setId(id);
        routePlanService.updateWithSpots(routePlan, routePlan.getSpotIds());
        return Result.ok(routePlanService.getDetailById(id));
    }

    @PatchMapping("/plan/{id}/status")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestBody RoutePlan routePlan) {
        if (routePlanService.getById(id) == null) {
            return Result.fail("Route plan not found");
        }
        if (routePlan.getStatus() == null) {
            return Result.fail("Status is required");
        }

        RoutePlan update = new RoutePlan();
        update.setId(id);
        update.setStatus(routePlan.getStatus());
        routePlanService.updateById(update);
        return Result.ok();
    }

    @DeleteMapping("/plan/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        if (routePlanService.getById(id) == null) {
            return Result.fail("Route plan not found");
        }

        routePlanService.removeById(id);
        return Result.ok();
    }

    @GetMapping("/plan/optimal")
    public Result<List<Spot>> getOptimalRoute(
            @RequestParam("startId") Long startId,
            @RequestParam("endId") Long endId,
            @RequestParam(value = "isPopularityFirst", defaultValue = "false") Boolean isPopularityFirst) {

        List<Spot> optimalPath = routePlanService.calculateOptimalRoute(startId, endId, isPopularityFirst);

        if (optimalPath == null || optimalPath.isEmpty()) {
            return Result.fail("Unable to plan a route");
        }

        return Result.ok(optimalPath);
    }
}
