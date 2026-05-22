package com.swu.guide.modules.route.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_route_plan")
public class RoutePlan extends BaseEntity {
    private Long userId;
    private String name;
    private String spotIds;
    private String routePath;
    private Double totalDistance;
    private Integer estimatedMinutes;
    private String status;
}
