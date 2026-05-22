package com.swu.guide.modules.ai.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.swu.guide.common.BaseEntity;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("t_corpus_entry")
public class CorpusEntry extends BaseEntity {
    private Long spotId;
    private String question;
    private String answer;
    private String category;
    private String keywords;
    private Boolean enabled;
}
