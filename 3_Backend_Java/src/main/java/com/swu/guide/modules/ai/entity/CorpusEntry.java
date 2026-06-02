package com.swu.guide.modules.ai.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("campus_knowledge_base")
public class CorpusEntry {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 关联景点ID */
    private Long spotId;

    /** 知识条目名称/问题 */
    private String title;

    /** 分类 */
    private String category;

    /** 回答/知识内容 */
    private String content;

    /** 关键词（逗号分隔） */
    private String keywords;

    /** 状态: 0停用 1启用 */
    @TableField(fill = FieldFill.INSERT)
    private Integer status;

    /** 创建时间 - 映射数据库 created_at 字段 */
    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    /** 更新时间 - 映射数据库 updated_at 字段 */
    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;

    /** 逻辑删除 */
    @TableLogic(value = "0", delval = "1")
    @TableField(fill = FieldFill.INSERT)
    private Integer deleted;

    // ========== 前端展示用字段 ==========

    @TableField(exist = false)
    private String spotName;
}
