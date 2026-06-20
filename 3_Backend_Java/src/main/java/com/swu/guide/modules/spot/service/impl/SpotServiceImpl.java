package com.swu.guide.modules.spot.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.spot.entity.Spot;
import com.swu.guide.modules.spot.mapper.SpotMapper;
import com.swu.guide.modules.spot.service.SpotService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
public class SpotServiceImpl
        extends ServiceImpl<SpotMapper, Spot>
        implements SpotService {

    private static final List<SearchAlias> SEARCH_ALIASES = List.of(
            new SearchAlias("计信院", "计算机与信息科学学院 软件学院", "计算机与信息科学学院", "软件学院", "25教", "第25教学楼"),
            new SearchAlias("jixinyuan", "计算机与信息科学学院 软件学院", "计算机与信息科学学院", "软件学院", "25教", "第25教学楼"),
            new SearchAlias("jxy", "计算机与信息科学学院 软件学院", "计算机与信息科学学院", "软件学院", "25教", "第25教学楼"),
            new SearchAlias("计算机学院", "计算机与信息科学学院 软件学院", "计算机与信息科学学院", "软件学院"),
            new SearchAlias("软件学院", "计算机与信息科学学院 软件学院", "计算机与信息科学学院"),
            new SearchAlias("25教", "计算机与信息科学学院 软件学院", "明德楼", "第25教学楼"),
            new SearchAlias("二十五教", "计算机与信息科学学院 软件学院", "明德楼", "第25教学楼"),
            new SearchAlias("电信院", "电子信息工程学院", "电信工程学院", "博学楼", "明德楼"),
            new SearchAlias("数统院", "数学与统计学院", "数统学院", "数学学院"),
            new SearchAlias("生科院", "生命科学学院", "生科学院"),
            new SearchAlias("新传院", "新闻传媒学院", "新闻传播学院", "传媒学院"),
            new SearchAlias("文学院", "中国语言文学学院", "文学院"),
            new SearchAlias("菊园", "橘园", "桔园", "ju园", "juyuan"),
            new SearchAlias("桔园", "橘园", "菊园", "ju园", "juyuan"),
            new SearchAlias("枚园", "梅园", "meiyuan"),
            new SearchAlias("楠园", "楠香廊", "nanyuan")
    );

    private static final Map<Character, String> PINYIN = buildPinyinMap();

    @Override
    public Page<Spot> searchSpot(String keyword, int page, int size) {

        LambdaQueryWrapper<Spot> wrapper = new LambdaQueryWrapper<>();

        if (!StringUtils.hasText(keyword)) {
            wrapper.orderByDesc(Spot::getId);
            return this.page(new Page<>(page, size), wrapper);
        }

        Set<String> terms = expandKeyword(keyword);
        List<ScoredSpot> scoredSpots = new ArrayList<>();
        for (Spot spot : this.list()) {
            int score = scoreSpot(spot, terms);
            if (score > 0) {
                scoredSpots.add(new ScoredSpot(spot, score));
            }
        }
        scoredSpots.sort(
                Comparator.comparingInt(ScoredSpot::score)
                        .reversed()
                        .thenComparing(item -> item.spot().getId(), Comparator.reverseOrder())
        );

        int safePage = Math.max(page, 1);
        int safeSize = Math.max(size, 1);
        int from = Math.min((safePage - 1) * safeSize, scoredSpots.size());
        int to = Math.min(from + safeSize, scoredSpots.size());
        List<Spot> records = scoredSpots.subList(from, to)
                .stream()
                .map(ScoredSpot::spot)
                .toList();

        Page<Spot> result = new Page<>(safePage, safeSize);
        result.setRecords(records);
        result.setTotal(scoredSpots.size());
        result.setPages((scoredSpots.size() + safeSize - 1L) / safeSize);
        return result;
    }

    private Set<String> expandKeyword(String keyword) {
        String normalized = keyword.trim();
        Set<String> terms = new LinkedHashSet<>();
        terms.add(normalized);
        String compact = normalized.replaceAll("\\s+", "");
        if (!compact.equals(normalized)) {
            terms.add(compact);
        }

        for (SearchAlias alias : SEARCH_ALIASES) {
            if (alias.matches(compact)) {
                for (String term : alias.terms()) {
                    terms.add(term);
                }
            }
        }
        return terms;
    }

    private int scoreSpot(Spot spot, Set<String> terms) {
        int best = 0;
        for (String term : terms) {
            best = Math.max(best, scoreTerm(spot, term));
        }
        return best;
    }

    private int scoreTerm(Spot spot, String term) {
        String query = normalizeSearchText(term);
        if (query.isEmpty()) {
            return 0;
        }

        String name = normalizeSearchText(spot.getName());
        String description = normalizeSearchText(spot.getDescription());
        String category = normalizeSearchText(spot.getCategory());
        String allText = name + description + category;

        if (name.equals(query)) {
            return 1200;
        }
        if (name.contains(query) || query.contains(name)) {
            return 1050;
        }
        if (allText.contains(query)) {
            return 900;
        }

        String queryPinyin = toPinyin(query);
        String queryInitials = toPinyinInitials(query);
        String namePinyin = toPinyin(name);
        String nameInitials = toPinyinInitials(name);

        if (!queryPinyin.isEmpty() && !namePinyin.isEmpty()) {
            if (namePinyin.equals(queryPinyin)) {
                return 880;
            }
            if (namePinyin.contains(queryPinyin)) {
                return 820;
            }
            int distance = levenshteinDistance(namePinyin, queryPinyin);
            int maxLength = Math.max(namePinyin.length(), queryPinyin.length());
            if (maxLength > 0 && distance <= Math.max(1, maxLength / 5)) {
                return 680 - distance;
            }
        }

        if (!queryInitials.isEmpty() && !nameInitials.isEmpty()) {
            if (nameInitials.equals(queryInitials)) {
                return 760;
            }
            if (nameInitials.contains(queryInitials)) {
                return 700;
            }
        }

        return 0;
    }

    private String normalizeSearchText(String value) {
        if (value == null) {
            return "";
        }
        return value.toLowerCase()
                .replaceAll("\\s+", "")
                .replace("西南大学", "")
                .replace("北碚校区", "")
                .replace("（", "")
                .replace("）", "")
                .replace("(", "")
                .replace(")", "");
    }

    private String toPinyin(String value) {
        StringBuilder builder = new StringBuilder();
        for (char ch : value.toCharArray()) {
            if (Character.isDigit(ch) || (ch >= 'a' && ch <= 'z')) {
                builder.append(ch);
            } else {
                builder.append(PINYIN.getOrDefault(ch, String.valueOf(ch)));
            }
        }
        return builder.toString().replaceAll("[^a-z0-9]", "");
    }

    private String toPinyinInitials(String value) {
        StringBuilder builder = new StringBuilder();
        for (char ch : value.toCharArray()) {
            if (Character.isDigit(ch) || (ch >= 'a' && ch <= 'z')) {
                builder.append(ch);
            } else {
                String pinyin = PINYIN.get(ch);
                if (pinyin != null && !pinyin.isEmpty()) {
                    builder.append(pinyin.charAt(0));
                }
            }
        }
        return builder.toString();
    }

    private int levenshteinDistance(String left, String right) {
        int[] previous = new int[right.length() + 1];
        int[] current = new int[right.length() + 1];
        for (int j = 0; j <= right.length(); j++) {
            previous[j] = j;
        }
        for (int i = 1; i <= left.length(); i++) {
            current[0] = i;
            for (int j = 1; j <= right.length(); j++) {
                int cost = left.charAt(i - 1) == right.charAt(j - 1) ? 0 : 1;
                current[j] = Math.min(
                        Math.min(current[j - 1] + 1, previous[j] + 1),
                        previous[j - 1] + cost
                );
            }
            int[] tmp = previous;
            previous = current;
            current = tmp;
        }
        return previous[right.length()];
    }

    private static Map<Character, String> buildPinyinMap() {
        Map<Character, String> map = new HashMap<>();
        put(map, "橘桔菊居聚举巨距具炬剧据", "ju");
        put(map, "园院原源苑袁圆缘", "yuan");
        put(map, "梅枚美媒每", "mei");
        put(map, "桃陶讨涛", "tao");
        put(map, "竹筑逐主朱", "zhu");
        put(map, "楠南男难", "nan");
        put(map, "香乡湘相祥", "xiang");
        put(map, "廊郎朗", "lang");
        put(map, "中忠钟终", "zhong");
        put(map, "心新信欣鑫", "xin");
        put(map, "图土途涂", "tu");
        put(map, "书树暑", "shu");
        put(map, "馆管观关", "guan");
        put(map, "计技纪济记", "ji");
        put(map, "算酸", "suan");
        put(map, "机基积吉及级集", "ji");
        put(map, "与语雨育", "yu");
        put(map, "信息", "xin");
        put(map, "息西习希溪", "xi");
        put(map, "科可课克", "ke");
        put(map, "学雪", "xue");
        put(map, "软阮", "ruan");
        put(map, "件建健", "jian");
        put(map, "物五伍", "wu");
        put(map, "理礼里李立", "li");
        put(map, "数树术", "shu");
        put(map, "统同童通", "tong");
        put(map, "新闻", "xin");
        put(map, "闻文", "wen");
        put(map, "传川穿", "chuan");
        put(map, "媒梅", "mei");
        put(map, "生声省", "sheng");
        put(map, "命明名", "ming");
        put(map, "含涵韩", "han");
        put(map, "弘红宏", "hong");
        put(map, "门们", "men");
        put(map, "行形型", "xing");
        put(map, "府附富", "fu");
        put(map, "星兴", "xing");
        put(map, "军均君", "jun");
        put(map, "雨语育", "yu");
        put(map, "僧森", "seng");
        put(map, "楼", "lou");
        put(map, "亭庭", "ting");
        put(map, "场厂", "chang");
        put(map, "广光", "guang");
        put(map, "场", "chang");
        put(map, "林琳临", "lin");
        put(map, "山杉", "shan");
        put(map, "路露鹿", "lu");
        put(map, "桥乔", "qiao");
        put(map, "湖胡", "hu");
        put(map, "池迟", "chi");
        put(map, "苑园院", "yuan");
        put(map, "第", "di");
        put(map, "一", "yi");
        put(map, "二", "er");
        put(map, "三", "san");
        put(map, "四", "si");
        put(map, "五", "wu");
        put(map, "六", "liu");
        put(map, "七", "qi");
        put(map, "八", "ba");
        put(map, "九", "jiu");
        put(map, "十", "shi");
        return map;
    }

    private static void put(Map<Character, String> map, String chars, String pinyin) {
        for (char ch : chars.toCharArray()) {
            map.put(ch, pinyin);
        }
    }

    private record SearchAlias(String alias, String... terms) {
        boolean matches(String keyword) {
            if (alias.contains(keyword) || keyword.contains(alias)) {
                return true;
            }
            for (String term : terms) {
                String compactTerm = term.replaceAll("\\s+", "");
                if (compactTerm.contains(keyword) || keyword.contains(compactTerm)) {
                    return true;
                }
            }
            return false;
        }
    }

    private record ScoredSpot(Spot spot, int score) {
    }
}
