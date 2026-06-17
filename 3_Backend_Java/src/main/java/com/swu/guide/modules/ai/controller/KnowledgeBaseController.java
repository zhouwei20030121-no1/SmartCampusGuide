package com.swu.guide.modules.ai.controller;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.swu.guide.common.Result;
import org.springframework.core.io.UrlResource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/ai/knowledge")
public class KnowledgeBaseController {

    private static final Object FILE_LOCK = new Object();
    private static final TypeReference<List<Map<String, Object>>> LIST_TYPE = new TypeReference<>() {};

    private final ObjectMapper objectMapper;
    private final Path repoRoot;
    private final Path aiRoot;
    private final Path visionDatasetPath;
    private final Path dialogChunksPath;
    private final Path visionImagesDir;

    public KnowledgeBaseController(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        Path currentDir = Paths.get(System.getProperty("user.dir")).toAbsolutePath().normalize();
        this.repoRoot = "3_Backend_Java".equals(currentDir.getFileName().toString()) ? currentDir.getParent() : currentDir;
        this.aiRoot = repoRoot.resolve("4_AIService_Python").normalize();
        this.visionDatasetPath = aiRoot.resolve("data/rag_dataset/dataset.json").normalize();
        this.dialogChunksPath = aiRoot.resolve("data/knowledge_chunks.json").normalize();
        this.visionImagesDir = aiRoot.resolve("data/rag_dataset/images").normalize();
    }

    @GetMapping("/summary")
    public Result<Map<String, Object>> summary() {
        Map<String, Object> data = new LinkedHashMap<>();
        List<Map<String, Object>> visionItems = readList(visionDatasetPath);
        data.put("visionCount", visionItems.size());
        data.put("visionPlaceCount", buildVisionGroups(visionItems).size());
        data.put("dialogCount", readList(dialogChunksPath).size());
        data.put("visionDatasetPath", repoRoot.relativize(visionDatasetPath).toString());
        data.put("dialogChunksPath", repoRoot.relativize(dialogChunksPath).toString());
        data.put("dialogVectorHint", "对话知识库保存后，需要重建 4_AIService_Python/chroma_db 向量索引并重启 AI 服务后完全生效。");
        data.put("visionVectorHint", "AI识别知识库保存或上传照片后，需要重新导入 smart_campus_images 图像向量集合后完全生效。");
        return Result.ok(data);
    }

    @GetMapping("/vision/list")
    public Result<Map<String, Object>> listVision(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size
    ) {
        List<Map<String, Object>> source = buildVisionGroups(readList(visionDatasetPath));
        List<Map<String, Object>> filtered = new ArrayList<>();
        for (Map<String, Object> record : source) {
            if (matches(record, keyword, "buildingName", "description", "sourceUrl", "imagePaths")) {
                filtered.add(record);
            }
        }
        return Result.ok(pageResult(filtered, page, size));
    }

    @PostMapping("/vision")
    public Result<Map<String, Object>> createVision(@RequestBody Map<String, Object> body) {
        String buildingName = firstText(body, "buildingName", "building_name");
        List<Map<String, Object>> items = normalizeVisionItems(body);
        if (buildingName.isBlank()) {
            return Result.fail("名称不能为空");
        }
        if (items.isEmpty()) {
            return Result.fail("至少需要上传或填写一张照片");
        }
        synchronized (FILE_LOCK) {
            List<Map<String, Object>> data = readList(visionDatasetPath);
            data.addAll(items);
            writeList(visionDatasetPath, data);
            return Result.ok(findVisionGroup(data, buildingName));
        }
    }

    @PutMapping("/vision/{key}")
    public Result<Map<String, Object>> updateVision(@PathVariable String key, @RequestBody Map<String, Object> body) {
        synchronized (FILE_LOCK) {
            List<Map<String, Object>> data = readList(visionDatasetPath);
            String buildingName = firstText(body, "buildingName", "building_name");
            List<Map<String, Object>> items = normalizeVisionItems(body);
            if (buildingName.isBlank()) {
                return Result.fail("名称不能为空");
            }
            if (items.isEmpty()) {
                return Result.fail("至少需要上传或填写一张照片");
            }
            boolean removed = data.removeIf(item -> key.equals(text(item.get("building_name"))));
            if (!removed) {
                return Result.fail("识别知识地点不存在");
            }
            data.addAll(items);
            writeList(visionDatasetPath, data);
            return Result.ok(findVisionGroup(data, buildingName));
        }
    }

