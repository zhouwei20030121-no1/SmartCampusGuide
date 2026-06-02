package com.swu.guide.modules.ai.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.swu.guide.common.Result;
import com.swu.guide.modules.ai.entity.PromptTemplate;
import com.swu.guide.modules.ai.mapper.PromptTemplateMapper;
import com.swu.guide.modules.ai.service.AiGuideService;
import com.swu.guide.modules.ai.service.AiSessionService;
import com.swu.guide.modules.ai.service.LlmGatewayService;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/ai")
public class LlmController {

    private final LlmGatewayService llmGateway;
    private final AiSessionService sessionService;
    private final PromptTemplateMapper promptMapper;
    private final AiGuideService aiGuideService;

    public LlmController(LlmGatewayService llmGateway, AiSessionService sessionService,
                         PromptTemplateMapper promptMapper, AiGuideService aiGuideService) {
        this.llmGateway = llmGateway;
        this.sessionService = sessionService;
        this.promptMapper = promptMapper;
        this.aiGuideService = aiGuideService;
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
            @RequestParam(defaultValue = "新生") String persona) {
        String text = aiGuideService.generateGuide(spotName, persona);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("spotName", spotName);
        result.put("text", text);
        result.put("persona", persona);
        return Result.ok(result);
    }

    /** 清除会话 */
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
