# 智慧校园导览系统 (Smart Campus Guide)

## 一、核心技术栈

### 手机 APP 端 (Flutter)
- **核心框架：** Flutter 3.44 + Dart 3.12
- **状态管理：** Provider
- **本地存储：** SQLite (sqflite)
- **网络请求：** http
- **最终产物：** Android APP、iOS APP（一套代码双端运行）

### 管理后台 Web 端 (Vue 3)
- **核心框架：** Vue 3 + TypeScript + Vite
- **UI 组件库：** Element Plus
- **状态管理：** Pinia
- **图表：** ECharts
- **HTTP 客户端：** Axios

### 核心业务后端 (Java)
- **核心框架：** Spring Boot 3.1 + MyBatis-Plus 3.5.3
- **运行环境：** JDK 17 + Maven
- **安全：** JWT 认证
- **缓存：** Redis

### AI 智能微服务 (Python)
- **核心框架：** FastAPI + Python 3.10+
- **大模型生态：** LangChain（RAG 知识库）
- **向量数据库：** Chroma
- **语音合成：** 阿里云/讯飞 TTS
- **视觉识别：** OpenAI Vision / 多模态模型

### 数据存储与缓存
- **主数据库：** MySQL 8.0
- **高速缓存/LBS计算：** Redis（地理围栏高频判定）
- **向量数据库：** Chroma（本地 AI 知识库）

---

## 二、开发工具与平台

| 角色 | 工具 | 用途 |
|---|---|---|
| 前端双端开发 | VS Code / Android Studio | Flutter 手机端编写与调试 |
| Web 后台开发 | VS Code | Vue 3 管理后台编写 |
| Java 后端开发 | IntelliJ IDEA | Spring Boot 核心业务逻辑 |
| Python AI 开发 | PyCharm / VS Code | FastAPI 人工智能微服务 |
| 团队协作 | Git | 代码版本管理（GitHub） |
| API 联调 | Apifox | 接口文档管理与前后端联调 |
| 基础环境 | JDK 17 / Node.js v18+ / Flutter 3.44 | 各端运行环境 |

---

## 三、团队分工（4人垂直业务域）

| 同学 | 业务域 | 负责功能模块 |
|---|---|---|
| **李卓尔** | 基础与LBS地图域 | 用户登录注册、地图展示、实时GPS定位、弱网离线缓存、数据大屏 |
| **贾丝楠** | 业务内容与后台数据域 | 景点CRUD管理、多媒体讲解内容编辑、管理后台全页面、内容建设 |
| **周玮** | 核心AI讲解与语音域 | 智能语音讲解、TTS语音合成触发、AI文案生成、打卡徽章、路线轨迹 |
| **陈昱霖** | 智能体与创新交互域 | AI对话机器人(RAG)、AR多模态识别、智能路线规划、代码Review与合并 |

---

## 四、项目目录结构（按功能模块组织）

