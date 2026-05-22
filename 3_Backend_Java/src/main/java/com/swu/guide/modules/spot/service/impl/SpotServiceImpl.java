package com.swu.guide.modules.spot.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.mapper.SpotMapper;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;

@Service
public class SpotServiceImpl extends ServiceImpl<SpotMapper, Spot> implements SpotService {
}
