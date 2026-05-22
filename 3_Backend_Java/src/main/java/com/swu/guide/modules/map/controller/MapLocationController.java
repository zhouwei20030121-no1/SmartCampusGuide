package com.swu.guide.modules.map.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.map.entity.MapLocation;
import com.swu.guide.modules.map.service.MapLocationService;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/map")
public class MapLocationController {

    private final MapLocationService mapLocationService;

    public MapLocationController(MapLocationService mapLocationService) {
        this.mapLocationService = mapLocationService;
    }

    @PostMapping("/location/upload")
    public Result<Void> uploadLocation(@RequestBody Map<String, Object> params) {
        Long userId = Long.valueOf(params.get("userId").toString());
        BigDecimal lat = new BigDecimal(params.get("latitude").toString());
        BigDecimal lng = new BigDecimal(params.get("longitude").toString());
        mapLocationService.uploadLocation(userId, lat, lng);
        return Result.ok();
    }

    @GetMapping("/location/nearby")
    public Result<java.util.List<MapLocation>> getNearby(
            @RequestParam BigDecimal lat,
            @RequestParam BigDecimal lng,
            @RequestParam(defaultValue = "1.0") double radius) {
        return Result.ok(mapLocationService.getNearbyUsers(lat, lng, radius));
    }
}
