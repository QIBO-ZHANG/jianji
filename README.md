# 简记（AppSkeleton）

iOS 原生应用（SwiftUI + 系统组件 + SwiftData，无第三方依赖）。四个模块：待办、便签、记账、我的，均含增删改查；架构骨架（DI / 路由 / 网络 / 日志 / 错误 / 配置）保留在 `Core/`。

## 运行

```bash
xcodebuild -project AppSkeleton.xcodeproj -scheme AppSkeleton \
  -destination 'platform=iOS Simulator,id=<UDID>' build test
```

打开工程：`open AppSkeleton.xcodeproj`。真机需在自己的 Team 下签名（Signing & Capabilities）。

## 目录约定

| 路径 | 职责 |
| --- | --- |
| `AppSkeleton/App` | `@main` 入口、`RootView`（TabView + 每 Tab 独立 NavigationStack + sheet 分发） |
| `AppSkeleton/Core/DI` | 组装根 `ServiceContainer`，经 `EnvironmentValues.services` 注入 |
| `AppSkeleton/Core/Navigation` | `AppTab` / `AppRoute` / `AppSheet` / `DeepLink` / `AppRouter`（每 Tab 一条返回栈） |
| `AppSkeleton/Core/Networking` | `Endpoint` → `APIClient` → `HTTPTransport`（`URLSessionTransport` / `StubTransport`） |
| `AppSkeleton/Core/Persistence` | `ModelStore`（SwiftData schema 与容器）+ `KeyValueStore`（类型化 UserDefaults） |
| `AppSkeleton/Core/Errors` | `AppError`：所有层统一的错误模型 |
| `AppSkeleton/Core/Logging` | `AppLogger`：`os.Logger` 封装，按 category 分域 |
| `AppSkeleton/Core/Configuration` | 环境（dev/staging/prod）与编译期配置 |
| `AppSkeleton/Core/DesignSystem` | `Theme` 设计令牌（主色 #222222，暗色自适应）+ `.card()` 等修饰符 |
| `AppSkeleton/Features/<Feature>` | 一个模块一个目录：`@Model` + 列表视图 + 编辑器 sheet |
| `AppSkeletonTests` | Core 层与模型层单测（宿主为 App target） |
| `AppSkeletonUITests` | 模拟器冒烟测试：增删改、汇总、sheet、架构自检 |

## 加一个业务模块

1. 在 `AppTab` 增加 case，在 `RootView` 加一个 `Tab` 与 `<Feature>TabRoot`（复制现有四个之一）。
2. 在 `Features/<Feature>` 放 `@Model`、列表视图与编辑器；模型登记进 `ModelStore.schema`。
3. 编辑器走 `AppSheet`（`nil` = 新建，`UUID` = 编辑），push 目的地走 `AppRoute` + `RouteDestination`。
4. 网络请求写成 `Endpoint`，用 `services.api.fetch(Model.self, from:)`，错误统一是 `AppError`。
5. 单测里用 `ModelStore.makeInMemory()` 与 `ServiceContainer.stub(responses:)` 替换真实依赖。

`Features/Scaffold/ScaffoldCheckView.swift` 从「我的 → 架构自检」进入，逐条自检配置 / 请求 / 解码 / 持久化 / 路由 / 日志，可由 UI 测试断言全绿。

## 新增源文件

工程使用传统文件引用（`objectVersion = 56`）。在 Xcode 里新增文件会自动登记；在编辑器外新增文件后，重新生成工程：

```bash
python3 tools/generate-project.py
```

脚本会扫描 `AppSkeleton/` 与 `AppSkeletonTests/`、`AppSkeletonUITests/`，重写 `project.pbxproj` 和共享 Scheme，并校验每个源文件都挂在 group 树上。

## 深链

`Supporting/Info.plist` 注册了 scheme `appskeleton`。`DeepLink.from(url:)` 把链接映射成「Tab + 可选 push」，`AppRouter.open(_:)` 落地；未识别的链接交给调用方处理。

```bash
xcrun simctl openurl <UDID> "appskeleton://ledger"
```

DEBUG 包还支持 `SKELETON_PREVIEW_TAB` 环境变量（`todo` / `note` / `ledger` / `mine`）指定启动 Tab，便于截图与调试：

```bash
SIMCTL_CHILD_SKELETON_PREVIEW_TAB=ledger xcrun simctl launch <UDID> com.qibo.jianji
```

注意两点：环境变量必须用 `SIMCTL_CHILD_` 前缀放在调用环境里（`simctl launch` 的尾参是 argv 不是环境）；模拟器窗口不在前台时渲染会被节流，截图可能抓到启动快照，截图前先把设备窗口切到前台。
