package com.swu.guide.modules.route.service;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.route.entity.RoutePlan;
import com.swu.guide.modules.spot.entity.Spot;
import java.util.List;

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

    /**
     * A* 算法：计算两点之间的最优路线（支持热度优先）
     */
    List<Spot> calculateOptimalRoute(Long startId, Long endId, boolean isPopularityFirst);
}