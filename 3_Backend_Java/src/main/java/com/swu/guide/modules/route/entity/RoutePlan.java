package com.swu.guide.modules.route.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@TableName("tour_route")
public class RoutePlan {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 路线名称 */
    private String routeName;

    /** 适用人群 */
    private String targetAudience;

    /** 预计游览时间(分钟) - 系统自动计算 */
    private Integer estimatedTime;

    /** 路线整体介绍 */
    private String description;

    /** 状态: 0禁用 1启用 */
    @TableField(fill = FieldFill.INSERT)
    private Integer status;

    /** 创建时间 */
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    /** 更新时间 */
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    /** 逻辑删除 */
    @TableLogic(value = "0", delval = "1")
    @TableField(fill = FieldFill.INSERT)
    private Integer deleted;

    /** 前端传的景点ID列表（逗号分隔），非数据库字段 */
    @TableField(exist = false)
    private String spotIds;

    /** 前端展示用 - 景点节点列表，非数据库字段 */
    @TableField(exist = false)
    private List<RouteSpotNode> spots;
}
