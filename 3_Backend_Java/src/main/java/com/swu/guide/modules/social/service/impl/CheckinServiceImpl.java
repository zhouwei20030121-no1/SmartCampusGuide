package com.swu.guide.modules.social.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.social.entity.Checkin;
import com.swu.guide.modules.social.mapper.CheckinMapper;
import com.swu.guide.modules.social.service.CheckinService;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class CheckinServiceImpl extends ServiceImpl<CheckinMapper, Checkin> implements CheckinService {

    private final SpotService spotService;

    public CheckinServiceImpl(SpotService spotService) {
        this.spotService = spotService;
    }

    @Override
    public Checkin doCheckin(Long userId, Long spotId) {
        LambdaQueryWrapper<Checkin> existingWrapper = new LambdaQueryWrapper<>();
        existingWrapper.eq(Checkin::getUserId, userId)
                .eq(Checkin::getSpotId, spotId)
                .last("limit 1");
        Checkin existing = baseMapper.selectOne(existingWrapper);
        if (existing != null) {
            return fillSpotInfo(existing);
        }

        Checkin checkin = new Checkin();
        checkin.setUserId(userId);
        checkin.setSpotId(spotId);
        int count = getCheckinCount(userId) + 1;
        if (count == 1) checkin.setBadgeName("探索者");
        else if (count >= 5) checkin.setBadgeName("收藏家");
        baseMapper.insert(checkin);
        return fillSpotInfo(checkin);
    }

    @Override
    public List<Checkin> getUserBadges(Long userId) {
        LambdaQueryWrapper<Checkin> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Checkin::getUserId, userId).isNotNull(Checkin::getBadgeName);
        return baseMapper.selectList(wrapper).stream().map(this::fillSpotInfo).toList();
    }

    @Override
    public List<Checkin> getUserHistory(Long userId) {
        LambdaQueryWrapper<Checkin> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Checkin::getUserId, userId)
                .orderByDesc(Checkin::getCheckinTime)
                .orderByDesc(Checkin::getId);
        return baseMapper.selectList(wrapper).stream().map(this::fillSpotInfo).toList();
    }

    @Override
    public Map<String, Object> getUserProgress(Long userId) {
        long checkedCount = getCheckinCount(userId);
        long totalSpotCount = spotService.count();
        Map<String, Object> progress = new LinkedHashMap<>();
        progress.put("checkedCount", checkedCount);
        progress.put("totalSpotCount", totalSpotCount);
        progress.put("percent", totalSpotCount == 0 ? 0 : Math.round(checkedCount * 100.0 / totalSpotCount));
        progress.put("badges", getUserBadges(userId));
        progress.put("history", getUserHistory(userId));
        return progress;
    }

    @Override
    public int getCheckinCount(Long userId) {
        LambdaQueryWrapper<Checkin> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Checkin::getUserId, userId);
        // 已修改：处理 Long 到 int 的转换
        Long count = baseMapper.selectCount(wrapper);
        return count == null ? 0 : count.intValue();
    }

    private Checkin fillSpotInfo(Checkin checkin) {
        if (checkin == null || checkin.getSpotId() == null) {
            return checkin;
        }
        Spot spot = spotService.getById(checkin.getSpotId());
        if (spot != null) {
            checkin.setSpotName(spot.getName());
            checkin.setCoverImage(spot.getCoverImage());
            checkin.setCategory(spot.getCategory());
        }
        return checkin;
    }
}
