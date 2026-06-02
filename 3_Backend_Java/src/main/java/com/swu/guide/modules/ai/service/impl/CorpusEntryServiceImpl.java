package com.swu.guide.modules.ai.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.ai.entity.CorpusEntry;
import com.swu.guide.modules.ai.mapper.CorpusEntryMapper;
import com.swu.guide.modules.ai.service.CorpusEntryService;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.*;
import java.util.stream.Collectors;

@Service
public class CorpusEntryServiceImpl
        extends ServiceImpl<CorpusEntryMapper, CorpusEntry>
        implements CorpusEntryService {

    private final SpotService spotService;

    public CorpusEntryServiceImpl(SpotService spotService) {
        this.spotService = spotService;
    }

    @Override
    public Page<CorpusEntry> search(String keyword, String category, Integer status,
                                    int page, int size) {
        LambdaQueryWrapper<CorpusEntry> wrapper = new LambdaQueryWrapper<>();

        if (StringUtils.hasText(keyword)) {
            wrapper.and(w -> w
                    .like(CorpusEntry::getTitle, keyword)
                    .or()
                    .like(CorpusEntry::getKeywords, keyword)
            );
        }

        if (StringUtils.hasText(category)) {
            wrapper.eq(CorpusEntry::getCategory, category);
        }

        if (status != null) {
            wrapper.eq(CorpusEntry::getStatus, status);
        }

        wrapper.orderByDesc(CorpusEntry::getId);

        Page<CorpusEntry> result = this.page(new Page<>(page, size), wrapper);

        for (CorpusEntry entry : result.getRecords()) {
            fillSpotInfo(entry);
        }

        return result;
    }

    @Override
    public List<String> getCategories() {
        LambdaQueryWrapper<CorpusEntry> wrapper = new LambdaQueryWrapper<>();
        wrapper.select(CorpusEntry::getCategory)
                .isNotNull(CorpusEntry::getCategory)
                .ne(CorpusEntry::getCategory, "")
                .groupBy(CorpusEntry::getCategory);

        List<CorpusEntry> list = this.list(wrapper);
        return list.stream()
                .map(CorpusEntry::getCategory)
                .filter(StringUtils::hasText)
                .distinct()
                .collect(Collectors.toList());
    }

    @Override
    public Map<String, Object> getStats() {
        Map<String, Object> stats = new HashMap<>();

        LambdaQueryWrapper<CorpusEntry> enabledWrapper = new LambdaQueryWrapper<>();
        enabledWrapper.eq(CorpusEntry::getStatus, 1);
        stats.put("enabled", this.count(enabledWrapper));

        LambdaQueryWrapper<CorpusEntry> disabledWrapper = new LambdaQueryWrapper<>();
        disabledWrapper.eq(CorpusEntry::getStatus, 0);
        stats.put("disabled", this.count(disabledWrapper));

        stats.put("categories", getCategories().size());

        return stats;
    }

    private void fillSpotInfo(CorpusEntry entry) {
        if (entry.getSpotId() != null) {
            try {
                Spot spot = spotService.getById(entry.getSpotId());
                if (spot != null) {
                    entry.setSpotName(spot.getName());
                }
            } catch (Exception e) {
                // 忽略
            }
        }
    }
}
