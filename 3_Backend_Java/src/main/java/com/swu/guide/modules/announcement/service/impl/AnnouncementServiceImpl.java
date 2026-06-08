package com.swu.guide.modules.announcement.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.swu.guide.modules.announcement.entity.Announcement;
import com.swu.guide.modules.announcement.mapper.AnnouncementMapper;
import com.swu.guide.modules.announcement.service.AnnouncementService;
import org.springframework.stereotype.Service;

@Service
public class AnnouncementServiceImpl extends ServiceImpl<AnnouncementMapper, Announcement> implements AnnouncementService {
}