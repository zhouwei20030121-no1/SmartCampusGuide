package com.swu.guide.modules.ai.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "deepseek")
public class DeepSeekProperties {
    private String apiKey = "";
    private String apiUrl = "https://api.deepseek.com/chat/completions";
    private String defaultModel = "deepseek-chat";
    private double temperature = 0.7;
    private int maxTokens = 2048;
    private int contextWindow = 10;

    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }
    public String getApiUrl() { return apiUrl; }
    public void setApiUrl(String apiUrl) { this.apiUrl = apiUrl; }
    public String getDefaultModel() { return defaultModel; }
    public void setDefaultModel(String defaultModel) { this.defaultModel = defaultModel; }
    public double getTemperature() { return temperature; }
    public void setTemperature(double temperature) { this.temperature = temperature; }
    public int getMaxTokens() { return maxTokens; }
    public void setMaxTokens(int maxTokens) { this.maxTokens = maxTokens; }
    public int getContextWindow() { return contextWindow; }
    public void setContextWindow(int contextWindow) { this.contextWindow = contextWindow; }
}
