INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '外国语学院：从一扇窗听见世界', 'zh', 'manual',
'外国语学院的故事，常常从清晨的朗读声开始。走近这里，你会听见不同语言在走廊、教室和树影之间交错，有人练习发音，有人准备演讲，也有人为了一个词的准确表达反复推敲。

对新生来说，这里提醒大家，大学不只是学一门专业，更是在学习用另一种方式理解世界。对游客来说，外国语学院像校园里一扇面向远方的窗，让西大的日常和更广阔的文化相连。

许多校友回忆起这里时，记得的不只是课本和考试，还有第一次完整读懂一篇外文文章的惊喜，第一次和外教交流时的紧张，以及后来发现自己真的能把声音送到更远地方的自信。', 1, 0
FROM scenic_spot WHERE name = '外国语学院'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '外国语学院：从一扇窗听见世界')
LIMIT 1;

INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '音乐学院：练琴声穿过傍晚', 'zh', 'manual',
'音乐学院附近，总有一种很容易被听见的校园气质。傍晚经过时，琴声、歌声和节拍声会从不同方向传来，像给一天的课程加上一段温柔的尾声。

这里的故事属于反复练习的人。一个小节、一句旋律、一段合唱，可能要被打磨很多遍，才会在舞台上显得自然。旁人听到的是几分钟的完整表演，学生记住的却是无数次从头再来的耐心。

如果你只是路过，也可以停一下。音乐让校园变得有温度，它提醒人：大学生活不只有赶课和考试，也有表达、热爱和把自己交给某个梦想的瞬间。', 1, 0
FROM scenic_spot WHERE name = '音乐学院'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '音乐学院：练琴声穿过傍晚')
LIMIT 1;

INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '园艺园林学院：把春天种进课程表', 'zh', 'manual',
'园艺园林学院的故事，有泥土、叶片和季节的气息。很多人第一次认真观察一株植物，不是在公园，而是在这里的课堂和实践里。花什么时候开，树怎样修剪，景观如何让人愿意停留，都是可以被学习的问题。

这里适合慢慢走。你会发现校园里的美并不是偶然出现的，它需要知识、经验和长期照料。那些看起来安静的植物，其实记录着时间，也记录着同学们从书本走向土地的过程。

对新生来说，这里是一种提醒：专业会把普通事物变得深刻。对游客来说，这里则展示了西大校园为什么常常让人觉得亲近，因为它真的把自然放进了日常生活。', 1, 0
FROM scenic_spot WHERE name = '园艺园林学院'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '园艺园林学院：把春天种进课程表')
LIMIT 1;

INSERT INTO ai_story (spot_id, title, language, source_type, story_content, status, deleted)
SELECT id, '计算机与信息科学学院：代码亮到深夜', 'zh', 'manual',
'计算机与信息科学学院的夜晚，常常被屏幕光照亮。有人在调试程序，有人在准备竞赛，也有人为了一个报错查资料到很晚。这里的故事不总是浪漫的，却很真实：它由耐心、逻辑和一次次失败后的重新运行组成。

很多同学第一次写出能正常运行的程序时，都会有一种小小的兴奋。那一刻，抽象的知识变成了可以看见的结果，也让人相信复杂问题可以被拆开、理解，再一点点解决。

如果你路过这里，可以想象那些安静教室里的键盘声。它们像校园里的另一种脚步，带着年轻人对未来技术、应用和创造力的期待。', 1, 0
FROM scenic_spot WHERE name LIKE '计算机与信息科学学院%'
  AND NOT EXISTS (SELECT 1 FROM ai_story WHERE title = '计算机与信息科学学院：代码亮到深夜')
LIMIT 1;
