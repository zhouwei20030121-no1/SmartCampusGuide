package com.swu.guide.modules.guide.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.guide.entity.GuideContent;

public interface GuideContentService extends IService<GuideContent> {

    /**
     * 根据景点ID和语言获取讲解内容
     */
    GuideContent getBySpotIdAndLanguage(Long spotId, String language);
}
