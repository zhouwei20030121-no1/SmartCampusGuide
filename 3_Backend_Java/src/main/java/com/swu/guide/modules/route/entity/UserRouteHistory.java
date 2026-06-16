package com.swu.guide.modules.route.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("user_route_history")
public class UserRouteHistory extends BaseEntity {

    private Long userId;
    private Long startSpotId;
    private Long endSpotId;
    private String startSpotName;
    private String endSpotName;
    private String waypointIds;
    private String waypointNames;
    private String strategy;
    private String userIdentity;
    private Integer distanceMeters;
    private Integer durationMinutes;
    private String routeSummary;
}
