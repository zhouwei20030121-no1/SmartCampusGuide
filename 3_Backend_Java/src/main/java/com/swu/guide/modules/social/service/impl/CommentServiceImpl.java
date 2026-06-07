package com.swu.guide.modules.social.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.social.entity.Comment;
import com.swu.guide.modules.social.mapper.CommentMapper;
import com.swu.guide.modules.social.service.CommentService;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class CommentServiceImpl
        extends ServiceImpl<CommentMapper, Comment>
        implements CommentService {

    private final SpotService spotService;

    public CommentServiceImpl(SpotService spotService) {
        this.spotService = spotService;
    }

    @Override
    public Page<Comment> searchComments(Integer status, String keyword, int page, int size) {
        LambdaQueryWrapper<Comment> wrapper = new LambdaQueryWrapper<>();

        // 筛选状态：null表示全部
        if (status != null) {
            wrapper.eq(Comment::getStatus, status);
        }

        // 关键词搜索
        if (StringUtils.hasText(keyword)) {
            wrapper.like(Comment::getContent, keyword);
        }

        // 按ID倒序
        wrapper.orderByDesc(Comment::getId);

        Page<Comment> result = this.page(new Page<>(page, size), wrapper);

        // 填充景点名称和用户名
        for (Comment comment : result.getRecords()) {
            fillDisplayInfo(comment);
        }

        return result;
    }

    @Override
    public void review(Long id, Integer status, String rejectReason,
                       String rejectNote, Long reviewerId) {
        Comment comment = new Comment();
        comment.setId(id);
        comment.setStatus(status);
        comment.setReviewTime(LocalDateTime.now());
        comment.setReviewerId(reviewerId);

        if (status == 2) {
            // 驳回时记录原因和备注
            comment.setRejectReason(rejectReason);
            comment.setRejectNote(rejectNote);
        } else if (status == 1) {
            // 通过时清除驳回信息
            comment.setRejectReason(null);
            comment.setRejectNote(null);
        }

        this.updateById(comment);
        System.out.printf("评论审核 - ID: %d, 状态: %d, 驳回原因: %s%n",
                id, status, rejectReason);
    }

    @Override
    public Map<String, Long> getStats() {
        Map<String, Long> stats = new HashMap<>();

        // 待审核
        LambdaQueryWrapper<Comment> pendingWrapper = new LambdaQueryWrapper<>();
        pendingWrapper.eq(Comment::getStatus, 0);
        stats.put("pending", this.count(pendingWrapper));

        // 已通过
        LambdaQueryWrapper<Comment> approvedWrapper = new LambdaQueryWrapper<>();
        approvedWrapper.eq(Comment::getStatus, 1);
        stats.put("approved", this.count(approvedWrapper));

        // 已驳回
        LambdaQueryWrapper<Comment> rejectedWrapper = new LambdaQueryWrapper<>();
        rejectedWrapper.eq(Comment::getStatus, 2);
        stats.put("rejected", this.count(rejectedWrapper));

        return stats;
    }

    @Override
    public List<Comment> getBySpotId(Long spotId) {
        LambdaQueryWrapper<Comment> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Comment::getSpotId, spotId)
                .eq(Comment::getStatus, 1)
                .orderByDesc(Comment::getId);
        return this.list(wrapper);
    }

    @Override
    public List<Comment> getByUserId(Long userId) {
        LambdaQueryWrapper<Comment> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Comment::getUserId, userId)
                .orderByDesc(Comment::getId);
        List<Comment> comments = this.list(wrapper);
        for (Comment comment : comments) {
            fillDisplayInfo(comment);
        }
        return comments;
    }

    /**
     * 填充展示信息
     */
    private void fillDisplayInfo(Comment comment) {
        // 填充景点名称
        if (comment.getSpotId() != null) {
            try {
                Spot spot = spotService.getById(comment.getSpotId());
                if (spot != null) {
                    comment.setSpotName(spot.getName());
                }
            } catch (Exception e) {
                // 忽略
            }
        }

        // 设置默认用户名
        if (!StringUtils.hasText(comment.getUsername())) {
            comment.setUsername("用户" + comment.getUserId());
        }
    }
}

