package com.swu.guide.modules.bus.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("bus_station")
public class BusStation {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String stationName;
    private BigDecimal longitude;
    private BigDecimal latitude;
    private String remark;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;
}
