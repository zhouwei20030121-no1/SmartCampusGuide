package com.swu.guide.modules.ai.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.ai.entity.AiStory;
import com.swu.guide.modules.ai.mapper.AiStoryMapper;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.List;
import java.util.Map;

@Service
public class AiStoryService extends ServiceImpl<AiStoryMapper, AiStory> {

    private final SpotService spotService;
    private final AiGuideService aiGuideService;

    public AiStoryService(SpotService spotService, AiGuideService aiGuideService) {
        this.spotService = spotService;
        this.aiGuideService = aiGuideService;
    }

    public Page<AiStory> searchStories(String keyword, Long spotId, String language, int page, int size) {
        Page<AiStory> result = queryStories(keyword, spotId, language, page, size);

        if (result.getRecords().isEmpty() && StringUtils.hasText(language)) {
            result = queryStories(keyword, spotId, "", page, size);
        }
        if (result.getRecords().isEmpty() && spotId != null && StringUtils.hasText(keyword)) {
            result = queryStories("", spotId, language, page, size);
        }
        if (result.getRecords().isEmpty() && spotId != null && StringUtils.hasText(keyword) && StringUtils.hasText(language)) {
            result = queryStories("", spotId, "", page, size);
        }
        if (result.getRecords().isEmpty() && spotId != null && StringUtils.hasText(keyword)) {
            result = queryStories(keyword, null, language, page, size);
        }
        if (result.getRecords().isEmpty() && spotId != null && StringUtils.hasText(keyword) && StringUtils.hasText(language)) {
            result = queryStories(keyword, null, "", page, size);
        }

        result.getRecords().forEach(this::fillSpotName);
        return result;
    }

    private Page<AiStory> queryStories(String keyword, Long spotId, String language, int page, int size) {
        String effectiveKeyword = expandAlias(keyword);
        LambdaQueryWrapper<AiStory> wrapper = new LambdaQueryWrapper<>();
        if (spotId != null) {
            wrapper.eq(AiStory::getSpotId, spotId);
        }
        if (StringUtils.hasText(language)) {
            wrapper.eq(AiStory::getLanguage, language);
        }
        if (StringUtils.hasText(effectiveKeyword)) {
            wrapper.and(w -> w.like(AiStory::getTitle, effectiveKeyword).or().like(AiStory::getStoryContent, effectiveKeyword));
        }
        wrapper.orderByDesc(AiStory::getUpdateTime).orderByDesc(AiStory::getId);
        return page(new Page<>(page, size), wrapper);
    }

    public AiStory getDetail(Long id) {
        AiStory story = getById(id);
        fillSpotName(story);
        return story;
    }

    public AiStory findLatestBySpot(Long spotId, String language) {
        if (spotId == null) return null;
        LambdaQueryWrapper<AiStory> wrapper = new LambdaQueryWrapper<AiStory>()
                .eq(AiStory::getSpotId, spotId)
                .eq(AiStory::getStatus, 1);
        if (StringUtils.hasText(language)) {
            wrapper.eq(AiStory::getLanguage, language);
        }
        wrapper.orderByDesc(AiStory::getUpdateTime).orderByDesc(AiStory::getId).last("limit 1");
        AiStory story = getOne(wrapper);
        fillSpotName(story);
        return story;
    }

    public AiStory generateAndSave(Map<String, Object> params) {
        Map<String, Object> generated = aiGuideService.generateStoryWithAi(params);
        String spotName = String.valueOf(generated.getOrDefault("spotName", params.getOrDefault("spotName", "")));
        Long spotId = resolveSpotId(params, spotName);

        AiStory story = new AiStory();
        story.setSpotId(spotId);
        story.setTitle(String.valueOf(generated.getOrDefault("title", defaultTitle(spotName, params))));
        story.setLanguage(String.valueOf(generated.getOrDefault("language", params.getOrDefault("language", "zh"))));
        story.setSourceType("ai_generated");
        story.setStoryContent(String.valueOf(generated.getOrDefault("story", "")));
        story.setStatus(1);
        save(story);
        fillSpotName(story);
        return story;
    }

    public Long resolveSpotId(Map<String, Object> params, String spotName) {
        Object spotId = params.get("spotId");
        if (spotId != null && !spotId.toString().isBlank()) {
            return Long.valueOf(spotId.toString());
        }
        if (!StringUtils.hasText(spotName)) return null;
        String effectiveSpotName = expandAlias(spotName);

        QueryWrapper<Spot> wrapper = new QueryWrapper<>();
        wrapper.like("name", effectiveSpotName).last("limit 1");
        List<Spot> spots = spotService.list(wrapper);
        Spot spot = spots.isEmpty() ? null : spots.get(0);
        if (spot == null) {
            String normalizedSpotName = normalizeName(effectiveSpotName);
            spot = spotService.list().stream()
                    .filter(item -> namesMatch(normalizedSpotName, normalizeName(item.getName())))
                    .findFirst()
                    .orElse(null);
        }
        return spot == null ? null : spot.getId();
    }

    private String expandAlias(String name) {
        String normalized = normalizeName(name);
        return switch (normalized) {
            case "\u4e2d\u56fe", "\u56fe\u4e66\u9986", "\u4e2d\u5fc3\u9986" -> "\u4e2d\u5fc3\u56fe\u4e66\u9986";
            case "\u516b\u6559", "8\u6559", "\u7b2c\u516b\u6559\u5b66\u697c" -> "\u7b2c\u516b\u6559\u5b66\u697c";
            case "\u7530\u5bb6\u70b3", "\u7530\u5bb6\u70b3\u4e66\u9662" -> "\u7530\u5bb6\u70b3\u6559\u80b2\u4e66\u9662";
            default -> name;
        };
    }

    private void fillSpotName(AiStory story) {
        if (story == null || story.getSpotId() == null) return;
        Spot spot = spotService.getById(story.getSpotId());
        if (spot != null) {
            story.setSpotName(spot.getName());
        }
    }

    private boolean namesMatch(String left, String right) {
        if (!StringUtils.hasText(left) || !StringUtils.hasText(right)) {
            return false;
        }
        return left.contains(right) || right.contains(left);
    }

    private String normalizeName(String name) {
        if (name == null) return "";
        return name
                .replaceAll("\\s+", "")
                .replace("\u3000", "")
                .replace("\u897f\u5357\u5927\u5b66", "")
                .replace("\u5317\u789a\u6821\u533a", "")
                .replace("(", "")
                .replace(")", "")
                .replace("\uFF08", "")
                .replace("\uFF09", "")
                .toLowerCase();
    }

    private String defaultTitle(String spotName, Map<String, Object> params) {
        String language = String.valueOf(params.getOrDefault("language", "zh"));
        return language.equals("zh") ? spotName + "\u7684\u6821\u56ed\u6545\u4e8b" : "Campus story of " + spotName;
    }
}
