package com.swu.guide.modules.spot.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.mapper.SpotMapper;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class SpotServiceImpl
        extends ServiceImpl<SpotMapper, Spot>
        implements SpotService {

    @Override
    public Page<Spot> searchSpot(String keyword, int page, int size) {

        LambdaQueryWrapper<Spot> wrapper = new LambdaQueryWrapper<>();

        // 模糊搜索景点名称
        if (StringUtils.hasText(keyword)) {
            wrapper.like(Spot::getName, keyword);
        }

        // 按ID倒序排列
        wrapper.orderByDesc(Spot::getId);

        // MyBatis-Plus的逻辑删除会自动过滤deleted=true的记录
        return this.page(new Page<>(page, size), wrapper);
    }
}
