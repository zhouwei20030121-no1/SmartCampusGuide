package com.swu.guide.modules.map.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.math.BigDecimal;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_map_location")
public class MapLocation extends BaseEntity {
    private Long userId;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private BigDecimal accuracy;
    private String deviceInfo;
}
