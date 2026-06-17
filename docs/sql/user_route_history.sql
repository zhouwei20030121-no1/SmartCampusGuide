-- User route planning history for profile page.
CREATE TABLE IF NOT EXISTS user_route_history (
  id BIGINT NOT NULL AUTO_INCREMENT,
  user_id BIGINT NOT NULL COMMENT 'User id',
  start_spot_id BIGINT NOT NULL COMMENT 'Start spot id',
  end_spot_id BIGINT NOT NULL COMMENT 'End spot id',
  start_spot_name VARCHAR(100) NOT NULL COMMENT 'Start spot name',
  end_spot_name VARCHAR(100) NOT NULL COMMENT 'End spot name',
  waypoint_ids VARCHAR(500) DEFAULT NULL COMMENT 'Comma separated waypoint spot ids',
  waypoint_names VARCHAR(1000) DEFAULT NULL COMMENT 'Comma separated waypoint names',
  strategy VARCHAR(32) DEFAULT 'DISTANCE' COMMENT 'DISTANCE/TIME/PERSONALIZED',
  user_identity VARCHAR(32) DEFAULT 'TOURIST' COMMENT 'User identity when planning',
  distance_meters INT DEFAULT 0 COMMENT 'Estimated distance in meters',
  duration_minutes INT DEFAULT 0 COMMENT 'Estimated duration in minutes',
  route_summary VARCHAR(500) DEFAULT NULL COMMENT 'Readable route summary',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT DEFAULT 0 COMMENT '0 active, 1 deleted',
  PRIMARY KEY (id),
  KEY idx_user_route_history_user (user_id, deleted, create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
