package com.swu.guide.modules.social.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.social.entity.Comment;
import com.swu.guide.modules.social.service.CommentService;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/comment")
public class CommentController {

    private final CommentService commentService;

    public CommentController(CommentService commentService) {
        this.commentService = commentService;
    }

    @PostMapping
    public Result<Comment> add(@RequestBody Comment comment) {
        comment.setStatus("pending");
        commentService.save(comment);
        return Result.ok(comment);
    }

    @GetMapping("/spot/{spotId}")
    public Result<java.util.List<Comment>> getBySpot(@PathVariable Long spotId) {
        return Result.ok(commentService.getBySpotId(spotId));
    }

    @PutMapping("/review/{id}")
    public Result<Void> review(@PathVariable Long id, @RequestBody Map<String, String> params) {
        commentService.review(id, params.get("status"));
        return Result.ok();
    }

    @GetMapping("/pending")
    public Result<java.util.List<Comment>> listPending() {
        return Result.ok(commentService.list());
    }
}
