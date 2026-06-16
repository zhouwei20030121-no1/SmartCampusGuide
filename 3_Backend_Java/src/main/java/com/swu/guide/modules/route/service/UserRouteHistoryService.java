package com.swu.guide.modules.route.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.route.entity.UserRouteHistory;
import com.swu.guide.modules.spot.entity.Spot;

import java.util.List;

public interface UserRouteHistoryService extends IService<UserRouteHistory> {

    UserRouteHistory saveHistory(UserRouteHistory history);

    List<UserRouteHistory> listByUserId(Long userId);

    void recordFromPlan(Long userId, Long startId, Long endId, List<Long> waypoints,
                        String strategy, String userIdentity, List<Spot> plannedSpots);
}
