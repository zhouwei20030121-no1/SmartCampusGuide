package com.swu.guide.modules.guide.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("guide_content")
public class GuideContent {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 关联景点ID */
    private Long spotId;

    /** 语言: zh/en/ja */
    private String language;

    /** 讲解标题 */
    private String title;

    /** 讲解文案内容(支持HTML) */
    private String scriptContent;

    /** 讲解音频文件URL */
    private String audioUrl;

    /** 音频原始文件名 */
    private String audioName;

    /** 讲解视频文件URL */
    private String videoUrl;

    /** 视频原始文件名 */
    private String videoName;

    /** 创建时间 */
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    /** 更新时间 */
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    /** 逻辑删除: 0未删除 1已删除 */
    @TableLogic(value = "0", delval = "1")
    @TableField(fill = FieldFill.INSERT)
    private Integer deleted;
}
