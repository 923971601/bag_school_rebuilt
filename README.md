# 完蛋校园 · bag_school

一个 Flutter 写的「校园卡 + 请假」演示 App。
本仓库的起点是**从一份同学分享的 APK 逆向重建出的 Dart 源码**，之后又在此基础上补了几个原版没做完的功能。

> ⚠️ **这东西是整活用的，不是真请假系统。** 界面是假的、余额是假的、审批流程也是假的。
> 详见底部[来源与免责](#来源与免责)。

---

## 这个项目怎么来的

原 APK 是一个 release 构建的 Flutter 应用，业务代码全在 `libapp.so`（Dart AOT 快照）里。
我用 `apktool` + `jadx` + [blutter](https://github.com/worawit/blutter) 把它还原成了可读的 Dart 工程：

- Dart **没开 `--obfuscate`**，所以类名 / 方法名 / 源文件路径 **100% 保留**
- 所有字符串、颜色、图标码点、尺寸数值都能从 Dart 对象池里逐字取出
- 还原后重新编译出来的 APK，`libflutter.so`、`resources.arsc`、`MaterialIcons` 子集字体、
  启动图标、4 张 jpg **与原件字节级完全相同**

完整的逆向过程、判定依据和保真度说明见 **[RECONSTRUCTION.md](RECONSTRUCTION.md)**。

---

## 功能

### 从原版还原的部分（行为保持一致）

| 页面 | 说明 |
|---|---|
| `main.dart` | 校园卡首页：余额卡（渐变 + 校徽）、10 项功能菜单、底部广告、启动免责声明弹窗 |
| `LeaveRequestPage.dart` | 请假列表，5 条硬编码记录 |
| `LeaveDetailPage.dart` | 请假单详情：`free.jpg` 头图、随机头像、姓名/学号/班级/院系、审批时间轴 |

原版的实际状态：**10 项菜单里只有「请假」接通了**，其余 9 项和「立即申请」、「二维码」三个入口
的 `onPressed` 都是同一个空闭包（`0x3e8c44`），点了没反应。

### 额外实现的部分（原版没有）

| 功能 | 文件 |
|---|---|
| 「立即申请」→ 完整请假表单（类型/事由/时间选择器/目的地/出行方式 + 校验），提交后列表新增一条 | `LeaveApplyPage.dart`、`LeaveRequestPage.dart` |
| 头像可换（相册 / 图片链接 / 重新随机），姓名·学号·班级·院系可改 | `LeaveDetailPage.dart` |
| 请假单所有字段可改（含请假时间的日期+时间选择器） | `LeaveDetailPage.dart` |
| 审批流程可编辑：增减审批级数、改环节 / 角色 / 审批人 | `LeaveDetailPage.dart` |
| 校园卡二维码：余额卡右上角真二维码 + AppBar 图标 → 二维码详情页（可改内容、实时刷新） | `MyQrPage.dart`、`main.dart` |
| **全局状态 + 本地持久化**：改过的内容退出页面/重启 App 都不会变回随机值 | `app_state.dart`（`shared_preferences`） |

---

## 跑起来

### 环境

- Flutter **3.24.3 / Dart 3.5.3**（与原 APK 内置引擎完全同版本）
- JDK 17（Gradle 8.3 官方只支持到 Java 20，**用 JDK 21 会报错**）
- Android SDK：`platforms;android-34` + `build-tools;34.0.0`

### 命令

```bash
flutter pub get
flutter analyze          # 0 issue
flutter test             # 6 个测试
flutter run -d chrome    # 最快：浏览器里看
flutter run              # 模拟器 / 真机
flutter build apk --release
```

国内网络建议先设好镜像（否则 `pub get` 很容易卡住）：

```powershell
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

如果 Gradle 发行包下载失败/损坏，可以把 `android/gradle/wrapper/gradle-wrapper.properties`
里的 `distributionUrl` 换成国内镜像，例如
`https://mirrors.cloud.tencent.com/gradle/gradle-8.3-all.zip`。

VSCode 用户：仓库里带了 `.vscode/launch.json`（Chrome / 模拟器 / 真机 / Profile / 跑测试 五套配置），
把 `settings.json.example` 复制成 `settings.json` 并填上你自己的 SDK 路径即可。

---

## 下载 APK（不想自己编译的）

### 方式一：GitHub Releases（推荐）

去 **[Releases](https://github.com/923971601/bag_school_rebuilt/releases/latest)** 页面，在 **Assets** 里点 `完蛋校园-*.apk` 下载，
传到手机上点开安装即可。首次安装需要允许「安装未知来源应用」。

> 国内直连 GitHub 下载可能很慢或中断，慢的话走下面两个方式。

### 方式二：网盘 / 直接发文件

蓝奏云、阿里云盘、百度网盘都行；好友之间最省事的还是**微信 / QQ 直接发文件**。

> 注意：微信会把 `.apk` 改名成 `.apk.1`，对方收到后**要把文件名末尾的 `.1` 删掉**才能安装。
> （原始 APK 就是这么变成 `base.apk.1(1)` 的，同一个原因。）

### 方式三：自己编译 / Actions 自动编译

见下面的[跑起来](#跑起来)。或者 fork 本仓库，在 **Actions** 页手动触发
`Build & Release APK`，编译好的 APK 会出现在那次运行的 **Artifacts** 里。

### 发新版本

```bash
git tag v1.0.1
git push origin v1.0.1
```

GitHub Actions 会自动编译并把 APK 挂到新 Release 上
（配置见 `.github/workflows/release-apk.yml`）。

### 安装说明

| 项目 | 值 |
|---|---|
| 最低系统 | Android 5.0（minSdk 21） |
| CPU 架构 | universal —— arm64-v8a / armeabi-v7a / x86 / x86_64 都带，任何手机都能装 |
| 权限 | 只有 `INTERNET`（拉随机头像用） |
| 大小 | 约 22 MB |

> 如果手机上已经装了别人的「完蛋校园」，装这个之前**要先卸载** —— 签名不同
> （原作者和我用的都是各自机器的 debug key），不能覆盖安装。

## 目录结构

```
lib/
├── main.dart                 校园卡首页（余额卡、10 项菜单、免责弹窗、卡片二维码）
├── LeaveRequestPage.dart     请假列表 + LeaveRecord 模型
├── LeaveDetailPage.dart      请假单详情 + 审批流程 + 可编辑头像/学籍区
├── LeaveApplyPage.dart       【新增】请假申请表单
├── MyQrPage.dart             【新增】校园卡二维码页
└── app_state.dart            【新增】全局状态 + shared_preferences 持久化
assets/                       4 张图（从原 APK 原样提取）
test/reconstruction_test.dart 6 个 widget 测试，断言全部对着 APK 对象池校验
RECONSTRUCTION.md             逆向过程记录：判定依据、保真度、二进制比对
```

---

## 来源与免责

1. **来源**：本工程的界面布局、文案、数据表来自某同学开发并私下分享的 APK（未公开托管）。
   原 APK 仅作**逆向学习**用途，本仓库**不包含**该 APK、也不包含任何反编译产物
   （blutter / jadx / apktool 的输出一概没有提交）。
2. **署名**：原作者未在 APK 中留下任何署名信息。如果你是原作者并且不希望这份重建版公开，
   开个 issue 我立刻下架。
3. **用途**：这个 App 会生成**看起来很真的假请假条**。请只用于同学之间的玩笑或 UI 学习，
   **不要拿去给老师看或用于任何形式的欺骗**——原作者自己在启动弹窗里就写了四条免责声明。
4. 仓库里出现的「荆州学院」等校名、学号、人名均为原 App 里硬编码的**占位数据**，与真实个人无关。

## License

代码部分以 [MIT](LICENSE) 开放。第三方依赖与资源的授权见各自项目。
