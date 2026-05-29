-- =============================================
-- 校园班车与路线查询模块 - 数据库建表+初始数据
-- 执行方式: 在 MySQL 中 source 本文件
-- =============================================

-- 1. 校车线路表
DROP TABLE IF EXISTS `bus_line`;
CREATE TABLE `bus_line` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `line_name` VARCHAR(100) NOT NULL COMMENT '线路名称，如八号门A线',
    `start_station` VARCHAR(100) COMMENT '始发站名称',
    `start_time` TIME COMMENT '首班车时间',
    `end_time` TIME COMMENT '末班车时间',
    `interval_mins` INT COMMENT '发车间隔(分钟)',
    `direction_type` TINYINT DEFAULT 0 COMMENT '0-往返线 1-单向循环线',
    `fare_info` VARCHAR(200) COMMENT '票价/支付方式说明',
    `remark` VARCHAR(500) COMMENT '备注',
    `enabled` TINYINT DEFAULT 1 COMMENT '是否启用',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='校车线路表';

-- 2. 站点基础表
DROP TABLE IF EXISTS `bus_station`;
CREATE TABLE `bus_station` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `station_name` VARCHAR(100) NOT NULL COMMENT '站点名称',
    `longitude` DECIMAL(10,7) DEFAULT NULL COMMENT '经度',
    `latitude` DECIMAL(10,7) DEFAULT NULL COMMENT '纬度',
    `remark` VARCHAR(200) COMMENT '备注',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='校车站点表';

-- 3. 线路-站点关联表（核心）
DROP TABLE IF EXISTS `line_station_relation`;
CREATE TABLE `line_station_relation` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `line_id` BIGINT NOT NULL COMMENT '线路ID',
    `station_id` BIGINT NOT NULL COMMENT '站点ID',
    `stop_order` INT NOT NULL COMMENT '停靠顺序(1开始)',
    `direction` TINYINT DEFAULT 0 COMMENT '0-上行/正向 1-下行/反向',
    FOREIGN KEY (`line_id`) REFERENCES `bus_line`(`id`),
    FOREIGN KEY (`station_id`) REFERENCES `bus_station`(`id`)
) COMMENT='线路-站点关联表';

-- =============================================
-- 初始数据：西大真实校车线路（7条）
-- =============================================

INSERT INTO `bus_line` (`id`, `line_name`, `start_station`, `start_time`, `end_time`, `interval_mins`, `direction_type`, `fare_info`, `remark`) VALUES
(1, '八号门A线', '八号门动物医院', '07:30', '22:30', 15, 0, '校园一卡通/钉钉扫码', '往返线'),
(2, '八号门B线', '八号门动物医院', '07:30', '22:30', 15, 0, '校园一卡通/钉钉扫码', '往返线'),
(3, '音乐学院A线', '音乐学院', '07:30', '22:30', 15, 0, '校园一卡通/钉钉扫码', '往返线'),
(4, '音乐学院B线', '音乐学院', '07:30', '22:30', 15, 0, '校园一卡通/钉钉扫码', '往返线'),
(5, '新药化大楼A线', '药学院', '07:30', '22:30', 15, 1, '校园一卡通/钉钉扫码', '单向循环线'),
(6, '新药化大楼B线', '药学院', '07:30', '22:30', 15, 0, '校园一卡通/钉钉扫码', '往返线'),
(7, '蚕学宫线', '蚕学宫', '07:30', '22:30', 15, 0, '校园一卡通/钉钉扫码', '往返线');

-- 站点数据（去重后约40个站点）
INSERT INTO `bus_station` (`id`, `station_name`) VALUES
(1,'八号门动物医院'),(2,'经济管理学院'),(3,'资源环境学院'),(4,'六号门'),
(5,'园艺园林学院'),(6,'共青团花园'),(7,'楠园(第四运动场)'),(8,'校史馆'),
(9,'第二十一教学楼'),(10,'中心图书馆'),(11,'第八教学楼'),(12,'行署楼'),
(13,'田家炳教育书院'),(14,'圆顶'),(15,'五号门'),(16,'地理科学学院'),
(17,'心理学部'),(18,'外国语学院'),(19,'药学院'),(20,'梅园'),(21,'橘园'),
(22,'桃园'),(23,'四新村博士公寓'),(24,'音乐学院'),(25,'大礼堂'),
(26,'竹园'),(27,'蚕学宫'),(28,'楠园');

