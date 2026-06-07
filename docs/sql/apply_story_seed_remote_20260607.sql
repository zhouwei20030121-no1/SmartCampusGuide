ALTER TABLE ai_story ADD COLUMN title VARCHAR(160) DEFAULT NULL;
ALTER TABLE ai_story ADD COLUMN language VARCHAR(16) DEFAULT 'zh';
ALTER TABLE ai_story ADD COLUMN status TINYINT DEFAULT 1;
ALTER TABLE ai_story ADD COLUMN create_time DATETIME DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE ai_story ADD COLUMN update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;
ALTER TABLE ai_story ADD COLUMN deleted TINYINT DEFAULT 0;

UPDATE ai_story
SET title = COALESCE(title, CONCAT('校园故事 #', id)),
    language = COALESCE(language, 'zh'),
    source_type = COALESCE(source_type, 'manual'),
    status = COALESCE(status, 1),
    create_time = COALESCE(create_time, created_at, NOW()),
    update_time = COALESCE(update_time, created_at, NOW()),
    deleted = COALESCE(deleted, 0);

INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '中心图书馆：灯光里的约定', 'zh', 'manual',
'中心图书馆的故事，常常从傍晚开始。夕阳落到玻璃幕墙上，整栋楼像一本被慢慢翻开的书。有人抱着专业课教材匆匆进门，有人把电脑放到靠窗的位置，也有人只是路过，却会下意识抬头看一眼那片亮起来的灯。

据老同学说，期末周的图书馆最像一座安静的港口。大家从不同宿舍、不同学院赶来，在这里把白天没有完成的计划一点点补上。有人第一次在这里通宵复习，也有人在一楼大厅等到了并肩去吃夜宵的朋友。

后来毕业的人再回到校园，最容易被图书馆的灯光击中。它提醒人想起那些普通却用力的日子：占座、借书、赶论文、查资料，也想起自己曾经相信，只要再坚持一页，答案就会更近一点。', 1, 0
FROM scenic_spot
WHERE name LIKE '%中心图书馆%'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '中心图书馆：灯光里的约定')
LIMIT 1;

INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '光大礼堂：掌声经过的地方', 'zh', 'manual',
'光大礼堂是一处很适合被记住的地方。新生开学典礼、学院活动、社团演出、毕业季合影，都可能在这里或附近发生。它不只是一个建筑名字，更像校园仪式感的容器。

很多人的西大记忆，是从礼堂前的台阶开始的。第一次穿正装参加活动，第一次看见台上灯光亮起，第一次在人群里听到整齐的掌声，那些瞬间会把“我来到这所大学了”这件事变得特别具体。

校友回到这里时，往往会发现周围树木更高了，路过的人也换了一批。但礼堂还在原处，安静地接住新的欢呼和旧的怀念。每一阵掌声过去以后，都像在墙面和树影之间留下了一点回声。', 1, 0
FROM scenic_spot
WHERE name LIKE '%光大礼堂%'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '光大礼堂：掌声经过的地方')
LIMIT 1;

INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '共青团花园：慢下来的一小段路', 'zh', 'manual',
'共青团花园的故事，不一定轰轰烈烈。它更像课间被偷出来的十分钟，或者从图书馆去食堂时临时改道的一小段路。这里有树、有花、有可以放慢脚步的空间。

春天的时候，很多同学会在这里拍照；夏天树荫变厚，路过的人会不自觉把步子放慢。有人在这里等朋友，有人在这里背单词，也有人只是坐一会儿，让一天的忙碌从肩上落下来。

校园里真正温柔的地方，往往不是被隆重介绍的地方，而是你反复经过以后，忽然发现自己已经把它当成生活的一部分。共青团花园就是这样，它把很多人的普通日常，悄悄保存成了回忆。', 1, 0
FROM scenic_spot
WHERE name LIKE '%共青团花园%'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '共青团花园：慢下来的一小段路')
LIMIT 1;

INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '行署楼：旧建筑里的新脚步', 'zh', 'manual',
'行署楼有一种很特别的气质。它不像新楼那样锋利明亮，却因为时间留下的痕迹，显得稳重而耐看。路过它的时候，人会自然想到学校更早的历史，以及一代代师生怎样在这里留下脚步。

对新生来说，行署楼像一段需要慢慢读懂的校史。对校友来说，它可能是一张旧照片里的背景。对游客来说，它则是理解西南大学气质的入口：这所学校不是凭空出现的，它在时间里生长，也在每一天的教学、研究和生活里继续更新。

如果你站在楼前停一会儿，会发现老建筑并不沉默。它用窗、墙、树影和经过的人，讲着一所大学如何把过去带到今天。', 1, 0
FROM scenic_spot
WHERE name LIKE '%行署楼%'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '行署楼：旧建筑里的新脚步')
LIMIT 1;

INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '心理学部：湖边的思考练习', 'zh', 'manual',
'心理学部周围的节奏，常常比想象中更安静。这里适合学习，也适合把脚步放慢。很多同学第一次来到这里，是因为一门课、一场讲座，或者一次对“认识自己”的好奇。

有人说，心理学最迷人的地方，是它把日常生活里那些微小的情绪、选择和关系，变成可以认真讨论的问题。于是这栋楼不只承载课堂，也承载很多关于成长的提问：我为什么紧张，如何和别人相处，怎样更好地理解自己。

如果你从这里走向崇德湖，风会把校园的声音放轻一点。那一刻，学习不再只是背诵概念，也像是在练习观察自己、理解他人，并温柔地面对真实生活。', 1, 0
FROM scenic_spot
WHERE name LIKE '%心理%'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '心理学部：湖边的思考练习')
LIMIT 1;
