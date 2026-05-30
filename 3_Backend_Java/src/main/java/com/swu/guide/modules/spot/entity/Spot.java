package com.swu.guide.modules.spot.entity;

import com.baomidou.mybatisplus.annotation.*;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("scenic_spot")
public class Spot extends BaseEntity {

    private String name;
    private String description;
    private String coverImage;
    private String images;
    // audioUrl 和 videoUrl 已删除，由 guide_content 表管理
    private BigDecimal latitude;
    private BigDecimal longitude;
    private Integer triggerRadius;
    private String category;

    @TableField(fill = FieldFill.INSERT)
    private Integer visitCount;

    @TableField(fill = FieldFill.INSERT)
    private Double rating;

    @TableField(fill = FieldFill.INSERT)
    private Integer status;
}
