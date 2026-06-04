package com.swu.guide.modules.ai.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 调用 Python AI 微服务生成智能讲解词。
 * 如果 Python 不可用，降级为本地模板生成。
 */
@Service
public class AiGuideService {

    private final LlmGatewayService llmGateway;
    private final JdbcTemplate jdbcTemplate;
    private final SpotService spotService;

    @Value("${ai-service.url:http://localhost:5000}")
    private String aiServiceUrl;

    public AiGuideService(LlmGatewayService llmGateway, JdbcTemplate jdbcTemplate, SpotService spotService) {
        this.llmGateway = llmGateway;
        this.jdbcTemplate = jdbcTemplate;
        this.spotService = spotService;
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
                    "请为「" + spotName + "」生成一段300-450字的校园导览讲解词。要求：像一位亲切的学长学姐在带路，语气自然、短句多、适合语音播报，不要像新闻播音稿；尽量包含地点功能、周边环境、建筑特色或历史背景。");
            if (result != null && !result.isBlank()) return result;
        } catch (Exception ignored) {}

        // 3. 完全降级：本地模板
        return templateGuide(spotName, persona);
    }

    public Map<String, Object> generateDynamicGuide(Map<String, Object> params) {
        String spotName = String.valueOf(params.getOrDefault("spotName", params.getOrDefault("spot_name", "")));
        String persona = String.valueOf(params.getOrDefault("persona", "新生"));
        String language = String.valueOf(params.getOrDefault("language", "zh"));
        String voice = String.valueOf(params.getOrDefault("voice", "gentle_guide"));
        String style = String.valueOf(params.getOrDefault("style", "auto"));

        Map<String, Object> req = new LinkedHashMap<>();
        req.put("spot_name", spotName);
        req.put("persona", persona);
        req.put("language", language);
        req.put("voice", voice);
        req.put("style", style);
        req.put("environment", params.getOrDefault("environment", Map.of()));
        req.put("top_k", params.getOrDefault("topK", params.getOrDefault("top_k", 5)));

        try {
            var resp = new org.springframework.web.client.RestTemplate()
                    .postForEntity(aiServiceUrl + "/api/rag/guide/dynamic", req, Map.class);
            Map<String, Object> body = resp.getBody();
            if (body != null && body.get("data") instanceof Map<?, ?> data) {
                Map<String, Object> result = normalizeMap(data);
                persistGuideResource(spotName, persona, language, voice, String.valueOf(result.getOrDefault("text", "")));
                return result;
            }
        } catch (Exception ignored) {}

        Map<String, Object> fallback = new LinkedHashMap<>();
        String text = generateGuide(spotName, persona);
        if (language.toLowerCase().startsWith("en")) {
            text = translateOrTemplateEnglish(spotName, text);
        }
        fallback.put("spotName", spotName);
        fallback.put("spot_name", spotName);
        fallback.put("text", text);
        fallback.put("originalText", language.toLowerCase().startsWith("en") ? generateGuide(spotName, persona) : text);
        fallback.put("persona", persona);
        fallback.put("language", language);
        fallback.put("voice", voice);
        fallback.put("style", style);
        fallback.put("fallback", true);
        persistGuideResource(spotName, persona, language, voice, text);
        return fallback;
    }

    public Map<String, Object> translateGuide(Map<String, Object> params) {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("text", params.getOrDefault("text", ""));
        req.put("target_language", params.getOrDefault("targetLanguage", params.getOrDefault("target_language", "en")));
        req.put("source_language", params.getOrDefault("sourceLanguage", params.getOrDefault("source_language", "zh")));

        try {
            var resp = new org.springframework.web.client.RestTemplate()
                    .postForEntity(aiServiceUrl + "/api/rag/guide/translate", req, Map.class);
            Map<String, Object> body = resp.getBody();
            if (body != null && body.get("data") instanceof Map<?, ?> data) {
                Map<String, Object> result = normalizeMap(data);
                persistStoryResource(spotName, String.valueOf(result.getOrDefault("story", "")));
                return result;
            }
        } catch (Exception ignored) {}

        Map<String, Object> fallback = new LinkedHashMap<>();
        fallback.put("text", params.getOrDefault("text", ""));
        fallback.put("targetLanguage", req.get("target_language"));
        fallback.put("sourceLanguage", req.get("source_language"));
        fallback.put("fallback", true);
        return fallback;
    }

    public Map<String, Object> generateStory(Map<String, Object> params) {
        String spotName = String.valueOf(params.getOrDefault("spotName", params.getOrDefault("spot_name", "")));
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("spot_name", spotName);
        req.put("persona", params.getOrDefault("persona", "新生"));
        req.put("language", params.getOrDefault("language", "zh"));
        req.put("comments", params.getOrDefault("comments", java.util.List.of()));
        req.put("time_context", params.getOrDefault("timeContext", params.getOrDefault("time_context", null)));

        try {
            var resp = new org.springframework.web.client.RestTemplate()
                    .postForEntity(aiServiceUrl + "/api/rag/story/generate", req, Map.class);
            Map<String, Object> body = resp.getBody();
            if (body != null && body.get("data") instanceof Map<?, ?> data) {
                return normalizeMap(data);
            }
        } catch (Exception ignored) {}

        Map<String, Object> fallback = new LinkedHashMap<>();
        fallback.put("spotName", spotName);
        String story = templateStory(
                spotName,
                String.valueOf(req.getOrDefault("persona", "新生")),
                req.get("comments")
        );
        if (String.valueOf(req.getOrDefault("language", "zh")).toLowerCase().startsWith("en")) {
            story = translateOrTemplateEnglishStory(spotName, story);
        }
        fallback.put("story", story);
        fallback.put("persona", req.get("persona"));
        fallback.put("language", req.get("language"));
        fallback.put("fallback", true);
        persistStoryResource(spotName, story);
        return fallback;
    }

    private Map<String, Object> normalizeMap(Map<?, ?> source) {
        Map<String, Object> result = new LinkedHashMap<>();
        source.forEach((key, value) -> result.put(String.valueOf(key), value));
        if (result.containsKey("spot_name") && !result.containsKey("spotName")) {
            result.put("spotName", result.get("spot_name"));
        }
        return result;
    }

    private void persistGuideResource(String spotName, String styleType, String language, String voiceType, String content) {
        if (content == null || content.isBlank()) return;
        Long spotId = resolveSpotId(spotName);
        if (spotId == null) return;
        try {
            jdbcTemplate.update(
                    "insert into ai_explanation(spot_id, style_type, language, content, voice_type) values(?,?,?,?,?)",
                    spotId, styleType, language, content, voiceType
            );
        } catch (Exception ignored) {}
    }

    private void persistStoryResource(String spotName, String storyContent) {
        if (storyContent == null || storyContent.isBlank()) return;
        Long spotId = resolveSpotId(spotName);
        if (spotId == null) return;
        try {
            jdbcTemplate.update(
                    "insert into ai_story(spot_id, source_type, story_content) values(?,?,?)",
                    spotId, "ai_generated", storyContent
            );
        } catch (Exception ignored) {}
    }

    private Long resolveSpotId(String spotName) {
        if (spotName == null || spotName.isBlank()) return null;
        try {
            Spot spot = spotService.lambdaQuery().like(Spot::getName, spotName).last("limit 1").one();
            return spot == null ? null : spot.getId();
        } catch (Exception ignored) {
            return null;
        }
    }

    private String translateOrTemplateEnglish(String spotName, String chineseText) {
        try {
            String translated = llmGateway.chatSimple(
                    "Translate this Chinese campus audio guide into natural English. Keep facts unchanged and do not add Markdown.",
                    chineseText
            );
            if (translated != null && !translated.isBlank()) {
                return translated;
            }
        } catch (Exception ignored) {}
        return "Welcome to " + spotName + ". This is one of the important places on Southwest University's campus. "
                + "As you walk through this area, please notice its daily function, the nearby buildings, and the way students use this space for study, meetings and campus life. "
                + "The current knowledge base has limited detailed records for this spot, so this guide focuses on orientation, atmosphere and visiting suggestions. "
                + "You can complete a check-in here, read other visitors' memories, and continue to the next campus landmark.";
    }

    private String templateStory(String spotName, String persona, Object commentsObj) {
        String comments = "";
        if (commentsObj instanceof Iterable<?> items) {
            StringBuilder builder = new StringBuilder();
            for (Object item : items) {
                if (item != null && !item.toString().isBlank()) {
                    if (!builder.isEmpty()) builder.append("、");
                    builder.append(item.toString().trim());
                }
                if (builder.length() > 120) break;
            }
            comments = builder.toString();
        }
        if (comments.isBlank()) {
            comments = "还没有太多公开评论，第一段记忆正等着被写下";
        }
        String opening = switch (persona) {
            case "校友" -> "给校友的一段回忆";
            case "游客" -> "给来访者的一则校园札记";
            default -> "给新同学的一则校园故事";
        };
        return opening + "：" + spotName + "的故事，常常藏在大家路过时留下的几句话里。"
                + comments + "。这些声音把一个地点变得具体：它不只是地图上的一个名称，也是赶课、等人、拍照、散步和重新回到校园时会想起的坐标。"
                + "如果你现在正站在这里，可以看看周围的道路、建筑和人流，再把自己的感受也写下来。后来的人读到它时，看到的就不只是一处景点，而是一段正在继续生长的校园记忆。";
    }

    private String translateOrTemplateEnglishStory(String spotName, String chineseStory) {
        try {
            String translated = llmGateway.chatSimple(
                    "Translate this Chinese campus story into warm, natural English. Keep it concise and do not add Markdown.",
                    chineseStory
            );
            if (translated != null && !translated.isBlank()) {
                return translated;
            }
        } catch (Exception ignored) {}
        return "A campus story for " + spotName + ": every campus place becomes warmer when people leave their memories there. "
                + "Some visitors hurry to class, some wait for friends, and some return years later with a different feeling. "
                + "Your check-in and comment can become part of this evolving story for the next visitor.";
    }

    private String buildPrompt(String spotName, String persona) {
        String style = switch (persona) {
            case "校友" -> "用怀旧、亲切的语气，唤起美好校园回忆";
            case "游客" -> "用专业、生动的语气，介绍校园文化和建筑特色";
            default -> "用热情、憧憬的语气，欢迎新同学探索校园";
        };
        return "你是西南大学虚拟导游「西小导」。用户是" + persona + "。" + style + "。请像学长学姐一样自然讲解，少用套话，多用短句和停顿。";
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
                    "西南大学作为国家“双一流”建设高校，拥有悠久的历史和深厚的文化积淀。" +
                    spotName + "不仅是一处建筑景观，更体现了百年学府的人文精神与学术传承。欢迎继续探索校园的更多精彩！";
        };
    }
}
