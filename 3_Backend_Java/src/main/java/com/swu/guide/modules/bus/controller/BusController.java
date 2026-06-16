package com.swu.guide.modules.bus.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.common.Result;
import com.swu.guide.modules.bus.entity.BusLine;
import com.swu.guide.modules.bus.entity.BusStation;
import com.swu.guide.modules.bus.service.BusService;
import org.springframework.web.bind.annotation.*;

import java.time.LocalTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/bus")
public class BusController {

    private final BusService busService;

    public BusController(BusService busService) {
        this.busService = busService;
    }

    @GetMapping("/line/list")
    public Result<Page<BusLine>> listLines(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        return Result.ok(busService.searchLines(keyword, page, size));
    }

    @GetMapping("/lines")
    public Result<List<Map<String, Object>>> getLinesWithStations() {
        return Result.ok(busService.getAllLinesWithStations());
    }

    @GetMapping("/line/{id}/stations")
    public Result<Map<Integer, List<Map<String, Object>>>> getLineStations(@PathVariable Long id) {
        return Result.ok(busService.getLineStations(id));
    }

    @GetMapping("/stations")
    public Result<List<BusStation>> listStations() {
        return Result.ok(busService.listStations());
    }

    @GetMapping("/nearest")
    public Result<Map<String, Object>> nearestStation(
            @RequestParam double lat,
            @RequestParam double lng) {
        return Result.ok(busService.nearestRecommendation(lat, lng));
    }

    @PostMapping("/plan")
    public Result<Map<String, Object>> planCommute(@RequestBody Map<String, Object> body) {
        return Result.ok(busService.planCommute(body));
    }

    @PostMapping("/assistant")
    public Result<Map<String, Object>> assistant(@RequestBody Map<String, Object> body) {
        return Result.ok(busService.assistant(body));
    }

    @PostMapping("/guide/prefetch")
    public Result<Map<String, Object>> prefetchGuide(@RequestBody Map<String, Object> body) {
        return Result.ok(busService.prefetchGuide(body));
    }

    @PostMapping("/line")
    public Result<Void> saveLine(@RequestBody Map<String, Object> body) {
        System.out.println("收到保存请求: " + body);

        BusLine line = new BusLine();
        Object idObj = body.get("id");
        if (idObj != null && !idObj.toString().isEmpty()) {
            line.setId(Long.valueOf(idObj.toString()));
        }

        line.setLineName((String) body.get("lineName"));
        line.setStartStation((String) body.get("startStation"));
        line.setFareInfo((String) body.get("fareInfo"));
        line.setRemark((String) body.get("remark"));

        // 时间
        Object st = body.get("startTime");
        if (st != null && !st.toString().isEmpty()) {
            try {
                String ts = st.toString();
                if (ts.length() > 8) ts = ts.substring(0, 8);
                line.setStartTime(LocalTime.parse(ts));
            } catch (Exception e) { System.out.println("解析startTime失败: " + st); }
        }

        Object et = body.get("endTime");
        if (et != null && !et.toString().isEmpty()) {
            try {
                String ts = et.toString();
                if (ts.length() > 8) ts = ts.substring(0, 8);
                line.setEndTime(LocalTime.parse(ts));
            } catch (Exception e) { System.out.println("解析endTime失败: " + et); }
        }

        // 数字字段
        line.setIntervalMins(getInt(body, "intervalMins", 15));
        line.setDirectionType(getInt(body, "directionType", 0));

        String upStationIds = (String) body.get("upStationIds");
        String downStationIds = (String) body.get("downStationIds");

        System.out.println("upStationIds: " + upStationIds);
        System.out.println("downStationIds: " + downStationIds);

        busService.saveLine(line, upStationIds, downStationIds);
        return Result.ok();
    }

    @DeleteMapping("/line/{id}")
    public Result<Void> deleteLine(@PathVariable Long id) {
        busService.deleteLine(id);
        return Result.ok();
    }

    @PatchMapping("/line/{id}/status")
    public Result<Void> updateStatus(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Integer enabled = (Integer) body.get("enabled");
        BusLine line = new BusLine();
        line.setId(id);
        line.setEnabled(enabled);
        busService.updateLine(line);
        return Result.ok();
    }

    private int getInt(Map<String, Object> body, String key, int defaultValue) {
        Object val = body.get(key);
        if (val != null) {
            return Integer.valueOf(val.toString());
        }
        return defaultValue;
    }
}
