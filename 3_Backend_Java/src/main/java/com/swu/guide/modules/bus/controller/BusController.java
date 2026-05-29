package com.swu.guide.modules.bus.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.bus.entity.BusLine;
import com.swu.guide.modules.bus.entity.BusStation;
import com.swu.guide.modules.bus.service.BusService;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/bus")
public class BusController {

    private final BusService busService;

    public BusController(BusService busService) {
        this.busService = busService;
    }

    /** APP端：获取所有线路+站点详情 */
    @GetMapping("/lines")
    public Result<List<Map<String, Object>>> getLinesWithStations() {
        return Result.ok(busService.getAllLinesWithStations());
    }

    /** 后台：获取线路列表 */
    @GetMapping("/lines/simple")
    public Result<List<BusLine>> listLines() {
        return Result.ok(busService.listLines());
    }

    /** 后台：获取站点列表 */
    @GetMapping("/stations")
    public Result<List<BusStation>> listStations() {
        return Result.ok(busService.listStations());
    }

    /** 后台：保存/更新线路 */
    @PostMapping("/line")
    public Result<Void> saveLine(@RequestBody BusLine line) {
        busService.saveLine(line);
        return Result.ok();
    }

    /** 后台：删除线路 */
    @DeleteMapping("/line/{id}")
    public Result<Void> deleteLine(@PathVariable Long id) {
        busService.deleteLine(id);
        return Result.ok();
    }
}
