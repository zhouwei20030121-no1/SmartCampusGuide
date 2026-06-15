package com.swu.guide.modules.ai.controller;

import com.swu.guide.common.Result;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

@RestController
@RequestMapping("/stats")
public class StatsController {

    private final JdbcTemplate jdbcTemplate;

    public StatsController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * 获取近7天访问趋势
     * 返回格式: { dates: ["5/25","5/26",...], counts: [8,10,8,...] }
     */
    @GetMapping("/weekly-visits")
    public Result<Map<String, Object>> weeklyVisits() {
        List<String> dates = new ArrayList<>();
        List<Integer> counts = new ArrayList<>();

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");
        DateTimeFormatter shortFormatter = DateTimeFormatter.ofPattern("M/d");

        for (int i = 6; i >= 0; i--) {
            LocalDate date = LocalDate.now().minusDays(i);
            String dateStr = date.format(formatter);
            String shortDate = date.format(shortFormatter);

            // 统计当天所有行为数量
            String sql = "SELECT COUNT(*) FROM user_behavior_log WHERE DATE(created_at) = ?";
            Integer count = jdbcTemplate.queryForObject(sql, Integer.class, dateStr);

            dates.add(shortDate);
            counts.add(count != null ? count : 0);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("dates", dates);
        result.put("counts", counts);

        return Result.ok(result);
    }

    @PostMapping("/app-visit")
    public Result<Void> recordAppVisit(@RequestBody(required = false) Map<String, Object> body) {
        Map<String, Object> payload = body == null ? Map.of() : body;
        Object userIdValue = payload.get("userId");
        Long userId = null;
        if (userIdValue != null && !userIdValue.toString().isBlank()) {
            try {
                userId = Long.valueOf(userIdValue.toString());
            } catch (NumberFormatException ignored) {
                userId = null;
            }
        }
        String deviceInfo = String.valueOf(payload.getOrDefault("deviceInfo", "mobile_app"));
        jdbcTemplate.update(
                "INSERT INTO user_behavior_log (user_id, action_type, device_info, created_at) VALUES (?, ?, ?, NOW())",
                userId,
                "APP_VISIT",
                deviceInfo
        );
        return Result.ok();
    }
}
