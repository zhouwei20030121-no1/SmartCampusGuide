package com.swu.guide.modules.ai.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.ai.entity.CorpusEntry;
import com.swu.guide.modules.ai.mapper.CorpusEntryMapper;
import com.swu.guide.modules.ai.service.CorpusEntryService;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CorpusEntryServiceImpl extends ServiceImpl<CorpusEntryMapper, CorpusEntry> implements CorpusEntryService {

    @Override
    public List<CorpusEntry> search(String keyword) {
        LambdaQueryWrapper<CorpusEntry> wrapper = new LambdaQueryWrapper<>();
        wrapper.like(CorpusEntry::getQuestion, keyword)
                .or()
                .like(CorpusEntry::getKeywords, keyword)
                .eq(CorpusEntry::getEnabled, true);
        return baseMapper.selectList(wrapper);
    }
}
