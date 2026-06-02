package com.swu.guide.modules.map.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.map.service.GeofenceService;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/location")
public class LocationHeartbeatController {

    private final GeofenceService geofenceService;

    public LocationHeartbeatController(GeofenceService geofenceService) {
        this.geofenceService = geofenceService;
    }

    /**
     * Flutter端每5秒发送GPS心跳
     * 请求体: { "userId": "xxx", "lng": 106.421, "lat": 29.820 }
     */
    @PostMapping("/heartbeat")
    public Result<Map<String, Object>> heartbeat(@RequestBody Map<String, Object> body) {
        String userId = body.get("userId") != null ? body.get("userId").toString() : "anonymous";
        double lng = Double.parseDouble(body.get("lng").toString());
        double lat = Double.parseDouble(body.get("lat").toString());

        String triggered = geofenceService.checkProximity(userId, lng, lat);

        Map<String, Object> result = new LinkedHashMap<>();
        if (triggered != null) {
            result.put("action", "TRIGGER_GUIDE");
            result.put("spotName", triggered);
        } else {
            result.put("action", "KEEP_WALKING");
        }
        return Result.ok(result);
    }
}
