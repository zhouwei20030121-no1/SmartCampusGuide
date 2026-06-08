package com.swu.guide.modules.ai.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.ai.entity.AiStory;
import com.swu.guide.modules.ai.mapper.AiStoryMapper;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

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
        LambdaQueryWrapper<AiStory> wrapper = new LambdaQueryWrapper<>();
        if (spotId != null) {
            wrapper.eq(AiStory::getSpotId, spotId);
        }
        if (StringUtils.hasText(language)) {
            wrapper.eq(AiStory::getLanguage, language);
        }
        if (StringUtils.hasText(keyword)) {
            wrapper.and(w -> w.like(AiStory::getTitle, keyword).or().like(AiStory::getStoryContent, keyword));
        }
        wrapper.orderByDesc(AiStory::getUpdateTime).orderByDesc(AiStory::getId);
        Page<AiStory> result = page(new Page<>(page, size), wrapper);
        result.getRecords().forEach(this::fillSpotName);
        return result;
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
        Spot spot = spotService.lambdaQuery().like(Spot::getName, spotName).last("limit 1").one();
        if (spot == null) {
            spot = spotService.list().stream()
                    .filter(item -> namesMatch(spotName, item.getName()))
                    .findFirst()
                    .orElse(null);
        }
        return spot == null ? null : spot.getId();
    }

    private void fillSpotName(AiStory story) {
        if (story == null || story.getSpotId() == null) return;
        Spot spot = spotService.getById(story.getSpotId());
        if (spot != null) {
            story.setSpotName(spot.getName());
        }
    }

    private boolean namesMatch(String left, String right) {
        String a = normalizeName(left);
        String b = normalizeName(right);
        return a.contains(b) || b.contains(a);
    }

    private String normalizeName(String name) {
        if (name == null) return "";
        return name
                .replaceAll("[\\s　]", "")
                .replace("西南大学", "")
                .replace("北碚校区", "")
                .replaceAll("[()（）]", "")
                .toLowerCase();
    }

    private String defaultTitle(String spotName, Map<String, Object> params) {
        String language = String.valueOf(params.getOrDefault("language", "zh"));
        return language.equals("zh") ? spotName + "的校园故事" : "Campus story of " + spotName;
    }
}
