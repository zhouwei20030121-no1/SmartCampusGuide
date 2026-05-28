package com.swu.guide.modules.guide.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.guide.entity.GuideContent;
import com.swu.guide.modules.guide.service.GuideContentService;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/guide/content")
public class GuideContentController {

    private final GuideContentService guideContentService;
    private final SpotService spotService;

    public GuideContentController(GuideContentService guideContentService, SpotService spotService) {
        this.guideContentService = guideContentService;
        this.spotService = spotService;
    }

    /**
     * 获取讲解内容
     */
    @GetMapping("/{spotId}")
    public Result<GuideContent> getContent(
            @PathVariable Long spotId,
            @RequestParam(defaultValue = "zh") String language) {

        GuideContent content = guideContentService.getBySpotIdAndLanguage(spotId, language);
        return Result.ok(content);
    }

    /**
     * 新增讲解内容
     */
    @PostMapping
    public Result<GuideContent> save(@RequestBody GuideContent content) {
        content.setId(null);
        guideContentService.save(content);
        return Result.ok(content);
    }

    /**
     * 更新讲解内容
     */
    @PutMapping("/{id}")
    public Result<GuideContent> update(@PathVariable Long id, @RequestBody GuideContent content) {
        GuideContent existing = guideContentService.getById(id);
        if (existing == null) {
            return Result.fail("内容不存在");
        }
        content.setId(id);
        guideContentService.updateById(content);
        return Result.ok(content);
    }

    /**
     * 删除讲解内容
     */
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        guideContentService.removeById(id);
        return Result.ok();
    }

    /**
     * AI生成文案
     */
    @PostMapping("/generate")
    public Result<String> generate(@RequestBody GuideContent request) {
        Long spotId = request.getSpotId();
        String language = request.getLanguage();

        // 获取景点名称
        Spot spot = spotService.getById(spotId);
        String spotName = spot != null ? spot.getName() : "该景点";

        String script = generateScriptByLanguage(spotName, language, spot);
        return Result.ok(script);
    }

    /**
     * 根据语言生成文案（后续可替换为真正的AI接口）
     */
    private String generateScriptByLanguage(String spotName, String language, Spot spot) {
        String description = spot != null && spot.getDescription() != null ? spot.getDescription() : "";

        return switch (language) {
            case "en" -> String.format(
                    "<h3>%s</h3>" +
                            "<p>Welcome to this beautiful spot on campus.</p>" +
                            "<p>%s</p>" +
                            "<p>We hope you enjoy your visit here and take wonderful memories with you.</p>",
                    spotName, description
            );
            case "ja" -> String.format(
                    "<h3>%s</h3>" +
                            "<p>キャンパス内の美しいスポットへようこそ。</p>" +
                            "<p>%s</p>" +
                            "<p>素敵な思い出を作ってください。</p>",
                    spotName, description
            );
            default -> String.format(
                    "<h3>%s</h3>" +
                            "<p>欢迎来到校园内这处美丽的景点。</p>" +
                            "<p>%s</p>" +
                            "<p>希望您在这里度过愉快的时光，留下美好的回忆。</p>",
                    spotName, description
            );
        };
    }
}
