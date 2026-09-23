# Entropix（Processor）— iOS

**Entropix** 是一款以相机为首页的 **AI 摄影教练** App（App Store 展示名 *Entropix*，工程 Target 名 `processor`，Bundle ID `com.entropix.inspirecam`）。用户对着实景取景，由端侧 ML + 自带 Key 的云端大模型（BYOK）生成构图模板，再通过 AR / Agent 引导对齐并拍摄。

本仓库是 FramAist / Entropix 产品的 **iOS 客户端**。跨端设计原则见同目录 [`DESIGN.md`](./DESIGN.md)；实现细节与 SPEC 见仓库外 `docs/ios/`。

---

## 1. 产品思路与创意

### 1.1 核心命题

很多人站在漂亮场景前，却不知道怎么框。Entropix 不是「再做一个滤镜相机」，而是：

1. **看懂场景** — Find Spot / Scene Explore：从冻帧里找出值得拍的点位（Spot），可选热力图。
2. **给出可拍的样子** — Inspire Me / Idea Inspiration：按当前画面（或 Spot 附录）生成一组构图建议图。
3. **教你对准** — Composition Selected + Agent：参考图叠在预览上，用框 / 线稿 / 语义动作 + 实时打分，把「模板」还原成快门那一瞬间。

产品原则（与 `DESIGN.md` 一致）：**Camera-first**、**Coach, don’t clutter**、取向诚实（事件开始时锁定方向再采样）、跨端行为对齐。

### 1.2 当前运行模式（重要）

| 能力 | 当前状态 |
|------|----------|
| FramAist 业务 Backend（登录 / Composition 上传轮询 / 订阅额度闸门） | **硬关闭**（`LMFeatureFlagsManager.backendApiEnabled == false`） |
| 用户模型调用 | **BYOK**：Mine → Setting → Models，按模块配置 Base URL / API Key / 模型 |
| 启动身份 | Splash 走 `LMUserManager.setupLocalBYOKUser()`，不拉起游客注册登录 |
| Offline / 未配置 Inspiration | Inspire Me 可回落本地 `demo_suggestions` 资源 |
| 广告 | `GoogleAdConfigs.adsEnabled = false`（本版关闭）；Demo 单元仍保留，发版改 `true` 可再开 |

也就是说：当前主线是 **本地 App + 用户自己的模型密钥**，而不是依赖 `https://framaist.entropixai.com` 构图服务。Backend 相关代码大量保留在 `FRAMAIST_BACKEND_DISABLED` 注释块内，便于以后重新打开。

### 1.3 三条主路径（相机内）

```
Basic Camera (.normal)
 ├── Find Spot ──► 冻帧分析 (.sceneExploreProcessing)
 │                 ├── 结果图 Spot / 热力图 (.sceneExploreResult)
 │                 ├── Path A：选 Spot → Get Template → Inspire（带 Spot prompt 附录）
 │                 └── Path B：Go to Spot → 现场对齐 (.exploreGoToSpot)
 ├── Inspire Me / Composition ──► 冻帧 (.inspireMeProcessing)
 │                                 └── 建议图轮播 (.showingSuggestions)
 └── 选中建议图 ──► Composition Selected (.compositionSelected)
                     └── Agent / Box / Line Art + Score Donut + 快门 Instruct/Capture
```

**广告落点（代码已接好；`adsEnabled == false` 时全部跳过）：**

| 时机 | 形态 | 说明 |
|------|------|------|
| Splash → 进首页前 | App Open | 不打断已进入的相机预览 |
| Mine 页 | Adaptive Banner | 仅个人中心 |
| Find Spot 冻帧分析中 | Interstitial | 有缓存才立刻出；结果先到则等关闭后再进结果页 |
| Suggestion 卡片仍在 loading（`ready != true`） | Interstitial | 数据可先写进内存，轮播 UI 等关闭再刷新 |
| Inspiring 冻帧（`.inspireMeProcessing`） | **不出广告** | 与产品确认一致 |

总开关：`AppConfigs.GoogleAdConfigs.adsEnabled`。关闭时不 `MobileAds.start`、不 preload/show。开启后关闭按钮由 Google SDK 控制；未预加载则跳过，不阻塞 loading。

---

