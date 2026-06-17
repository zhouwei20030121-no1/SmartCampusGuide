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
import java.util.stream.Collectors;

@Service
public class RoutePlanServiceImpl extends ServiceImpl<RoutePlanMapper, RoutePlan> implements RoutePlanService {

    private static final double WALK_SPEED = 80.0;
    private static final int STAY_TIME_PER_SPOT = 10;
    private static final double EARTH_RADIUS = 6371000.0;

    private final RouteSpotNodeMapper nodeMapper;
    private final SpotService spotService;
    private final AmapUtil amapUtil;

    public RoutePlanServiceImpl(RouteSpotNodeMapper nodeMapper, SpotService spotService, AmapUtil amapUtil) {
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

    private int calculateRealisticStayTime(int spotCount) {
        if (spotCount <= 0) return 0;
        if (spotCount <= 2) {
            return spotCount * STAY_TIME_PER_SPOT;
        }
        return 20 + ((spotCount - 2) * 3);
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
            int stayMinutes = calculateRealisticStayTime(spots.size());
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
        int stayMinutes = calculateRealisticStayTime(spots.size());
        return Math.max(walkMinutes + stayMinutes, 10);
    }

    private boolean hasCoordinates(Spot spot) {
        return spot != null && spot.getLatitude() != null && spot.getLongitude() != null;
    }

    private double haversineDistance(BigDecimal lat1, BigDecimal lng1, BigDecimal lat2, BigDecimal lng2) {
        double dLat = Math.toRadians(lat2.doubleValue() - lat1.doubleValue());
        double dLng = Math.toRadians(lng2.doubleValue() - lng1.doubleValue());
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1.doubleValue())) *
                        Math.cos(Math.toRadians(lat2.doubleValue())) *
                        Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS * c;
    }

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
        return calculateAdvancedRoute(startId, endId, new ArrayList<>(), isPopularityFirst ? "PERSONALIZED" : "DISTANCE", "TOURIST");
    }

    public List<Spot> calculateAdvancedRoute(Long startId, Long endId, List<Long> waypoints, String strategy, String userIdentity) {
        List<Spot> finalPath = new ArrayList<>();
        List<Long> pathSequence = new ArrayList<>();

        pathSequence.add(startId);
        if (waypoints != null && !waypoints.isEmpty()) {
            pathSequence.addAll(waypoints);
        }

        List<Spot> allSpots = spotService.list();

        if ("PERSONALIZED".equalsIgnoreCase(strategy) && (waypoints == null || waypoints.isEmpty())) {
            Spot startSpot = allSpots.stream().filter(s -> s.getId().equals(startId)).findFirst().orElse(null);
            Spot endSpot = allSpots.stream().filter(s -> s.getId().equals(endId)).findFirst().orElse(null);

            if (startSpot != null && endSpot != null) {
                List<Spot> topSpots = findTopPersonaSpots(startSpot, endSpot, allSpots, userIdentity, 2);
                for (Spot s : topSpots) {
                    pathSequence.add(s.getId());
                }
            }
        }

        pathSequence.add(endId);

        for (int i = 0; i < pathSequence.size() - 1; i++) {
            List<Spot> segment = aStarSegment(pathSequence.get(i), pathSequence.get(i + 1), allSpots, strategy, userIdentity);
            if (segment.isEmpty()) continue;

            if (finalPath.isEmpty()) {
                finalPath.addAll(segment);
            } else {
                segment.remove(0);
                finalPath.addAll(segment);
            }
        }
        return finalPath;
    }

    private List<Spot> findTopPersonaSpots(Spot start, Spot end, List<Spot> allSpots, String identity, int limit) {
        double baseDist = haversineDistance(start.getLatitude(), start.getLongitude(), end.getLatitude(), end.getLongitude());

        // 计算从起点指向终点的基础方向向量
        double vX = end.getLongitude().doubleValue() - start.getLongitude().doubleValue();
        double vY = end.getLatitude().doubleValue() - start.getLatitude().doubleValue();

        List<Spot> bestSpots = allSpots.stream()
            .filter(s -> hasCoordinates(s) && !s.getId().equals(start.getId()) && !s.getId().equals(end.getId()))
            .filter(s -> {
                // 1. 顺路基础限制：利用距离和建立椭圆形包围网，防止为了高分绕行太远（允许最大多走 40% 的路，或最低 500 米容错）
                double distToStart = haversineDistance(start.getLatitude(), start.getLongitude(), s.getLatitude(), s.getLongitude());
                double distToEnd = haversineDistance(s.getLatitude(), s.getLongitude(), end.getLatitude(), end.getLongitude());
                if (distToStart + distToEnd > Math.max(baseDist * 1.4, 500.0)) {
                    return false;
                }

                // 2. 正向防反向锁：计算从起点指向该候选景点的向量
                double uX = s.getLongitude().doubleValue() - start.getLongitude().doubleValue();
                double uY = s.getLatitude().doubleValue() - start.getLatitude().doubleValue();

                // 向量点乘。若小于 0，说明候选景点处在起点的背后（偏离目标方向超过 90 度），直接剔除。
                // 移除了对终点的严格判断，给终点周边的景点留出呼吸空间。
                if ((vX * uX) + (vY * uY) < 0) {
                    return false;
                }

                return true;
            })
            .sorted((s1, s2) -> Double.compare(getPersonaScore(s2, identity), getPersonaScore(s1, identity)))
            .limit(limit)
            .collect(Collectors.toList());

        bestSpots.sort(Comparator.comparingDouble(s -> haversineDistance(start.getLatitude(), start.getLongitude(), s.getLatitude(), s.getLongitude())));

        return bestSpots;
    }

    private boolean isPreferredCategory(Spot spot, String identity) {
        if (spot == null || spot.getCategory() == null) return false;
        String cat = spot.getCategory().trim();
        if ("FRESHMAN".equalsIgnoreCase(identity)) {
            return "教学设施".equals(cat) || "生活服务".equals(cat);
        } else if ("TOURIST".equalsIgnoreCase(identity)) {
            return "自然景观".equals(cat) || "历史建筑".equals(cat);
        } else if ("ALUMNI".equalsIgnoreCase(identity)) {
            return "历史建筑".equals(cat) || "校园文化".equals(cat);
        }
        return false;
    }

    private double getPersonaScore(Spot spot, String identity) {
        double score = 0.0;

        if ("TOURIST".equalsIgnoreCase(identity)) {
            double vc = spot.getVisitCount() == null ? 0.0 : spot.getVisitCount().doubleValue();
            score = vc * vc;
        } else if ("FRESHMAN".equalsIgnoreCase(identity)) {
            score = spot.getDescription() == null ? 0.0 : spot.getDescription().length();
        } else if ("ALUMNI".equalsIgnoreCase(identity)) {
            double id = spot.getId() == null ? 1.0 : spot.getId().doubleValue();
            score = 100000.0 / Math.max(id, 1.0);
        }

        if (isPreferredCategory(spot, identity)) {
            score += 1000000.0;
        }

        return score;
    }

    private List<Spot> aStarSegment(Long startId, Long endId, List<Spot> allSpots, String strategy, String userIdentity) {
        Spot startSpot = allSpots.stream().filter(s -> s.getId().equals(startId)).findFirst().orElse(null);
        Spot endSpot = allSpots.stream().filter(s -> s.getId().equals(endId)).findFirst().orElse(null);

        if (startSpot == null || endSpot == null || !hasCoordinates(startSpot) || !hasCoordinates(endSpot)) {
            return new ArrayList<>();
        }

        if ("DISTANCE".equalsIgnoreCase(strategy)) {
            return Arrays.asList(startSpot, endSpot);
        }

        double maxScore = 1.0;
        if ("PERSONALIZED".equalsIgnoreCase(strategy)) {
            for (Spot s : allSpots) {
                double score = getPersonaScore(s, userIdentity);
                if (score > maxScore) maxScore = score;
            }
        }

        Map<Long, Node> nodeMap = new HashMap<>();
        for (Spot s : allSpots) {
            Node n = new Node(s);
            n.gCost = Double.MAX_VALUE;
            nodeMap.put(s.getId(), n);
        }

        Map<Long, List<Node>> graph = new HashMap<>();
        for (Spot s1 : allSpots) {
            if (!hasCoordinates(s1)) continue;
            List<Node> neighbors = allSpots.stream()
                .filter(s2 -> !s1.getId().equals(s2.getId()) && hasCoordinates(s2))
                .sorted(Comparator.comparingDouble(s2 -> haversineDistance(s1.getLatitude(), s1.getLongitude(), s2.getLatitude(), s2.getLongitude())))
                // 核心修复点：将邻接节点放宽至 15 个，保证图的绝对连通性，防止算法断联而强制返回直线
                .limit(15)
                .map(s2 -> nodeMap.get(s2.getId()))
                .collect(Collectors.toList());
            graph.put(s1.getId(), neighbors);
        }

        PriorityQueue<Node> openSet = new PriorityQueue<>();
        Set<Long> closedSet = new HashSet<>();

        Node startNode = nodeMap.get(startId);
        startNode.gCost = 0;
        double initialH = haversineDistance(startSpot.getLatitude(), startSpot.getLongitude(), endSpot.getLatitude(), endSpot.getLongitude());
        // 因为我们在大思路上已经强制注入了 Waypoints，所以 A* 的分段只需本分地走向下一个目标即可，H-Cost 设为 1.0 是最稳妥的
        startNode.hCost = initialH * 1.0;
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
                double moveCost = physicalDistance;

                if ("TIME".equalsIgnoreCase(strategy)) {
                    String catN = neighbor.spot.getCategory() == null ? "" : neighbor.spot.getCategory();
                    if ("生活服务".equals(catN)) moveCost += 20000.0;
                    else if ("教学设施".equals(catN)) moveCost += 10000.0;
                }
                else if ("PERSONALIZED".equalsIgnoreCase(strategy)) {
                    double score = getPersonaScore(neighbor.spot, userIdentity);
                    double discount = Math.max(0.01, 1.0 - (score / maxScore));
                    moveCost = physicalDistance * discount;
                }

                double tentativeGCost = current.gCost + moveCost;

                if (tentativeGCost < neighbor.gCost) {
                    neighbor.parent = current;
                    neighbor.gCost = tentativeGCost;

                    double nextH = haversineDistance(neighbor.spot.getLatitude(), neighbor.spot.getLongitude(), endSpot.getLatitude(), endSpot.getLongitude());
                    neighbor.hCost = nextH * 1.0;

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