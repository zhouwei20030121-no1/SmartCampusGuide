package com.swu.guide.common.utils;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class AmapUtil {

    @Value("${amap.key}")
    private String amapKey;

    @Value("${amap.direction-url}")
    private String directionUrl;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 缓存：key=起点经纬度_终点经纬度, value=缓存条目
     * 缓存24小时内的计算结果
     */
    private final Map<String, CacheEntry> cache = new ConcurrentHashMap<>();

    /**
     * 缓存条目
     */
    private static class CacheEntry {
        final double distance;  // 米
        final double duration;  // 秒
        final LocalDateTime createTime;

        CacheEntry(double distance, double duration) {
            this.distance = distance;
            this.duration = duration;
            this.createTime = LocalDateTime.now();
        }

        boolean isExpired() {
            return LocalDateTime.now().isAfter(createTime.plusHours(24));
        }
    }

    /**
     * 判断Key是否已配置
     */
    public boolean isConfigured() {
        return amapKey != null && !amapKey.isEmpty() && !amapKey.startsWith("YOUR");
    }

    /**
     * 获取两个坐标点之间的步行距离（米）和预计时间（秒）
     * 优先从缓存获取，缓存未命中则调用高德API
     *
     * @param originLat 起点纬度
     * @param originLng 起点经度
     * @param destLat   终点纬度
     * @param destLng   终点经度
     * @return [距离(米), 时间(秒)]，失败返回null
     */
    public double[] getWalkingDistanceAndTime(BigDecimal originLat, BigDecimal originLng,
                                              BigDecimal destLat, BigDecimal destLng) {
        // 生成缓存key（保留6位小数）
        String cacheKey = buildCacheKey(originLat, originLng, destLat, destLng);

        // 1. 先查缓存
        CacheEntry cached = cache.get(cacheKey);
        if (cached != null && !cached.isExpired()) {
            System.out.println("📦 使用缓存数据 - 距离: " + cached.distance + "米, 时间: " + cached.duration + "秒");
            return new double[]{cached.distance, cached.duration};
        }

        // 2. 缓存未命中，检查Key是否配置
        if (!isConfigured()) {
            System.out.println("⚠️ 高德Key未配置，跳过API调用");
            return null;
        }

        // 3. 调用高德API
        try {
            String origin = originLng + "," + originLat;
            String destination = destLng + "," + destLat;

            String url = String.format(
                    "%s?origin=%s&destination=%s&key=%s",
                    directionUrl, origin, destination, amapKey
            );

            System.out.println("🌐 高德API请求: " + url);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(10))
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request,
                    HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200) {
                JsonNode root = objectMapper.readTree(response.body());

                int status = root.path("status").asInt();
                String info = root.path("info").asText();

                if (status == 1 && "ok".equalsIgnoreCase(info)) {
                    JsonNode route = root.path("route");
                    JsonNode paths = route.path("paths");

                    if (paths.isArray() && paths.size() > 0) {
                        JsonNode firstPath = paths.get(0);
                        double distance = firstPath.path("distance").asDouble();
                        double duration = firstPath.path("duration").asDouble();

                        // 存入缓存
                        cache.put(cacheKey, new CacheEntry(distance, duration));

                        System.out.printf("✅ 高德API返回 - 距离: %.0f米, 时间: %.0f秒 (已缓存)%n",
                                distance, duration);

                        return new double[]{distance, duration};
                    }
                } else {
                    System.out.println("❌ 高德API返回错误: " + info);
                    if (info.contains("EXCEEDED")) {
                        System.out.println("💡 提示: 高德API配额已用完，将使用Haversine公式计算");
                    }
                }
            } else {
                System.out.println("❌ 高德API请求失败，状态码: " + response.statusCode());
            }
        } catch (IOException | InterruptedException e) {
            System.err.println("❌ 高德API调用异常: " + e.getMessage());
        }
        return null;
    }

    /**
     * 构建缓存Key
     * 将经纬度保留6位小数，保证相同路径命中缓存
     */
    private String buildCacheKey(BigDecimal lat1, BigDecimal lng1,
                                 BigDecimal lat2, BigDecimal lng2) {
        String key1 = round(lat1) + "," + round(lng1);
        String key2 = round(lat2) + "," + round(lng2);
        // 保证双向路径使用同一缓存（字母序排列）
        if (key1.compareTo(key2) < 0) {
            return key1 + "→" + key2;
        } else {
            return key2 + "→" + key1;
        }
    }

    /**
     * 四舍五入保留6位小数
     */
    private String round(BigDecimal value) {
        if (value == null) return "0";
        return value.setScale(6, RoundingMode.HALF_UP).toString();
    }

    /**
     * 清除过期缓存（可定时调用）
     */
    public void clearExpiredCache() {
        cache.entrySet().removeIf(entry -> entry.getValue().isExpired());
        System.out.println("🧹 清理过期缓存，当前缓存数量: " + cache.size());
    }

    /**
     * 获取缓存统计信息
     */
    public String getCacheStats() {
        long total = cache.size();
        long expired = cache.values().stream().filter(CacheEntry::isExpired).count();
        return String.format("缓存总数: %d, 已过期: %d, 有效: %d", total, expired, total - expired);
    }
}