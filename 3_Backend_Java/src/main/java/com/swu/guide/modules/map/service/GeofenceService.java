package com.swu.guide.modules.map.service;

import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import jakarta.annotation.PostConstruct;
import org.springframework.data.geo.Point;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.TimeUnit;

@Service
public class GeofenceService {

    private final StringRedisTemplate redis;
    private final SpotService spotService;

    private static final String GEO_KEY = "campus:spots:geo";
    private static final double BASE_TRIGGER_RADIUS = 50.0;
    private static final double FAST_PASSING_SPEED_MPS = 1.8;
    private static final long DWELL_SECONDS = 12;
    private static final long COOLDOWN_MINUTES = 30;

    private final List<LocalSpot> localSpots = new CopyOnWriteArrayList<>();
    private final Map<String, Long> dwellStartedAt = new ConcurrentHashMap<>();
    private final Map<String, Long> cooldownUntil = new ConcurrentHashMap<>();

    private static final Map<String, Point> FALLBACK_SPOTS = Map.of(
            "\u4e2d\u5fc3\u56fe\u4e66\u9986", new Point(106.4308, 29.8235),
            "\u5171\u9752\u56e2\u82b1\u56ed", new Point(106.427, 29.821),
            "\u884c\u7f72\u697c", new Point(106.425, 29.822),
            "\u7b2c\u516b\u6559\u5b66\u697c", new Point(106.426, 29.823),
            "\u7af9\u56ed", new Point(106.422, 29.815)
    );

    public GeofenceService(StringRedisTemplate redis, SpotService spotService) {
        this.redis = redis;
        this.spotService = spotService;
    }

    @PostConstruct
    public void initGeoData() {
        refreshGeoData();
    }

    public void refreshGeoData() {
        List<LocalSpot> loaded = loadDbSpots();
        if (loaded.isEmpty()) {
            loaded = loadFallbackSpots();
        }
        localSpots.clear();
        localSpots.addAll(loaded);
        syncRedisGeoData(loaded);
    }

    public String checkProximity(String userId, double lng, double lat, double speedMps, double accuracyMeters) {
        Map<String, Object> result = checkProximityDetail(userId, lng, lat, speedMps, accuracyMeters);
        return "TRIGGER_GUIDE".equals(result.get("action")) ? String.valueOf(result.get("spotName")) : null;
    }

    public Map<String, Object> checkProximityDetail(String userId, double lng, double lat, double speedMps, double accuracyMeters) {
        String safeUserId = normalizeUserId(userId);
        long now = System.currentTimeMillis();
        Map<String, Object> result = new java.util.LinkedHashMap<>();

        if (speedMps >= FAST_PASSING_SPEED_MPS) {
            clearDwellForUser(safeUserId);
            result.put("action", "KEEP_WALKING");
            result.put("confidence", 0.25);
            result.put("reason", "移动速度较快，暂不触发讲解");
            return result;
        }

        LocalSpot nearest = findNearest(lng, lat, triggerRadius(accuracyMeters));
        if (nearest == null) {
            clearDwellForUser(safeUserId);
            result.put("action", "KEEP_WALKING");
            result.put("confidence", 0.0);
            result.put("reason", "尚未进入景点地理围栏");
            return result;
        }

        clearOtherDwellKeys(safeUserId, nearest.name);
        String userSpotKey = safeUserId + ":" + nearest.name;
        Long cooldownEnd = cooldownUntil.get(userSpotKey);
        if (cooldownEnd != null) {
            if (cooldownEnd > now) {
                result.put("action", "KEEP_WALKING");
                result.put("spotName", nearest.name);
                result.put("distanceMeters", Math.round(nearest.distanceMeters));
                result.put("confidence", 0.38);
                result.put("reason", "该景点刚刚讲解过，仍在冷却时间内");
                return result;
            }
            cooldownUntil.remove(userSpotKey);
        }

        Long firstSeen = dwellStartedAt.putIfAbsent(userSpotKey, now);
        if (firstSeen == null) {
            result.put("action", "KEEP_WALKING");
            result.put("spotName", nearest.name);
            result.put("distanceMeters", Math.round(nearest.distanceMeters));
            result.put("confidence", confidence(nearest.distanceMeters, 0, speedMps, accuracyMeters, false));
            result.put("reason", "已进入围栏，开始累计停留时间");
            return result;
        }

        long elapsedSeconds = TimeUnit.MILLISECONDS.toSeconds(now - firstSeen);
        double confidence = confidence(nearest.distanceMeters, elapsedSeconds, speedMps, accuracyMeters, true);
        if (elapsedSeconds < DWELL_SECONDS) {
            result.put("action", "KEEP_WALKING");
            result.put("spotName", nearest.name);
            result.put("distanceMeters", Math.round(nearest.distanceMeters));
            result.put("dwellSeconds", elapsedSeconds);
            result.put("confidence", confidence);
            result.put("reason", "低速靠近景点，继续停留 " + Math.max(0, DWELL_SECONDS - elapsedSeconds) + " 秒后触发");
            return result;
        }

        dwellStartedAt.remove(userSpotKey);
        cooldownUntil.put(userSpotKey, now + TimeUnit.MINUTES.toMillis(COOLDOWN_MINUTES));
        result.put("action", "TRIGGER_GUIDE");
        result.put("spotName", nearest.name);
        result.put("distanceMeters", Math.round(nearest.distanceMeters));
        result.put("dwellSeconds", elapsedSeconds);
        result.put("confidence", confidence);
        result.put("reason", "低速停留" + elapsedSeconds + "秒，距离" + Math.round(nearest.distanceMeters) + "米，定位精度良好");
        return result;
    }

