# 智慧校园导览系统 (Smart Campus Guide)

## 一、核心技术栈

### 📱 手机 APP 端 (UniApp)
- **核心框架：** UniApp (Vue 3 语法)
- **最终产物：** Android APP、iOS APP、微信小程序（三端合一）
- **UI/特效：** 原生 CSS3（高斯模糊毛玻璃等科技感特效）

### 💻 管理后台 Web 端 (Vue 3)
- **核心框架：** Vue 3 + TypeScript
- **UI 组件库：** Element Plus

### ⚙️ 核心业务后端 (Java)
- **核心框架：** Spring Boot + MyBatis
- **运行环境：** JDK 17

### 🧠 AI 智能微服务 (Python)
- **核心框架：** Python 3.10+ + FastAPI
- **大模型生态：** LangChain（RAG 知识库和多轮对话）

### 🗄️ 数据存储与缓存
- **主数据库：** MySQL 8.0
- **高速缓存/LBS计算：** Redis（地理围栏高频判定）
- **向量数据库：** Chroma / Milvus（本地 AI 知识库）

---

## 二、开发工具与平台

| 角色 | 工具 | 用途 |
|---|---|---|
| 前端双端开发 | HBuilderX | UniApp 手机端编写与调试 |
| Web 后台开发 | VS Code | Vue 3 管理后台编写 |
| Java 后端开发 | IntelliJ IDEA | Spring Boot 核心业务逻辑 |
| Python AI 开发 | PyCharm / VS Code | FastAPI 人工智能微服务 |
| 团队协作 | Git | 代码版本管理（GitHub / Gitee） |
| API 联调 | Apifox | 接口文档管理与前后端联调 |
| 基础环境 | Node.js v18+ | Vue 3 和 UniApp 运行环境 |

---

## 三、团队分工（4人垂直业务域）

| 同学 | 业务域 | 负责模块 |
|---|---|---|
| **同学 A** | 基础与LBS地图域 | 用户管理、地图展示、实时定位、弱网离线缓存 |
| **同学 B** | 业务内容与后台数据域 | 多媒体讲解内容、管理后台、讲解内容建设 |
| **同学 C** | 核心AI讲解与语音域 | 智能讲解触发、AI动态讲解生成、互动故事 |
| **同学 D** | 智能体与创新交互域 | AI虚拟导游、AR多模态识别、智能路线规划 |

详细分工见qq群

---

## 四、项目目录结构

```
SmartCampusGuide/
│
├── 团队分工方案.md
├── README.md
│
├── 📱 1_CampusApp_UniApp/                # 手机端 (HBuilderX 打开)
│   ├── main.js                           # Vue3 启动入口
│   ├── App.vue                           # 全局样式与生命周期
│   ├── pages.json                        # 路由与导航栏配置
│   ├── uni.scss                          # 全局 SCSS 变量
│   ├── static/images/                    # 静态资源
│   ├── components/                       # 公共组件库
│   │   └── glass-card/                   # 磨砂玻璃卡片
│   └── pages/
│       ├── user_map/                     # 同学A：登录 + 地图
│       ├── spot_content/                 # 同学B：景点详情
│       ├── smart_guide/                  # 同学C：语音播报 + 打卡
│       └── agent_ar/                     # 同学D：聊天 + AR
│
├── 💻 2_AdminWeb_Vue/                    # Web后台 (VS Code 打开)
│   └── src/views/
│       ├── user_sys/                     # 同学A：用户管理
│       ├── content_sys/                  # 同学B：数据大屏 + 景点CRUD
│       ├── ai_config/                    # 同学C：TTS配置 + 语料库
│       └── interactive_sys/              # 同学D：评论审核
│
├── ⚙️ 3_Backend_Java/                   # Java后端 (IDEA 打开)
│   └── src/main/java/com/swu/guide/modules/
│       ├── user_lbs/                     # 同学A：用户鉴权 + 坐标
│       ├── spot_manage/                  # 同学B：景点数据 + 上传
│       ├── trigger_event/                # 同学C：Geofence 触发
│       └── route_social/                 # 同学D：路线规划 + 评论
│
└── 🧠 4_AIService_Python/               # AI微服务 (PyCharm 打开)
    └── modules/
        ├── dynamic_tts/                  # 同学C：文案生成 + TTS
        └── agent_vision/                 # 同学D：RAG检索 + CV
```

---

## 五、Git 协作工作流

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

### 首次克隆项目
```bash
git clone git@github.com:zhouwei20030121-no1/SmartCampusGuide.git
cd SmartCampusGuide
git checkout dev
```

### 日常开发流程（每次写新功能都要这样做）

**第 1 步：切换到 dev 分支并拉取最新代码**
```bash
git checkout dev
git pull origin dev
```

**第 2 步：从 dev 创建你的功能分支（命名规范：`feature/功能名`）**
```bash
# 示例：同学A 写登录功能
git checkout -b feature/login

# 示例：同学C 写地理围栏
git checkout -b feature/geofence

# 示例：同学D 写路线规划
git checkout -b feature/route-plan
```

**第 3 步：在你的功能分支上写代码，然后提交**
```bash
git add .
git commit -m "feat: 完成登录页面UI"
```

**第 4 步：推送功能分支到 GitHub**
```bash
git push origin feature/login
```

**第 5 步：去 GitHub 创建 Pull Request**
- 打开仓库页面 → Pull requests → New pull request
- `base` 选 `dev`，`compare` 选你的 `feature/xxx` 分支
- 填写标题和描述，点击 Create pull request
- 通知 **陈昱霖** 进行代码 Review

### 合并与冲突解决（陈昱霖负责）

陈昱霖收到 PR 后：
1. 在 GitHub 上 Review 代码变更
2. 如果无冲突，直接点击 **Merge pull request** 合并到 `dev`
3. 如果有冲突：
   ```bash
   git checkout dev
   git pull origin dev
   git merge feature/xxx
   # 手动解决冲突文件
   git add .
   git commit -m "merge: 解决 feature/xxx 合并冲突"
   git push origin dev
   ```
4. 合并完成后删除功能分支：
   ```bash
   git branch -d feature/xxx
   git push origin --delete feature/xxx
   ```

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
- **每个功能分支只做一个功能**，不要混在一起
- **每天开始工作前先 `git pull origin dev`**，避免越写越远
- **遇到冲突不要慌**，叫陈昱霖一起来看

---

## 六、快速启动

### 手机 APP 端
```bash
# 用 HBuilderX 打开 1_CampusApp_UniApp 目录
# 运行 → 运行到浏览器 → Chrome
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
