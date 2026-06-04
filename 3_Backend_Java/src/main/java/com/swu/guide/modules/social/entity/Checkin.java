package com.swu.guide.modules.social.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("user_checkin_badge")
public class Checkin {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private Long spotId;
    private String badgeName;
    private LocalDateTime checkinTime;

    @TableField(exist = false)
    private String spotName;

    @TableField(exist = false)
    private String coverImage;

    @TableField(exist = false)
    private String category;
}
