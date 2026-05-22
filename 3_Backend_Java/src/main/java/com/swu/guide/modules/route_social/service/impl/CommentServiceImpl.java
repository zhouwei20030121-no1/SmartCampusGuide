package com.swu.guide.modules.route_social.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.route_social.entity.Comment;
import com.swu.guide.modules.route_social.mapper.CommentMapper;
import com.swu.guide.modules.route_social.service.CommentService;
import org.springframework.stereotype.Service;

@Service
public class CommentServiceImpl extends ServiceImpl<CommentMapper, Comment> implements CommentService {
}