```
SmartCampusGuide/
├── README.md
├── 团队分工方案.md
│
├── 📱 1_CampusApp_Flutter/                         # 手机端
│   ├── lib/
│   │   ├── main.dart                               # 启动入口
│   │   ├── core/
│   │   │   ├── theme/app_theme.dart                # 全局主题（智慧蓝 #4A90E2）
│   │   │   ├── router/app_router.dart              # 命名路由配置
│   │   │   ├── network/network_client.dart         # HTTP 客户端（统一拦截 + Token）
│   │   │   └── storage/local_storage.dart          # SQLite 离线缓存
│   │   ├── features/
│   │   │   ├── user/                               # 【李卓尔】用户认证
│   │   │   │   ├── login_page.dart                 #   登录页
│   │   │   │   ├── register_page.dart              #   注册页
│   │   │   │   └── profile_page.dart               #   个人中心
│   │   │   ├── map/                                # 【李卓尔】地图展示
│   │   │   │   └── map_page.dart                   #   高德地图集成
│   │   │   ├── location/                           # 【李卓尔】实时定位
│   │   │   │   └── location_service.dart           #   GPS 定位 + 坐标上传
│   │   │   ├── cache/                              # 【李卓尔】离线缓存
│   │   │   │   └── cache_service.dart              #   景点数据预加载
│   │   │   ├── spot/                               # 【贾丝楠】景点详情
│   │   │   │   └── spot_detail_page.dart           #   图文/视频展示
│   │   │   ├── guide/                              # 【周玮】智能讲解
│   │   │   │   └── guide_page.dart                 #   播放/暂停 + 多语种切换
│   │   │   ├── chat/                               # 【陈昱霖】AI 对话
│   │   │   │   └── chat_page.dart                  #   聊天 UI + RAG 接口
│   │   │   ├── ar/                                 # 【陈昱霖】AR 识别
│   │   │   │   └── ar_page.dart                    #   相机预览 + CV 识别
│   │   │   ├── route/                              # 【陈昱霖】路线规划
│   │   │   │   └── route_page.dart                 #   路线轨迹绘制
│   │   │   └── social/                             # 【周玮】打卡徽章
│   │   │       └── checkin_page.dart               #   徽章 GridView
│   │   └── shared/widgets/
│   │       └── glass_card.dart                     # 毛玻璃卡片组件
│   ├── pubspec.yaml
│   └── test/
│
├── 💻 2_AdminWeb_Vue/                              # Web后台
│   ├── src/
│   │   ├── main.ts                                 # 入口（Pinia + Router + ElementPlus）
│   │   ├── App.vue                                 # 根组件
│   │   ├── router/index.ts                         # 路由配置
│   │   ├── api/request.ts                          # Axios 封装
│   │   ├── layouts/MainLayout.vue                  # 主布局（侧边栏 + 顶栏）
│   │   ├── styles/global.scss                      # 全局样式
│   │   └── views/
│   │       ├── dashboard/                          # 【贾丝楠】数据大屏
│   │       │   └── Dashboard.vue                   #   统计卡片 + ECharts 趋势图
│   │       ├── user/                               # 【贾丝楠】用户管理
│   │       │   └── UserList.vue                    #   用户列表 CRUD
│   │       ├── spot/                               # 【贾丝楠】景点管理
│   │       │   └── SpotManage.vue                  #   景点 CRUD 表格
│   │       ├── content/                            # 【贾丝楠】内容编辑
│   │       │   └── ContentEdit.vue                 #   讲解文案 + AI 生成
│   │       ├── guide/                              # 【贾丝楠】讲解配置
│   │       │   └── GuideConfig.vue                 #   TTS 引擎 + 触发配置
│   │       ├── route/                              # 【贾丝楠】路线管理
│   │       │   └── RouteConfig.vue                 #   路线 CRUD
│   │       ├── comment/                            # 【贾丝楠】评论审核
│   │       │   └── CommentReview.vue               #   评论通过/驳回
│   │       └── ai/                                 # 【贾丝楠】语料库
│   │           └── CorpusManage.vue                #   语料 CRUD + 搜索
│   ├── package.json
│   └── vite.config.ts
│
├── ⚙️ 3_Backend_Java/                              # Java后端
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/swu/guide/
│       │   ├── GuideApplication.java               # 启动类
│       │   ├── config/
│       │   │   ├── CorsConfig.java                 # 跨域配置
│       │   │   └── MyBatisPlusConfig.java          # 分页插件
│       │   ├── common/
│       │   │   ├── Result.java                     # 统一响应 {code, message, data}
│       │   │   ├── BaseEntity.java                 # 实体基类
│       │   │   └── exception/
│       │   │       └── GlobalExceptionHandler.java
│       │   └── modules/
│       │       ├── user/                           # 【李卓尔】用户模块
│       │       │   ├── entity/User.java
│       │       │   ├── mapper/UserMapper.java
│       │       │   ├── service/UserService.java
│       │       │   ├── service/impl/UserServiceImpl.java
│       │       │   └── controller/UserController.java   # /user/login, /user/register, /user/list
│       │       ├── map/                            # 【李卓尔】地图定位模块
│       │       │   ├── entity/MapLocation.java
│       │       │   ├── mapper/MapLocationMapper.java
│       │       │   ├── service/MapLocationService.java
│       │       │   ├── service/impl/MapLocationServiceImpl.java
│       │       │   └── controller/MapLocationController.java  # /map/location/upload, /map/location/nearby
│       │       ├── spot/                           # 【贾丝楠】景点模块
│       │       │   ├── entity/Spot.java
│       │       │   ├── mapper/SpotMapper.java
│       │       │   ├── service/SpotService.java
│       │       │   ├── service/impl/SpotServiceImpl.java
│       │       │   └── controller/SpotController.java       # CRUD: /spot
│       │       ├── guide/                          # 【周玮】讲解内容模块
│       │       │   ├── entity/GuideContent.java
│       │       │   ├── mapper/GuideContentMapper.java
│       │       │   ├── service/GuideContentService.java
│       │       │   ├── service/impl/GuideContentServiceImpl.java
│       │       │   └── controller/GuideContentController.java  # /guide/content
│       │       ├── route/                          # 【陈昱霖】路线规划模块
│       │       │   ├── entity/RoutePlan.java
│       │       │   ├── mapper/RoutePlanMapper.java
│       │       │   ├── service/RoutePlanService.java
│       │       │   ├── service/impl/RoutePlanServiceImpl.java
│       │       │   └── controller/RoutePlanController.java   # /route/plan, /route/user
│       │       ├── social/                         # 【周玮】社交互动模块
│       │       │   ├── entity/Comment.java
│       │       │   ├── entity/Checkin.java
│       │       │   ├── mapper/CommentMapper.java
│       │       │   ├── mapper/CheckinMapper.java
│       │       │   ├── service/CommentService.java
│       │       │   ├── service/CheckinService.java
│       │       │   ├── service/impl/CommentServiceImpl.java
│       │       │   ├── service/impl/CheckinServiceImpl.java
│       │       │   ├── controller/CommentController.java      # /comment
│       │       │   └── controller/CheckinController.java      # /checkin
│       │       └── ai/                             # 【陈昱霖】AI 语料模块
│       │           ├── entity/CorpusEntry.java
│       │           ├── mapper/CorpusEntryMapper.java
│       │           ├── service/CorpusEntryService.java
│       │           ├── service/impl/CorpusEntryServiceImpl.java
│       │           └── controller/CorpusController.java       # /ai/corpus
│       └── resources/
│           └── application.yml
│
└── 🧠 4_AIService_Python/                          # AI微服务
    ├── main.py                                     # FastAPI 入口（CORS + 路由注册）
    ├── config.py                                   # 环境变量配置
    ├── requirements.txt                            # FastAPI + LangChain + Chroma + httpx
    ├── core_utils/
    │   ├── __init__.py
    │   └── response.py                             # ApiResponse 统一响应
    └── modules/
        ├── __init__.py
        ├── tts/                                    # 【周玮】TTS 语音模块
        │   ├── __init__.py
        │   ├── tts_router.py                       #   /api/tts/generate-script, /api/tts/synthesize
        │   └── tts_service.py                      #   LLM文案生成 + TTS语音合成
        ├── rag/                                    # 【陈昱霖】RAG 知识库模块
        │   ├── __init__.py
        │   ├── rag_router.py                       #   /api/rag/chat, /api/rag/load-corpus, /api/rag/search
        │   └── rag_service.py                      #   向量检索 + 上下文对话
        └── vision/                                 # 【陈昱霖】视觉识别模块
            ├── __init__.py
            ├── vision_router.py                    #   /api/vision/recognize, /api/vision/scene-qa
            └── vision_service.py                   #   建筑识别 + 场景问答
```

