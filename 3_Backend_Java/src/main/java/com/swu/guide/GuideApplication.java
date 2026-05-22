package com.swu.guide;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@MapperScan("com.swu.guide.modules.**.mapper")
public class GuideApplication {
    public static void main(String[] args) {
        SpringApplication.run(GuideApplication.class, args);
    }
}
