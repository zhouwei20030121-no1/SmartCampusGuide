package com.swu.guide.modules.social.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.social.entity.Comment;
import com.swu.guide.modules.social.mapper.CommentMapper;
import com.swu.guide.modules.social.service.CommentService;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CommentServiceImpl extends ServiceImpl<CommentMapper, Comment> implements CommentService {

    @Override
    public void review(Long commentId, String status) {
        Comment comment = baseMapper.selectById(commentId);
        if (comment != null) {
            comment.setStatus(status);
            baseMapper.updateById(comment);
        }
    }

    @Override
    public List<Comment> getBySpotId(Long spotId) {
        LambdaQueryWrapper<Comment> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Comment::getSpotId, spotId).eq(Comment::getStatus, "approved");
        return baseMapper.selectList(wrapper);
    }
}
