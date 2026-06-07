-- Southwest University campus bus routes 1-8.
-- This script replaces the old wrong campus bus lines with the official 1-8 routes.

DELETE FROM line_station_relation;
DELETE FROM bus_line;

INSERT INTO bus_station (station_name, remark)
SELECT '六号门', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '六号门');
INSERT INTO bus_station (station_name, remark)
SELECT '共青团花园', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '共青团花园');
INSERT INTO bus_station (station_name, remark)
SELECT '大礼堂', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '大礼堂');
INSERT INTO bus_station (station_name, remark)
SELECT '田家炳', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '田家炳');
INSERT INTO bus_station (station_name, remark)
SELECT '五号门', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '五号门');
INSERT INTO bus_station (station_name, remark)
SELECT '二号门', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '二号门');
INSERT INTO bus_station (station_name, remark)
SELECT '楠园', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '楠园');
INSERT INTO bus_station (station_name, remark)
SELECT '中心图书馆', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '中心图书馆');
INSERT INTO bus_station (station_name, remark)
SELECT '八教', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '八教');
INSERT INTO bus_station (station_name, remark)
SELECT '行署楼', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '行署楼');
INSERT INTO bus_station (station_name, remark)
SELECT '西师街', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '西师街');
INSERT INTO bus_station (station_name, remark)
SELECT '后山竹园', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '后山竹园');
INSERT INTO bus_station (station_name, remark)
SELECT '工程技术学院', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '工程技术学院');
INSERT INTO bus_station (station_name, remark)
SELECT '地科院', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '地科院');
INSERT INTO bus_station (station_name, remark)
SELECT '五教', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '五教');
INSERT INTO bus_station (station_name, remark)
SELECT '梅园', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '梅园');
INSERT INTO bus_station (station_name, remark)
SELECT '橘园', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '橘园');
INSERT INTO bus_station (station_name, remark)
SELECT '禾丰楼', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '禾丰楼');
INSERT INTO bus_station (station_name, remark)
SELECT '外办', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '外办');
INSERT INTO bus_station (station_name, remark)
SELECT '北区幼儿园', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '北区幼儿园');
INSERT INTO bus_station (station_name, remark)
SELECT '博物馆', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '博物馆');
INSERT INTO bus_station (station_name, remark)
SELECT '十五教', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '十五教');
INSERT INTO bus_station (station_name, remark)
SELECT '楠园第二食堂', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '楠园第二食堂');
INSERT INTO bus_station (station_name, remark)
SELECT '竹园', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '竹园');
INSERT INTO bus_station (station_name, remark)
SELECT '音乐学院', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '音乐学院');
INSERT INTO bus_station (station_name, remark)
SELECT '一号门', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '一号门');
INSERT INTO bus_station (station_name, remark)
SELECT '外国语学院', '校车站点' WHERE NOT EXISTS (SELECT 1 FROM bus_station WHERE station_name = '外国语学院');

INSERT INTO bus_line(line_name,start_station,start_time,end_time,interval_mins,direction_type,fare_info,remark,enabled)
VALUES('1路','六号门','07:00:00','22:30:00',20,1,'校园一卡通 1元','六号门至五号门，途经共青团花园、大礼堂、田家炳；发车频率不高。',1);
SET @line_id = LAST_INSERT_ID();
INSERT INTO line_station_relation(line_id,station_id,stop_order,direction) VALUES
(@line_id,(SELECT id FROM bus_station WHERE station_name='六号门' LIMIT 1),1,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='共青团花园' LIMIT 1),2,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),3,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='田家炳' LIMIT 1),4,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='五号门' LIMIT 1),5,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='田家炳' LIMIT 1),6,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),7,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='共青团花园' LIMIT 1),8,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='六号门' LIMIT 1),9,0);

INSERT INTO bus_line(line_name,start_station,start_time,end_time,interval_mins,direction_type,fare_info,remark,enabled)
VALUES('2路','六号门','07:00:00','18:30:00',20,0,'校园一卡通 1元','六号门至五号门，唯一经过西师街，途经八教和李园小吃街附近；发车频率不高。',1);
SET @line_id = LAST_INSERT_ID();
INSERT INTO line_station_relation(line_id,station_id,stop_order,direction) VALUES
(@line_id,(SELECT id FROM bus_station WHERE station_name='六号门' LIMIT 1),1,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='二号门' LIMIT 1),2,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='共青团花园' LIMIT 1),3,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='楠园' LIMIT 1),4,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),5,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='中心图书馆' LIMIT 1),6,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='八教' LIMIT 1),7,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='行署楼' LIMIT 1),8,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='田家炳' LIMIT 1),9,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='西师街' LIMIT 1),10,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='五号门' LIMIT 1),11,0);

