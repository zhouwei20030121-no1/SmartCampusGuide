package com.swu.guide.modules.trigger_event.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.trigger_event.service.GeofenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/trigger")
@RequiredArgsConstructor
public class TriggerController {

    private final GeofenceService geofenceService;

    @PostMapping("/check")
    public Result<Void> checkPosition(@RequestParam Long userId,
                                      @RequestParam double lng,
                                      @RequestParam double lat) {
        geofenceService.checkAndTrigger(userId, lng, lat);
        return Result.ok();
    }
}
