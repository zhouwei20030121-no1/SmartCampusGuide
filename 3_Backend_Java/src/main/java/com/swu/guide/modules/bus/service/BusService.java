package com.swu.guide.modules.bus.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.swu.guide.modules.bus.entity.BusLine;
import com.swu.guide.modules.bus.entity.BusStation;
import com.swu.guide.modules.bus.entity.LineStationRelation;
import com.swu.guide.modules.bus.mapper.BusLineMapper;
import com.swu.guide.modules.bus.mapper.BusStationMapper;
import com.swu.guide.modules.bus.mapper.LineStationRelationMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.*;

@Service
public class BusService {

    private final BusLineMapper lineMapper;
    private final BusStationMapper stationMapper;
    private final LineStationRelationMapper relationMapper;

    public BusService(BusLineMapper lineMapper, BusStationMapper stationMapper,
                      LineStationRelationMapper relationMapper) {
        this.lineMapper = lineMapper;
        this.stationMapper = stationMapper;
        this.relationMapper = relationMapper;
    }

    public Page<BusLine> searchLines(String keyword, int page, int size) {
        LambdaQueryWrapper<BusLine> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(keyword)) {
            wrapper.like(BusLine::getLineName, keyword);
        }
        wrapper.orderByAsc(BusLine::getId);
        return lineMapper.selectPage(new Page<>(page, size), wrapper);
    }

    public List<Map<String, Object>> getAllLinesWithStations() {
        List<BusLine> lines = lineMapper.selectList(
                new LambdaQueryWrapper<BusLine>().eq(BusLine::getEnabled, 1));
        List<Map<String, Object>> result = new ArrayList<>();
        for (BusLine line : lines) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("lineId", line.getId());
            item.put("lineName", line.getLineName());
            item.put("startStation", line.getStartStation());
            item.put("startTime", line.getStartTime());
            item.put("endTime", line.getEndTime());
            item.put("intervalMins", line.getIntervalMins());
            item.put("directionType", line.getDirectionType());
            item.put("fareInfo", line.getFareInfo());
            item.put("stations", getLineStations(line.getId()));
            result.add(item);
        }
        return result;
    }

    public Map<Integer, List<Map<String, Object>>> getLineStations(Long lineId) {
        List<Map<String, Object>> stations = relationMapper.getStationDetailByLine(lineId);
        Map<Integer, List<Map<String, Object>>> grouped = new LinkedHashMap<>();
        for (Map<String, Object> s : stations) {
            int dir = (int) s.get("direction");
            grouped.computeIfAbsent(dir, k -> new ArrayList<>()).add(s);
        }
        return grouped;
    }

    public List<BusStation> listStations() {
        return stationMapper.selectList(
                new LambdaQueryWrapper<BusStation>().orderByAsc(BusStation::getId));
    }

    /**
     * 保存线路及站点
     */
    @Transactional
    public void saveLine(BusLine line, String upStationIds, String downStationIds) {
        System.out.println("saveLine - line: " + line.getLineName() + ", id: " + line.getId());
        System.out.println("saveLine - upStationIds: " + upStationIds);
        System.out.println("saveLine - downStationIds: " + downStationIds);

        boolean isUpdate = line.getId() != null;
        if (isUpdate) {
            lineMapper.updateById(line);
            // 删除旧关联
            LambdaQueryWrapper<LineStationRelation> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(LineStationRelation::getLineId, line.getId());
            int deleted = relationMapper.delete(wrapper);
            System.out.println("删除旧站点关联: " + deleted + " 条");
        } else {
            lineMapper.insert(line);
            System.out.println("新增线路，ID: " + line.getId());
        }

        // 保存上行站点
        if (StringUtils.hasText(upStationIds)) {
            saveStations(line.getId(), upStationIds, 0);
        }
        // 保存下行站点
        if (StringUtils.hasText(downStationIds)) {
            saveStations(line.getId(), downStationIds, 1);
        }
    }

    /** 简单更新（不涉及站点） */
    public void updateLine(BusLine line) {
        lineMapper.updateById(line);
    }

    @Transactional
    public void deleteLine(Long id) {
        // 先删除站点关联
        LambdaQueryWrapper<LineStationRelation> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(LineStationRelation::getLineId, id);
        relationMapper.delete(wrapper);

        // 再删除线路
        lineMapper.deleteById(id);
    }

    private void saveStations(Long lineId, String stationIds, int direction) {
        String[] ids = stationIds.split(",");
        int order = 1;
        for (String idStr : ids) {
            String trimmed = idStr.trim();
            if (!StringUtils.hasText(trimmed)) continue;

            LineStationRelation relation = new LineStationRelation();
            relation.setLineId(lineId);
            relation.setStationId(Long.parseLong(trimmed));
            relation.setStopOrder(order++);
            relation.setDirection(direction);
            relationMapper.insert(relation);
        }
        System.out.println("保存方向" + direction + "站点: " + (order - 1) + " 个");
    }
}
