package com.swu.guide.modules.ai.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 调用 Python AI 微服务生成智能讲解词。
 * 如果 Python 不可用，降级为本地模板生成。
 */
@Service
public class AiGuideService {

    private final LlmGatewayService llmGateway;

    @Value("${ai-service.url:http://localhost:5000}")
    private String aiServiceUrl;

    public AiGuideService(LlmGatewayService llmGateway) {
        this.llmGateway = llmGateway;
    }

    /**
     * 为指定景点生成 AI 讲解词。
     * @param spotName 景点名称
     * @param persona  用户画像（新生/校友/游客）
     * @return 讲解文本
     */
    public String generateGuide(String spotName, String persona) {
        // 1. 尝试调用 Python AI 微服务
        try {
            Map<String, Object> req = new LinkedHashMap<>();
            req.put("spot_name", spotName);
            req.put("persona", persona);
            var resp = new org.springframework.web.client.RestTemplate()
                    .postForEntity(aiServiceUrl + "/api/rag/guide/generate", req, Map.class);
            if (resp.getBody() != null) {
                Map<String, Object> data = (Map<String, Object>) resp.getBody().get("data");
                if (data != null && data.get("text") != null) {
                    return data.get("text").toString();
                }
            }
        } catch (Exception ignored) {}

        // 2. 降级：直接用 DeepSeek（跳过 Python RAG）
        try {
            String prompt = buildPrompt(spotName, persona);
            String result = llmGateway.chatSimple(prompt,
                    "请为「" + spotName + "」生成一段200-300字的校园导览讲解词。要求：口语化、生动有趣、适合语音播报、包含建筑特色和历史背景。");
            if (result != null && !result.isBlank()) return result;
        } catch (Exception ignored) {}

        // 3. 完全降级：本地模板
        return templateGuide(spotName, persona);
    }

    private String buildPrompt(String spotName, String persona) {
        String style = switch (persona) {
            case "校友" -> "用怀旧、亲切的语气，唤起美好校园回忆";
            case "游客" -> "用专业、生动的语气，介绍校园文化和建筑特色";
            default -> "用热情、憧憬的语气，欢迎新同学探索校园";
        };
        return "你是西南大学虚拟导游「西小导」。用户是" + persona + "。" + style + "。";
    }

    private String templateGuide(String spotName, String persona) {
        return switch (persona) {
            case "新生" -> "欢迎来到" + spotName + "！作为西大新人，你将在这里开启一段精彩的大学生活。" +
                    spotName + "是校园内极具代表性的地标，不仅有着独特的建筑风格，更承载着西南大学百余年的历史底蕴。" +
                    "这里每天都有无数师生往来穿梭，充满了浓厚的学术氛围与青春活力。请带着好奇心，慢慢感受这片美丽校园的每一处风景吧！";
            case "校友" -> "又见面了，" + spotName + "。时光荏苒，这里的一砖一瓦都承载着属于西大人的青春记忆。" +
                    "还记得那些在这里度过的日日夜夜吗？无论是清晨的晨读、午后的闲谈，还是傍晚的漫步，" +
                    spotName + "见证了无数西大学子的成长与蜕变。欢迎常回来看看，这里永远是您的精神家园。";
            default -> "您现在看到的是西南大学" + spotName + "，这是校园内最具代表性的地标之一。" +
                    "西南大学作为国家"双一流"建设高校，拥有悠久的历史和深厚的文化积淀。" +
                    spotName + "不仅是一处建筑景观，更体现了百年学府的人文精神与学术传承。欢迎继续探索校园的更多精彩！";
        };
    }
}
