package com.swu.guide.modules.ai.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.ai.entity.PromptTemplate;
import com.swu.guide.modules.ai.mapper.PromptTemplateMapper;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/ai/prompt")
public class PromptController {

    private final PromptTemplateMapper promptMapper;

    public PromptController(PromptTemplateMapper promptMapper) {
        this.promptMapper = promptMapper;
    }

    @GetMapping("/list")
    public Result<List<PromptTemplate>> list() {
        return Result.ok(promptMapper.selectList(null));
    }

    @GetMapping("/{id}")
    public Result<PromptTemplate> getById(@PathVariable Long id) {
        return Result.ok(promptMapper.selectById(id));
    }

    @PostMapping
    public Result<Void> save(@RequestBody PromptTemplate prompt) {
        if (prompt.getId() != null) {
            promptMapper.updateById(prompt);
        } else {
            promptMapper.insert(prompt);
        }
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        promptMapper.deleteById(id);
        return Result.ok();
    }
}
