package com.swu.guide.modules.spot.controller;

import com.swu.guide.common.Result;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/upload")
public class FileUploadController {

    private static final String IMAGE_BASE_PATH = "images/spots";

    @PostMapping("/spot-image")
    public Result<Map<String, String>> uploadSpotImage(@RequestParam("file") MultipartFile file) {
        try {
            if (file.isEmpty()) {
                return Result.fail("上传文件不能为空");
            }

            String contentType = file.getContentType();
            if (contentType == null || !contentType.startsWith("image/")) {
                return Result.fail("只能上传图片文件");
            }

            if (file.getSize() > 5 * 1024 * 1024) {
                return Result.fail("图片大小不能超过5MB");
            }

            String uploadDir = getUploadDirectory();
            System.out.println("图片上传目录: " + uploadDir);

            File dir = new File(uploadDir);
            if (!dir.exists()) {
                boolean created = dir.mkdirs();
                System.out.println("创建目录 " + uploadDir + " : " + (created ? "成功" : "失败"));
            }

            String originalFilename = file.getOriginalFilename();
            String fileName = originalFilename;

            File destFile = new File(dir, fileName);
            if (destFile.exists()) {
                String nameWithoutExt = originalFilename;
                String extension = "";
                if (originalFilename != null && originalFilename.contains(".")) {
                    int lastDot = originalFilename.lastIndexOf(".");
                    nameWithoutExt = originalFilename.substring(0, lastDot);
                    extension = originalFilename.substring(lastDot);
                }

                int count = 1;
                while (destFile.exists()) {
                    fileName = nameWithoutExt + "_" + count + extension;
                    destFile = new File(dir, fileName);
                    count++;
                }
            }

            file.transferTo(destFile);
            System.out.println("图片保存成功: " + destFile.getAbsolutePath());

            String imageUrl = "/" + IMAGE_BASE_PATH + "/" + fileName;
            System.out.println("图片访问URL: " + imageUrl);

            Map<String, String> result = new HashMap<>();
            result.put("url", imageUrl);
            result.put("fileName", fileName);

            return Result.ok(result);

        } catch (IOException e) {
            e.printStackTrace();
            return Result.fail("图片上传失败：" + e.getMessage());
        }
    }

    /**
     * 删除图片文件
     */
    @DeleteMapping("/spot-image")
    public Result<Void> deleteImage(@RequestParam("url") String imageUrl) {
        try {
            System.out.println("准备删除图片，URL: " + imageUrl);

            // 从URL中提取文件名
            String fileName = imageUrl.substring(imageUrl.lastIndexOf("/") + 1);
            System.out.println("文件名: " + fileName);

            // 获取上传目录
            String uploadDir = getUploadDirectory();

            // 构建文件完整路径
            File file = new File(uploadDir, fileName);
            System.out.println("文件路径: " + file.getAbsolutePath());

            if (file.exists()) {
                boolean deleted = file.delete();
                if (deleted) {
                    System.out.println("图片删除成功: " + file.getAbsolutePath());
                    return Result.ok();
                } else {
                    System.out.println("图片删除失败: " + file.getAbsolutePath());
                    return Result.fail("删除失败");
                }
            } else {
                System.out.println("文件不存在: " + file.getAbsolutePath());
                // 文件不存在也算删除成功（可能已经被删除过了）
                return Result.ok();
            }
        } catch (Exception e) {
            e.printStackTrace();
            return Result.fail("删除失败：" + e.getMessage());
        }
    }

    private String getUploadDirectory() {
        String projectPath = System.getProperty("user.dir");
        String devPath = projectPath + "/src/main/resources/static/" + IMAGE_BASE_PATH;

        File devDir = new File(devPath);
        if (devDir.exists() || devDir.mkdirs()) {
            System.out.println("使用开发路径: " + devPath);
            return devPath;
        }

        try {
            String classesPath = this.getClass().getClassLoader().getResource("").getPath();
            classesPath = URLDecoder.decode(classesPath, StandardCharsets.UTF_8.name());
            String staticPath = classesPath + "static/";
            String targetPath = staticPath + IMAGE_BASE_PATH;
            System.out.println("使用编译路径: " + targetPath);
            return targetPath;
        } catch (Exception e) {
            String fallbackPath = projectPath + "/uploads/" + IMAGE_BASE_PATH;
            System.out.println("使用备用路径: " + fallbackPath);
            return fallbackPath;
        }
    }
}