    private List<LocalSpot> loadDbSpots() {
        List<LocalSpot> result = new ArrayList<>();
        try {
            for (Spot spot : spotService.list()) {
                if (spot.getName() == null || spot.getLongitude() == null || spot.getLatitude() == null) {
                    continue;
                }
                result.add(new LocalSpot(
                        spot.getName(),
                        spot.getLongitude().doubleValue(),
                        spot.getLatitude().doubleValue()
                ));
            }
        } catch (Exception ignored) {
            return List.of();
        }
        return result;
    }

    private List<LocalSpot> loadFallbackSpots() {
        return FALLBACK_SPOTS.entrySet().stream()
                .map(entry -> new LocalSpot(entry.getKey(), entry.getValue().getX(), entry.getValue().getY()))
                .toList();
    }

    private void syncRedisGeoData(List<LocalSpot> spots) {
        try {
            redis.delete(GEO_KEY);
            for (LocalSpot spot : spots) {
                redis.opsForGeo().add(GEO_KEY, new Point(spot.lng, spot.lat), spot.name);
            }
        } catch (Exception ignored) {
            // Redis is an optional acceleration layer here; in-memory geofence keeps the app runnable.
        }
    }

    private LocalSpot findNearest(double lng, double lat, double radiusMeters) {
        if (localSpots.isEmpty()) {
            refreshGeoData();
        }
        return localSpots.stream()
                .map(spot -> spot.withDistance(distanceMeters(lat, lng, spot.lat, spot.lng)))
                .filter(spot -> spot.distanceMeters <= radiusMeters)
                .min(Comparator.comparingDouble(spot -> spot.distanceMeters))
                .orElse(null);
    }

    private double triggerRadius(double accuracyMeters) {
        if (accuracyMeters <= 0) {
            return BASE_TRIGGER_RADIUS;
        }
        return Math.max(BASE_TRIGGER_RADIUS, Math.min(90.0, accuracyMeters * 1.6));
    }

    private double confidence(double distanceMeters, long dwellSeconds, double speedMps, double accuracyMeters, boolean sameSpot) {
        double distanceScore = Math.max(0.0, 1.0 - distanceMeters / 90.0) * 0.35;
        double dwellScore = Math.min(1.0, dwellSeconds / (double) DWELL_SECONDS) * 0.25;
        double speedScore = Math.max(0.0, 1.0 - speedMps / FAST_PASSING_SPEED_MPS) * 0.18;
        double accuracyScore = accuracyMeters <= 0 ? 0.12 : Math.max(0.0, 1.0 - accuracyMeters / 80.0) * 0.12;
        double stabilityScore = sameSpot ? 0.10 : 0.0;
        double total = distanceScore + dwellScore + speedScore + accuracyScore + stabilityScore;
        return Math.round(Math.min(0.99, total) * 100.0) / 100.0;
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

    private String normalizeUserId(String userId) {
        if (userId == null || userId.isBlank()) {
            return "anonymous";
        }
        return userId;
    }

    private void clearDwellForUser(String userId) {
        dwellStartedAt.keySet().removeIf(key -> key.startsWith(userId + ":"));
    }

    private void clearOtherDwellKeys(String userId, String activeSpotName) {
        String activeKey = userId + ":" + activeSpotName;
        dwellStartedAt.keySet().removeIf(key -> key.startsWith(userId + ":") && !key.equals(activeKey));
    }

    private static class LocalSpot {
        private final String name;
        private final double lng;
        private final double lat;
        private final double distanceMeters;

        private LocalSpot(String name, double lng, double lat) {
            this(name, lng, lat, 0.0);
        }

        private LocalSpot(String name, double lng, double lat, double distanceMeters) {
            this.name = name;
            this.lng = lng;
            this.lat = lat;
            this.distanceMeters = distanceMeters;
        }

        private LocalSpot withDistance(double distanceMeters) {
            return new LocalSpot(name, lng, lat, distanceMeters);
        }
    }
}