---

## 五、API 接口总览

| 模块 | 方法 | 路径 | 负责人 |
|---|---|---|---|
| 用户 | POST | `/user/login` | 李卓尔 |
| 用户 | POST | `/user/register` | 李卓尔 |
| 用户 | GET | `/user/list` | 李卓尔 |
| 地图 | POST | `/map/location/upload` | 李卓尔 |
| 地图 | GET | `/map/location/nearby` | 李卓尔 |
| 景点 | GET | `/spot/list` | 贾丝楠 |
| 景点 | GET | `/spot/{id}` | 贾丝楠 |
| 景点 | POST | `/spot` | 贾丝楠 |
| 景点 | DELETE | `/spot/{id}` | 贾丝楠 |
| 讲解 | GET | `/guide/content/{spotId}` | 周玮 |
| 讲解 | POST | `/guide/content` | 周玮 |
| 路线 | POST | `/route/plan` | 陈昱霖 |
| 路线 | GET | `/route/user/{userId}` | 陈昱霖 |
| 评论 | POST | `/comment` | 周玮 |
| 评论 | PUT | `/comment/review/{id}` | 周玮 |
| 评论 | GET | `/comment/spot/{spotId}` | 周玮 |
| 打卡 | POST | `/checkin` | 周玮 |
| 打卡 | GET | `/checkin/badges/{userId}` | 周玮 |
| 语料 | GET | `/ai/corpus/list` | 陈昱霖 |
| 语料 | POST | `/ai/corpus` | 陈昱霖 |
| 语料 | GET | `/ai/corpus/search` | 陈昱霖 |
| TTS | POST | `/api/tts/generate-script` | 周玮 |
| TTS | POST | `/api/tts/synthesize` | 周玮 |
| RAG | POST | `/api/rag/chat` | 陈昱霖 |
| RAG | POST | `/api/rag/load-corpus` | 陈昱霖 |
| 视觉 | POST | `/api/vision/recognize` | 陈昱霖 |
| 视觉 | POST | `/api/vision/scene-qa` | 陈昱霖 |

