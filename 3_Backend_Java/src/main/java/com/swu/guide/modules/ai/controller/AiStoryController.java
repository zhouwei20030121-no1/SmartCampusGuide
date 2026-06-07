package com.swu.guide.modules.ai.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.ai.entity.AiStory;
import com.swu.guide.modules.ai.service.AiStoryService;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/ai/story")
public class AiStoryController {

    private final AiStoryService storyService;

    public AiStoryController(AiStoryService storyService) {
        this.storyService = storyService;
    }

    @GetMapping("/list")
    public Result<Page<AiStory>> list(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(required = false) Long spotId,
            @RequestParam(defaultValue = "") String spotName,
            @RequestParam(defaultValue = "") String language,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        if (spotId == null && !spotName.isBlank()) {
            spotId = storyService.resolveSpotId(Map.of(), spotName);
        }
        return Result.ok(storyService.searchStories(keyword, spotId, language, page, size));
    }

    @GetMapping("/{id}")
    public Result<AiStory> getById(@PathVariable Long id) {
        AiStory story = storyService.getDetail(id);
        if (story == null) {
            return Result.fail("Story not found");
        }
        return Result.ok(story);
    }

    @PostMapping
    public Result<AiStory> save(@RequestBody AiStory story) {
        story.setId(null);
        if (story.getStatus() == null) story.setStatus(1);
        if (story.getSourceType() == null || story.getSourceType().isBlank()) story.setSourceType("manual");
        storyService.save(story);
        return Result.ok(storyService.getDetail(story.getId()));
    }

    @PutMapping("/{id}")
    public Result<AiStory> update(@PathVariable Long id, @RequestBody AiStory story) {
        if (storyService.getById(id) == null) {
            return Result.fail("Story not found");
        }
        story.setId(id);
        storyService.updateById(story);
        return Result.ok(storyService.getDetail(id));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        storyService.removeById(id);
        return Result.ok();
    }

    @PostMapping("/generate-save")
    public Result<AiStory> generateAndSave(@RequestBody Map<String, Object> params) {
        return Result.ok(storyService.generateAndSave(params));
    }
}
