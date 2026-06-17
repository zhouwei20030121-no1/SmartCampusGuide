package com.swu.guide.modules.bus.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.modules.bus.entity.BusLine;
import com.swu.guide.modules.bus.entity.BusStation;
import com.swu.guide.modules.bus.entity.LineStationRelation;
import com.swu.guide.modules.bus.mapper.BusLineMapper;
import com.swu.guide.modules.bus.mapper.BusStationMapper;
import com.swu.guide.modules.bus.mapper.LineStationRelationMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class BusService {

    private final BusLineMapper lineMapper;
    private final BusStationMapper stationMapper;
    private final LineStationRelationMapper relationMapper;

    public BusService(BusLineMapper lineMapper, BusStationMapper stationMapper,
                      LineStationRelationMapper relationMapper) {
        this.lineMapper = lineMapper;
        this.stationMapper = stationMapper;
        this.relationMapper = relationMapper;
    }

    public Page<BusLine> searchLines(String keyword, int page, int size) {
        LambdaQueryWrapper<BusLine> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(keyword)) {
            wrapper.like(BusLine::getLineName, keyword);
        }
        wrapper.orderByAsc(BusLine::getId);
        return lineMapper.selectPage(new Page<>(page, size), wrapper);
    }

    public List<Map<String, Object>> getAllLinesWithStations() {
        List<BusLine> lines = lineMapper.selectList(
                new LambdaQueryWrapper<BusLine>().eq(BusLine::getEnabled, 1));
        List<Map<String, Object>> result = new ArrayList<>();
        for (BusLine line : lines) {
            Map<String, Object> item = lineBasicMap(line);
            item.put("startStation", line.getStartStation());
            item.put("directionType", line.getDirectionType());
            item.put("fareInfo", line.getFareInfo());
            item.put("stations", getLineStations(line.getId()));
            item.put("eta", lineEta(line, LocalTime.now()));
            result.add(item);
        }
        return result;
    }

    public Map<Integer, List<Map<String, Object>>> getLineStations(Long lineId) {
        List<Map<String, Object>> stations = relationMapper.getStationDetailByLine(lineId);
        Map<Integer, List<Map<String, Object>>> grouped = new LinkedHashMap<>();
        for (Map<String, Object> s : stations) {
            int dir = ((Number) s.get("direction")).intValue();
            grouped.computeIfAbsent(dir, k -> new ArrayList<>()).add(s);
        }
        return grouped;
    }

    public List<BusStation> listStations() {
        return stationMapper.selectList(
                new LambdaQueryWrapper<BusStation>().orderByAsc(BusStation::getId));
    }

    public Map<String, Object> nearestRecommendation(double lat, double lng) {
        List<BusStation> stations = listStations();
        BusStation nearest = nearestStation(lat, lng, stations);
        Map<String, Object> result = new LinkedHashMap<>();
        if (nearest == null) {
            result.put("available", false);
            result.put("message", "暂无可用校车站点数据");
            return result;
        }

        double distance = distanceMeters(lat, lng, nearest.getLatitude(), nearest.getLongitude());
        List<Map<String, Object>> lineOptions = linesServingStation(nearest.getStationName()).stream()
                .map(line -> lineEta(line, LocalTime.now()))
                .sorted(Comparator.comparingInt(item -> ((Number) item.getOrDefault("waitMinutes", 9999)).intValue()))
                .limit(3)
                .collect(Collectors.toList());
        Map<String, Object> bestLine = lineOptions.isEmpty() ? Map.of() : lineOptions.get(0);

        result.put("available", true);
        result.put("station", stationMap(nearest, distance));
        result.put("walkMinutes", walkMinutes(distance));
        result.put("lines", lineOptions);
        result.put("crowding", crowding(LocalTime.now(), nearest.getStationName(), ""));
        result.put("suggestion", buildNearestSuggestion(nearest.getStationName(), distance, bestLine));
        return result;
    }

    public Map<String, Object> planCommute(Map<String, Object> params) {
        double fromLat = parseDouble(params.get("fromLat"), parseDouble(params.get("lat"), 29.820));
        double fromLng = parseDouble(params.get("fromLng"), parseDouble(params.get("lng"), 106.421));
        double toLat = parseDouble(params.get("toLat"), 0);
        double toLng = parseDouble(params.get("toLng"), 0);
        String fromStationName = String.valueOf(params.getOrDefault("fromStation", "")).trim();
        String toStationName = String.valueOf(params.getOrDefault("toStation", params.getOrDefault("destination", ""))).trim();
        String preference = String.valueOf(params.getOrDefault("preference", "fastest"));

        List<BusStation> stations = listStations();
        BusStation fromStation = StringUtils.hasText(fromStationName)
                ? findStationByName(fromStationName, stations)
                : nearestStation(fromLat, fromLng, stations);
        BusStation toStation = StringUtils.hasText(toStationName)
                ? findStationByName(toStationName, stations)
                : nearestStation(toLat, toLng, stations);
        if (fromStation == null || toStation == null) {
            return Map.of("available", false, "message", "未匹配到可用校车站点，请先补充站点经纬度");
        }

        double walkToStart = distanceMeters(fromLat, fromLng, fromStation.getLatitude(), fromStation.getLongitude());
        double walkFromEnd = toLat == 0 || toLng == 0 ? 0 : distanceMeters(toLat, toLng, toStation.getLatitude(), toStation.getLongitude());
        if (Objects.equals(fromStation.getId(), toStation.getId())
                || Objects.equals(fromStation.getStationName(), toStation.getStationName())) {
            return walkingOnlyResult(fromStation, toStation, walkToStart, walkFromEnd, preference);
        }

        List<RouteCandidate> candidates = findRouteCandidates(fromStation.getStationName(), toStation.getStationName());
        LocalTime now = LocalTime.now();
        List<Map<String, Object>> plans = candidates.stream()
                .map(candidate -> scoreCandidate(candidate, fromStation, toStation, walkToStart, walkFromEnd, now, preference))
                .sorted(Comparator.comparingDouble(item -> ((Number) item.get("score")).doubleValue()))
                .limit(6)
                .collect(Collectors.toList());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("available", !plans.isEmpty());
        result.put("algorithm", "CampusBus-Dijkstra multi-factor routing");
        result.put("preference", preference);
        result.put("fromStation", stationMap(fromStation, walkToStart));
        result.put("toStation", stationMap(toStation, walkFromEnd));
        result.put("plans", plans);
        result.put("best", plans.isEmpty() ? null : plans.get(0));
        result.put("message", plans.isEmpty() ? "没有找到合适校车方案，建议步行或重新选择站点" : "已根据步行、等车、站数、换乘和末班风险生成方案");
        return result;
    }

    public Map<String, Object> assistant(Map<String, Object> params) {
        String message = String.valueOf(params.getOrDefault("message", ""));
        List<BusStation> stations = listStations();
        List<BusStation> mentionedStations = mentionedStations(message, stations);

        Map<String, Object> planParams = new LinkedHashMap<>(params);
        if (mentionedStations.size() >= 2) {
            planParams.put("fromStation", mentionedStations.get(0).getStationName());
            planParams.put("toStation", mentionedStations.get(mentionedStations.size() - 1).getStationName());
        } else if (mentionedStations.size() == 1) {
            BusStation only = mentionedStations.get(0);
            if (message.contains("从" + only.getStationName())
                    || message.contains("在" + only.getStationName())
                    || message.contains("我现在在" + only.getStationName())) {
                planParams.put("fromStation", only.getStationName());
            } else {
                planParams.put("toStation", only.getStationName());
            }
        }
        Map<String, Object> plan = planCommute(planParams);
        Map<String, Object> best = plan.get("best") instanceof Map<?, ?> bestMap ? normalizeMap(bestMap) : Map.of();

        String reply;
        if (Boolean.TRUE.equals(plan.get("available")) && !best.isEmpty()) {
            Map<String, Object> fromStation = normalizeMap((Map<?, ?>) plan.get("fromStation"));
            Map<String, Object> toStation = normalizeMap((Map<?, ?>) plan.get("toStation"));
            reply = "建议从" + fromStation.get("stationName") + "上车，乘坐"
                    + best.getOrDefault("lineName", "推荐线路") + "，在" + toStation.get("stationName")
                    + "附近下车。预计步行到站" + best.getOrDefault("walkToStartMinutes", 0)
                    + "分钟，等车" + best.getOrDefault("waitMinutes", 0)
                    + "分钟，全程约" + best.getOrDefault("totalMinutes", 0) + "分钟。";
        } else {
            reply = "暂时没有匹配到完整校车方案，可以先选择始发站和目的站，或改用步行路线规划。";
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("reply", reply);
        result.put("plan", plan);
        result.put("intent", "campus_bus_commute");
        return result;
    }

    public Map<String, Object> prefetchGuide(Map<String, Object> params) {
        Object stationsObj = params.get("stations");
        List<String> stations = new ArrayList<>();
        if (stationsObj instanceof Iterable<?> iterable) {
            for (Object item : iterable) {
                if (item != null && StringUtils.hasText(item.toString())) {
                    stations.add(item.toString());
                }
                if (stations.size() >= 3) break;
            }
        }
        return Map.of(
                "prefetchStations", stations,
                "count", stations.size(),
                "status", "queued",
                "message", "已记录未来讲解预加载站点，靠近后将优先复用缓存讲解词"
        );
    }

    @Transactional
    public void saveLine(BusLine line, String upStationIds, String downStationIds) {
        boolean isUpdate = line.getId() != null;
        if (isUpdate) {
            lineMapper.updateById(line);
            LambdaQueryWrapper<LineStationRelation> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(LineStationRelation::getLineId, line.getId());
            relationMapper.delete(wrapper);
        } else {
            lineMapper.insert(line);
        }

        if (StringUtils.hasText(upStationIds)) {
            saveStations(line.getId(), upStationIds, 0);
        }
        if (StringUtils.hasText(downStationIds)) {
            saveStations(line.getId(), downStationIds, 1);
        }
    }

    public void updateLine(BusLine line) {
        lineMapper.updateById(line);
    }

    @Transactional
    public void deleteLine(Long id) {
        LambdaQueryWrapper<LineStationRelation> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(LineStationRelation::getLineId, id);
        relationMapper.delete(wrapper);
        lineMapper.deleteById(id);
    }

    private void saveStations(Long lineId, String stationIds, int direction) {
        String[] ids = stationIds.split(",");
        int order = 1;
        for (String idStr : ids) {
            String trimmed = idStr.trim();
            if (!StringUtils.hasText(trimmed)) continue;

            LineStationRelation relation = new LineStationRelation();
            relation.setLineId(lineId);
            relation.setStationId(Long.parseLong(trimmed));
            relation.setStopOrder(order++);
            relation.setDirection(direction);
            relationMapper.insert(relation);
        }
    }

    private List<RouteCandidate> findRouteCandidates(String from, String to) {
        List<LinePath> paths = allLinePaths();
        List<RouteCandidate> candidates = new ArrayList<>();
        for (LinePath path : paths) {
            List<String> segment = path.segment(from, to);
            if (!segment.isEmpty()) {
                candidates.add(new RouteCandidate(path.line, path.line.getLineName(), segment, null, 0));
            }
        }
        for (LinePath first : paths) {
            for (LinePath second : paths) {
                if (Objects.equals(first.line.getId(), second.line.getId())) continue;
                Set<String> common = new LinkedHashSet<>(first.stations);
                common.retainAll(second.stations);
                for (String transfer : common) {
                    if (transfer.equals(from) || transfer.equals(to)) continue;
                    List<String> left = first.segment(from, transfer);
                    List<String> right = second.segment(transfer, to);
                    if (!left.isEmpty() && !right.isEmpty()) {
                        List<String> full = new ArrayList<>(left);
                        full.addAll(right.subList(1, right.size()));
                        candidates.add(new RouteCandidate(first.line, first.line.getLineName() + " -> " + second.line.getLineName(), full, transfer, 1));
                        break;
                    }
                }
            }
        }
        dijkstraCandidate(paths, from, to).ifPresent(candidate -> {
            boolean duplicated = candidates.stream().anyMatch(item -> item.stations.equals(candidate.stations));
            if (!duplicated) {
                candidates.add(candidate);
            }
        });
        return candidates;
    }

    private java.util.Optional<RouteCandidate> dijkstraCandidate(List<LinePath> paths, String from, String to) {
        Map<String, List<Edge>> graph = new LinkedHashMap<>();
        BusLine fallbackLine = null;
        for (LinePath path : paths) {
            if (fallbackLine == null) fallbackLine = path.line;
            for (int i = 0; i < path.stations.size() - 1; i++) {
                String a = path.stations.get(i);
                String b = path.stations.get(i + 1);
                graph.computeIfAbsent(a, key -> new ArrayList<>()).add(new Edge(b, path.line));
                graph.computeIfAbsent(b, key -> new ArrayList<>()).add(new Edge(a, path.line));
            }
        }
        if (!graph.containsKey(from) || !graph.containsKey(to) || fallbackLine == null) {
            return java.util.Optional.empty();
        }

        Map<String, Double> dist = new LinkedHashMap<>();
        Map<String, String> prev = new LinkedHashMap<>();
        Set<String> visited = new LinkedHashSet<>();
        for (String node : graph.keySet()) dist.put(node, Double.MAX_VALUE / 4);
        dist.put(from, 0.0);

        while (visited.size() < graph.size()) {
            String current = graph.keySet().stream()
                    .filter(node -> !visited.contains(node))
                    .min(Comparator.comparingDouble(node -> dist.getOrDefault(node, Double.MAX_VALUE / 4)))
                    .orElse(null);
            if (current == null || current.equals(to)) break;
            visited.add(current);
            for (Edge edge : graph.getOrDefault(current, List.of())) {
                double next = dist.get(current) + 1.0;
                if (next < dist.getOrDefault(edge.to, Double.MAX_VALUE / 4)) {
                    dist.put(edge.to, next);
                    prev.put(edge.to, current);
                }
            }
        }

        if (!prev.containsKey(to)) return java.util.Optional.empty();
        List<String> stations = new ArrayList<>();
        String cursor = to;
        stations.add(cursor);
        while (!cursor.equals(from)) {
            cursor = prev.get(cursor);
            if (cursor == null) return java.util.Optional.empty();
            stations.add(cursor);
        }
        Collections.reverse(stations);
        return java.util.Optional.of(new RouteCandidate(fallbackLine, fallbackLine.getLineName(), stations, null, 0));
    }

    private Map<String, Object> scoreCandidate(RouteCandidate candidate, BusStation fromStation, BusStation toStation,
                                               double walkToStart, double walkFromEnd, LocalTime now, String preference) {
        Map<String, Object> eta = lineEta(candidate.primaryLine, now);
        int wait = ((Number) eta.getOrDefault("waitMinutes", 999)).intValue();
        int stationCount = Math.max(0, candidate.stations.size() - 1);
        int rideMinutes = Math.max(3, stationCount * 3 + candidate.transfers * 6);
        int walkStartMinutes = walkMinutes(walkToStart);
        int walkEndMinutes = walkMinutes(walkFromEnd);
        int totalMinutes = walkStartMinutes + wait + rideMinutes + walkEndMinutes;
        int lateRisk = Boolean.TRUE.equals(eta.get("nearLastBus")) ? 12 : 0;

        double score = totalMinutes + candidate.transfers * 8 + lateRisk;
        if ("less_walk".equals(preference)) {
            score += (walkToStart + walkFromEnd) / 35.0;
        } else if ("less_transfer".equals(preference)) {
            score += candidate.transfers * 20;
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("type", candidate.transfers == 0 ? "direct" : "transfer");
        result.put("lineName", candidate.lineName);
        result.put("stations", candidate.stations);
        result.put("transferAt", candidate.transferAt);
        result.put("transferCount", candidate.transfers);
        result.put("stationCount", stationCount);
        result.put("walkToStartMeters", Math.round(walkToStart));
        result.put("walkFromEndMeters", Math.round(walkFromEnd));
        result.put("walkToStartMinutes", walkStartMinutes);
        result.put("walkFromEndMinutes", walkEndMinutes);
        result.put("waitMinutes", wait);
        result.put("rideMinutes", rideMinutes);
        result.put("totalMinutes", totalMinutes);
        result.put("score", Math.round(score * 10.0) / 10.0);
        result.put("eta", eta);
        result.put("crowding", crowding(now, fromStation.getStationName(), toStation.getStationName()));
        result.put("reminder", Map.of(
                "targetStation", toStation.getStationName(),
                "targetLat", toStation.getLatitude(),
                "targetLng", toStation.getLongitude(),
                "radiusMeters", 80,
                "missedThresholdMeters", 180
        ));
        result.put("summary", candidate.lineName + "，预计等车" + wait + "分钟，全程约" + totalMinutes + "分钟");
        return result;
    }

    private List<Map<String, Object>> linesServingStation(String stationName) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (BusLine line : lineMapper.selectList(new LambdaQueryWrapper<BusLine>().eq(BusLine::getEnabled, 1))) {
            Map<Integer, List<Map<String, Object>>> grouped = getLineStations(line.getId());
            boolean serves = grouped.values().stream()
                    .flatMap(Collection::stream)
                    .anyMatch(station -> stationName.equals(String.valueOf(station.get("stationName"))));
            if (serves) {
                result.add(lineBasicMap(line));
            }
        }
        return result;
    }

    private List<LinePath> allLinePaths() {
        List<LinePath> paths = new ArrayList<>();
        for (BusLine line : lineMapper.selectList(new LambdaQueryWrapper<BusLine>().eq(BusLine::getEnabled, 1))) {
            Map<Integer, List<Map<String, Object>>> grouped = getLineStations(line.getId());
            for (List<Map<String, Object>> stations : grouped.values()) {
                List<String> names = stations.stream()
                        .map(item -> String.valueOf(item.get("stationName")))
                        .filter(StringUtils::hasText)
                        .collect(Collectors.toList());
                if (names.size() >= 2) paths.add(new LinePath(line, names));
            }
        }
        return paths;
    }

    private Map<String, Object> lineBasicMap(BusLine line) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("lineId", line.getId());
        map.put("lineName", line.getLineName());
        map.put("startTime", line.getStartTime());
        map.put("endTime", line.getEndTime());
        map.put("intervalMins", line.getIntervalMins());
        return map;
    }

    private Map<String, Object> lineEta(Map<String, Object> lineMap, LocalTime now) {
        BusLine line = lineMapper.selectById(Long.valueOf(lineMap.get("lineId").toString()));
        return lineEta(line, now);
    }

    private Map<String, Object> lineEta(BusLine line, LocalTime now) {
        Map<String, Object> eta = new LinkedHashMap<>();
        LocalTime start = line.getStartTime() == null ? LocalTime.of(7, 0) : line.getStartTime();
        LocalTime end = line.getEndTime() == null ? LocalTime.of(22, 30) : line.getEndTime();
        int interval = line.getIntervalMins() == null || line.getIntervalMins() <= 0 ? 15 : line.getIntervalMins();
        eta.put("lineId", line.getId());
        eta.put("lineName", line.getLineName());
        eta.put("lastBus", end.toString());
        eta.put("intervalMins", interval);

        if (now.isBefore(start)) {
            eta.put("running", true);
            eta.put("nextBus", start.toString());
            eta.put("waitMinutes", Math.max(0, (int) Duration.between(now, start).toMinutes()));
            eta.put("nearLastBus", false);
            return eta;
        }
        if (now.isAfter(end)) {
            eta.put("running", false);
            eta.put("nextBus", null);
            eta.put("waitMinutes", 999);
            eta.put("nearLastBus", true);
            return eta;
        }
        long elapsed = Duration.between(start, now).toMinutes();
        long slots = (long) Math.ceil(elapsed / (double) interval);
        LocalTime next = start.plusMinutes(slots * interval);
        if (next.isBefore(now)) next = next.plusMinutes(interval);
        if (next.isAfter(end)) {
            eta.put("running", false);
            eta.put("nextBus", null);
            eta.put("waitMinutes", 999);
            eta.put("nearLastBus", true);
            return eta;
        }
        eta.put("running", true);
        eta.put("nextBus", next.toString());
        eta.put("waitMinutes", Math.max(0, (int) Duration.between(now, next).toMinutes()));
        eta.put("nearLastBus", Duration.between(next, end).toMinutes() <= 30);
        return eta;
    }

    private Map<String, Object> crowding(LocalTime now, String from, String to) {
        String level = "低";
        String reason = "当前不在典型高峰时段";
        if (between(now, 7, 30, 8, 30)) {
            level = "高";
            reason = "早高峰，教学区方向客流较集中";
        } else if (between(now, 11, 40, 12, 30)) {
            level = "中";
            reason = "午间食堂和宿舍方向客流增加";
        } else if (between(now, 17, 30, 18, 30)) {
            level = "高";
            reason = "晚高峰，宿舍和校门方向客流较集中";
        } else if (!now.isBefore(LocalTime.of(21, 30))) {
            level = "中";
            reason = "接近末班时段，请留意末班车风险";
        }
        return Map.of("level", level, "reason", reason, "from", from, "to", to);
    }

    private boolean between(LocalTime time, int sh, int sm, int eh, int em) {
        return !time.isBefore(LocalTime.of(sh, sm)) && !time.isAfter(LocalTime.of(eh, em));
    }

    private BusStation nearestStation(double lat, double lng, List<BusStation> stations) {
        return stations.stream()
                .filter(station -> station.getLatitude() != null && station.getLongitude() != null)
                .min(Comparator.comparingDouble(station -> distanceMeters(lat, lng, station.getLatitude(), station.getLongitude())))
                .orElse(null);
    }

    private BusStation findStationByName(String name, List<BusStation> stations) {
        String target = normalizeName(name);
        return stations.stream()
                .filter(station -> {
                    String candidate = normalizeName(station.getStationName());
                    return candidate.equals(target)
                            || candidate.contains(target)
                            || target.contains(candidate)
                            || stationAliases(station.getStationName()).stream().anyMatch(alias -> {
                        String normalizedAlias = normalizeName(alias);
                        return normalizedAlias.equals(target)
                                || normalizedAlias.contains(target)
                                || target.contains(normalizedAlias);
                    });
                })
                .findFirst()
                .orElse(null);
    }

    private Map<String, Object> walkingOnlyResult(BusStation fromStation, BusStation toStation,
                                                  double walkToStart, double walkFromEnd, String preference) {
        int walkMinutes = Math.max(1, walkMinutes(walkToStart + walkFromEnd));
        Map<String, Object> plan = new LinkedHashMap<>();
        plan.put("type", "walk_only");
        plan.put("lineName", "步行建议");
        plan.put("stations", List.of(fromStation.getStationName(), toStation.getStationName()));
        plan.put("transferCount", 0);
        plan.put("stationCount", 0);
        plan.put("walkToStartMeters", Math.round(walkToStart));
        plan.put("walkFromEndMeters", Math.round(walkFromEnd));
        plan.put("walkToStartMinutes", walkMinutes);
        plan.put("walkFromEndMinutes", 0);
        plan.put("waitMinutes", 0);
        plan.put("rideMinutes", 0);
        plan.put("totalMinutes", walkMinutes);
        plan.put("score", walkMinutes);
        plan.put("eta", Map.of("running", true, "lastBus", "--", "waitMinutes", 0));
        plan.put("crowding", Map.of("level", "低", "reason", "无需乘车"));
        plan.put("summary", "你已经在目的站附近，建议直接步行约" + walkMinutes + "分钟");

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("available", true);
        result.put("algorithm", "CampusBus-Dijkstra multi-factor routing");
        result.put("preference", preference);
        result.put("fromStation", stationMap(fromStation, walkToStart));
        result.put("toStation", stationMap(toStation, walkFromEnd));
        result.put("plans", List.of(plan));
        result.put("best", plan);
        result.put("message", "起终点已在同一站点附近，生成步行建议");
        return result;
    }

    private List<BusStation> mentionedStations(String message, List<BusStation> stations) {
        return stations.stream()
                .map(station -> Map.entry(station, stationMentionIndex(message, station)))
                .filter(entry -> entry.getValue() >= 0)
                .sorted(Comparator.comparingInt(Map.Entry::getValue))
                .map(Map.Entry::getKey)
                .distinct()
                .collect(Collectors.toList());
    }

    private int stationMentionIndex(String message, BusStation station) {
        int best = -1;
        for (String alias : stationAliases(station.getStationName())) {
            int index = message.indexOf(alias);
            if (index >= 0 && (best < 0 || index < best)) best = index;
        }
        if (best >= 0) return best;
        String normalizedMessage = normalizeName(message);
        String normalizedName = normalizeName(station.getStationName());
        return normalizedMessage.contains(normalizedName) ? 9999 : -1;
    }

    private List<String> stationAliases(String stationName) {
        String normalized = normalizeName(stationName);
        List<String> aliases = new ArrayList<>();
        aliases.add(stationName);
        if (normalized.contains("中心图书馆")) aliases.addAll(List.of("图书馆", "中图"));
        if (normalized.contains("八教")) aliases.addAll(List.of("第八教学楼", "8教"));
        if (normalized.contains("一号门")) aliases.addAll(List.of("1号门", "一门"));
        if (normalized.contains("二号门")) aliases.addAll(List.of("2号门", "二门"));
        if (normalized.contains("五号门")) aliases.addAll(List.of("5号门", "五门"));
        return aliases;
    }

    private Map<String, Object> stationMap(BusStation station, double distanceMeters) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("stationId", station.getId());
        map.put("stationName", station.getStationName());
        map.put("latitude", station.getLatitude());
        map.put("longitude", station.getLongitude());
        map.put("distanceMeters", Math.round(distanceMeters));
        return map;
    }

    private String buildNearestSuggestion(String stationName, double distance, Map<String, Object> bestLine) {
        if (bestLine.isEmpty()) {
            return "你附近最近的校车站是" + stationName + "，约" + Math.round(distance) + "米，暂未匹配到运行线路，可查看时刻表。";
        }
        boolean running = Boolean.TRUE.equals(bestLine.get("running"));
        if (!running) {
            return "你附近最近的校车站是" + stationName + "，约" + Math.round(distance) + "米；当前校车可能已停运，建议步行或查看明日班次。";
        }
        return "你附近最近的校车站是" + stationName + "，约" + Math.round(distance) + "米，步行约"
                + walkMinutes(distance) + "分钟。" + bestLine.get("lineName") + "预计"
                + bestLine.get("waitMinutes") + "分钟后发车，建议前往该站乘车。";
    }

    private int walkMinutes(double meters) {
        return Math.max(1, (int) Math.ceil(meters / 75.0));
    }

    private double parseDouble(Object value, double fallback) {
        if (value == null) return fallback;
        try {
            return Double.parseDouble(value.toString());
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private double distanceMeters(double lat1, double lng1, BigDecimal lat2, BigDecimal lng2) {
        if (lat2 == null || lng2 == null) return Double.MAX_VALUE / 4;
        return distanceMeters(lat1, lng1, lat2.doubleValue(), lng2.doubleValue());
    }

    private double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
        double earthRadius = 6371000.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private String normalizeName(String name) {
        if (name == null) return "";
        return name.replaceAll("\\s+", "")
                .replace("西南大学", "")
                .replace("北碚校区", "")
                .replace("（", "")
                .replace("）", "")
                .replace("(", "")
                .replace(")", "")
                .toLowerCase();
    }

    private Map<String, Object> normalizeMap(Map<?, ?> source) {
        Map<String, Object> result = new LinkedHashMap<>();
        source.forEach((key, value) -> result.put(String.valueOf(key), value));
        return result;
    }

    private static class LinePath {
        private final BusLine line;
        private final List<String> stations;

        private LinePath(BusLine line, List<String> stations) {
            this.line = line;
            this.stations = stations;
        }

        private List<String> segment(String from, String to) {
            int start = stations.indexOf(from);
            int end = stations.indexOf(to);
            if (start < 0 || end < 0 || start == end) return List.of();
            if (start < end) return new ArrayList<>(stations.subList(start, end + 1));
            List<String> reversed = new ArrayList<>(stations.subList(end, start + 1));
            Collections.reverse(reversed);
            return reversed;
        }
    }

    private static class RouteCandidate {
        private final BusLine primaryLine;
        private final String lineName;
        private final List<String> stations;
        private final String transferAt;
        private final int transfers;

        private RouteCandidate(BusLine primaryLine, String lineName, List<String> stations, String transferAt, int transfers) {
            this.primaryLine = primaryLine;
            this.lineName = lineName;
            this.stations = stations;
            this.transferAt = transferAt;
            this.transfers = transfers;
        }
    }

    private static class Edge {
        private final String to;
        private final BusLine line;

        private Edge(String to, BusLine line) {
            this.to = to;
            this.line = line;
        }
    }
}