---

## 六、Git 协作工作流

### 仓库地址
```
git@github.com:zhouwei20030121-no1/SmartCampusGuide.git
```

### 分支策略

| 分支 | 用途 |
|---|---|
| `main` | 主分支，始终保持稳定可发布状态 |
| `dev` | 开发分支，所有功能分支合并到此 |
| `feature/xxx` | 功能分支，每人每个功能新建一条 |

### 日常开发流程

**第 1 步：切换到 dev 分支并拉取最新代码**
```bash
git checkout dev
git pull origin dev
```

**第 2 步：从 dev 创建功能分支（命名规范：`feature/功能名`）**
```bash
git checkout -b feature/login        # 示例：登录功能
git checkout -b feature/geofence     # 示例：地理围栏
git checkout -b feature/route-plan   # 示例：路线规划
```

**第 3 步：在功能分支上写代码，然后提交**
```bash
git add .
git commit -m "feat: 完成某某功能"
```

**第 4 步：推送功能分支到 GitHub**
```bash
git push origin feature/xxx
```

**第 5 步：去 GitHub 创建 Pull Request**
- `base` 选 `dev`，`compare` 选你的 `feature/xxx` 分支
- 通知 **陈昱霖** 进行代码 Review

### 合并与冲突解决（陈昱霖负责）

1. 在 GitHub 上 Review 代码变更
2. 无冲突 → 点击 **Merge pull request** 合并到 `dev`
3. 有冲突 → 本地解决后推送：
   ```bash
   git checkout dev
   git pull origin dev
   git merge feature/xxx
   # 手动解决冲突
   git add .
   git commit -m "merge: 解决 feature/xxx 合并冲突"
   git push origin dev
   ```
4. 合并完成后删除功能分支

### 提交信息规范
```
feat: 新功能
fix: 修复bug
docs: 文档修改
style: 代码格式（不影响功能）
refactor: 重构
test: 测试相关
```

### 注意事项
- **永远不要直接往 `main` 分支推送代码**
- **每个功能分支只做一个功能**
- **每天开始工作前先 `git pull origin dev`**
- **遇到冲突不要慌，叫陈昱霖一起来看**

---

## 七、快速启动

### 手机 APP 端（Flutter）
```bash
cd 1_CampusApp_Flutter

# 国内网络环境需先设置镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 安装依赖
flutter pub get

# 运行到已连接的设备/模拟器
flutter run

# 或编译 Android APK
flutter build apk --debug
```

### Web 管理后台
```bash
cd 2_AdminWeb_Vue
npm install
npm run dev
```

### Java 业务后端
```bash
cd 3_Backend_Java
mvn spring-boot:run
```

### Python AI 微服务
```bash
cd 4_AIService_Python
pip install -r requirements.txt
uvicorn main:app --reload --port 5000
```
