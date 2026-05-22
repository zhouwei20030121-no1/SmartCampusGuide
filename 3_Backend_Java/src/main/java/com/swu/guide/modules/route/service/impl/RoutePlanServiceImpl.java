package com.swu.guide.modules.route.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.route.entity.RoutePlan;
import com.swu.guide.modules.route.mapper.RoutePlanMapper;
import com.swu.guide.modules.route.service.RoutePlanService;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class RoutePlanServiceImpl extends ServiceImpl<RoutePlanMapper, RoutePlan> implements RoutePlanService {

    @Override
    public RoutePlan planRoute(Long userId, String name, List<Long> spotIds) {
        RoutePlan plan = new RoutePlan();
        plan.setUserId(userId);
        plan.setName(name);
        plan.setSpotIds(spotIds.stream().map(String::valueOf).collect(Collectors.joining(",")));
        plan.setStatus("active");
        baseMapper.insert(plan);
        return plan;
    }

    @Override
    public List<RoutePlan> getUserRoutes(Long userId) {
        LambdaQueryWrapper<RoutePlan> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(RoutePlan::getUserId, userId);
        return baseMapper.selectList(wrapper);
    }
}