## 2. 仓库结构

```
entropix_ios_app/
├── README.md                 # 本文件
├── DESIGN.md                 # 跨端设计原则 / 视觉与广告放置规则
├── .gitignore
└── processor/                # Xcode / CocoaPods 工程根
    ├── Podfile / Podfile.lock
    ├── setup_pods.sh         # 一键装 CocoaPods + pod install
    ├── processor.xcworkspace # ← 始终打开这个
    ├── processor.xcodeproj
    ├── Pods/
    ├── tests/                # 少量 AR 相关测试辅助
    └── processor/            # App Target 源码与资源
        ├── AppDelegate.swift
        ├── SceneDelegate.swift
        ├── Info.plist        # 含 GADApplicationIdentifier
        └── src/
            ├── classes/
            │   ├── coaching/     # Agent / Score / LLM 运行时（对标 Android）
            │   ├── managers/     # 业务门面、广告、存储、Explore、用户等
            │   ├── models/
            │   ├── pages/        # UIViewController：camera / entrance / mine / login …
            │   ├── views/        # 可复用 UI（相机控件、轮播、HUD…）
            │   └── wrappers/     # 导航 / 弹窗等壳
            ├── constants/        # AppConfigs、文案、主题等
            └── resources/
                ├── Assets.xcassets
                ├── config/       # prompt、model_config、policy JSON
                ├── demo_suggestions/
                ├── *.mlpackage   # EVA02 / DepthAnything / PiDiNet / U2-Netp
                └── processor.xcdatamodeld
```

命名约定：类型前缀 **`LM`**（历史命名），例如 `LMCameraPage`、`LMInterstitialAdManager`。相机页按职责拆成多个 extension 文件（`+SceneExplore`、`+InspireMe`、`+ShowSuggestions`、`+ARGuidance`、`+AgentCoaching`…）。

---

## 3. 技术栈

| 层 | 选择 |
|----|------|
| 语言 / UI | Swift · UIKit · iOS **18.0+** |
| 布局 | SnapKit |
| 网络 | Alamofire |
| 图片 | Kingfisher |
| 密钥 | KeychainAccess |
| 动效 / Toast | lottie-ios · Toast-Swift |
| 广告 | Google-Mobile-Ads-SDK（+ UMP 随 Pod 拉取） |
| 端侧 ML | Core ML 包：EVA02、DepthAnythingV2、PiDiNet、U2-Netp；Vision 人体框等作回退 |
| 架构风格 | MVC + 组件化；相机状态机与 Android `CameraState` 对齐；广告等模块用 Protocol + Manager（依赖倒置，页面不直接 import GoogleMobileAds） |

---

## 4. 模块说明

### 4.1 入口（`pages/entrance`）

- **`LMLaunchSplashPage`**：隐私同意 → 本地 BYOK 用户 → 预加载 App Open → 进首页。
- **`LMMainRootPage`**：`UITabBarController`；产品是 **相机优先**，个人中心等为离开相机后再进入的目的地。

### 4.2 相机（`pages/camera` + `views/camera`）

- 预览、快门、侧栏（闪光 / 比例 / 定时 / 网格 / 翻转等；UI 铬件大量用 **SF Symbols**）。
- **Pre-Shoot Plan**：Find Spot ↔ Composition（Inspire）模式切换。
- **Show Suggestions**：横向构图卡片；占位 `ready: false` 时显示进度感 UI。
- **Composition Selected**：参考图 + AR 引导 + Agent Coaching Bubble + Score Donut。
- 方向诚实：Inspire / Score tick 在事件开始锁定 orientation 再采样。

### 4.3 Coaching / Score（`classes/coaching`）

对标 Android agentic coaching：

- 构图分：全局结构（EVA02）、几何线 / 规则（PiDiNet + U2 + Depth 或 Vision 回退）、人物场景等。
- Agent：OpenAI-compatible Vision Chat（SSE），按模块读 `LMLlmModuleSettingsStore`；执行工具可为 Box / Line Art / 纯语义动作。
- Instruct 快门角色机：Thinking → 动作展示 → Capture。

### 4.4 Find Spot / Scene Explore（`managers` + `+SceneExplore`）

