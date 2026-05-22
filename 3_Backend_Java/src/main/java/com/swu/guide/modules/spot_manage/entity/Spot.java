package com.swu.guide.modules.spot_manage.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_spot")
public class Spot extends BaseEntity {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String name;

    private String category;

    private String description;

    private String coverImage;

    private String audioUrl;

    private BigDecimal longitude;

    private BigDecimal latitude;

    private Integer geofenceRadius;

    private Integer status;
}
