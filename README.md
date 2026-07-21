# Processor - iOS应用架构文档

## 📱 项目概述

Processor是一个基于Swift和UIKit开发的iOS应用，采用模块化架构设计，专注于图像处理和用户交互体验。项目使用SnapKit进行自动布局，遵循MVC设计模式，并实现了高度可复用的组件化架构。

## 🏗️ 项目架构

### 目录结构

```
processor/
├── AppDelegate.swift              # 应用程序入口
├── SceneDelegate.swift            # 场景管理
├── Info.plist                     # 应用配置
└── src/                          # 源代码目录
    ├── classes/                  # 核心类文件
    │   ├── managers/             # 业务管理器
    │   ├── models/               # 数据模型
    │   ├── pages/                # 页面控制器
    │   ├── views/                # 自定义视图
    │   └── wrappers/             # 基础包装类
    ├── constants/                # 常量定义
    ├── libs/                     # 第三方库封装
    └── resources/                # 资源文件
```

## 🔧 技术栈

- **语言**: Swift 5.0+
- **UI框架**: UIKit
- **布局**: SnapKit (自动布局)
- **架构模式**: MVC + 组件化
- **最低支持**: iOS 18.0+


## 🎨 设计原则

### 1. 单一职责原则
每个组件只负责一个特定功能，便于维护和测试。

### 2. 组件化设计
- 高内聚，低耦合
- 可复用的UI组件
- 独立的事件处理

### 3. 响应式布局
- 使用SnapKit进行约束布局
- 适配不同屏幕尺寸
- 安全区域自动适配

### 4. 主题一致性
- 统一的颜色管理
- 一致的字体和间距
- 标准化的UI组件


## 📱 功能模块

### 入口模块 (Entrance)
- 启动页面
- 主根页面 (TabBar控制器)

### 登录模块 (Login)
- 用户认证
- 登录状态管理

### 首页模块 (Home)
- 主要功能入口
- 内容展示

### 个人中心模块 (Mine)
- 用户信息管理
- 会员功能
- 图片管理

### 相机模块 (Camera)
- 图像捕获
- 图像处理

## 🔍 代码规范

### 命名规范
- 类名: `LM` + 功能描述 + 类型 (如: `LMMinePage`)
- 组件: `LM` + 功能描述 + `View` (如: `LMProfileView`)
- 管理器: `LM` + 功能描述 + `Manager` (如: `LMPackageManager`)

### 文件组织
- 按功能模块分组
- 相关文件放在同一目录
- 使用MARK注释分隔代码段

## CocoaPods 环境

项目依赖 CocoaPods。若终端提示 `pod: command not found`，任选其一：

### 方式 A — 一键脚本（推荐）

```bash
cd entropix_ios_app/processor
chmod +x setup_pods.sh
./setup_pods.sh
```

### 方式 B — 手动 PATH

CocoaPods 可能已安装在用户 gem 目录，只需加入 PATH：

```bash
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"
cd entropix_ios_app/processor
pod install
```

将上面 `export` 行加入 `~/.zshrc` 可永久生效。

### 方式 C — 新版 Ruby + CocoaPods（与 Podfile.lock 1.16.x 一致）

系统 Ruby 2.6 最高支持 CocoaPods 1.13。若需 1.16+，请先安装 [Homebrew](https://brew.sh)，再执行：

```bash
brew install ruby cocoapods
cd entropix_ios_app/processor
pod install
```

安装完成后请打开 **`processor.xcworkspace`**（不要直接打开 `.xcodeproj`）。