- `LMSceneExploreClient` 调用户配置的 Vision Chat 模型解析 Spot。
- `LMGaussianHeatmapRenderer` 在冻帧上渲染热力；过宽场景可隐藏热力。
- `LMSceneHistoryStore` 可落盘历史，Mine 侧有浏览页。

### 4.5 Inspire Me / Inspiration（`LMCompositionService` 等）

- 默认 **Direct Gemini**（`inspireMeDirectGeminiEnabled`，启动默认 ON）：设备直连 Gemini `generateContent` 出 2×2 拼图再切四格，不经 FramAist Composition `/analyze` 轮询。
- Prompt 打捆在 `resources/config/gemini_inspire_prompt.txt`。
- Path A 会把 Spot 名称 / 理由追加进 prompt。

### 4.6 个人中心（`pages/mine`）

图库 / 已存 Idea / Scene History、设置、语言、关于、订阅页骨架、**Models** 三模块配置、FAQ / About 等。Mine 底部挂 **Banner** 广告宿主。

### 4.7 广告（`managers`）

| 类型 | 关键类型 |
|------|----------|
| Bootstrap | `LMMobileAdsBootstrap` |
| App Open | `LMAppOpenAdManager` + `LMGoogleAppOpenAdLoader` |
| Banner | `LMBannerAdHost` |
| Interstitial | `LMInterstitialAdManager` + `LMGoogleInterstitialAdLoader` |

策略：先查 `adsEnabled`，再查单元 ID 非空；**忽略** `backendApiEnabled`（业务 Backend 关了广告仍可出）。

### 4.8 登录模块（`pages/login`）

代码仍在；在 Backend 硬关闭 + BYOK 启动路径下，正常冷启动 **不会** 进入游客/账号登录。不要在合并旧 `feat-ads` 分支时无意解开 Splash 注释。

---

## 5. 配置指南

### 5.1 编译期：`AppConfigs.swift`

| 配置 | 用途 |
|------|------|
| `Host.release` | FramAist 域名（Backend 关闭时基本不用） |
| `GoogleAdConfigs.*` | `adsEnabled` + AdMob App ID / App Open / Banner / 两处 Interstitial（单元仍为 Google **Demo** ID） |
| `llmCallQuotaInitial` | Scene Explore / Inspire / AR Guidance 各模块本地调用配额初始值（默认 100） |
| `Gemini.*` | Direct Inspiration 默认 base、超时、输入边长、prompt 路径等（**密钥不写这里**） |
| `AgentLLM.*` | Agent 编译期辅助；默认 base/model **故意为空**，运行时读 Models |

### 5.2 用户密钥：Mine → Setting → Models

按模块独立配置（`LMLlmModuleSettingsStore`，Keychain）：

| 模块 | 典型用途 | 传输形态 |
|------|----------|----------|
| **Scene Explore** | Find Spot | OpenAI-compatible Chat + Vision |
| **Idea Inspiration** | Inspire Me 出图 | Gemini 图像（及 SPEC 中的扩展 Provider） |
| **AR Guidance** | Agent 教练 | OpenAI-compatible Chat + Vision + SSE |

解析顺序：**用户 Save → `resources/config/model_config.json` → 空默认**。  
仓库内 `model_config.json` 可预填非密钥字段（如 Inspiration 的 Gemini base / model）；**不要把真实 API Key 提交进 Git**。

### 5.3 Feature Flags（`LMFeatureFlagsManager`）

| Flag | 默认 | 含义 |
|------|------|------|
| `backendApiEnabled` | 恒 `false` | FramAist 业务 API |
| `inspireMeDirectGeminiEnabled` | `true` | Inspire 走设备直连 Gemini |
| `useNeuralGeometricScorers` | `true` | 几何分优先神经模型，缺模型则 Vision 回退 |

### 5.4 打捆资源（`resources/config/`）

常见文件：`model_config.json`、`gemini_inspire_prompt.txt`、`scene_explore_*_prompt.txt`、`system_prompt_agentic_v3.txt`、`prompts.json`、`coaching_policy.json`、各模块 `*_config.json`。

### 5.5 AdMob

当前 **`adsEnabled = false`**（无广告上线）。重新启用时：

