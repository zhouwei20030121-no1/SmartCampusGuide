package com.swu.guide.modules.spot.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/spot")
public class SpotController {

    private final SpotService spotService;

    public SpotController(SpotService spotService) {
        this.spotService = spotService;
    }

    @GetMapping("/list")
    public Result<Page<Spot>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        return Result.ok(spotService.page(new Page<>(page, size)));
    }

    @GetMapping("/{id}")
    public Result<Spot> getById(@PathVariable Long id) {
        return Result.ok(spotService.getById(id));
    }

    @PostMapping
    public Result<Spot> save(@RequestBody Spot spot) {
        spotService.saveOrUpdate(spot);
        return Result.ok(spot);
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        spotService.removeById(id);
        return Result.ok();
    }
}
