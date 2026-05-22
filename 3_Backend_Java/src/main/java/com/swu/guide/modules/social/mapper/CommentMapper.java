package com.swu.guide.modules.social.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.swu.guide.modules.social.entity.Comment;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface CommentMapper extends BaseMapper<Comment> {
}