INSERT INTO bus_line(line_name,start_station,start_time,end_time,interval_mins,direction_type,fare_info,remark,enabled)
VALUES('3路','后山竹园','07:00:00','22:30:00',8,0,'校园一卡通 1元','站点较多，橘园候车人数较多但发车频率高；桃园同学可在橘园下车。',1);
SET @line_id = LAST_INSERT_ID();
INSERT INTO line_station_relation(line_id,station_id,stop_order,direction) VALUES
(@line_id,(SELECT id FROM bus_station WHERE station_name='后山竹园' LIMIT 1),1,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='工程技术学院' LIMIT 1),2,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='二号门' LIMIT 1),3,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),4,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='地科院' LIMIT 1),5,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='五教' LIMIT 1),6,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='梅园' LIMIT 1),7,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='橘园' LIMIT 1),8,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='田家炳' LIMIT 1),9,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='禾丰楼' LIMIT 1),10,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='外办' LIMIT 1),11,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='北区幼儿园' LIMIT 1),12,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='五号门' LIMIT 1),13,0);

INSERT INTO bus_line(line_name,start_station,start_time,end_time,interval_mins,direction_type,fare_info,remark,enabled)
VALUES('4路','二号门','07:00:00','22:30:00',8,0,'校园一卡通 1元','往返二号门和橘园，北区同学常坐。',1);
SET @line_id = LAST_INSERT_ID();
INSERT INTO line_station_relation(line_id,station_id,stop_order,direction) VALUES
(@line_id,(SELECT id FROM bus_station WHERE station_name='二号门' LIMIT 1),1,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),2,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='地科院' LIMIT 1),3,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='五教' LIMIT 1),4,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='梅园' LIMIT 1),5,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='橘园' LIMIT 1),6,0);

INSERT INTO bus_line(line_name,start_station,start_time,end_time,interval_mins,direction_type,fare_info,remark,enabled)
VALUES('5路','二号门','07:00:00','22:30:00',12,0,'校园一卡通 1元','途经博物馆、十五教、八教、田家炳、外办和北区幼儿园。',1);
SET @line_id = LAST_INSERT_ID();
INSERT INTO line_station_relation(line_id,station_id,stop_order,direction) VALUES
(@line_id,(SELECT id FROM bus_station WHERE station_name='二号门' LIMIT 1),1,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='博物馆' LIMIT 1),2,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='十五教' LIMIT 1),3,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='八教' LIMIT 1),4,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='田家炳' LIMIT 1),5,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='禾丰楼' LIMIT 1),6,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='外办' LIMIT 1),7,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='北区幼儿园' LIMIT 1),8,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='五号门' LIMIT 1),9,0);

INSERT INTO bus_line(line_name,start_station,start_time,end_time,interval_mins,direction_type,fare_info,remark,enabled)
VALUES('6路','后山竹园','07:00:00','18:30:00',15,1,'校园一卡通 1元','两次经过二号门，是唯一到竹园的校车。',1);
SET @line_id = LAST_INSERT_ID();
INSERT INTO line_station_relation(line_id,station_id,stop_order,direction) VALUES
(@line_id,(SELECT id FROM bus_station WHERE station_name='后山竹园' LIMIT 1),1,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='工程技术学院' LIMIT 1),2,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='二号门' LIMIT 1),3,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),4,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='地科院' LIMIT 1),5,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='五教' LIMIT 1),6,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='梅园' LIMIT 1),7,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='橘园' LIMIT 1),8,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='田家炳' LIMIT 1),9,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='八教' LIMIT 1),10,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),11,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='楠园第二食堂' LIMIT 1),12,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='二号门' LIMIT 1),13,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='竹园' LIMIT 1),14,0);

INSERT INTO bus_line(line_name,start_station,start_time,end_time,interval_mins,direction_type,fare_info,remark,enabled)
VALUES('7路','二号门','07:00:00','22:30:00',8,1,'校园一卡通 1元','二号门环线，经过人流集中的站点，载人数量较多。',1);
SET @line_id = LAST_INSERT_ID();
INSERT INTO line_station_relation(line_id,station_id,stop_order,direction) VALUES
(@line_id,(SELECT id FROM bus_station WHERE station_name='二号门' LIMIT 1),1,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),2,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='地科院' LIMIT 1),3,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='五教' LIMIT 1),4,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='梅园' LIMIT 1),5,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='橘园' LIMIT 1),6,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='田家炳' LIMIT 1),7,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='八教' LIMIT 1),8,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='大礼堂' LIMIT 1),9,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='楠园第二食堂' LIMIT 1),10,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='二号门' LIMIT 1),11,0);

INSERT INTO bus_line(line_name,start_station,start_time,end_time,interval_mins,direction_type,fare_info,remark,enabled)
VALUES('8路','音乐学院','07:00:00','22:30:00',12,1,'校园一卡通 1元','唯一到音乐学院的校车，附近离小吃街较近。',1);
SET @line_id = LAST_INSERT_ID();
INSERT INTO line_station_relation(line_id,station_id,stop_order,direction) VALUES
(@line_id,(SELECT id FROM bus_station WHERE station_name='音乐学院' LIMIT 1),1,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='八教' LIMIT 1),2,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='一号门' LIMIT 1),3,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='田家炳' LIMIT 1),4,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='橘园' LIMIT 1),5,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='梅园' LIMIT 1),6,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='外国语学院' LIMIT 1),7,0),
(@line_id,(SELECT id FROM bus_station WHERE station_name='音乐学院' LIMIT 1),8,0);
