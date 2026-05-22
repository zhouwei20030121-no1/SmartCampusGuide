package com.swu.guide.modules.spot_manage.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.spot_manage.entity.Spot;
import com.swu.guide.modules.spot_manage.service.SpotService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/spot")
@RequiredArgsConstructor
public class SpotController {

    private final SpotService spotService;

    @GetMapping("/page")
    public Result<IPage<Spot>> page(@RequestParam(defaultValue = "1") int current,
                                    @RequestParam(defaultValue = "10") int size) {
        return Result.ok(spotService.page(new Page<>(current, size)));
    }

    @GetMapping("/{id}")
    public Result<Spot> getById(@PathVariable Long id) {
        return Result.ok(spotService.getById(id));
    }

    @PostMapping
    public Result<Void> save(@RequestBody Spot spot) {
        spotService.save(spot);
        return Result.ok();
    }

    @PutMapping("/{id}")
    public Result<Void> update(@PathVariable Long id, @RequestBody Spot spot) {
        spot.setId(id);
        spotService.updateById(spot);
        return Result.ok();
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        spotService.removeById(id);
        return Result.ok();
    }
}
