package com.swu.guide.modules.ai.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.swu.guide.modules.ai.entity.PromptTemplate;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface PromptTemplateMapper extends BaseMapper<PromptTemplate> {
}
