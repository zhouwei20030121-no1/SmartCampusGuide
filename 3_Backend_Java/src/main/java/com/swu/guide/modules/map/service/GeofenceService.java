package com.swu.guide.modules.map.service;

import org.springframework.data.geo.*;
import org.springframework.data.redis.connection.RedisGeoCommands;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

@Service
public class GeofenceService {

    private final StringRedisTemplate redis;
    private static final String GEO_KEY = "campus:spots:geo";
    private static final String DWELL_PREFIX = "campus:dwell:";
    private static final double TRIGGER_RADIUS = 50.0; // 米
    private static final long DWELL_SECONDS = 15;      // 驻留秒数

    // 校园景点坐标
    private static final Map<String, Point> CAMPUS_SPOTS = Map.of(
            "25教", new Point(106.421, 29.820),
            "樟树林", new Point(106.428, 29.822),
            "中心图书馆", new Point(106.4308, 29.8235),
            "共青团花园", new Point(106.427, 29.821),
            "行署楼", new Point(106.425, 29.822),
            "第八教学楼", new Point(106.426, 29.823),
            "校史馆", new Point(106.429, 29.824),
            "楠园", new Point(106.424, 29.818),
            "竹园", new Point(106.422, 29.815)
    );

    public GeofenceService(StringRedisTemplate redis) {
        this.redis = redis;
    }

    @PostConstruct
    public void initGeoData() {
        try {
            redis.delete(GEO_KEY);
            for (var e : CAMPUS_SPOTS.entrySet()) {
                redis.opsForGeo().add(GEO_KEY, e.getValue(), e.getKey());
            }
        } catch (Exception ignored) {}
    }

    /**
     * 检测用户附近是否有景点，并进行驻留判定
     * @return 触发讲解的景点名，null表示未触发
     */
    public String checkProximity(String userId, double lng, double lat) {
        try {
            Circle circle = new Circle(new Point(lng, lat),
                    new Distance(TRIGGER_RADIUS, RedisGeoCommands.DistanceUnit.METERS));
            GeoResults<RedisGeoCommands.GeoLocation<String>> results =
                    redis.opsForGeo().radius(GEO_KEY, circle);

            if (results == null || results.getContent().isEmpty()) {
                redis.delete(DWELL_PREFIX + userId); // 离开区域，清除驻留
                return null;
            }

            String spotName = results.getContent().get(0).getContent().getName();
            double distance = results.getContent().get(0).getDistance().getValue();

            String dwellKey = DWELL_PREFIX + userId + ":" + spotName;
            String firstSeen = redis.opsForValue().get(dwellKey);

            if (firstSeen == null) {
                redis.opsForValue().set(dwellKey, String.valueOf(System.currentTimeMillis()),
                        120, TimeUnit.SECONDS);
                return null; // 首次进入，等待驻留
            }

            long elapsed = (System.currentTimeMillis() - Long.parseLong(firstSeen)) / 1000;
            if (elapsed >= DWELL_SECONDS) {
                redis.delete(dwellKey); // 已触发，清除避免重复
                return spotName;
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }
}
