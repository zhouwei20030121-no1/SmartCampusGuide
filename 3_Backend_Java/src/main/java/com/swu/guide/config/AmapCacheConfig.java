package com.swu.guide.config;
//定期清理景点路径缓存
import com.swu.guide.common.utils.AmapUtil;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

@Configuration
@EnableScheduling
public class AmapCacheConfig {

    private final AmapUtil amapUtil;

    public AmapCacheConfig(AmapUtil amapUtil) {
        this.amapUtil = amapUtil;
    }

    /**
     * 每天凌晨3点清理过期缓存
     */
    @Scheduled(cron = "0 0 3 * * ?")
    public void cleanExpiredCache() {
        amapUtil.clearExpiredCache();
    }
}
