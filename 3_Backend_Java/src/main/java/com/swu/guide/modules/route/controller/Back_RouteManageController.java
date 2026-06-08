package com.swu.guide.modules.route.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.route.entity.RoutePlan;
import com.swu.guide.modules.route.service.RoutePlanService;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/route/manage")
public class Back_RouteManageController {

    private final RoutePlanService routePlanService;

    public Back_RouteManageController(RoutePlanService routePlanService) {
        this.routePlanService = routePlanService;
    }

    /** 分页搜索路线 */
    @GetMapping("/list")
    public Result<Page<RoutePlan>> list(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        return Result.ok(routePlanService.searchRoutes(keyword, page, size));
    }

    /** 获取路线详情 */
    @GetMapping("/{id}")
    public Result<RoutePlan> getById(@PathVariable Long id) {
        RoutePlan route = routePlanService.getDetailById(id);
        if (route == null) {
            return Result.fail("路线不存在");
        }
        return Result.ok(route);
    }

    /** 新增路线 */
    @PostMapping
    public Result<RoutePlan> save(@RequestBody RoutePlan route) {
        String spotIds = route.getSpotIds();
        route.setId(null);
        routePlanService.saveWithSpots(route, spotIds);
        return Result.ok(route);
    }

    /** 更新路线 */
    @PutMapping("/{id}")
    public Result<RoutePlan> update(@PathVariable Long id, @RequestBody RoutePlan route) {
        RoutePlan existing = routePlanService.getById(id);
        if (existing == null) {
            return Result.fail("路线不存在");
        }
        String spotIds = route.getSpotIds();
        route.setId(id);
        routePlanService.updateWithSpots(route, spotIds);
        return Result.ok(route);
    }

    /** 删除路线 */
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        routePlanService.removeById(id);
        return Result.ok();
    }

    /** 更新路线状态 */
    @PatchMapping("/{id}/status")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        RoutePlan existing = routePlanService.getById(id);
        if (existing == null) {
            return Result.fail("路线不存在");
        }
        Integer status = (Integer) body.get("status");
        RoutePlan updateRoute = new RoutePlan();
        updateRoute.setId(id);
        updateRoute.setStatus(status);
        routePlanService.updateById(updateRoute);
        return Result.ok();
    }
}
