package com.swu.guide.modules.map.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.map.entity.MapLocation;
import com.swu.guide.modules.map.mapper.MapLocationMapper;
import com.swu.guide.modules.map.service.MapLocationService;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class MapLocationServiceImpl extends ServiceImpl<MapLocationMapper, MapLocation> implements MapLocationService {

    @Override
    public void uploadLocation(Long userId, BigDecimal lat, BigDecimal lng) {
        MapLocation loc = new MapLocation();
        loc.setUserId(userId);
        loc.setLatitude(lat);
        loc.setLongitude(lng);
        baseMapper.insert(loc);
    }

    @Override
    public List<MapLocation> getNearbyUsers(BigDecimal lat, BigDecimal lng, double radiusKm) {
        double latDelta = radiusKm / 111.0;
        double lngDelta = radiusKm / (111.0 * Math.cos(Math.toRadians(lat.doubleValue())));
        return baseMapper.selectList(null).stream()
                .filter(loc -> {
                    double dLat = loc.getLatitude().subtract(lat).abs().doubleValue();
                    double dLng = loc.getLongitude().subtract(lng).abs().doubleValue();
                    return dLat <= latDelta && dLng <= lngDelta;
                })
                .collect(Collectors.toList());
    }
}
