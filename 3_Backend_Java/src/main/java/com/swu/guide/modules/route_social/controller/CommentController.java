package com.swu.guide.modules.route_social.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.route_social.entity.Comment;
import com.swu.guide.modules.route_social.service.CommentService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/comment")
@RequiredArgsConstructor
public class CommentController {

    private final CommentService commentService;

    @GetMapping("/page")
    public Result<IPage<Comment>> page(@RequestParam(defaultValue = "1") int current,
                                       @RequestParam(defaultValue = "10") int size,
                                       @RequestParam(required = false) Integer status) {
        Page<Comment> page = new Page<>(current, size);
        if (status != null) {
            commentService.lambdaQuery().eq(Comment::getStatus, status).page(page);
        } else {
            commentService.page(page);
        }
        return Result.ok(page);
    }

    @PutMapping("/{id}/audit")
    public Result<Void> audit(@PathVariable Long id, @RequestParam Integer status) {
        Comment comment = new Comment();
        comment.setId(id);
        comment.setStatus(status);
        commentService.updateById(comment);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        commentService.removeById(id);
        return Result.ok();
    }
}
