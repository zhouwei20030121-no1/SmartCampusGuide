package com.swu.guide.modules.trigger_event.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_geofence_event")
public class GeofenceEvent extends BaseEntity {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long spotId;

    private Long userId;

    private String eventType;

    private String eventData;
}
