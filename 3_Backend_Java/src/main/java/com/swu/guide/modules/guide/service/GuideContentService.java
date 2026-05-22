package com.swu.guide.modules.guide.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.guide.entity.GuideContent;

public interface GuideContentService extends IService<GuideContent> {
    java.util.List<GuideContent> getBySpotAndLang(Long spotId, String lang);
}
