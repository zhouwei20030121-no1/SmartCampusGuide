package com.swu.guide.modules.bus.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.swu.guide.modules.bus.entity.BusLine;
import com.swu.guide.modules.bus.entity.BusStation;
import com.swu.guide.modules.bus.mapper.BusLineMapper;
import com.swu.guide.modules.bus.mapper.BusStationMapper;
import com.swu.guide.modules.bus.mapper.LineStationRelationMapper;
import org.springframework.stereotype.Service;

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

    /** 获取所有线路（含站点详情） */
    public List<Map<String, Object>> getAllLinesWithStations() {
        List<BusLine> lines = lineMapper.selectList(
                new LambdaQueryWrapper<BusLine>().eq(BusLine::getEnabled, true));
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

            List<Map<String, Object>> stations = relationMapper.getStationDetailByLine(line.getId());
            // 按方向分组
            Map<Integer, List<Map<String, Object>>> grouped = new LinkedHashMap<>();
            for (Map<String, Object> s : stations) {
                int dir = (int) s.get("direction");
                grouped.computeIfAbsent(dir, k -> new ArrayList<>()).add(s);
            }
            item.put("stations", grouped);
            result.add(item);
        }
        return result;
    }

    /** 获取所有线路列表（不含站点） */
    public List<BusLine> listLines() {
        return lineMapper.selectList(null);
    }

    /** 获取所有站点 */
    public List<BusStation> listStations() {
        return stationMapper.selectList(null);
    }

    /** 保存/更新线路 */
    public void saveLine(BusLine line) {
        if (line.getId() != null) lineMapper.updateById(line);
        else lineMapper.insert(line);
    }

    /** 删除线路 */
    public void deleteLine(Long id) {
        lineMapper.deleteById(id);
    }
}
