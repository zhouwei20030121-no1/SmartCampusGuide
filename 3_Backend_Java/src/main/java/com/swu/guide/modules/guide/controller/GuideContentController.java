package com.swu.guide.modules.guide.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.guide.entity.GuideContent;
import com.swu.guide.modules.guide.service.GuideContentService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/guide")
public class GuideContentController {

    private final GuideContentService guideContentService;

    public GuideContentController(GuideContentService guideContentService) {
        this.guideContentService = guideContentService;
    }

    @GetMapping("/content/{spotId}")
    public Result<java.util.List<GuideContent>> getContent(
            @PathVariable Long spotId,
            @RequestParam(defaultValue = "zh") String lang) {
        return Result.ok(guideContentService.getBySpotAndLang(spotId, lang));
    }

    @PostMapping("/content")
    public Result<GuideContent> save(@RequestBody GuideContent content) {
        guideContentService.saveOrUpdate(content);
        return Result.ok(content);
    }

    @GetMapping("/content/list")
    public Result<java.util.List<GuideContent>> listAll() {
        return Result.ok(guideContentService.list());
    }
}
