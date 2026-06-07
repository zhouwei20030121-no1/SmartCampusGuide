package com.swu.guide.modules.ai.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;

import java.util.LinkedHashMap;
import java.util.List;
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
        return generateGuide(spotName, persona, "zh");
    }

    public String generateGuide(String spotName, String persona, String language) {
        return generateGuide(spotName, persona, language, "gentle_guide", "auto");
    }

    public String generateGuide(String spotName, String persona, String language, String voice, String style) {
        // 1. 尝试调用 Python AI 微服务
        try {
            Map<String, Object> req = new LinkedHashMap<>();
            req.put("spot_name", spotName);
            req.put("persona", persona);
            req.put("language", language);
            var resp = new org.springframework.web.client.RestTemplate()
                    .postForEntity(aiServiceUrl + "/api/rag/guide/generate", req, Map.class);
            if (resp.getBody() != null) {
                Map<String, Object> data = (Map<String, Object>) resp.getBody().get("data");
                if (data != null && data.get("text") != null) {
                    return stripStageDirections(data.get("text").toString());
                }
            }
        } catch (Exception ignored) {}

        // 2. 降级：直接用 DeepSeek（跳过 Python RAG）
        try {
            String prompt = buildPrompt(spotName, persona, language, voice, style);
            String result = llmGateway.chatSimple(prompt,
                    "请为「" + spotName + "」生成一段300-450字的校园导览讲解词。目标语言：" + languageName(language)
                            + "。要求：语气自然、短句多、适合语音播报；不要写括号里的动作提示、语速提示、舞台说明或 Markdown；根据用户身份调整侧重点；尽量包含地点功能、周边环境、建筑特色或历史背景。");
            if (result != null && !result.isBlank()) return stripStageDirections(result);
        } catch (Exception ignored) {}

        // 3. 完全降级：本地模板
        return translateIfNeeded(spotName, stripStageDirections(templateGuide(spotName, persona)), language);
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
                String text = stripStageDirections(String.valueOf(result.getOrDefault("text", "")));
                result.put("text", translateIfNeeded(spotName, text, language));
                persistGuideResource(spotName, persona, language, voice, String.valueOf(result.getOrDefault("text", "")));
                return result;
            }
        } catch (Exception ignored) {}

        Map<String, Object> fallback = new LinkedHashMap<>();
        String text = generateGuide(spotName, persona, language, voice, style);
        fallback.put("spotName", spotName);
        fallback.put("spot_name", spotName);
        fallback.put("text", stripStageDirections(text));
        fallback.put("originalText", "zh".equalsIgnoreCase(language) ? text : generateGuide(spotName, persona, "zh"));
        fallback.put("persona", persona);
        fallback.put("language", language);
        fallback.put("voice", voice);
        fallback.put("style", style);
        fallback.put("fallback", true);
        persistGuideResource(spotName, persona, language, voice, stripStageDirections(text));
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
                return result;
            }
        } catch (Exception ignored) {}

        Map<String, Object> fallback = new LinkedHashMap<>();
        String sourceText = String.valueOf(params.getOrDefault("text", ""));
        String targetLanguage = String.valueOf(req.get("target_language"));
        fallback.put("text", translateIfNeeded("", sourceText, targetLanguage));
        fallback.put("targetLanguage", req.get("target_language"));
        fallback.put("sourceLanguage", req.get("source_language"));
        fallback.put("fallback", true);
        return fallback;
    }

    public Map<String, Object> generateStory(Map<String, Object> params) {
        return generateStory(params, false);
    }

    public Map<String, Object> generateStoryWithAi(Map<String, Object> params) {
        return generateStory(params, true);
    }

    private Map<String, Object> generateStory(Map<String, Object> params, boolean forceGenerate) {
        String spotName = String.valueOf(params.getOrDefault("spotName", params.getOrDefault("spot_name", "")));
        String language = String.valueOf(params.getOrDefault("language", "zh"));
        if (!forceGenerate) {
            Map<String, Object> existing = findExistingStory(spotName, language);
            if (!existing.isEmpty()) return existing;
        }
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("spot_name", spotName);
        req.put("persona", params.getOrDefault("persona", "新生"));
        req.put("language", language);
        req.put("comments", params.getOrDefault("comments", java.util.List.of()));
        req.put("time_context", params.getOrDefault("timeContext", params.getOrDefault("time_context", null)));

        try {
            var resp = new org.springframework.web.client.RestTemplate()
                    .postForEntity(aiServiceUrl + "/api/rag/story/generate", req, Map.class);
            Map<String, Object> body = resp.getBody();
            if (body != null && body.get("data") instanceof Map<?, ?> data) {
                Map<String, Object> result = normalizeMap(data);
                result.putIfAbsent("title", defaultStoryTitle(spotName, language));
                return result;
            }
        } catch (Exception ignored) {}

        Map<String, Object> fallback = new LinkedHashMap<>();
        fallback.put("spotName", spotName);
        String story = templateStory(
                spotName,
                String.valueOf(req.getOrDefault("persona", "新生")),
                req.get("comments")
        );
        story = translateStoryIfNeeded(spotName, story, language);
        fallback.put("title", defaultStoryTitle(spotName, language));
        fallback.put("story", story);
        fallback.put("persona", req.get("persona"));
        fallback.put("language", req.get("language"));
        fallback.put("fallback", true);
        persistStoryResource(spotName, story, language);
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
        persistStoryResource(spotName, storyContent, "zh");
    }

    private void persistStoryResource(String spotName, String storyContent, String language) {
        if (storyContent == null || storyContent.isBlank()) return;
        Long spotId = resolveSpotId(spotName);
        if (spotId == null) return;
        try {
            jdbcTemplate.update(
                    "insert into ai_story(spot_id, title, language, source_type, story_content, status) values(?,?,?,?,?,1)",
                    spotId, defaultStoryTitle(spotName, language), language, "ai_generated", storyContent
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

    private String translateIfNeeded(String spotName, String sourceText, String language) {
        if (language == null || language.isBlank() || language.equalsIgnoreCase("zh")) {
            return stripStageDirections(sourceText);
        }
        try {
            String translated = llmGateway.chatSimple(
                    "Translate or rewrite this campus audio guide into " + languageName(language)
                            + ". Keep facts unchanged. Use natural speech for audio playback. Do not add Markdown or bracketed stage directions.",
                    sourceText
            );
            if (translated != null && !translated.isBlank()) {
                return stripStageDirections(translated);
            }
        } catch (Exception ignored) {}
        return fallbackGuideByLanguage(spotName, language);
    }

    private String translateStoryIfNeeded(String spotName, String chineseStory, String language) {
        if (language == null || language.isBlank() || language.equalsIgnoreCase("zh")) {
            return chineseStory;
        }
        try {
            String translated = llmGateway.chatSimple(
                    "Translate this Chinese campus story into " + languageName(language)
                            + ". Keep it warm and natural. Do not add Markdown.",
                    chineseStory
            );
            if (translated != null && !translated.isBlank()) {
                return translated;
            }
        } catch (Exception ignored) {}
        return fallbackStoryByLanguage(spotName, language);
    }

    private String fallbackGuideByLanguage(String spotName, String language) {
        return switch (language.toLowerCase()) {
            case "en" -> "Welcome to " + spotName + ". This is an important place on Southwest University's campus. "
                    + "Please notice its daily function, nearby buildings and the way students use this space for study, meetings and campus life.";
            case "ja" -> spotName + "へようこそ。ここは西南大学キャンパスの大切な場所です。周囲の建物や人の流れを見ながら、学びと生活が重なる雰囲気を感じてください。";
            case "fr" -> "Bienvenue a " + spotName + ". C'est un lieu important du campus de l'Universite du Sud-Ouest. Observez ses usages quotidiens, les batiments voisins et la vie etudiante autour de vous.";
            case "ko" -> spotName + "에 오신 것을 환영합니다. 이곳은 서남대학교 캠퍼스의 중요한 장소입니다. 주변 건물과 학생들의 일상을 살펴보며 캠퍼스의 분위기를 느껴 보세요.";
            default -> "Welcome to " + spotName + ". This is an important campus place. Please enjoy the atmosphere and continue exploring Southwest University.";
        };
    }

    private String fallbackStoryByLanguage(String spotName, String language) {
        return switch (language.toLowerCase()) {
            case "en" -> "A campus story for " + spotName + ": every campus place becomes warmer when people leave their memories there. Your check-in and comment can become part of this evolving story.";
            case "ja" -> spotName + "のキャンパスストーリー。人々の記憶が残ると、場所はただの名前ではなく、歩いた時間や出会いを思い出す座標になります。";
            case "fr" -> "Une histoire de campus pour " + spotName + " : un lieu devient plus vivant lorsque les etudiants et les visiteurs y laissent leurs souvenirs.";
            case "ko" -> spotName + "의 캠퍼스 이야기입니다. 사람들이 남긴 기억이 쌓이면, 한 장소는 지도 위의 이름을 넘어 살아 있는 추억이 됩니다.";
            default -> "A campus story for " + spotName + ": every campus place becomes warmer when people leave their memories there.";
        };
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

    private Map<String, Object> findExistingStory(String spotName, String language) {
        Map<String, Object> result = new LinkedHashMap<>();
        Long spotId = resolveSpotId(spotName);
        if (spotId == null) return result;
        try {
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                    "select id, title, language, source_type, story_content from ai_story "
                            + "where spot_id = ? and language = ? and status = 1 and deleted = 0 "
                            + "order by update_time desc, id desc limit 1",
                    spotId, language
            );
            if (!rows.isEmpty()) {
                Map<String, Object> row = rows.get(0);
                result.put("id", row.get("id"));
                result.put("spotName", spotName);
                result.put("title", row.get("title"));
                result.put("language", row.get("language"));
                result.put("sourceType", row.get("source_type"));
                result.put("story", row.get("story_content"));
                result.put("fallback", false);
            }
        } catch (Exception ignored) {}
        return result;
    }

    private String stripStageDirections(String text) {
        if (text == null) return "";
        return text
                .replaceAll("[（(][^）)]*(?:语速|音量|停顿|转身|指向|动作|镜头|表情|放慢|提高|pause|slow|volume|gesture|turn|look)[^）)]*[）)]", "")
                .replaceAll("[\\r\\n]{3,}", "\n\n")
                .replaceAll("[ \\t]{2,}", " ")
                .trim();
    }

    private String languageName(String language) {
        if (language == null) return "Chinese";
        return switch (language.toLowerCase()) {
            case "zh" -> "Chinese";
            case "en" -> "English";
            case "ja" -> "Japanese";
            case "fr" -> "French";
            case "ko" -> "Korean";
            default -> language;
        };
    }

    private String defaultStoryTitle(String spotName, String language) {
        return "zh".equalsIgnoreCase(language) ? spotName + "的校园故事" : "Campus story of " + spotName;
    }

    private String buildPrompt(String spotName, String persona) {
        return buildPrompt(spotName, persona, "zh");
    }

    private String buildPrompt(String spotName, String persona, String language) {
        return buildPrompt(spotName, persona, language, "gentle_guide", "auto");
    }

    private String buildPrompt(String spotName, String persona, String language, String voice, String styleCode) {
        String style = switch (persona) {
            case "校友" -> "面向校友：侧重旧地重游、校园记忆、变化与传承，不要称呼新同学";
            case "游客" -> "面向游客：侧重参观价值、建筑文化、路线提示和拍照观察点，不要称呼新同学";
            default -> "面向新生：侧重入学熟悉、学习生活功能、如何使用这个地点，可以亲切称呼新同学";
        };
        String voiceStyle = switch (voice == null ? "" : voice) {
            case "young_male" -> "播报风格偏清爽、稳重、有活力";
            case "young_female" -> "播报风格偏明亮、亲切、有陪伴感";
            default -> "播报风格偏温柔、慢节奏、适合边走边听";
        };
        String explicitStyle = "auto".equalsIgnoreCase(String.valueOf(styleCode)) ? "" : "额外风格要求：" + styleCode + "。";
        return "你是西南大学虚拟导游「西小导」。用户身份是" + persona + "。" + style
                + "。" + voiceStyle + "。" + explicitStyle + "请使用" + languageName(language) + "输出。像真实导游一样自然讲解，少用套话，多用短句。"
                + "不要输出括号里的动作提示、语速提示、舞台说明或 Markdown。";
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
