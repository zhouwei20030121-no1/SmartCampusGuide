package com.swu.guide.modules.guide.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.guide.entity.GuideContent;
import com.swu.guide.modules.guide.mapper.GuideContentMapper;
import com.swu.guide.modules.guide.service.GuideContentService;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class GuideContentServiceImpl extends ServiceImpl<GuideContentMapper, GuideContent> implements GuideContentService {

    @Override
    public List<GuideContent> getBySpotAndLang(Long spotId, String lang) {
        LambdaQueryWrapper<GuideContent> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(GuideContent::getSpotId, spotId).eq(GuideContent::getLanguage, lang);
        return baseMapper.selectList(wrapper);
    }
}
