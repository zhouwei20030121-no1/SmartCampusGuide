-- Route management tables used by the admin route page.
-- Run this on the backend MySQL database if these tables do not exist yet.

CREATE TABLE IF NOT EXISTS tour_route (
  id BIGINT NOT NULL AUTO_INCREMENT,
  route_name VARCHAR(100) NOT NULL COMMENT 'Route name',
  target_audience VARCHAR(50) DEFAULT NULL COMMENT 'Target audience',
  estimated_time INT DEFAULT 0 COMMENT 'Estimated time in minutes',
  description VARCHAR(500) DEFAULT NULL COMMENT 'Route description',
  status TINYINT DEFAULT 1 COMMENT '0 disabled, 1 enabled',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT DEFAULT 0 COMMENT '0 active, 1 deleted',
  PRIMARY KEY (id),
  KEY idx_tour_route_deleted_status (deleted, status),
  KEY idx_tour_route_name (route_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS route_spot_node (
  id BIGINT NOT NULL AUTO_INCREMENT,
  route_id BIGINT NOT NULL COMMENT 'Route id',
  spot_id BIGINT NOT NULL COMMENT 'Spot id',
  sort_order INT NOT NULL COMMENT 'Display order in route',
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_route_spot_node_route_order (route_id, sort_order),
  KEY idx_route_spot_node_spot (spot_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
