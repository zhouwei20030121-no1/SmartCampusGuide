package com.swu.guide.modules.bus.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.swu.guide.modules.bus.entity.LineStationRelation;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.Map;

@Mapper
public interface LineStationRelationMapper extends BaseMapper<LineStationRelation> {

    @Select("SELECT r.stop_order, r.direction, s.station_name, s.longitude, s.latitude " +
            "FROM line_station_relation r JOIN bus_station s ON r.station_id = s.id " +
            "WHERE r.line_id = #{lineId} ORDER BY r.direction, r.stop_order")
    List<Map<String, Object>> getStationDetailByLine(Long lineId);
}