-- 线路-站点关联（按实际行车顺序）
-- 八号门A线(上行) line_id=1
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(1,1,1,0),(1,2,2,0),(1,3,3,0),(1,4,4,0),(1,5,5,0),(1,6,6,0),(1,7,7,0),
(1,8,8,0),(1,9,9,0),(1,10,10,0),(1,11,11,0),(1,12,12,0),(1,13,13,0),(1,14,14,0),(1,15,15,0);
-- 八号门A线(下行/反向)
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(1,15,1,1),(1,14,2,1),(1,13,3,1),(1,12,4,1),(1,11,5,1),(1,10,6,1),(1,9,7,1),
(1,8,8,1),(1,7,9,1),(1,6,10,1),(1,5,11,1),(1,4,12,1),(1,3,13,1),(1,2,14,1),(1,1,15,1);

-- 八号门B线(上行) line_id=2
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(2,1,1,0),(2,2,2,0),(2,3,3,0),(2,4,4,0),(2,5,5,0),(2,6,6,0),(2,7,7,0),
(2,8,8,0),(2,9,9,0),(2,10,10,0),(2,16,11,0),(2,17,12,0),(2,18,13,0),(2,19,14,0),
(2,20,15,0),(2,21,16,0),(2,22,17,0),(2,23,18,0);
-- 八号门B线(下行)
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(2,23,1,1),(2,22,2,1),(2,21,3,1),(2,20,4,1),(2,19,5,1),(2,18,6,1),(2,17,7,1),
(2,16,8,1),(2,10,9,1),(2,9,10,1),(2,8,11,1),(2,7,12,1),(2,6,13,1),(2,5,14,1),
(2,4,15,1),(2,3,16,1),(2,2,17,1),(2,1,18,1);

-- 音乐学院A线(上行) line_id=3
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(3,24,1,0),(3,11,2,0),(3,16,3,0),(3,17,4,0),(3,18,5,0),(3,19,6,0),
(3,20,7,0),(3,21,8,0),(3,22,9,0),(3,23,10,0);
-- 音乐学院A线(下行)
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(3,23,1,1),(3,22,2,1),(3,21,3,1),(3,20,4,1),(3,19,5,1),(3,18,6,1),
(3,17,7,1),(3,16,8,1),(3,11,9,1),(3,24,10,1);

-- 音乐学院B线(上行) line_id=4
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(4,24,1,0),(4,11,2,0),(4,16,3,0),(4,25,4,0),(4,8,5,0),(4,7,6,0),(4,26,7,0);
-- 音乐学院B线(下行)
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(4,26,1,1),(4,7,2,1),(4,8,3,1),(4,25,4,1),(4,16,5,1),(4,11,6,1),(4,24,7,1);

-- 新药化大楼A线(单向循环) line_id=5
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(5,19,1,0),(5,20,2,0),(5,21,3,0),(5,22,4,0),(5,23,5,0),(5,14,6,0),
(5,13,7,0),(5,11,8,0),(5,16,9,0),(5,17,10,0),(5,19,11,0);

-- 新药化大楼B线(上行) line_id=6
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(6,19,1,0),(6,17,2,0),(6,16,3,0),(6,25,4,0),(6,8,5,0),(6,7,6,0),(6,26,7,0);
-- 新药化大楼B线(下行)
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(6,26,1,1),(6,7,2,1),(6,8,3,1),(6,25,4,1),(6,16,5,1),(6,17,6,1),(6,19,7,1);

-- 蚕学宫线(上行) line_id=7
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(7,27,1,0),(7,7,2,0),(7,26,3,0);
-- 蚕学宫线(下行)
INSERT INTO `line_station_relation` (`line_id`,`station_id`,`stop_order`,`direction`) VALUES
(7,26,1,1),(7,7,2,1),(7,27,3,1);
