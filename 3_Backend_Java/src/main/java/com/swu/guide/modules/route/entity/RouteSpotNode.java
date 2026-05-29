package com.swu.guide.modules.route.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("route_spot_node")
public class RouteSpotNode {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 关联路线ID */
    private Long routeId;

    /** 关联景点ID */
    private Long spotId;

    /** 游览顺序 */
    private Integer sortOrder;

    /** 创建时间 */
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    /** 前端展示用 - 景点名称 */
    @TableField(exist = false)
    private String spotName;

    /** 前端展示用 - 景点分类 */
    @TableField(exist = false)
    private String spotCategory;

    /** 前端展示用 - 景点描述 */
    @TableField(exist = false)
    private String spotDescription;

    /** 前端展示用 - 景点封面图 */
    @TableField(exist = false)
    private String spotCoverImage;
}
