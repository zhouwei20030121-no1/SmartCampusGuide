package com.swu.guide.modules.bus.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

@Data
@TableName("line_station_relation")
public class LineStationRelation {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long lineId;
    private Long stationId;
    private Integer stopOrder;
    private Integer direction;
}
