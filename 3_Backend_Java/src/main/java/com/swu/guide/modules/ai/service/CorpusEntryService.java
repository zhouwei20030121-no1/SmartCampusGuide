package com.swu.guide.modules.ai.service;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.IService;
import com.swu.guide.modules.ai.entity.CorpusEntry;

import java.util.List;
import java.util.Map;

public interface CorpusEntryService extends IService<CorpusEntry> {

    /**
     * 分页搜索语料
     */
    Page<CorpusEntry> search(String keyword, String category, Integer status, int page, int size);

    /**
     * 获取所有分类
     */
    List<String> getCategories();

    /**
     * 获取统计数据
     */
    Map<String, Object> getStats();
}
