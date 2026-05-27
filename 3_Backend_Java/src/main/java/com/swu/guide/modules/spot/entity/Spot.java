package com.swu.guide.modules.spot.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("scenic_spot")
public class Spot extends BaseEntity {

    // 景点名称
    private String name;

    // 景点介绍
    private String description;

    // 封面图
    private String coverImage;

    // 轮播图(JSON数组)
    private String images;

    // 视频地址
    private String videoUrl;

    // 音频地址
    private String audioUrl;

    // 纬度
    private BigDecimal latitude;

    // 经度
    private BigDecimal longitude;

    // 地理围栏触发半径
    private Integer triggerRadius;

    // 景点分类
    private String category;

    // 访问量
    private Integer visitCount;

    // 评分
    private Double rating;

    // 状态 0-禁用 1-启用
    @TableField(fill = FieldFill.INSERT)
    private Integer status;
}
