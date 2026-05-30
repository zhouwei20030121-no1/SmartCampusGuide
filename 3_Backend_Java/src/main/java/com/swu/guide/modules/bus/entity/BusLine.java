package com.swu.guide.modules.bus.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Data
@TableName("bus_line")
public class BusLine {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String lineName;
    private String startStation;
    private LocalTime startTime;
    private LocalTime endTime;
    private Integer intervalMins;
    private Integer directionType;
    private String fareInfo;
    private String remark;
    private Boolean enabled;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
