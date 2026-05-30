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

    @GetMapping("/lines")
    public Result<List<Map<String, Object>>> getLinesWithStations() {
        return Result.ok(busService.getAllLinesWithStations());
    }

    @GetMapping("/lines/simple")
    public Result<List<BusLine>> listLines() {
        return Result.ok(busService.listLines());
    }

    @GetMapping("/stations")
    public Result<List<BusStation>> listStations() {
        return Result.ok(busService.listStations());
    }

    @PostMapping("/line")
    public Result<Void> saveLine(@RequestBody BusLine line) {
        busService.saveLine(line);
        return Result.ok();
    }

    @DeleteMapping("/line/{id}")
    public Result<Void> deleteLine(@PathVariable Long id) {
        busService.deleteLine(id);
        return Result.ok();
    }
}
