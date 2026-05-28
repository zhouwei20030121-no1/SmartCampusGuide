package com.swu.guide.modules.guide.controller;

import com.swu.guide.common.Result;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/upload")
public class MediaUploadController {

    /** 音频存储子目录 */
    private static final String AUDIO_DIR = "audios";
    /** 视频存储子目录 */
    private static final String VIDEO_DIR = "videos";

    /**
     * 上传音频文件
     */
    @PostMapping("/audio")
    public Result<Map<String, String>> uploadAudio(@RequestParam("file") MultipartFile file) {
        return uploadMediaFile(file, AUDIO_DIR, 20);
    }

    /**
     * 上传视频文件
     */
    @PostMapping("/video")
    public Result<Map<String, String>> uploadVideo(@RequestParam("file") MultipartFile file) {
        return uploadMediaFile(file, VIDEO_DIR, 100);
    }

    /**
     * 通用文件上传方法
     */
    private Result<Map<String, String>> uploadMediaFile(MultipartFile file, String subDir, int maxSizeMB) {
        try {
            // 1. 验证文件是否为空
            if (file.isEmpty()) {
                return Result.fail("上传文件不能为空");
            }

            // 2. 验证文件大小
            long maxSizeBytes = maxSizeMB * 1024L * 1024L;
            if (file.getSize() > maxSizeBytes) {
                return Result.fail("文件大小不能超过" + maxSizeMB + "MB");
            }

            // 3. 获取上传目录
            String uploadDir = getUploadDirectory(subDir);
            System.out.println("文件上传目录: " + uploadDir);

            // 4. 创建目录
            File dir = new File(uploadDir);
            if (!dir.exists()) {
                boolean created = dir.mkdirs();
                System.out.println("创建目录 " + uploadDir + " : " + (created ? "成功" : "失败"));
            }

            // 5. 生成文件名
            String originalFilename = file.getOriginalFilename();
            String suffix = "";
            if (originalFilename != null && originalFilename.contains(".")) {
                suffix = originalFilename.substring(originalFilename.lastIndexOf("."));
            }
            String fileName = originalFilename;

            // 检查重名
            File destFile = new File(dir, fileName);
            if (destFile.exists()) {
                String baseName = originalFilename;
                String ext = "";
                if (originalFilename != null && originalFilename.contains(".")) {
                    int dotIndex = originalFilename.lastIndexOf(".");
                    baseName = originalFilename.substring(0, dotIndex);
                    ext = originalFilename.substring(dotIndex);
                }
                int count = 1;
                while (destFile.exists()) {
                    fileName = baseName + "_" + count + ext;
                    destFile = new File(dir, fileName);
                    count++;
                }
            }

            // 6. 保存文件
            file.transferTo(destFile);
            System.out.println("文件保存成功: " + destFile.getAbsolutePath());

            // 7. 返回URL
            String fileUrl = "/" + subDir + "/" + fileName;
            System.out.println("文件访问URL: " + fileUrl);

            Map<String, String> result = new HashMap<>();
            result.put("url", fileUrl);
            result.put("fileName", originalFilename);

            return Result.ok(result);

        } catch (IOException e) {
            e.printStackTrace();
            return Result.fail("文件上传失败：" + e.getMessage());
        }
    }

    /**
     * 删除媒体文件
     */
    @DeleteMapping("/media")
    public Result<Void> deleteMedia(@RequestParam("url") String fileUrl) {
        try {
            System.out.println("准备删除文件，URL: " + fileUrl);

            // 从URL提取文件名和子目录
            String fileName = fileUrl.substring(fileUrl.lastIndexOf("/") + 1);

            // 确定子目录
            String subDir;
            if (fileUrl.contains("/audios/")) {
                subDir = AUDIO_DIR;
            } else if (fileUrl.contains("/videos/")) {
                subDir = VIDEO_DIR;
            } else {
                return Result.fail("无法识别的文件类型");
            }

            // 获取上传目录
            String uploadDir = getUploadDirectory(subDir);
            File file = new File(uploadDir, fileName);

            if (file.exists()) {
                boolean deleted = file.delete();
                if (deleted) {
                    System.out.println("文件删除成功: " + file.getAbsolutePath());
                    return Result.ok();
                } else {
                    return Result.fail("文件删除失败");
                }
            } else {
                System.out.println("文件不存在: " + file.getAbsolutePath());
                return Result.ok();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return Result.fail("删除失败：" + e.getMessage());
        }
    }

    /**
     * 获取上传目录路径
     */
    private String getUploadDirectory(String subDir) {
        String projectPath = System.getProperty("user.dir");
        String devPath = projectPath + "/src/main/resources/static/" + subDir + "/";

        File devDir = new File(devPath);
        if (devDir.exists() || devDir.mkdirs()) {
            return devPath;
        }

        // 备用路径
        try {
            String classesPath = this.getClass().getClassLoader().getResource("").getPath();
            classesPath = java.net.URLDecoder.decode(classesPath, "UTF-8");
            return classesPath + "static/" + subDir + "/";
        } catch (Exception e) {
            return projectPath + "/uploads/" + subDir + "/";
        }
    }
}
