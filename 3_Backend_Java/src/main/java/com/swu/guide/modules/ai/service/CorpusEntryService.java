package com.swu.guide.modules.ai.service;

import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.ai.entity.CorpusEntry;

public interface CorpusEntryService extends IService<CorpusEntry> {
    java.util.List<CorpusEntry> search(String keyword);
}
