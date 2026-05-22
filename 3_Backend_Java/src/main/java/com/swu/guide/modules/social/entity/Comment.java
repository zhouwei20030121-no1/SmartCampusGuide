package com.swu.guide.modules.social.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_comment")
public class Comment extends BaseEntity {
    private Long userId;
    private Long spotId;
    private String content;
    private Integer rating;
    private String status;
    private Long parentId;
}
