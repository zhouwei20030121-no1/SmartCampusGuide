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
import java.util.*;

@Service
public class RoutePlanServiceImpl
        extends ServiceImpl<RoutePlanMapper, RoutePlan>
        implements RoutePlanService {

    private static final double WALK_SPEED = 80.0;
    private static final int STAY_TIME_PER_SPOT = 10;
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
    }

    @Override
    @Transactional
    public void updateWithSpots(RoutePlan routePlan, String spotIds) {
        int estimatedTime = calculateEstimatedTime(spotIds);
        routePlan.setEstimatedTime(estimatedTime);

        this.updateById(routePlan);

        LambdaQueryWrapper<RouteSpotNode> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(RouteSpotNode::getRouteId, routePlan.getId());
        nodeMapper.delete(wrapper);

        saveSpotNodes(routePlan.getId(), spotIds);
    }

    @Override
    public RoutePlan getDetailById(Long id) {
        RoutePlan routePlan = this.getById(id);
        if (routePlan != null) {
            fillSpotInfo(routePlan);
        }
        return routePlan;
    }

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

        Integer amapTime = calculateByAmap(spots);
        if (amapTime != null) return amapTime;
        return calculateByHaversine(spots);
    }

    private Integer calculateByAmap(List<Spot> spots) {
        if (!amapUtil.isConfigured()) return null;

        try {
            double totalWalkSeconds = 0;
            int segmentCount = 0;

            for (int i = 0; i < spots.size() - 1; i++) {
                Spot s1 = spots.get(i);
                Spot s2 = spots.get(i + 1);

                if (!hasCoordinates(s1) || !hasCoordinates(s2)) continue;

                double[] result = amapUtil.getWalkingDistanceAndTime(
                        s1.getLatitude(), s1.getLongitude(),
                        s2.getLatitude(), s2.getLongitude()
                );

                if (result != null) {
                    totalWalkSeconds += result[1];
                    segmentCount++;
                } else {
                    return null;
                }
            }

            if (segmentCount == 0) return null;

            int walkMinutes = (int) Math.ceil(totalWalkSeconds / 60);
            int stayMinutes = spots.size() * STAY_TIME_PER_SPOT;
            return Math.max(walkMinutes + stayMinutes, 10);
        } catch (Exception e) {
            return null;
        }
    }

    private int calculateByHaversine(List<Spot> spots) {
        double totalDistance = 0;
        int segmentCount = 0;

        for (int i = 0; i < spots.size() - 1; i++) {
            Spot s1 = spots.get(i);
            Spot s2 = spots.get(i + 1);

            if (hasCoordinates(s1) && hasCoordinates(s2)) {
                totalDistance += haversineDistance(
                        s1.getLatitude(), s1.getLongitude(),
                        s2.getLatitude(), s2.getLongitude()
                );
                segmentCount++;
            }
        }

        if (segmentCount == 0) return spots.size() * STAY_TIME_PER_SPOT;

        int walkMinutes = (int) (totalDistance / WALK_SPEED);
        int stayMinutes = spots.size() * STAY_TIME_PER_SPOT;
        return Math.max(walkMinutes + stayMinutes, 10);
    }

    private boolean hasCoordinates(Spot spot) {
        return spot != null && spot.getLatitude() != null && spot.getLongitude() != null;
    }

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


    // ================= 以下为深度修复后的最优路线算法 =================

    private static class Node implements Comparable<Node> {
        Spot spot;
        double gCost; 
        double hCost; 
        Node parent;

        public Node(Spot spot) {
            this.spot = spot;
        }

        public double getFCost() { return gCost + hCost; }

        @Override
        public int compareTo(Node other) {
            return Double.compare(this.getFCost(), other.getFCost());
        }
    }

    @Override
    public List<Spot> calculateOptimalRoute(Long startId, Long endId, boolean isPopularityFirst) {
        Spot startSpot = spotService.getById(startId);
        Spot endSpot = spotService.getById(endId);
        
        if (startSpot == null || endSpot == null || !hasCoordinates(startSpot) || !hasCoordinates(endSpot)) {
            return new ArrayList<>();
        }

        // 🌟 修复一：如果是“最短路线”，直接返回起止点！让高德底层路网接管规划，绝对不会有乱绕路的叠加！
        if (!isPopularityFirst) {
            return Arrays.asList(startSpot, endSpot);
        }

        // ==========================================
        // 下面是“体验最佳（热度打卡优先）”的专属 A* 算法
        // ==========================================
        List<Spot> allSpots = spotService.list();
        Map<Long, Spot> spotMap = new HashMap<>();
        Map<Long, Node> nodeMap = new HashMap<>();
        
        // 动态探测真实最高热度
        int maxVisitCount = 1;
        for (Spot s : allSpots) {
            spotMap.put(s.getId(), s);
            Node n = new Node(s);
            // 🌟 修复二：初始代价必须设为正无穷，否则探索失效
            n.gCost = Double.MAX_VALUE; 
            nodeMap.put(s.getId(), n);
            if (s.getVisitCount() != null && s.getVisitCount() > maxVisitCount) {
                maxVisitCount = s.getVisitCount();
            }
        }

        Map<Long, List<Node>> graph = new HashMap<>();
        for (Spot s1 : allSpots) {
            List<Node> neighbors = new ArrayList<>();
            for (Spot s2 : allSpots) {
                if (!s1.getId().equals(s2.getId()) && hasCoordinates(s1) && hasCoordinates(s2)) {
                    double dist = haversineDistance(s1.getLatitude(), s1.getLongitude(), s2.getLatitude(), s2.getLongitude());
                    if (dist < 500.0) { // 校园连通半径 500米
                        neighbors.add(nodeMap.get(s2.getId()));
                    }
                }
            }
            graph.put(s1.getId(), neighbors);
        }

        PriorityQueue<Node> openSet = new PriorityQueue<>();
        Set<Long> closedSet = new HashSet<>();
        
        Node startNode = nodeMap.get(startId);
        startNode.gCost = 0;
        double initialH = haversineDistance(startSpot.getLatitude(), startSpot.getLongitude(), endSpot.getLatitude(), endSpot.getLongitude());
        // 🌟 修复三：削弱终点方向的目的性，让算法更愿意在校园里乱逛打卡
        startNode.hCost = initialH * 0.2; 
        openSet.add(startNode);

        while (!openSet.isEmpty()) {
            Node current = openSet.poll();

            if (current.spot.getId().equals(endId)) {
                return reconstructPath(current);
            }

            closedSet.add(current.spot.getId());

            for (Node neighbor : graph.getOrDefault(current.spot.getId(), new ArrayList<>())) {
                if (closedSet.contains(neighbor.spot.getId())) continue;

                double physicalDistance = haversineDistance(current.spot.getLatitude(), current.spot.getLongitude(), neighbor.spot.getLatitude(), neighbor.spot.getLongitude());
                
                Integer visitCount = neighbor.spot.getVisitCount();
                if (visitCount == null) visitCount = 0;
                
                // 热门景点的代价急剧缩小（最多打 1 折），极度吸引路径偏移
                double discount = Math.max(0.1, 1.0 - ((double) visitCount / maxVisitCount));
                double moveCost = physicalDistance * discount;

                double tentativeGCost = current.gCost + moveCost;

                if (tentativeGCost < neighbor.gCost) {
                    neighbor.parent = current;
                    neighbor.gCost = tentativeGCost;
                    
                    double nextH = haversineDistance(neighbor.spot.getLatitude(), neighbor.spot.getLongitude(), endSpot.getLatitude(), endSpot.getLongitude());
                    neighbor.hCost = nextH * 0.2;
                    
                    // 🌟 修复四：Java 的优先队列修改属性后，必须重新插拔才能排序！
                    if (openSet.contains(neighbor)) {
                        openSet.remove(neighbor);
                    }
                    openSet.add(neighbor);
                }
            }
        }
        
        return Arrays.asList(startSpot, endSpot);
    }

    private List<Spot> reconstructPath(Node endNode) {
        List<Spot> path = new ArrayList<>();
        Node curr = endNode;
        while (curr != null) {
            path.add(curr.spot);
            curr = curr.parent;
        }
        Collections.reverse(path);
        return path;
    }
}