package com.swu.guide.modules.social.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.social.entity.Checkin;
import com.swu.guide.modules.social.mapper.CheckinMapper;
import com.swu.guide.modules.social.service.CheckinService;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CheckinServiceImpl extends ServiceImpl<CheckinMapper, Checkin> implements CheckinService {

    @Override
    public Checkin doCheckin(Long userId, Long spotId) {
        Checkin checkin = new Checkin();
        checkin.setUserId(userId);
        checkin.setSpotId(spotId);
        int count = getCheckinCount(userId) + 1;
        if (count == 1) checkin.setBadgeName("探索者");
        else if (count >= 5) checkin.setBadgeName("收藏家");
        baseMapper.insert(checkin);
        return checkin;
    }

    @Override
    public List<Checkin> getUserBadges(Long userId) {
        LambdaQueryWrapper<Checkin> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Checkin::getUserId, userId).isNotNull(Checkin::getBadgeName);
        return baseMapper.selectList(wrapper);
    }

    @Override
    public int getCheckinCount(Long userId) {
        LambdaQueryWrapper<Checkin> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Checkin::getUserId, userId);
        // 已修改：处理 Long 到 int 的转换
        Long count = baseMapper.selectCount(wrapper);
        return count == null ? 0 : count.intValue();
    }
}