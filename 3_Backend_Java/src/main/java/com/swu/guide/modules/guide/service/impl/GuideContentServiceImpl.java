package com.swu.guide.modules.guide.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.guide.entity.GuideContent;
import com.swu.guide.modules.guide.mapper.GuideContentMapper;
import com.swu.guide.modules.guide.service.GuideContentService;
import org.springframework.stereotype.Service;

@Service
public class GuideContentServiceImpl
        extends ServiceImpl<GuideContentMapper, GuideContent>
        implements GuideContentService {

    @Override
    public GuideContent getBySpotIdAndLanguage(Long spotId, String language) {
        LambdaQueryWrapper<GuideContent> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(GuideContent::getSpotId, spotId)
                .eq(GuideContent::getLanguage, language);
        return this.getOne(wrapper);
    }
}
