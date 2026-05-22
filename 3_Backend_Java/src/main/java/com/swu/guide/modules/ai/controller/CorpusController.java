package com.swu.guide.modules.ai.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.ai.entity.CorpusEntry;
import com.swu.guide.modules.ai.service.CorpusEntryService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/ai/corpus")
public class CorpusController {

    private final CorpusEntryService corpusEntryService;

    public CorpusController(CorpusEntryService corpusEntryService) {
        this.corpusEntryService = corpusEntryService;
    }

    @GetMapping("/list")
    public Result<Page<CorpusEntry>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        return Result.ok(corpusEntryService.page(new Page<>(page, size)));
    }

    @GetMapping("/search")
    public Result<java.util.List<CorpusEntry>> search(@RequestParam String keyword) {
        return Result.ok(corpusEntryService.search(keyword));
    }

    @PostMapping
    public Result<CorpusEntry> save(@RequestBody CorpusEntry entry) {
        corpusEntryService.saveOrUpdate(entry);
        return Result.ok(entry);
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        corpusEntryService.removeById(id);
        return Result.ok();
    }
}
