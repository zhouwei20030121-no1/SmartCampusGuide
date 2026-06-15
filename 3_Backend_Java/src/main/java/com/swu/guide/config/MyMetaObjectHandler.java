package com.swu.guide.config;

import com.baomidou.mybatisplus.core.handlers.MetaObjectHandler;
import org.apache.ibatis.reflection.MetaObject;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

@Component
public class MyMetaObjectHandler implements MetaObjectHandler {

    /**
     * 插入时的填充策略
     */
    @Override
    public void insertFill(MetaObject metaObject) {
        // 插入时自动填充创建时间和更新时间
        this.strictInsertFill(metaObject, "createTime", LocalDateTime.class, LocalDateTime.now());
        this.strictInsertFill(metaObject, "updateTime", LocalDateTime.class, LocalDateTime.now());

        // 如果deleted字段为空，设置默认值
        if (metaObject.hasSetter("deleted")) {
            Object deleted = this.getFieldValByName("deleted", metaObject);
            if (deleted == null) {
                Class<?> deletedType = metaObject.getSetterType("deleted");
                this.setFieldValByName("deleted", Boolean.class.equals(deletedType) ? Boolean.FALSE : 0, metaObject);
            }
        }

        // 如果status字段为空，设置默认值
        if (metaObject.hasSetter("status")) {
            Object status = this.getFieldValByName("status", metaObject);
            if (status == null) {
                this.setFieldValByName("status", 1, metaObject);
            }
        }
    }

    /**
     * 更新时的填充策略
     */
    @Override
    public void updateFill(MetaObject metaObject) {
        // 更新时自动填充更新时间
        this.strictUpdateFill(metaObject, "updateTime", LocalDateTime.class, LocalDateTime.now());
    }
}
