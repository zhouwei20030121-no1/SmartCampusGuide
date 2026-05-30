package com.swu.guide.modules.social.service;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.social.entity.Comment;

import java.util.List;
import java.util.Map;

public interface CommentService extends IService<Comment> {

    /**
     * 分页搜索评论
     */
    Page<Comment> searchComments(Integer status, String keyword, int page, int size);

    /**
     * 审核评论
     */
    void review(Long id, Integer status, String rejectReason, String rejectNote, Long reviewerId);

    /**
     * 获取各状态统计数量
     */
    Map<String, Long> getStats();

    /**
     * 根据景点ID获取已通过的评论（手机端用）
     */
    List<Comment> getBySpotId(Long spotId);
}
