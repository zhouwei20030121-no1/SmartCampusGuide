-- ============================================
-- 西南大学校园地标坐标修正 SQL（最终版 v3）
-- 生成于 2026-06-19
-- 验证路径: regeo → place/text → inputtips 三轮交叉验证
-- ============================================

-- 【🚨 修复重复坐标 Bug #1】三个校门共用同一坐标
-- 原bug: 1号门/5号门/7号门 = (106.434540, 29.828249)
-- 验证来源: 高德 inputtips API

-- [33] 1号门（含弘门）偏差 927m
UPDATE scenic_spot SET longitude = 106.428931, latitude = 29.821477 WHERE id = 33 AND deleted = 0;

-- [45] 5号门（学府门）偏差 65m — 保留最接近原坐标的校门
UPDATE scenic_spot SET longitude = 106.434266, latitude = 29.828786 WHERE id = 45 AND deleted = 0;

-- [56] 7号门（文星门）偏差 356m
UPDATE scenic_spot SET longitude = 106.431855, latitude = 29.830444 WHERE id = 56 AND deleted = 0;


-- 【🚨 修复重复坐标 Bug #2】植物保护学院/工程技术学院共用坐标
-- 原bug: 两者均为 (106.417957, 29.812335)
-- 验证: place/text 确认该坐标为植物保护学院; inputtips 给出工程技术学院独立坐标

-- [29] 工程技术学院 偏差 211m
UPDATE scenic_spot SET longitude = 106.415972, latitude = 29.813127 WHERE id = 29 AND deleted = 0;


-- 【补充修正】其他校门坐标
-- [35] 3号门（天生门）偏差 184m
UPDATE scenic_spot SET longitude = 106.425882, latitude = 29.818523 WHERE id = 35 AND deleted = 0;

-- [55] 6号门（学苑门）偏差 310m
UPDATE scenic_spot SET longitude = 106.416852, latitude = 29.811055 WHERE id = 55 AND deleted = 0;

-- [57] 8号门（将军门）偏差 52m（可选，差值较小）
UPDATE scenic_spot SET longitude = 106.412750, latitude = 29.811133 WHERE id = 57 AND deleted = 0;


-- 【生活区坐标修正】
-- [48] 橘园 偏差 192m
UPDATE scenic_spot SET longitude = 106.424822, latitude = 29.825730 WHERE id = 48 AND deleted = 0;

-- [46] 桃园 偏差 63m
UPDATE scenic_spot SET longitude = 106.427226, latitude = 29.827314 WHERE id = 46 AND deleted = 0;

-- [51] 竹园 偏差 114m
UPDATE scenic_spot SET longitude = 106.416843, latitude = 29.817270 WHERE id = 51 AND deleted = 0;


-- ============================================
-- 以下 3 个点位所有 API 均无法验证，保留原坐标：
--   60 樟树林, 62 荷花池, 71 大地广场
-- 建议在高德卫星图上手动确认后更新
-- ============================================


-- ============================================
-- 操作确认清单
-- ============================================
-- SELECT id, name, longitude, latitude FROM scenic_spot
-- WHERE id IN (33,45,56,29,35,55,57,48,46,51);
--
-- 预期影响: 10 行
-- 执行前建议备份: CREATE TABLE scenic_spot_backup_20260619 AS SELECT * FROM scenic_spot;
