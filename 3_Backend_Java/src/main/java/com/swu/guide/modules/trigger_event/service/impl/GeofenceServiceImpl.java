package com.swu.guide.modules.trigger_event.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.trigger_event.entity.GeofenceEvent;
import com.swu.guide.modules.trigger_event.mapper.GeofenceEventMapper;
import com.swu.guide.modules.trigger_event.service.GeofenceService;
import org.springframework.stereotype.Service;

@Service
public class GeofenceServiceImpl extends ServiceImpl<GeofenceEventMapper, GeofenceEvent> implements GeofenceService {

    @Override
    public void checkAndTrigger(Long userId, double longitude, double latitude) {
        // TODO: 结合 Redis GEO 进行高频地理围栏判定，触发语音讲解
    }
}
