package com.swu.guide.modules.route.controller;

import com.swu.guide.common.Result;
import com.swu.guide.modules.route.service.RoutePlanService;
import com.swu.guide.modules.spot.entity.Spot;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/route") 
public class RoutePlanController {

    @Autowired
    private RoutePlanService routePlanService;

    // 新增的最优路线规划接口
    @GetMapping("/plan/optimal")
    public Result<List<Spot>> getOptimalRoute(
            @RequestParam("startId") Long startId,
            @RequestParam("endId") Long endId,
            @RequestParam(value = "isPopularityFirst", defaultValue = "false") Boolean isPopularityFirst) {
        
        List<Spot> optimalPath = routePlanService.calculateOptimalRoute(startId, endId, isPopularityFirst);
        
        if (optimalPath == null || optimalPath.isEmpty()) {
            // 已修复：改为调用 Result.fail()
            return Result.fail("无法规划出可用路线"); 
        }
        
        // 已修复：改为调用 Result.ok()
        return Result.ok(optimalPath); 
    }
}