package com.swu.guide.modules.social.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.social.entity.Checkin;

public interface CheckinService extends IService<Checkin> {
    Checkin doCheckin(Long userId, Long spotId);
    java.util.List<Checkin> getUserBadges(Long userId);
    java.util.List<Checkin> getUserHistory(Long userId);
    java.util.Map<String, Object> getUserProgress(Long userId);
    int getCheckinCount(Long userId);
}
