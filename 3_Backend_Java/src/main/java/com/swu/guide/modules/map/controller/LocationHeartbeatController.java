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
        double speedMps = parseDouble(body.get("speedMps"), 0.0);
        double accuracyMeters = parseDouble(body.get("accuracyMeters"), -1.0);

        Map<String, Object> result = new LinkedHashMap<>(
                geofenceService.checkProximityDetail(userId, lng, lat, speedMps, accuracyMeters));
        return Result.ok(result);
    }

    private double parseDouble(Object value, double fallback) {
        if (value == null) return fallback;
        try {
            return Double.parseDouble(value.toString());
        } catch (NumberFormatException ignored) {
            return fallback;
        }
    }
}
