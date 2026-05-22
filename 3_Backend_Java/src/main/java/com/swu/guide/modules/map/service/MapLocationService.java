package com.swu.guide.modules.map.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.map.entity.MapLocation;

public interface MapLocationService extends IService<MapLocation> {
    void uploadLocation(Long userId, java.math.BigDecimal lat, java.math.BigDecimal lng);
    java.util.List<MapLocation> getNearbyUsers(java.math.BigDecimal lat, java.math.BigDecimal lng, double radiusKm);
}
