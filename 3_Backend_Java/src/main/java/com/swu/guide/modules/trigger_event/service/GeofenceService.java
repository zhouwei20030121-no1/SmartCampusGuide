package com.swu.guide.modules.trigger_event.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.trigger_event.entity.GeofenceEvent;

public interface GeofenceService extends IService<GeofenceEvent> {

    void checkAndTrigger(Long userId, double longitude, double latitude);
}
