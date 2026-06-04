-- Optional hardening for the AI guide/story and check-in modules.
-- The current code works with the existing tables:
--   scenic_spot, spot_comment, user_checkin_badge, ai_explanation, ai_story
-- Run this only if the index does not already exist.

ALTER TABLE user_checkin_badge
  ADD UNIQUE KEY uk_user_spot_checkin (user_id, spot_id);

-- Useful read-only checks:
SELECT COUNT(*) AS active_spots
FROM scenic_spot
WHERE deleted = 0 AND (status IS NULL OR status = 1);

SELECT COUNT(*) AS approved_comments
FROM spot_comment
WHERE status = 1 AND deleted = 0;

SELECT COUNT(*) AS checkin_rows
FROM user_checkin_badge;
