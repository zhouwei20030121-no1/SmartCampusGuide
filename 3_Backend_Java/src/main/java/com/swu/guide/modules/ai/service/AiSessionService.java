package com.swu.guide.modules.ai.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.swu.guide.modules.ai.config.DeepSeekProperties;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * 基于 Redis 的多轮对话上下文管理。
 * 每个 sessionId 维护一个滑动窗口（默认10条），
 * 每次对话后自动截断，30分钟过期。
 */
@Service
public class AiSessionService {

    private final StringRedisTemplate redis;
    private final ObjectMapper objectMapper;
    private final DeepSeekProperties config;

    private static final String PREFIX = "ai:session:";
    private static final long TTL_MINUTES = 30;

    public AiSessionService(StringRedisTemplate redis, ObjectMapper objectMapper,
                            DeepSeekProperties config) {
        this.redis = redis;
        this.objectMapper = objectMapper;
        this.config = config;
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

    /** 追加一轮对话到历史并持久化 */
    public void appendAndSave(String sessionId, String userMsg, String assistantMsg) {
        List<Map<String, String>> history = getHistory(sessionId);
        history.add(Map.of("role", "user", "content", userMsg));
        history.add(Map.of("role", "assistant", "content", assistantMsg));

        int window = config.getContextWindow();
        if (history.size() > window * 2) {
            history = new ArrayList<>(history.subList(history.size() - window * 2, history.size()));
        }

        try {
            String json = objectMapper.writeValueAsString(history);
            redis.opsForValue().set(PREFIX + sessionId, json, TTL_MINUTES, TimeUnit.MINUTES);
        } catch (JsonProcessingException ignored) {}
    }

    /** 清除会话 */
    public void clear(String sessionId) {
        redis.delete(PREFIX + sessionId);
    }
}
