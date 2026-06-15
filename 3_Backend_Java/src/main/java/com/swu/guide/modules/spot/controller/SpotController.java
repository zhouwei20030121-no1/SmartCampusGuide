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

    /**
     * 分页 + 搜索
     */
    @GetMapping("/list")
    public Result<Page<Spot>> list(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {

        return Result.ok(
                spotService.searchSpot(keyword, page, size)
        );
    }

    /**
     * 查看详情
     */
    @GetMapping("/{id}")
    public Result<Spot> getById(@PathVariable Long id) {
        Spot spot = spotService.getById(id);
        if (spot == null) {
            return Result.fail("景点不存在");
        }
        spotService.lambdaUpdate()
                .eq(Spot::getId, id)
                .setSql("visit_count = COALESCE(visit_count, 0) + 1")
                .update();
        return Result.ok(spotService.getById(id));
    }

    /**
     * 新增景点
     */
    @PostMapping
    public Result<Spot> save(@RequestBody Spot spot) {
        // 清除id，确保是新增而不是更新
        spot.setId(null);

        // MyMetaObjectHandler会自动填充createTime、updateTime、deleted、status
        spotService.save(spot);
        return Result.ok(spot);
    }

    /**
     * 更新景点（支持部分更新）
     */
    @PutMapping("/{id}")
    public Result<Spot> update(@PathVariable Long id, @RequestBody Spot spot) {
        // 检查景点是否存在
        Spot existingSpot = spotService.getById(id);
        if (existingSpot == null) {
            return Result.fail("景点不存在");
        }

        // 设置ID确保更新正确的记录
        spot.setId(id);

        // MyMetaObjectHandler会自动更新updateTime
        spotService.updateById(spot);

        // 返回更新后的景点信息
        Spot updatedSpot = spotService.getById(id);
        return Result.ok(updatedSpot);
    }

    /**
     * 更新景点状态（仅更新状态字段）
     */
    @PatchMapping("/{id}/status")
    public Result<Void> updateStatus(
            @PathVariable Long id,
            @RequestBody Spot spot) {

        // 检查景点是否存在
        Spot existingSpot = spotService.getById(id);
        if (existingSpot == null) {
            return Result.fail("景点不存在");
        }

        // 只更新状态
        Spot updateSpot = new Spot();
        updateSpot.setId(id);
        updateSpot.setStatus(spot.getStatus());

        // MyMetaObjectHandler会自动更新updateTime
        spotService.updateById(updateSpot);
        return Result.ok();
    }

    /**
     * 删除景点（逻辑删除）
     */
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable Long id) {
        Spot spot = spotService.getById(id);
        if (spot == null) {
            return Result.fail("景点不存在");
        }

        spotService.removeById(id);
        return Result.ok();
    }
}
