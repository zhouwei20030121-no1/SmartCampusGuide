package com.swu.guide.modules.ai.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.swu.guide.common.Result;
import com.swu.guide.modules.ai.entity.PromptTemplate;
import com.swu.guide.modules.ai.mapper.PromptTemplateMapper;
import com.swu.guide.modules.ai.service.AiGuideService;
import com.swu.guide.modules.ai.service.AiSessionService;
import com.swu.guide.modules.ai.service.LlmGatewayService;
import com.swu.guide.modules.social.entity.Comment;
import com.swu.guide.modules.social.service.CommentService;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/ai")
public class LlmController {

    private final LlmGatewayService llmGateway;
    private final AiSessionService sessionService;
    private final PromptTemplateMapper promptMapper;
    private final AiGuideService aiGuideService;
    private final CommentService commentService;
    private final SpotService spotService;

    public LlmController(LlmGatewayService llmGateway, AiSessionService sessionService,
                         PromptTemplateMapper promptMapper, AiGuideService aiGuideService,
                         CommentService commentService, SpotService spotService) {
        this.llmGateway = llmGateway;
        this.sessionService = sessionService;
        this.promptMapper = promptMapper;
        this.aiGuideService = aiGuideService;
        this.commentService = commentService;
        this.spotService = spotService;
    }

    /**
     * AI 对话接口（带上下文记忆）。
     * 请求体: { "sessionId": "xxx", "message": "用户问题", "sceneCode": "tour_guide_normal" }
     */
    @PostMapping("/chat")
    public Result<Map<String, Object>> chat(@RequestBody Map<String, String> params) {
        String sessionId = params.getOrDefault("sessionId", UUID.randomUUID().toString());
        String userMessage = params.get("message");
        String sceneCode = params.getOrDefault("sceneCode", "tour_guide_normal");

        if (userMessage == null || userMessage.isBlank()) {
            return Result.fail("message 不能为空");
        }

        // 1. 查 Prompt 模板
        String systemPrompt = loadSystemPrompt(sceneCode);

        // 2. 获取历史上下文
        List<Map<String, String>> history = sessionService.getHistory(sessionId);
        history.add(Map.of("role", "user", "content", userMessage));

        // 3. 调用 DeepSeek
        String reply = llmGateway.chat(systemPrompt, history, null);

        // 4. 存回会话
        sessionService.appendAndSave(sessionId, userMessage, reply);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("reply", reply);
        return Result.ok(result);
    }

    /** AI 讲解词生成（供 Flutter 智能讲解页调用） */
    @GetMapping("/guide/generate")
    public Result<Map<String, Object>> generateGuide(
            @RequestParam String spotName,
            @RequestParam(defaultValue = "新生") String persona,
            @RequestParam(defaultValue = "zh") String language) {
        String text = aiGuideService.generateGuide(spotName, persona, language);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("spotName", spotName);
        result.put("text", text);
        result.put("persona", persona);
        result.put("language", language);
        return Result.ok(result);
    }

    /** 清除会话 */
    /** RAG + persona + language + voice dynamic guide generation. */
    @PostMapping("/guide/dynamic")
    public Result<Map<String, Object>> generateDynamicGuide(@RequestBody Map<String, Object> params) {
        String spotName = String.valueOf(params.getOrDefault("spotName", params.getOrDefault("spot_name", "")));
        if (spotName == null || spotName.isBlank()) {
            return Result.fail("spotName 不能为空");
        }
        return Result.ok(aiGuideService.generateDynamicGuide(params));
    }

    /** Translate guide text between Chinese and English. */
    @PostMapping("/guide/translate")
    public Result<Map<String, Object>> translateGuide(@RequestBody Map<String, Object> params) {
        if (params.get("text") == null || String.valueOf(params.get("text")).isBlank()) {
            return Result.fail("text 不能为空");
        }
        return Result.ok(aiGuideService.translateGuide(params));
    }

    /** Generate a personalized campus story from spot facts and user comments. */
    @PostMapping("/story/generate")
    public Result<Map<String, Object>> generateStory(@RequestBody Map<String, Object> params) {
        String spotName = String.valueOf(params.getOrDefault("spotName", params.getOrDefault("spot_name", "")));
        if (spotName == null || spotName.isBlank()) {
            return Result.fail("spotName 不能为空");
        }
        if (!params.containsKey("comments")) {
            Long spotId = null;
            if (params.get("spotId") != null) {
                spotId = Long.valueOf(String.valueOf(params.get("spotId")));
            } else {
                Spot spot = spotService.lambdaQuery()
                        .like(Spot::getName, spotName)
                        .last("limit 1")
                        .one();
                if (spot != null) {
                    spotId = spot.getId();
                    params.put("spotId", spotId);
                }
            }
            if (spotId != null) {
            List<String> comments = commentService.getBySpotId(spotId).stream()
                    .map(Comment::getContent)
                    .filter(Objects::nonNull)
                    .filter(item -> !item.isBlank())
                    .limit(8)
                    .toList();
            params.put("comments", comments);
            }
        }
        return Result.ok(aiGuideService.generateStory(params));
    }

    @DeleteMapping("/session/{sessionId}")
    public Result<Void> clearSession(@PathVariable String sessionId) {
        sessionService.clear(sessionId);
        return Result.ok();
    }

    private String loadSystemPrompt(String sceneCode) {
        PromptTemplate pt = promptMapper.selectOne(
                new LambdaQueryWrapper<PromptTemplate>()
                        .eq(PromptTemplate::getSceneCode, sceneCode)
                        .eq(PromptTemplate::getEnabled, true));
        return pt != null ? pt.getPromptContent() : "你是西南大学智能导览助手'西小导'，请用友善、专业的语气回答校园相关问题。";
    }
}
