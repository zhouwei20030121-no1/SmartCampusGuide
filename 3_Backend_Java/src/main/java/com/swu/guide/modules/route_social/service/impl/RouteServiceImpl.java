package com.swu.guide.modules.route_social.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.route_social.entity.RoutePlan;
import com.swu.guide.modules.route_social.mapper.RoutePlanMapper;
import com.swu.guide.modules.route_social.service.RouteService;
import org.springframework.stereotype.Service;

@Service
public class RouteServiceImpl extends ServiceImpl<RoutePlanMapper, RoutePlan> implements RouteService {
}
