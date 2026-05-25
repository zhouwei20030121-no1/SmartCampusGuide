package com.swu.guide.modules.ai.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

@Configuration
public class LlmConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }

    @Bean
    @ConfigurationProperties(prefix = "deepseek")
    public DeepSeekProperties deepSeekProperties() {
        return new DeepSeekProperties();
    }
}
