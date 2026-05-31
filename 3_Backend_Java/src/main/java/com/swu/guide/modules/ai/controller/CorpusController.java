package com.swu.guide.modules.ai.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.ai.entity.CorpusEntry;
import com.swu.guide.modules.ai.service.CorpusEntryService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/ai/corpus")
public class CorpusController {

    private final CorpusEntryService corpusEntryService;

    public CorpusController(CorpusEntryService corpusEntryService) {
        this.corpusEntryService = corpusEntryService;
    }

    /**
     * 分页搜索语料列表
     */
    @GetMapping("/list")
    public Result<Page<CorpusEntry>> list(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(required = false) String category,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        return Result.ok(corpusEntryService.search(keyword, category, status, page, size));
    }

    /**
     * 获取统计数据
     */
    @GetMapping("/stats")
    public Result<Map<String, Object>> stats() {
        return Result.ok(corpusEntryService.getStats());
    }

    /**
     * 获取所有分类列表
     */
    @GetMapping("/categories")
    public Result<List<String>> categories() {
        return Result.ok(corpusEntryService.getCategories());
    }

    /**
     * 根据ID获取语料
     */
    @GetMapping("/{id}")
    public Result<CorpusEntry> getById(@PathVariable Long id) {
        CorpusEntry entry = corpusEntryService.getById(id);
        if (entry == null) {
            return Result.fail("语料不存在");
        }
        return Result.ok(entry);
    }

    /**
     * 新增语料
     */
    @PostMapping
    public Result<CorpusEntry> save(@RequestBody CorpusEntry entry) {
        entry.setId(null);
        if (entry.getStatus() == null) {
            entry.setStatus(1);
        }
        corpusEntryService.save(entry);
        return Result.ok(entry);
    }

    /**
     * 更新语料
     */
    @PutMapping("/{id}")
    public Result<CorpusEntry> update(@PathVariable Long id, @RequestBody CorpusEntry entry) {
        CorpusEntry existing = corpusEntryService.getById(id);
        if (existing == null) {
            return Result.fail("语料不存在");
        }
        entry.setId(id);
        corpusEntryService.updateById(entry);
        return Result.ok(entry);
    }

    /**
     * 删除语料
     */
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        corpusEntryService.removeById(id);
        return Result.ok();
    }

    /**
     * 更新语料状态
     */
    @PatchMapping("/{id}/status")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        CorpusEntry existing = corpusEntryService.getById(id);
        if (existing == null) {
            return Result.fail("语料不存在");
        }
        Integer status = (Integer) body.get("status");
        CorpusEntry updateEntry = new CorpusEntry();
        updateEntry.setId(id);
        updateEntry.setStatus(status);
        corpusEntryService.updateById(updateEntry);
        return Result.ok();
    }
}
