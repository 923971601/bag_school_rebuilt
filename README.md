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
