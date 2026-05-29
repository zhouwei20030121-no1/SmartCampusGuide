package com.swu.guide.modules.route.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.common.utils.AmapUtil;
import com.swu.guide.modules.route.entity.RoutePlan;
import com.swu.guide.modules.route.entity.RouteSpotNode;
import com.swu.guide.modules.route.mapper.RoutePlanMapper;
import com.swu.guide.modules.route.mapper.RouteSpotNodeMapper;
import com.swu.guide.modules.route.service.RoutePlanService;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Service
public class RoutePlanServiceImpl
        extends ServiceImpl<RoutePlanMapper, RoutePlan>
        implements RoutePlanService {

    /** 步行速度：米/分钟（Haversine备用方案使用） */
    private static final double WALK_SPEED = 80.0;
    /** 每个景点停留时间：分钟 */
    private static final int STAY_TIME_PER_SPOT = 10;
    /** 地球半径：米 */
    private static final double EARTH_RADIUS = 6371000.0;

    private final RouteSpotNodeMapper nodeMapper;
    private final SpotService spotService;
    private final AmapUtil amapUtil;

    public RoutePlanServiceImpl(RouteSpotNodeMapper nodeMapper,
                                SpotService spotService,
                                AmapUtil amapUtil) {
        this.nodeMapper = nodeMapper;
        this.spotService = spotService;
        this.amapUtil = amapUtil;
    }

    @Override
    public Page<RoutePlan> searchRoutes(String keyword, int page, int size) {
        LambdaQueryWrapper<RoutePlan> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(keyword)) {
            wrapper.like(RoutePlan::getRouteName, keyword);
        }
        wrapper.orderByDesc(RoutePlan::getId);
        Page<RoutePlan> result = this.page(new Page<>(page, size), wrapper);

        for (RoutePlan routePlan : result.getRecords()) {
            fillSpotInfo(routePlan);
        }
        return result;
    }

    @Override
    @Transactional
    public void saveWithSpots(RoutePlan routePlan, String spotIds) {
        int estimatedTime = calculateEstimatedTime(spotIds);
        routePlan.setEstimatedTime(estimatedTime);

        this.save(routePlan);
        saveSpotNodes(routePlan.getId(), spotIds);

        // 打印缓存统计
        System.out.println("📊 " + amapUtil.getCacheStats());
    }

    @Override
    @Transactional
    public void updateWithSpots(RoutePlan routePlan, String spotIds) {
        int estimatedTime = calculateEstimatedTime(spotIds);
        routePlan.setEstimatedTime(estimatedTime);

        this.updateById(routePlan);

        // 删除旧节点
        LambdaQueryWrapper<RouteSpotNode> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(RouteSpotNode::getRouteId, routePlan.getId());
        nodeMapper.delete(wrapper);

        // 保存新节点
        saveSpotNodes(routePlan.getId(), spotIds);

        // 打印缓存统计
        System.out.println("📊 " + amapUtil.getCacheStats());
    }

    @Override
    public RoutePlan getDetailById(Long id) {
        RoutePlan routePlan = this.getById(id);
        if (routePlan != null) {
            fillSpotInfo(routePlan);
        }
        return routePlan;
    }

    /**
     * 保存景点节点
     */
    private void saveSpotNodes(Long routeId, String spotIds) {
        if (!StringUtils.hasText(spotIds)) return;

        String[] ids = spotIds.split(",");
        for (int i = 0; i < ids.length; i++) {
            String idStr = ids[i].trim();
            if (!StringUtils.hasText(idStr)) continue;

            RouteSpotNode node = new RouteSpotNode();
            node.setRouteId(routeId);
            node.setSpotId(Long.parseLong(idStr));
            node.setSortOrder(i + 1);
            nodeMapper.insert(node);
        }
    }

    /**
     * 填充路线的景点信息
     */
    private void fillSpotInfo(RoutePlan routePlan) {
        LambdaQueryWrapper<RouteSpotNode> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(RouteSpotNode::getRouteId, routePlan.getId())
                .orderByAsc(RouteSpotNode::getSortOrder);
        List<RouteSpotNode> nodes = nodeMapper.selectList(wrapper);

        for (RouteSpotNode node : nodes) {
            Spot spot = spotService.getById(node.getSpotId());
            if (spot != null) {
                node.setSpotName(spot.getName());
                node.setSpotCategory(spot.getCategory());
                node.setSpotDescription(spot.getDescription());
                node.setSpotCoverImage(spot.getCoverImage());
            }
        }

        routePlan.setSpots(nodes);

        StringBuilder sb = new StringBuilder();
        for (RouteSpotNode node : nodes) {
            if (sb.length() > 0) sb.append(",");
            sb.append(node.getSpotId());
        }
        routePlan.setSpotIds(sb.toString());
    }

    /**
     * 根据景点ID列表计算预计耗时（仅在保存时调用一次）
     * 优先使用高德API（带缓存），失败降级为Haversine公式
     */
    private int calculateEstimatedTime(String spotIds) {
        if (!StringUtils.hasText(spotIds)) return 0;

        String[] ids = spotIds.split(",");
        List<Spot> spots = new ArrayList<>();
        for (String id : ids) {
            String idStr = id.trim();
            if (!StringUtils.hasText(idStr)) continue;
            Spot spot = spotService.getById(Long.parseLong(idStr));
            if (spot != null) spots.add(spot);
        }

        if (spots.isEmpty()) return 0;
        if (spots.size() == 1) return STAY_TIME_PER_SPOT;

        // 优先使用高德API（带缓存）
        Integer amapTime = calculateByAmap(spots);
        if (amapTime != null) {
            System.out.println("✅ 路线耗时计算完成(高德API): " + amapTime + " 分钟");
            return amapTime;
        }

        // 降级为Haversine公式
        int haversineTime = calculateByHaversine(spots);
        System.out.println("✅ 路线耗时计算完成(Haversine): " + haversineTime + " 分钟");
        return haversineTime;
    }

    /**
     * 使用高德API计算总耗时（带缓存）
     * 同一段路径24小时内不重复请求API
     * 返回总分钟数，失败返回null
     */
    private Integer calculateByAmap(List<Spot> spots) {
        // 检查高德Key是否配置
        if (!amapUtil.isConfigured()) {
            System.out.println("⚠️ 高德Key未配置，跳过API调用");
            return null;
        }

        try {
            double totalWalkSeconds = 0;
            int segmentCount = 0;
            int cacheHits = 0;

            for (int i = 0; i < spots.size() - 1; i++) {
                Spot s1 = spots.get(i);
                Spot s2 = spots.get(i + 1);

                if (!hasCoordinates(s1) || !hasCoordinates(s2)) {
                    System.out.println("⚠️ 景点缺少坐标，跳过: " + s1.getName() + " → " + s2.getName());
                    continue;
                }

                System.out.printf("📍 计算路径 %d/%d: %s → %s%n",
                        i + 1, spots.size() - 1, s1.getName(), s2.getName());

                double[] result = amapUtil.getWalkingDistanceAndTime(
                        s1.getLatitude(), s1.getLongitude(),
                        s2.getLatitude(), s2.getLongitude()
                );

                if (result != null) {
                    totalWalkSeconds += result[1];
                    segmentCount++;
                    // 检查是否是缓存命中（距离和时间与之前完全相同）
                    // 简单判断：如果日志没有"高德API请求"字样就是缓存命中
                } else {
                    System.out.println("❌ 路径计算失败，降级为Haversine公式");
                    return null;
                }
            }

            if (segmentCount == 0) return null;

            int walkMinutes = (int) Math.ceil(totalWalkSeconds / 60);
            int stayMinutes = spots.size() * STAY_TIME_PER_SPOT;
            int totalMinutes = Math.max(walkMinutes + stayMinutes, 10);

            System.out.printf("📊 计算结果 - 步行: %d分钟, 景点停留: %d分钟, 总计: %d分钟%n",
                    walkMinutes, stayMinutes, totalMinutes);

            return totalMinutes;
        } catch (Exception e) {
            System.err.println("❌ 高德API计算异常: " + e.getMessage());
            return null;
        }
    }

    /**
     * 使用Haversine公式计算总耗时（备用方案）
     */
    private int calculateByHaversine(List<Spot> spots) {
        double totalDistance = 0;
        int segmentCount = 0;

        for (int i = 0; i < spots.size() - 1; i++) {
            Spot s1 = spots.get(i);
            Spot s2 = spots.get(i + 1);

            if (hasCoordinates(s1) && hasCoordinates(s2)) {
                double distance = haversineDistance(
                        s1.getLatitude(), s1.getLongitude(),
                        s2.getLatitude(), s2.getLongitude()
                );
                totalDistance += distance;
                segmentCount++;
                System.out.printf("📏 Haversine: %s → %s = %.0f米%n",
                        s1.getName(), s2.getName(), distance);
            }
        }

        if (segmentCount == 0) return spots.size() * STAY_TIME_PER_SPOT;

        int walkMinutes = (int) (totalDistance / WALK_SPEED);
        int stayMinutes = spots.size() * STAY_TIME_PER_SPOT;
        int totalMinutes = Math.max(walkMinutes + stayMinutes, 10);

        System.out.printf("📊 Haversine结果 - 总距离: %.0f米, 步行: %d分钟, 停留: %d分钟, 总计: %d分钟%n",
                totalDistance, walkMinutes, stayMinutes, totalMinutes);

        return totalMinutes;
    }

    /**
     * 判断景点是否有坐标
     */
    private boolean hasCoordinates(Spot spot) {
        return spot.getLatitude() != null && spot.getLongitude() != null;
    }

    /**
     * Haversine公式计算两点间直线距离（米）
     */
    private double haversineDistance(BigDecimal lat1, BigDecimal lng1,
                                     BigDecimal lat2, BigDecimal lng2) {
        double dLat = Math.toRadians(lat2.doubleValue() - lat1.doubleValue());
        double dLng = Math.toRadians(lng2.doubleValue() - lng1.doubleValue());
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1.doubleValue())) *
                        Math.cos(Math.toRadians(lat2.doubleValue())) *
                        Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS * c;
    }
}
