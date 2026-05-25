package com.swu.guide.modules.ai.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("sys_prompt_template")
public class PromptTemplate {
    @TableId(type = IdType.AUTO)
    private Long id;

    /** 场景标识：tour_guide_normal / tour_guide_humor / story_generator */
    private String sceneCode;

    /** 场景名称（展示用） */
    private String sceneName;

    /** 提示词内容 */
    private String promptContent;

    /** 备注 */
    private String remark;

    /** 是否启用 */
    private Boolean enabled;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
