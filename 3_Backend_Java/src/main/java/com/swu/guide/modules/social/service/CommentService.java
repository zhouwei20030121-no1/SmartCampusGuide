package com.swu.guide.modules.social.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.social.entity.Comment;

public interface CommentService extends IService<Comment> {
    void review(Long commentId, String status);
    java.util.List<Comment> getBySpotId(Long spotId);
}
