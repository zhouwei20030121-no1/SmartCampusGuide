package com.swu.guide.modules.spot.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_spot")
public class Spot extends BaseEntity {
    private String name;
    private String description;
    private String coverImage;
    private String images;
    private String videoUrl;
    private String audioUrl;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private String category;
    private Integer visitCount;
    private Double rating;
}
