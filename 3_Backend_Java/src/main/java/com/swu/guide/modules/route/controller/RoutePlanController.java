package com.swu.guide.modules.route.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.route.entity.RoutePlan;
import com.swu.guide.modules.route.service.RoutePlanService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/route/plan")
public class RoutePlanController {

    private final RoutePlanService routePlanService;

    public RoutePlanController(RoutePlanService routePlanService) {
        this.routePlanService = routePlanService;
    }

    /**
     * 分页搜索路线
     */
    @GetMapping("/list")
    public Result<Page<RoutePlan>> list(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        return Result.ok(routePlanService.searchRoutes(keyword, page, size));
    }

    /**
     * 获取路线详情（含景点列表）
     */
    @GetMapping("/{id}")
    public Result<RoutePlan> getById(@PathVariable Long id) {
        RoutePlan routePlan = routePlanService.getDetailById(id);
        if (routePlan == null) {
            return Result.fail("路线不存在");
        }
        return Result.ok(routePlan);
    }

    /**
     * 新增路线
     */
    @PostMapping
    public Result<RoutePlan> save(@RequestBody RoutePlan routePlan) {
        String spotIds = routePlan.getSpotIds();
        routePlan.setId(null);
        routePlanService.saveWithSpots(routePlan, spotIds);
        return Result.ok(routePlan);
    }

    /**
     * 更新路线
     */
    @PutMapping("/{id}")
    public Result<RoutePlan> update(@PathVariable Long id, @RequestBody RoutePlan routePlan) {
        RoutePlan existing = routePlanService.getById(id);
        if (existing == null) {
            return Result.fail("路线不存在");
        }
        String spotIds = routePlan.getSpotIds();
        routePlan.setId(id);
        routePlanService.updateWithSpots(routePlan, spotIds);
        return Result.ok(routePlan);
    }

    /**
     * 删除路线（逻辑删除）
     */
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        routePlanService.removeById(id);
        return Result.ok();
    }

    /**
     * 更新路线状态
     */
    @PatchMapping("/{id}/status")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestBody RoutePlan routePlan) {
        RoutePlan existing = routePlanService.getById(id);
        if (existing == null) {
            return Result.fail("路线不存在");
        }
        RoutePlan updatePlan = new RoutePlan();
        updatePlan.setId(id);
        updatePlan.setStatus(routePlan.getStatus());
        routePlanService.updateById(updatePlan);
        return Result.ok();
    }
}
