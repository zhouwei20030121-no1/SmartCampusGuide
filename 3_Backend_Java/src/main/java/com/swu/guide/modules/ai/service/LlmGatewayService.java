package com.swu.guide.modules.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.swu.guide.modules.ai.config.DeepSeekProperties;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.*;

@Service
public class LlmGatewayService {

    private final RestTemplate restTemplate;
    private final DeepSeekProperties config;
    private final ObjectMapper objectMapper;

    public LlmGatewayService(RestTemplate restTemplate, DeepSeekProperties config,
                             ObjectMapper objectMapper) {
        this.restTemplate = restTemplate;
        this.config = config;
        this.objectMapper = objectMapper;
    }

    /**
     * 统一 LLM 调用入口。
     * @param systemPrompt 系统人设 Prompt
     * @param messages     历史对话列表 [{role, content}, ...]
     * @param model        可选模型名，null 则用默认 deepseek-chat
     * @return AI 回复文本
     */
    public String chat(String systemPrompt, List<Map<String, String>> messages, String model) {
        try {
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

            HttpEntity<String> entity = new HttpEntity<>(objectMapper.writeValueAsString(body), headers);
            ResponseEntity<Map> response = restTemplate.postForEntity(
                    config.getApiUrl(), entity, Map.class);

            Map<String, Object> resBody = response.getBody();
            if (resBody == null) throw new RuntimeException("LLM 返回为空");

            @SuppressWarnings("unchecked")
            List<Map<String, Object>> choices = (List<Map<String, Object>>) resBody.get("choices");
            if (choices == null || choices.isEmpty()) throw new RuntimeException("LLM choices 为空");

            @SuppressWarnings("unchecked")
            Map<String, String> message = (Map<String, String>) choices.get(0).get("message");
            return message.get("content");
        } catch (Exception e) {
            throw new RuntimeException("DeepSeek 调用失败: " + e.getMessage(), e);
        }
    }

    /** 简化调用：仅传单条用户消息 + 系统人设 */
    public String chatSimple(String systemPrompt, String userMessage) {
        List<Map<String, String>> msgs = new ArrayList<>();
        msgs.add(Map.of("role", "user", "content", userMessage));
        return chat(systemPrompt, msgs, null);
    }
}
