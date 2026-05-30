package com.swu.guide.modules.social.entity;

import com.baomidou.mybatisplus.annotation.*;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("spot_comment")
public class Comment extends BaseEntity {

    /** 评论用户ID */
    private Long userId;

    /** 关联景点ID */
    private Long spotId;

    /** 评论内容 */
    private String content;

    /** 评分 1-5 */
    private Double rating;

    /** 审核状态: 0待审核, 1已通过, 2违规驳回 */
    @TableField(fill = FieldFill.INSERT)
    private Integer status;

    /** 驳回原因 */
    private String rejectReason;

    /** 驳回备注 */
    private String rejectNote;

    /** 审核时间 */
    private LocalDateTime reviewTime;

    /** 审核人ID */
    private Long reviewerId;

    /** 父评论ID(回复功能) */
    private Long parentId;

    // ========== 前端展示用字段（非数据库字段） ==========

    /** 用户名 */
    @TableField(exist = false)
    private String username;

    /** 景点名称 */
    @TableField(exist = false)
    private String spotName;
}
