package com.swu.guide.modules.user_lbs.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.swu.guide.modules.user_lbs.entity.User;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface UserMapper extends BaseMapper<User> {
}
