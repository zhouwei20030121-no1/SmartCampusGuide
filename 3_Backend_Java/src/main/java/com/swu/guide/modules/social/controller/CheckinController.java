package com.swu.guide.modules.social.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.swu.guide.common.Result;
import com.swu.guide.modules.social.entity.Checkin;
import com.swu.guide.modules.social.service.CheckinService;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/checkin")
public class CheckinController {

    private final CheckinService checkinService;
    private final SpotService spotService;

    public CheckinController(CheckinService checkinService, SpotService spotService) {
        this.checkinService = checkinService;
        this.spotService = spotService;
    }

    @PostMapping
    public Result<Checkin> checkin(@RequestBody Map<String, Object> params) {
        Long userId = Long.valueOf(params.get("userId").toString());
        Long spotId = Long.valueOf(params.get("spotId").toString());
        return Result.ok(checkinService.doCheckin(userId, spotId));
    }

    @PostMapping("/by-spot-name")
    public Result<Checkin> checkinBySpotName(@RequestBody Map<String, Object> params) {
        Long userId = Long.valueOf(params.getOrDefault("userId", 1).toString());
        String spotName = String.valueOf(params.getOrDefault("spotName", "")).trim();
        if (spotName.isBlank()) {
            return Result.fail("spotName 不能为空");
        }
        Spot spot = findSpotByLooseName(spotName);
        if (spot == null) {
            return Result.fail("景点不存在，无法打卡");
        }
        return Result.ok(checkinService.doCheckin(userId, spot.getId()));
    }

    private Spot findSpotByLooseName(String spotName) {
        Spot direct = spotService.getOne(new LambdaQueryWrapper<Spot>()
                .like(Spot::getName, spotName)
                .last("limit 1"));
        if (direct != null) return direct;

        String target = normalizeSpotName(spotName);
        return spotService.list().stream()
                .filter(spot -> {
                    String candidate = normalizeSpotName(spot.getName());
                    return target.contains(candidate)
                            || candidate.contains(target)
                            || hasUsefulOverlap(target, candidate);
                })
                .findFirst()
                .orElse(null);
    }

    private String normalizeSpotName(String name) {
        if (name == null) return "";
        return name
                .replaceAll("[\\s　]", "")
                .replace("西南大学", "")
                .replace("北碚校区", "")
                .replace("北碚", "")
                .replace("校区", "")
                .replaceAll("[()（）]", "")
                .replace("教学楼", "")
                .replace("学院", "")
                .replace("学部", "")
                .toLowerCase();
    }

    private boolean hasUsefulOverlap(String left, String right) {
        if (left.length() < 2 || right.length() < 2) return false;
        int hit = 0;
        for (int i = 0; i < left.length() - 1; i++) {
            if (right.contains(left.substring(i, i + 2))) {
                hit++;
            }
        }
        return hit >= 2;
    }

    @GetMapping("/badges/{userId}")
    public Result<java.util.List<Checkin>> getUserBadges(@PathVariable Long userId) {
        return Result.ok(checkinService.getUserBadges(userId));
    }

    @GetMapping("/history/{userId}")
    public Result<java.util.List<Checkin>> getUserHistory(@PathVariable Long userId) {
        return Result.ok(checkinService.getUserHistory(userId));
    }

    @GetMapping("/progress/{userId}")
    public Result<Map<String, Object>> getUserProgress(@PathVariable Long userId) {
        return Result.ok(checkinService.getUserProgress(userId));
    }

    @GetMapping("/count/{userId}")
    public Result<Integer> getCount(@PathVariable Long userId) {
        return Result.ok(checkinService.getCheckinCount(userId));
    }
}
