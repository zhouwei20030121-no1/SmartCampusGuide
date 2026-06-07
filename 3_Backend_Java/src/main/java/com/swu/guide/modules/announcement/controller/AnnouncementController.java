package com.swu.guide.modules.announcement.controller;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.swu.guide.common.Result;
import com.swu.guide.modules.announcement.entity.Announcement;
import com.swu.guide.modules.announcement.service.AnnouncementService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.util.Date;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/announcement")
public class AnnouncementController {

    @Autowired
    private AnnouncementService announcementService;

    @GetMapping("/list")
    public Result<List<Announcement>> getList() {
        QueryWrapper<Announcement> queryWrapper = new QueryWrapper<>();
        queryWrapper.orderByDesc("publish_date");
        return Result.ok(announcementService.list(queryWrapper));
    }

    @PostMapping("/upload")
    public Result<String> uploadAndPublish(
            @RequestParam("file") MultipartFile file,
            @RequestParam("title") String title) {
        
        if (file.isEmpty() || !file.getOriginalFilename().toLowerCase().endsWith(".pdf")) {
            return Result.fail("请上传有效的 PDF 文件");
        }

        try {
            // 确保目录存在
            String uploadDir = System.getProperty("user.dir") + "/uploads/pdf/";
            File dir = new File(uploadDir);
            if (!dir.exists()) dir.mkdirs();
            
            String fileName = UUID.randomUUID().toString() + ".pdf";
            File dest = new File(uploadDir + fileName);
            file.transferTo(dest);

            // 返回的 URL 必须匹配 WebMvcConfig 中的映射规则
            String pdfUrl = "http://localhost:8080/uploads/pdf/" + fileName;

            Announcement announcement = new Announcement();
            announcement.setTitle(title);
            announcement.setPdfUrl(pdfUrl);
            announcement.setPublishDate(new Date());
            announcementService.save(announcement);

            return Result.ok("公告发布成功");
        } catch (IOException e) {
            return Result.fail("文件上传失败: " + e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    public Result<Object> delete(@PathVariable Long id) {
        announcementService.removeById(id);
        return Result.ok();
    }
}