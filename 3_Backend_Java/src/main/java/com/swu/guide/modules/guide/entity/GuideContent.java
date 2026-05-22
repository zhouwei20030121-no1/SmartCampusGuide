package com.swu.guide.modules.guide.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_guide_content")
public class GuideContent extends BaseEntity {
    private Long spotId;
    private String language;
    private String title;
    private String scriptContent;
    private String audioUrl;
    private Integer duration;
    private String triggerRadius;
}
