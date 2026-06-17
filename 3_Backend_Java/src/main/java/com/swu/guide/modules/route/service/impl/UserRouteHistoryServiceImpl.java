package com.swu.guide.modules.route.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.route.entity.UserRouteHistory;
import com.swu.guide.modules.route.mapper.UserRouteHistoryMapper;
import com.swu.guide.modules.route.service.UserRouteHistoryService;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class UserRouteHistoryServiceImpl
        extends ServiceImpl<UserRouteHistoryMapper, UserRouteHistory>
        implements UserRouteHistoryService {

    private static final double WALK_SPEED_MPS = 1.2;

    private final SpotService spotService;

    public UserRouteHistoryServiceImpl(SpotService spotService) {
        this.spotService = spotService;
    }

    @Override
    public UserRouteHistory saveHistory(UserRouteHistory history) {
        if (history.getUserId() == null) {
            throw new IllegalArgumentException("userId is required");
        }
        if (history.getStartSpotId() == null || history.getEndSpotId() == null) {
            throw new IllegalArgumentException("startSpotId and endSpotId are required");
        }
        if (!StringUtils.hasText(history.getStartSpotName()) || !StringUtils.hasText(history.getEndSpotName())) {
            throw new IllegalArgumentException("startSpotName and endSpotName are required");
        }

        history.setId(null);
        if (!StringUtils.hasText(history.getStrategy())) {
            history.setStrategy("DISTANCE");
        }
        if (!StringUtils.hasText(history.getUserIdentity())) {
            history.setUserIdentity("TOURIST");
        }
        if (history.getDistanceMeters() == null) {
            history.setDistanceMeters(0);
        }
        if (history.getDurationMinutes() == null) {
            history.setDurationMinutes(0);
        }
        if (!StringUtils.hasText(history.getRouteSummary())) {
            history.setRouteSummary(buildSummary(history));
        }

        this.save(history);
        return history;
    }

    @Override
    public List<UserRouteHistory> listByUserId(Long userId) {
        return this.list(new LambdaQueryWrapper<UserRouteHistory>()
                .eq(UserRouteHistory::getUserId, userId)
                .orderByDesc(UserRouteHistory::getCreateTime)
                .last("LIMIT 100"));
    }

    @Override
    public void recordFromPlan(Long userId, Long startId, Long endId, List<Long> waypoints,
                               String strategy, String userIdentity, List<Spot> plannedSpots) {
        if (userId == null || startId == null || endId == null) {
            return;
        }

        Spot startSpot = spotService.getById(startId);
        Spot endSpot = spotService.getById(endId);
        if (startSpot == null || endSpot == null) {
            return;
        }

        List<Long> waypointIds = waypoints == null ? List.of() : waypoints;
        List<String> waypointNames = new ArrayList<>();
        for (Long waypointId : waypointIds) {
            Spot waypoint = spotService.getById(waypointId);
            if (waypoint != null) {
                waypointNames.add(waypoint.getName());
            }
        }

        int distanceMeters = estimateDistanceMeters(plannedSpots);
        int durationMinutes = Math.max(1, (int) Math.ceil(distanceMeters / (WALK_SPEED_MPS * 60)));

        UserRouteHistory history = new UserRouteHistory();
        history.setUserId(userId);
        history.setStartSpotId(startId);
        history.setEndSpotId(endId);
        history.setStartSpotName(startSpot.getName());
        history.setEndSpotName(endSpot.getName());
        history.setWaypointIds(waypointIds.stream().map(String::valueOf).collect(Collectors.joining(",")));
        history.setWaypointNames(String.join(",", waypointNames));
        history.setStrategy(StringUtils.hasText(strategy) ? strategy : "DISTANCE");
        history.setUserIdentity(StringUtils.hasText(userIdentity) ? userIdentity : "TOURIST");
        history.setDistanceMeters(distanceMeters);
        history.setDurationMinutes(durationMinutes);
        saveHistory(history);
    }

    private int estimateDistanceMeters(List<Spot> spots) {
        if (spots == null || spots.size() < 2) {
            return 0;
        }

        double total = 0;
        for (int i = 0; i < spots.size() - 1; i++) {
            Spot s1 = spots.get(i);
            Spot s2 = spots.get(i + 1);
            if (s1.getLatitude() == null || s1.getLongitude() == null
                    || s2.getLatitude() == null || s2.getLongitude() == null) {
                continue;
            }
            total += haversineMeters(
                    s1.getLatitude().doubleValue(), s1.getLongitude().doubleValue(),
                    s2.getLatitude().doubleValue(), s2.getLongitude().doubleValue()
            );
        }
        return (int) Math.round(total);
    }

    private double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
        double earthRadius = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadius * c;
    }

    private String buildSummary(UserRouteHistory history) {
        StringBuilder summary = new StringBuilder();
        summary.append(history.getStartSpotName()).append(" → ");
        if (StringUtils.hasText(history.getWaypointNames())) {
            summary.append(history.getWaypointNames()).append(" → ");
        }
        summary.append(history.getEndSpotName());
        return summary.toString();
    }
}
