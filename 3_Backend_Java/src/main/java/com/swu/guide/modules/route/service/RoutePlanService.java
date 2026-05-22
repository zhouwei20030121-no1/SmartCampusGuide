package com.swu.guide.modules.route.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.route.entity.RoutePlan;

public interface RoutePlanService extends IService<RoutePlan> {
    RoutePlan planRoute(Long userId, String name, java.util.List<Long> spotIds);
    java.util.List<RoutePlan> getUserRoutes(Long userId);
}