    @DeleteMapping("/vision/{key}")
    public Result<Void> deleteVision(@PathVariable String key) {
        synchronized (FILE_LOCK) {
            List<Map<String, Object>> data = readList(visionDatasetPath);
            boolean removed = data.removeIf(item -> key.equals(text(item.get("building_name"))));
            if (!removed) {
                return Result.fail("识别知识地点不存在");
            }
            writeList(visionDatasetPath, data);
            return Result.ok();
        }
    }

    @PostMapping("/vision/upload")
    public Result<Map<String, String>> uploadVisionImage(@RequestParam("file") MultipartFile file) {
        if (file == null || file.isEmpty()) {
            return Result.fail("上传文件不能为空");
        }
        String contentType = file.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) {
            return Result.fail("只能上传图片文件");
        }
        if (file.getSize() > 8 * 1024 * 1024) {
            return Result.fail("图片大小不能超过8MB");
        }

        try {
            Files.createDirectories(visionImagesDir);
            String originalName = StringUtils.cleanPath(file.getOriginalFilename() == null ? "image.jpg" : file.getOriginalFilename());
            String ext = extensionOf(originalName);
            String filename = "kb_" + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"))
                    + "_" + UUID.randomUUID().toString().substring(0, 8) + ext;
            Path target = visionImagesDir.resolve(filename).normalize();
            if (!target.startsWith(visionImagesDir)) {
                return Result.fail("非法文件路径");
            }
            file.transferTo(target);

            String imagePath = "data/rag_dataset/images/" + filename;
            Map<String, String> result = new LinkedHashMap<>();
            result.put("imagePath", imagePath);
            result.put("imageUrl", "/api/ai/knowledge/vision/image?path=" + imagePath);
            return Result.ok(result);
        } catch (IOException e) {
            return Result.fail("图片上传失败：" + e.getMessage());
        }
    }

    @GetMapping("/vision/image")
    public ResponseEntity<UrlResource> visionImage(@RequestParam("path") String imagePath) throws MalformedURLException {
        Path filePath = resolveAiFile(imagePath);
        UrlResource resource = new UrlResource(filePath.toUri());
        if (!resource.exists() || !resource.isReadable()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(detectMediaType(filePath)))
                .body(resource);
    }

    @GetMapping("/dialog/list")
    public Result<Map<String, Object>> listDialog(
            @RequestParam(defaultValue = "") String keyword,
            @RequestParam(defaultValue = "") String category,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size
    ) {
        List<Map<String, Object>> source = readList(dialogChunksPath);
        List<Map<String, Object>> filtered = new ArrayList<>();
        for (int i = 0; i < source.size(); i++) {
            Map<String, Object> record = new LinkedHashMap<>(source.get(i));
            record.put("index", i);
            boolean categoryMatched = category == null || category.isBlank() || category.equals(text(record.get("category")));
            if (categoryMatched && matches(record, keyword, "id", "title", "question", "answer", "category", "source_file", "section")) {
                filtered.add(record);
            }
        }
        return Result.ok(pageResult(filtered, page, size));
    }

    @PostMapping("/dialog")
    public Result<Map<String, Object>> createDialog(@RequestBody Map<String, Object> body) {
        Map<String, Object> item = normalizeDialogItem(body);
        if (text(item.get("id")).isBlank()) {
            item.put("id", "manual_" + System.currentTimeMillis());
        }
        if (text(item.get("title")).isBlank() || text(item.get("answer")).isBlank()) {
            return Result.fail("标题和回答内容不能为空");
        }
        synchronized (FILE_LOCK) {
            List<Map<String, Object>> data = readList(dialogChunksPath);
            String id = text(item.get("id"));
            if (findDialogIndex(data, id) >= 0) {
                return Result.fail("知识条目ID已存在");
            }
            data.add(item);
            writeList(dialogChunksPath, data);
            return Result.ok(item);
        }
    }

    @PutMapping("/dialog/{id}")
    public Result<Map<String, Object>> updateDialog(@PathVariable String id, @RequestBody Map<String, Object> body) {
        synchronized (FILE_LOCK) {
            List<Map<String, Object>> data = readList(dialogChunksPath);
            int index = findDialogIndex(data, id);
            if (index < 0) {
                return Result.fail("对话知识条目不存在");
            }
            Map<String, Object> item = normalizeDialogItem(body);
            if (text(item.get("id")).isBlank()) {
                item.put("id", id);
            }
            if (text(item.get("title")).isBlank() || text(item.get("answer")).isBlank()) {
                return Result.fail("标题和回答内容不能为空");
            }
            String newId = text(item.get("id"));
            int duplicateIndex = findDialogIndex(data, newId);
            if (!newId.equals(id) && duplicateIndex >= 0) {
                return Result.fail("知识条目ID已存在");
            }
            data.set(index, item);
            writeList(dialogChunksPath, data);
            return Result.ok(item);
        }
    }

    @DeleteMapping("/dialog/{id}")
    public Result<Void> deleteDialog(@PathVariable String id) {
        synchronized (FILE_LOCK) {
            List<Map<String, Object>> data = readList(dialogChunksPath);
            int index = findDialogIndex(data, id);
            if (index < 0) {
                return Result.fail("对话知识条目不存在");
            }
            data.remove(index);
            writeList(dialogChunksPath, data);
            return Result.ok();
        }
    }

    @GetMapping("/dialog/categories")
    public Result<List<String>> dialogCategories() {
        List<String> categories = readList(dialogChunksPath).stream()
                .map(item -> text(item.get("category")))
                .filter(value -> !value.isBlank())
                .distinct()
                .sorted()
                .toList();
        return Result.ok(categories);
    }

    private List<Map<String, Object>> readList(Path path) {
        try {
            if (!Files.exists(path)) {
                return new ArrayList<>();
            }
            return objectMapper.readValue(path.toFile(), LIST_TYPE);
        } catch (IOException e) {
            throw new IllegalStateException("读取知识库文件失败：" + path, e);
        }
    }

    private void writeList(Path path, List<Map<String, Object>> data) {
        try {
            Files.createDirectories(path.getParent());
            objectMapper.writerWithDefaultPrettyPrinter().writeValue(path.toFile(), data);
        } catch (IOException e) {
            throw new IllegalStateException("写入知识库文件失败：" + path, e);
        }
    }

    private Map<String, Object> pageResult(List<Map<String, Object>> data, int page, int size) {
        int currentPage = Math.max(page, 1);
        int pageSize = Math.min(Math.max(size, 1), 100);
        int total = data.size();
        int from = Math.min((currentPage - 1) * pageSize, total);
        int to = Math.min(from + pageSize, total);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("records", data.subList(from, to));
        result.put("total", total);
        result.put("page", currentPage);
        result.put("size", pageSize);
        return result;
    }

    private Map<String, Object> toVisionRecord(Map<String, Object> item, int index) {
        Map<String, Object> record = new LinkedHashMap<>(item);
        String imagePath = text(item.get("image_path"));
        record.put("index", index);
        record.put("buildingName", text(item.get("building_name")));
        record.put("imagePath", imagePath);
        record.put("sourceUrl", text(item.get("source_url")));
        record.put("imageUrl", imagePath.isBlank() ? "" : "/api/ai/knowledge/vision/image?path=" + imagePath);
        return record;
    }

    private List<Map<String, Object>> buildVisionGroups(List<Map<String, Object>> source) {
        Map<String, Map<String, Object>> groups = new LinkedHashMap<>();
        for (int i = 0; i < source.size(); i++) {
            Map<String, Object> item = source.get(i);
            String buildingName = defaultText(text(item.get("building_name")), "未命名地点");
            Map<String, Object> group = groups.computeIfAbsent(buildingName, key -> {
                Map<String, Object> value = new LinkedHashMap<>();
                value.put("key", key);
                value.put("buildingName", key);
                value.put("description", "");
                value.put("sourceUrl", "");
                value.put("imagePaths", new ArrayList<String>());
                value.put("indices", new ArrayList<Integer>());
                value.put("imageCount", 0);
                return value;
            });

            if (text(group.get("description")).isBlank()) {
                group.put("description", text(item.get("description")));
            }
            if (text(group.get("sourceUrl")).isBlank()) {
                group.put("sourceUrl", text(item.get("source_url")));
            }
            String imagePath = text(item.get("image_path"));
            if (!imagePath.isBlank()) {
                @SuppressWarnings("unchecked")
                List<String> imagePaths = (List<String>) group.get("imagePaths");
                imagePaths.add(imagePath);
                group.put("imageCount", imagePaths.size());
            }
            @SuppressWarnings("unchecked")
            List<Integer> indices = (List<Integer>) group.get("indices");
            indices.add(i);
        }
        return new ArrayList<>(groups.values());
    }

    private Map<String, Object> findVisionGroup(List<Map<String, Object>> data, String buildingName) {
        return buildVisionGroups(data).stream()
                .filter(group -> buildingName.equals(text(group.get("buildingName"))))
                .findFirst()
                .orElseGet(LinkedHashMap::new);
    }

    private List<Map<String, Object>> normalizeVisionItems(Map<String, Object> body) {
        String buildingName = firstText(body, "buildingName", "building_name");
        String description = firstText(body, "description");
        String sourceUrl = firstText(body, "sourceUrl", "source_url");
        List<String> imagePaths = normalizeImagePaths(body);

        List<Map<String, Object>> items = new ArrayList<>();
        for (String imagePath : imagePaths) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("building_name", buildingName);
            item.put("description", description);
            item.put("image_path", imagePath);
            item.put("source_url", sourceUrl);
            items.add(item);
        }
        return items;
    }

    private List<String> normalizeImagePaths(Map<String, Object> body) {
        List<String> imagePaths = new ArrayList<>();
        Object rawImagePaths = body.get("imagePaths");
        if (rawImagePaths instanceof List<?> list) {
            for (Object item : list) {
                String imagePath = text(item);
                if (!imagePath.isBlank() && !imagePaths.contains(imagePath)) {
                    imagePaths.add(imagePath);
                }
            }
        }

        String singleImagePath = firstText(body, "imagePath", "image_path");
        if (!singleImagePath.isBlank() && !imagePaths.contains(singleImagePath)) {
            imagePaths.add(singleImagePath);
        }
        return imagePaths;
    }

    private Map<String, Object> normalizeDialogItem(Map<String, Object> body) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("id", firstText(body, "id"));
        item.put("title", firstText(body, "title"));
        item.put("question", firstText(body, "question"));
        item.put("answer", firstText(body, "answer"));
        item.put("keywords", normalizeKeywords(body.get("keywords")));
        item.put("category", defaultText(firstText(body, "category"), "campus"));
        item.put("source", defaultText(firstText(body, "source"), "web_admin"));
        item.put("source_file", defaultText(firstText(body, "sourceFile", "source_file"), "admin_manual.json"));
        item.put("source_url", firstText(body, "sourceUrl", "source_url"));
        item.put("entity_id", firstText(body, "entityId", "entity_id"));
        item.put("section", firstText(body, "section"));
        return item;
    }

    private List<String> normalizeKeywords(Object value) {
        if (value instanceof List<?> list) {
            return list.stream().map(this::text).filter(item -> !item.isBlank()).toList();
        }
        String raw = text(value);
        if (raw.isBlank()) {
            return List.of();
        }
        String[] parts = raw.split("[,，、\\n\\r]+");
        List<String> result = new ArrayList<>();
        for (String part : parts) {
            String keyword = part.trim();
            if (!keyword.isBlank()) {
                result.add(keyword);
            }
        }
        return result;
    }

    private boolean matches(Map<String, Object> record, String keyword, String... fields) {
        if (keyword == null || keyword.isBlank()) {
            return true;
        }
        String lowerKeyword = keyword.toLowerCase();
        for (String field : fields) {
            Object value = record.get(field);
            if (value instanceof List<?> list && list.stream().anyMatch(item -> text(item).toLowerCase().contains(lowerKeyword))) {
                return true;
            }
            if (text(value).toLowerCase().contains(lowerKeyword)) {
                return true;
            }
        }
        return false;
    }

    private int findDialogIndex(List<Map<String, Object>> data, String id) {
        for (int i = 0; i < data.size(); i++) {
            if (id.equals(text(data.get(i).get("id")))) {
                return i;
            }
        }
        return -1;
    }

    private String firstText(Map<String, Object> body, String... keys) {
        for (String key : keys) {
            if (body.containsKey(key)) {
                return text(body.get(key));
            }
        }
        return "";
    }

    private String defaultText(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

    private String text(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }

    private String extensionOf(String filename) {
        String ext = StringUtils.getFilenameExtension(filename);
        return ext == null || ext.isBlank() ? ".jpg" : "." + ext.toLowerCase();
    }

    private Path resolveAiFile(String rawPath) {
        String normalizedInput = rawPath.replace("\\", "/");
        Path resolved;
        if (normalizedInput.startsWith("4_AIService_Python/")) {
            resolved = repoRoot.resolve(normalizedInput).normalize();
        } else {
            resolved = aiRoot.resolve(normalizedInput).normalize();
        }
        if (!resolved.startsWith(aiRoot)) {
            throw new IllegalArgumentException("非法文件路径");
        }
        return resolved;
    }

    private String detectMediaType(Path path) {
        try {
            String contentType = Files.probeContentType(path);
            return contentType == null ? MediaType.APPLICATION_OCTET_STREAM_VALUE : contentType;
        } catch (IOException e) {
            return MediaType.APPLICATION_OCTET_STREAM_VALUE;
        }
    }
}