1. 将 `AppConfigs.GoogleAdConfigs.adsEnabled` 改为 `true`
2. `Info.plist` → `GADApplicationIdentifier` 必须与 `appid` 一致
3. 替换 Demo 广告单元 ID，并完成 app-ads.txt / Marketing URL 验证
4. 按需补 ATT / UMP 合规流程

Demo 单元仍保留在 `AppConfigs.GoogleAdConfigs`（App Open / Banner / Interstitial）。

### 5.6 隐私与权限

相机用途文案在 Build Settings：`NSCameraUsageDescription`。UI 强制 Light（`UIUserInterfaceStyle = Light`）。设计系统以海军蓝 + 相机全黑预览为主，见 `DESIGN.md`。

---

## 6. 使用方式（开发）

### 6.1 环境

- macOS + Xcode（支持 iOS 18 SDK）
- CocoaPods（可用仓库脚本安装用户 gem 版）

### 6.2 安装依赖

在 `entropix_ios_app/processor` 下：

```bash
chmod +x setup_pods.sh
./setup_pods.sh
```

或手动：

```bash
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"   # 若 pod 不在 PATH
pod install
```

### 6.3 打开工程

```bash
open processor.xcworkspace
```

**不要**只打开 `processor.xcodeproj`，否则会出现找不到 Alamofire / SnapKit 等模块。

### 6.4 真机联调建议

1. 运行 App，同意隐私与相机权限。  
2. 打开 **Mine → Setting → Models**，至少配置：
   - Idea Inspiration（Gemini base + key + 图像模型）才能走 Direct Inspire；
   - Scene Explore / AR Guidance（Vision Chat）才能 Find Spot / Agent。  
3. 回到相机：试 Find Spot、Inspire Me、选建议图进 Agent。  
4. 广告：需联网；Demo 创意有时需预热，冷启动后第二次进入 loading 更容易看到插页。

### 6.5 分支说明（开发中）

近期相关工作多在 `merge/feat-ads-into-dev-localGemini`（相对 `dev-localGemini` 叠了 SF Symbol 迁移、AdMob 接线、插页等）。合并旧 `feat-ads` 全量历史时注意 **不要** 把已注释的 Splash 游客登录重新激活；广告能力以「嫁接进最新行为」为准。

---

## 7. 设计与文档索引

| 文档 | 内容 |
|------|------|
| [`DESIGN.md`](./DESIGN.md) | 产品意图、视觉 Token、相机 / Agent UX、广告放置原则 |
| `docs/ios/ios-inspire-me-direct-gemini-spec.md` | Direct Gemini Inspiration |
| `docs/ios/ios-models-multi-provider-spec.md` | Models 多 Provider |
| `docs/ios/ios-admob-test-study-plan.md` | AdMob 学习接线 |
| `docs/ios/ios-sf-symbol-migration-spec.md` | SF Symbol 迁移映射 |
| `docs/ios/ios-agentic-guidance-parity-plan.md` | Agent 与 Android 对齐 |
| `docs/ios/iOS_APP_CHANGELOG.md` | 变更记录 |
| `docs/ios/entropix_ios_app_util_list.md` | 可复用工具清单 |

（`docs/` 在 FramAist 工作区根目录，不一定在本 git 仓库内。）

---

## 8. 代码规范（简版）

- 类 / 文件：`LM` + 职责 + 类型后缀（`Page` / `View` / `Manager` / `Store`）。
- 相机状态、文案、主题走统一常量与 `LMText`，避免魔法字符串散落。
- UI 更新在主线程；重 ML 预测放后台，离开 Composition 时异步卸载模型，避免卡死。
- 注释：Swift 侧对公开 API 使用文档注释（`///` / 多行 `/** */`，参数用 `- Parameter`）。
- 图标：产品 UI 铬件优先 SF Symbol（`UIImage.lmSymbol`）；品牌 Logo、教程、比例资产等仍用 Raster（见 SF Symbol SPEC）。

---

## 9. 一句话总结

**Entropix iOS = 相机首页的 AI 构图教练**：用 BYOK 大模型「找点 / 出模板」，用端侧分数与 Agent「把模板拍回来」；FramAist 云业务当前关闭，广告总开关默认关闭。开发请打开 **`processor/processor.xcworkspace`**，先配 Models，再拍。
