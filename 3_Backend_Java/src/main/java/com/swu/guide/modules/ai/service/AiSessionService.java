package com.swu.guide.modules.ai.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.swu.guide.modules.ai.config.DeepSeekProperties;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * 基于 Redis 的多轮对话上下文管理。
 * 每个 sessionId 维护一个滑动窗口（默认10条），
 * 每次对话后自动截断，TTL 可配置，默认30分钟过期。
 * <p>
 * 并发安全：appendAndSave 使用 Lua 脚本保证读取→追加→截断→写回的原子性。
 */
@Service
public class AiSessionService {

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;
    private final DeepSeekProperties config;

    private static final String PREFIX = "ai:session:";

    public AiSessionService(StringRedisTemplate redis, ObjectMapper objectMapper,
                            DeepSeekProperties config) {
        this.redis = redis;
        this.objectMapper = objectMapper;
        this.config = config;
    }

    // ──────────────── Lua 脚本：原子化追加对话历史 ────────────────
    // KEYS[1]: Redis key
    // ARGV[1]: user message JSON 字符串
    // ARGV[2]: assistant message JSON 字符串
    // ARGV[3]: 上下文窗口大小（保留多少轮，每轮2条）
    // ARGV[4]: TTL 秒数
    private static final DefaultRedisScript<Long> APPEND_SCRIPT;

    static {
        APPEND_SCRIPT = new DefaultRedisScript<>();
        APPEND_SCRIPT.setScriptText(
            "local key = KEYS[1]\n" +
            "local userJson = ARGV[1]\n" +
            "local assistantJson = ARGV[2]\n" +
            "local window = tonumber(ARGV[3])\n" +
            "local ttl = tonumber(ARGV[4])\n\n" +
            "local existing = redis.call('GET', key)\n" +
            "local history = {}\n" +
            "if existing and existing ~= '' then\n" +
            "    local ok, decoded = pcall(cjson.decode, existing)\n" +
            "    if ok and type(decoded) == 'table' then\n" +
            "        history = decoded\n" +
            "    end\n" +
            "end\n\n" +
            "table.insert(history, cjson.decode(userJson))\n" +
            "table.insert(history, cjson.decode(assistantJson))\n\n" +
            "local maxSize = window * 2\n" +
            "while #history > maxSize do\n" +
            "    table.remove(history, 1)\n" +
            "end\n\n" +
            "redis.call('SET', key, cjson.encode(history), 'EX', ttl)\n" +
            "return 1"
        );
        APPEND_SCRIPT.setResultType(Long.class);
    }

    /** 获取会话历史 */
    public List<Map<String, String>> getHistory(String sessionId) {
        String json = redis.opsForValue().get(PREFIX + sessionId);
        if (json == null || json.isBlank()) return new ArrayList<>();
        try {
            @SuppressWarnings("unchecked")
            List<Map<String, String>> history = objectMapper.readValue(json, List.class);
            return history;
        } catch (JsonProcessingException e) {
            return new ArrayList<>();
        }
    }

    /**
     * 原子化追加一轮对话到历史并持久化。
     * 使用 Lua 脚本保证并发安全，避免 get-then-set 竞态条件。
     */
    public void appendAndSave(String sessionId, String userMsg, String assistantMsg) {
        try {
            String userJson = objectMapper.writeValueAsString(
                    Map.of("role", "user", "content", userMsg));
            String assistantJson = objectMapper.writeValueAsString(
                    Map.of("role", "assistant", "content", assistantMsg));

            int window = config.getContextWindow();
            long ttlSeconds = config.getSessionTtlMinutes() > 0
                    ? config.getSessionTtlMinutes() * 60L
                    : 30 * 60L;

            redis.execute(
                    APPEND_SCRIPT,
                    List.of(PREFIX + sessionId),
                    userJson, assistantJson,
                    String.valueOf(window), String.valueOf(ttlSeconds));
        } catch (JsonProcessingException e) {
            throw new RuntimeException("序列化会话历史失败", e);
        }
    }

    /** 清除会话 */
    public void clear(String sessionId) {
        redis.delete(PREFIX + sessionId);
    }
}
