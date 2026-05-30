package com.swu.guide.modules.social.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.social.entity.Comment;
import com.swu.guide.modules.social.service.CommentService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/comment")
public class CommentController {

    private final CommentService commentService;

    public CommentController(CommentService commentService) {
        this.commentService = commentService;
    }

    /**
     * 用户发表评论
     */
    @PostMapping
    public Result<Comment> add(@RequestBody Comment comment) {
        comment.setStatus(0);
        comment.setId(null);
        commentService.save(comment);
        return Result.ok(comment);
    }

    /**
     * 分页搜索评论列表（后台管理用）
     */
    @GetMapping("/list")
    public Result<Page<Comment>> list(
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        return Result.ok(commentService.searchComments(status, keyword, page, size));
    }

    /**
     * 获取各状态统计数量（后台管理用）
     */
    @GetMapping("/stats")
    public Result<Map<String, Long>> stats() {
        return Result.ok(commentService.getStats());
    }

    /**
     * 根据景点ID获取已通过的评论（手机端用）
     */
    @GetMapping("/spot/{spotId}")
    public Result<List<Comment>> getBySpot(@PathVariable Long spotId) {
        return Result.ok(commentService.getBySpotId(spotId));
    }

    /**
     * 审核评论（后台管理用）
     */
    @PutMapping("/review/{id}")
    public Result<Void> review(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Integer status = (Integer) body.get("status");
        String rejectReason = (String) body.get("rejectReason");
        String rejectNote = (String) body.get("rejectNote");
        Long reviewerId = body.get("reviewerId") != null ?
                Long.valueOf(body.get("reviewerId").toString()) : null;

        commentService.review(id, status, rejectReason, rejectNote, reviewerId);
        return Result.ok();
    }

    /**
     * 获取评论详情
     */
    @GetMapping("/{id}")
    public Result<Comment> getById(@PathVariable Long id) {
        Comment comment = commentService.getById(id);
        if (comment == null) {
            return Result.fail("评论不存在");
        }
        return Result.ok(comment);
    }
}
