package com.swu.guide.modules.social.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_checkin")
public class Checkin extends BaseEntity {
    private Long userId;
    private Long spotId;
    private String badgeName;
}
