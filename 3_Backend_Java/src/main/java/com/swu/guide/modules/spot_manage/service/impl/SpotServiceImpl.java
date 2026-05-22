package com.swu.guide.modules.spot_manage.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.spot_manage.entity.Spot;
import com.swu.guide.modules.spot_manage.mapper.SpotMapper;
import com.swu.guide.modules.spot_manage.service.SpotService;
import org.springframework.stereotype.Service;

@Service
public class SpotServiceImpl extends ServiceImpl<SpotMapper, Spot> implements SpotService {
}
