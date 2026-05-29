package com.swu.guide.modules.route.service;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.route.entity.RoutePlan;

public interface RoutePlanService extends IService<RoutePlan> {

    /**
     * 分页搜索路线
     */
    Page<RoutePlan> searchRoutes(String keyword, int page, int size);

    /**
     * 保存路线（含景点节点）
     */
    void saveWithSpots(RoutePlan routePlan, String spotIds);

    /**
     * 更新路线（含景点节点）
     */
    void updateWithSpots(RoutePlan routePlan, String spotIds);

    /**
     * 获取路线详情（含景点列表）
     */
    RoutePlan getDetailById(Long id);
}
