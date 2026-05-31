package com.swu.guide.modules.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.swu.guide.modules.ai.config.DeepSeekProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

import java.util.*;

@Service
public class LlmGatewayService {

    private static final Logger log = LoggerFactory.getLogger(LlmGatewayService.class);

    private final RestTemplate restTemplate;
    private final DeepSeekProperties config;
    private final ObjectMapper objectMapper;

    private static final int MAX_RETRIES = 3;
    private static final long INITIAL_BACKOFF_MS = 500;

    public LlmGatewayService(RestTemplate restTemplate, DeepSeekProperties config,
                             ObjectMapper objectMapper) {
        this.restTemplate = restTemplate;
        this.config = config;
        this.objectMapper = objectMapper;
    }

    /**
     * 统一 LLM 调用入口，支持指数退避重试（3次，500ms/1000ms/2000ms）。
     * @param systemPrompt 系统人设 Prompt
     * @param messages     历史对话列表 [{role, content}, ...]
     * @param model        可选模型名，null 则用默认 deepseek-chat
     * @return AI 回复文本
     */
    public String chat(String systemPrompt, List<Map<String, String>> messages, String model) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(config.getApiKey());

        List<Map<String, String>> fullMessages = new ArrayList<>();
        if (systemPrompt != null && !systemPrompt.isBlank()) {
            fullMessages.add(Map.of("role", "system", "content", systemPrompt));
        }
        fullMessages.addAll(messages);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", model != null ? model : config.getDefaultModel());
        body.put("messages", fullMessages);
        body.put("temperature", config.getTemperature());
        body.put("max_tokens", config.getMaxTokens());

        Exception lastException = null;
        for (int attempt = 0; attempt < MAX_RETRIES; attempt++) {
            try {
                HttpEntity<String> entity = new HttpEntity<>(objectMapper.writeValueAsString(body), headers);
                ResponseEntity<Map> response = restTemplate.postForEntity(
                        config.getApiUrl(), entity, Map.class);

                if (response.getStatusCode() == HttpStatus.TOO_MANY_REQUESTS) {
                    // 429 限流：等久一点再重试
                    long waitMs = INITIAL_BACKOFF_MS * (1L << attempt);
                    log.warn("DeepSeek 429 限流，第 {} 次重试等待 {}ms", attempt + 1, waitMs);
                    Thread.sleep(waitMs);
                    continue;
                }

                Map<String, Object> resBody = response.getBody();
                if (resBody == null) {
                    throw new LlmException("LLM 返回为空");
                }

                @SuppressWarnings("unchecked")
                List<Map<String, Object>> choices = (List<Map<String, Object>>) resBody.get("choices");
                if (choices == null || choices.isEmpty()) {
                    throw new LlmException("LLM choices 为空");
                }

                @SuppressWarnings("unchecked")
                Map<String, String> message = (Map<String, String>) choices.get(0).get("message");
                return message.get("content");

            } catch (ResourceAccessException e) {
                // 网络/超时问题，可重试
                lastException = e;
                long waitMs = INITIAL_BACKOFF_MS * (1L << attempt);
                log.warn("DeepSeek 连接异常，第 {} 次重试等待 {}ms: {}", attempt + 1, waitMs, e.getMessage());
                if (attempt < MAX_RETRIES - 1) {
                    try { Thread.sleep(waitMs); } catch (InterruptedException ie) { Thread.currentThread().interrupt(); break; }
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new LlmException("LLM 调用被中断", e);
            } catch (Exception e) {
                // 其他异常（如序列化错误）不重试
                throw new LlmException("DeepSeek 调用失败: " + e.getMessage(), e);
            }
        }

        throw new LlmException("DeepSeek 调用失败（已重试 " + MAX_RETRIES + " 次），最后错误: "
                + (lastException != null ? lastException.getMessage() : "未知"), lastException);
    }

    /** 简化调用：仅传单条用户消息 + 系统人设 */
    public String chatSimple(String systemPrompt, String userMessage) {
        List<Map<String, String>> msgs = new ArrayList<>();
        msgs.add(Map.of("role", "user", "content", userMessage));
        return chat(systemPrompt, msgs, null);
    }

    /** 业务异常，调用方可根据类型判断是否重试 */
    public static class LlmException extends RuntimeException {
        public LlmException(String message) {
            super(message);
        }
        public LlmException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
