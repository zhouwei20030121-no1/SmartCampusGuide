package com.swu.guide.modules.social.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.social.entity.Checkin;
import com.swu.guide.modules.social.service.CheckinService;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/checkin")
public class CheckinController {

    private final CheckinService checkinService;

    public CheckinController(CheckinService checkinService) {
        this.checkinService = checkinService;
    }

    @PostMapping
    public Result<Checkin> checkin(@RequestBody Map<String, Object> params) {
        Long userId = Long.valueOf(params.get("userId").toString());
        Long spotId = Long.valueOf(params.get("spotId").toString());
        return Result.ok(checkinService.doCheckin(userId, spotId));
    }

    @GetMapping("/badges/{userId}")
    public Result<java.util.List<Checkin>> getUserBadges(@PathVariable Long userId) {
        return Result.ok(checkinService.getUserBadges(userId));
    }

    @GetMapping("/count/{userId}")
    public Result<Integer> getCount(@PathVariable Long userId) {
        return Result.ok(checkinService.getCheckinCount(userId));
    }
}
