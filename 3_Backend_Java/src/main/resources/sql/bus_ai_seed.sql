-- SmartCampusGuide 校车智能规划补充数据
-- 运行前请确认 bus_station.station_name 与 bus_line.line_name 没有唯一约束冲突。

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '二号门', 106.421800, 29.821800, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '二号门');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '共青团花园', 106.427000, 29.821000, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '共青团花园');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '中心图书馆', 106.430800, 29.823500, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '中心图书馆');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '八教', 106.426000, 29.823000, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '八教');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '五号门', 106.420600, 29.817400, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '五号门');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '竹园', 106.422000, 29.815000, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '竹园');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '大礼堂', 106.425400, 29.822400, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '大礼堂');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '一号门', 106.431000, 29.819800, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '一号门');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '音乐学院', 106.428500, 29.817800, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '音乐学院');

INSERT INTO bus_station(station_name, longitude, latitude, remark)
SELECT '田家炳', 106.424000, 29.820500, '校车智能规划示例站点'
WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '田家炳');

UPDATE bus_station
SET longitude = CASE station_name
    WHEN '一号门' THEN 106.431000
    WHEN '二号门' THEN 106.421800
    WHEN '共青团花园' THEN 106.427000
    WHEN '中心图书馆' THEN 106.430800
    WHEN '八教' THEN 106.426000
    WHEN '第八教学楼' THEN 106.426000
    WHEN '五号门' THEN 106.420600
    WHEN '竹园' THEN 106.422000
    WHEN '大礼堂' THEN 106.425400
    WHEN '音乐学院' THEN 106.428500
    WHEN '田家炳' THEN 106.424000
    WHEN '田家炳教育书院' THEN 106.424000
    ELSE longitude
  END,
  latitude = CASE station_name
    WHEN '一号门' THEN 29.819800
    WHEN '二号门' THEN 29.821800
    WHEN '共青团花园' THEN 29.821000
    WHEN '中心图书馆' THEN 29.823500
    WHEN '八教' THEN 29.823000
    WHEN '第八教学楼' THEN 29.823000
    WHEN '五号门' THEN 29.817400
    WHEN '竹园' THEN 29.815000
    WHEN '大礼堂' THEN 29.822400
    WHEN '音乐学院' THEN 29.817800
    WHEN '田家炳' THEN 29.820500
    WHEN '田家炳教育书院' THEN 29.820500
    ELSE latitude
  END
WHERE station_name IN ('一号门', '二号门', '共青团花园', '中心图书馆', '八教', '第八教学楼', '五号门', '竹园', '大礼堂', '音乐学院', '田家炳', '田家炳教育书院');

INSERT INTO bus_line(line_name, start_station, start_time, end_time, interval_mins, direction_type, fare_info, remark, enabled)
SELECT '1路循环线', '二号门', '07:00:00', '22:30:00', 15, 1, '校园一卡通 1 元', '智能规划示例线路', 1
WHERE NOT EXISTS (SELECT 1 FROM bus_line WHERE line_name = '1路循环线');

INSERT INTO bus_line(line_name, start_station, start_time, end_time, interval_mins, direction_type, fare_info, remark, enabled)
SELECT '2路教学区线', '竹园', '07:10:00', '18:40:00', 20, 0, '校园一卡通 1 元', '智能规划示例线路', 1
WHERE NOT EXISTS (SELECT 1 FROM bus_line WHERE line_name = '2路教学区线');

DELETE r FROM line_station_relation r
JOIN bus_line l ON r.line_id = l.id
WHERE l.line_name IN ('1路循环线', '2路教学区线');

INSERT INTO line_station_relation(line_id, station_id, stop_order, direction)
SELECT l.id, s.id, x.stop_order, 0
FROM bus_line l
JOIN (
  SELECT '二号门' station_name, 1 stop_order UNION ALL
  SELECT '共青团花园', 2 UNION ALL
  SELECT '中心图书馆', 3 UNION ALL
  SELECT '八教', 4 UNION ALL
  SELECT '五号门', 5
) x
JOIN bus_station s ON s.station_name = x.station_name
WHERE l.line_name = '1路循环线';

INSERT INTO line_station_relation(line_id, station_id, stop_order, direction)
SELECT l.id, s.id, x.stop_order, 0
FROM bus_line l
JOIN (
  SELECT '竹园' station_name, 1 stop_order UNION ALL
  SELECT '二号门', 2 UNION ALL
  SELECT '大礼堂', 3 UNION ALL
  SELECT '中心图书馆', 4
) x
JOIN bus_station s ON s.station_name = x.station_name
WHERE l.line_name = '2路教学区线';
