# 完蛋校园 · 源码重建说明

本工程由 `base.apk` 里的 **`lib/arm64-v8a/libapp.so`（Dart AOT 快照，ARM64 机器码）**
逆向回译而成。原始工程路径（快照里泄漏的）：
`<原作者本机工程目录>/`

---

## 1. 数据来源与保真度

| 内容 | 来源 | 保真度 |
|---|---|---|
| 所有中文字符串 | Dart 对象池 | **100%（逐字）** |
| 菜单 10 项的标题 / 图标 / 颜色 | 对象池 `List<Map<String,dynamic>>(10)` + `IconData`/`Color` 对象 | **100%** |
| 学生姓名池 / 学号池 / 学院池 / 班级池 | 对象池字符串常量 | **100%** |
| 请假记录 5 条的日期 | 对象池字符串常量 | **100%** |
| 网络请求 URL / JSON 取值路径 | 对象池 + `[package:http] ::get` 调用 | **100%** |
| `Duration`（-30 分钟 / +3 小时） | `movz/movk` 立即数 | **100%** |
| 渐变两色 `0xFFFD5860` / `0xFFFF906C` | `movz/movk` 立即数 | **100%** |
| `Color(0xFF0A82CD)` | `movz/movk` 立即数 | **100%** |
| 字号 / 间距 / 宽高 / 圆角 | 对象池 `Double` 常量 | **~95%** |
| 类结构、方法、导航关系 | 反汇编符号 | **~100%** |
| Widget 树嵌套 | `AllocateXxxStub` 调用序列反推 | **~90%** |
| 变量名 / 代码排版 / 注释 | — | **无法还原**（AOT 不保留） |

---

## 2. 关键逆向判定（过程留痕）

### 2.1 `Colors.grey[...]` 到底取哪个色号？
反汇编里是 `movz x2, #0x3e8`（=1000）后调用 `_ConstMap.[]`。1000 不在
`Colors.grey` 的色号表里（50…900）。判定方法：

* 字符串键（`map['icon']`）与整数键（`Colors.grey[x]`）调用的是**同一个函数地址
  `0x3eb994`**（`_ConstMap.[]`）。字符串键必然是**带标记指针**，所以整数键必然是
  **带标记 Smi**；Dart 的 Smi 编码是 `value << 1`。
* 因此寄存器里的 1000 = `Smi(500)` → **`Colors.grey[500]`**。
* 同理 `#0x640`(=1600) → `Colors.grey[800]`；`#0x2bc`(=700) → `Colors.grey[350]`。
* 若按"未标记"理解会得到 `grey[1000]`/`grey[1600]` —— 两个不存在的色号，
  且在同一个文件里反复出现，不合常理。

### 2.2 菜单是 10 项还是 5 项？
`_buildMenuItems` 里 `movz x2, #0xa`（=10）后调用 `_GrowableList`。
判据：`colect()` 里 `_Random::nextInt` 的返回值被调用方用
`BoxInt64Instr`（`sbfiz x0, x2, #1, #0x1f`）**装箱** —— 说明 `nextInt` 用的是
**未标记 int ABI**（参数与返回一致）。所以立即数 **10 就是 10**，
`Random().nextInt(10)`、菜单 **10 项**。
（若按 Smi 理解会变成 5 项，那么 `请假`（第 8 项）永远渲染不出来，
整个请假功能不可达 —— 与 APK 里存在 3 个业务文件矛盾。）

### 2.3 "请假"菜单项为什么是 `Icons.timer`？
`IconData` 对象的码点从对象池取出后，对 **Flutter 3.24.3 的 `icons.dart`** 反查得到：
`0xe19f credit_card`、`0xe0b2 attach_money`、`0xe50c receipt`、`0xe3ae lock`、
`0xe6c7 vpn_key`、`0xe481 payment`、`0xe381 link_off`、**`0xe662 timer`**、
`0xe159 check_circle`、`0xe25a fastfood`。

### 2.4 只有「请假」能点
`_buildMenuItem` 的 `onTap` 闭包（VA `0x2ad850`）里：`r16 = "请假"` 比较，
相等则 `Navigator.push(LeavePage)`，否则 `ClosureCall` 一个**空闭包**。
所以另外 9 项点了没反应 —— 这是**原程序的真实行为**，不是重建造成的。

---

## 3. 验证结果（实测）

用与 APK **完全同版本**的 SDK（Flutter 3.24.3 / Dart 3.5.3）实测：

```
$ flutter --version
Flutter 3.24.3 • channel stable • revision 2663184aa7 • 2024-09-11
Tools • Dart 3.5.3 • DevTools 2.37.3

$ flutter analyze
No issues found! (ran in 13.9s)

$ flutter test
00:01 +2: All tests passed!
```

`test/reconstruction_test.dart` 断言了这些**逐字来自对象池**的内容：

| 断言 | 结果 |
|---|---|
| 启动弹出 `警告！` + 四条免责声明 + `确认` | ✓ |
| 首页 `校园卡` / `荆州学院` / `212310264 (有效期:2099-12-31)` / `¥ 520.1` | ✓ |
| `注意：本服务由完蛋校园提供技术支持` | ✓ |
| 10 项菜单标题全在（`find.byType(ListTile)` == 10） | ✓ |
| 只有 `请假` 能跳页 → 请假列表出现 `立即申请` | ✓ |
| 5 条请假记录（`List<LeaveRecord>` 长度 == 5），日期与对象池一致 | ✓ |
| 详情页 `姓名:/学号:/班级:/院系:` + 随机值落在对象池名单内 | ✓ |
| `请假单` / `审批流程` 两个 Tab、`湖北省-荆州市-荆州区` 等文案 | ✓ |

### 测试抓到的一个真实保真 bug（已修）

第一版我把广告条放在 `bottomNavigationBar`，测试报 `body` 高度 = 0，整个页面点不动。
回查反汇编：`Scaffold` 只存了 3 个槽位，其中 `field_17 = Column(children: [Container(滚动区),
_buildBottomAd()])` —— 也就是**广告条在 body 的 Column 里**，不是 bottomNavigationBar；
另外 `field_33` 存的是一个 `Color` 对象 = `Colors.grey[100]`，即 `backgroundColor`。
改正后 body 高度正常，命中测试通过。**这就是"跑测试"相对于"读汇编"的价值。**

### 命名规范 lint 为什么被屏蔽

`name`、`code`、`LeaveDetailPage.dart`、`LeavePage.Stime/Etime` 这些"不合规范"的名字
就是**原始工程的真实命名**（AOT 快照里逐字保留），所以用 `// ignore_for_file:` 屏蔽
`file_names` / `camel_case_types` / `non_constant_identifier_names`，而不是改名。

---

## 4. 构建（已在本机跑通）

### 4.1 本机环境

| 组件 | 版本 / 路径 | 说明 |
|---|---|---|
| Flutter | 3.24.3 stable / Dart 3.5.3 | 与 APK 内置引擎**完全同版本** |
| JDK | Temurin 17.0.20.1 | 本机只有 JDK21，但 Gradle 8.3 只支持到 Java 20，
故在 `gradle.properties` 里写了 `org.gradle.java.home` |
| Android SDK | `platforms;android-34` + `build-tools;34.0.0` + `platform-tools` | cmdline-tools 11076708 |
| Gradle | 8.3（模板默认，未改） | `distributionUrl` 指向腾讯云镜像（官方源经代理会下载成损坏 zip） |
| Maven | 阿里云镜像 + 官方源 | `settings.gradle` / `build.gradle` 里已加 |

```bash
flutter pub get
flutter analyze      # No issues found!
flutter test         # All tests passed!
flutter build apk --release
# => build/app/outputs/flutter-apk/app-release.apk (19.5MB)
```

### 4.2 与原件 APK 的二进制比对 ← 最硬核的验证

拿重建产出的 APK 和原 `base.apk` 逐条目对比：

| 文件 | 原 APK | 重建 APK | 结果 |
|---|---|---|---|
| `lib/arm64-v8a/libflutter.so` | 10,714,752 | 10,714,752 | **字节完全相同** |
| `lib/x86_64/libapp.so` | 4,326,304 | 4,326,304 | 同大小 |
| `lib/arm64-v8a/libapp.so` | 4,260,768 | 4,260,768 | 同大小 |
| `lib/armeabi-v7a/libapp.so` | 4,735,572 | 4,702,804 | 差 32,768（恰好一页对齐） |
| `assets/flutter_assets/fonts/MaterialIcons-Regular.otf` | 2,800 | 2,800 | **字节完全相同** |
| `resources.arsc` | 56,132 | 56,132 | **字节完全相同** |
| `FontManifest.json` | 208 | 208 | **字节完全相同** |
| `AssetManifest.bin` | 303 | 303 | **字节完全相同** |
| `res/*.png`（5 个启动图标） | 7,043 ×5 | 7,043 ×5 | **字节完全相同** |
| `assets/*.jpg`×4 | — | — | **字节完全相同** |
| `AndroidManifest.xml` | 6,572 | 6,572 | 同大小；`aapt2 dump xmltree` 归一化后**内容集合完全一致** |
| `classes.dex` | 755,748 | 758,528 | 差 +0.37% |
| `NOTICES.Z` | 85,546 | 85,500 | 差 -0.05%（依赖集已对齐） |
| 条目总数 | 149 | 152 | 多出的 3 个是 androidx 的 LICENSE.txt 与 R8 服务文件重命名 |

> `libapp.so` 同大小但内容不同 —— 因为我重写的是**行为等价**的 Dart 代码，
> 不是原作者逐字相同的源码（变量名/代码组织在 AOT 里不存在，无法恢复）。

### 4.3 这个"编译 → 二进制对比 → 回查反汇编 → 改源码"闭环抓出了 3 个 bug

这三个都是**只读汇编发现不了的**：

1. **缺少 1 个图标**。首次构建后子集字体是 2,712 字节，原件是 2,800 字节。
   写了个 TrueType `cmap` 解析器对比两边字形集：原件 19 个、重建 18 个，
   缺的正是 **`0xe3ab` = `Icons.location_on`**。回对象池果然有：
   `[pp+0xeba8] IconData(0xe3ab)` + `Alignment(1,0)` —— 是「请假位置」那行靠右的定位图钉。
   补上后子集字体 **2,800 字节，字节级相同**。
2. **release 版没有 INTERNET 权限**。Flutter 模板只把 `INTERNET` 放在
   `android/app/src/debug|profile/AndroidManifest.xml` 里，**release 必须在 main 里自己声明**。
   原件有（仅此一项权限），我漏了 —— 直接后果是打包出来的 APK 永远拉不到
   `randomuser.me` 头像，只能显示「加载失败」。已补到 main manifest。
3. **`body` 高度塔成 0**（见第 4 节）：广告条位置错了。

还发现一个**依赖线索**：第一次构建后 `classes.dex` 比原件小 39KB、`NOTICES.Z` 差 0.4%。
回查发现原 Dart 快照里有 `sqflite_*` / `path_provider_*`——它们**在业务代码里零引用**，
但 `dart_plugin_registrant.dart`（快照里确实有那个 `file:///D:/<原作者用户名>/.../dart_plugin_registrant.dart`）
会把 pubspec 里声明的插件都变成**可达代码**，所以不会被 tree-shake。
补上 `sqflite` + `path_provider` 后，`classes.dex` 差 0.37%、`NOTICES.Z` 差 0.05%。

---

## 7. 新增功能（超出了“重建”范围，额外实现的）

> ⚠️ 下面这些是**新写的**，原件里没有。加了它们之后，
> 第 4.2 节里“字节级相同 / 同大小”的结论**不再成立**（图标字体、`libapp.so`、
> `classes.dex` 都会变）。想看纯粹的重建版就对 `git stash` 或对照本节的改动撤掉。

### 7.1 「立即申请」按钮

**原版是空回调**。反汇编证据：`LeavePage::build` 里 ElevatedButton 的 `onPressed`
指向 `[pp+0xb0f8] Function: (0x3e8c44)` —— `0x3e8c44` 就是那个共用的**空闭包**实例，
和首页 9 个失效菜单项用的是同一个。所以原作者没写申请页。

实现内容：

* 新文件 `lib/LeaveApplyPage.dart`：请假类型（事假/病假/公假/其他）、申请事由、
  开始/结束时间（`showDatePicker` + `showTimePicker`）、目的地、出行方式，
  带校验（事由非空、结束不早于开始）。
* `lib/LeaveRequestPage.dart`：`LeavePage` 从 `StatelessWidget` 改为 `StatefulWidget`，
  5 条初始记录移入 State，提交后 `insert(0, record)` 并弹 SnackBar；
  `onPressed` 从 `() {}` 改为 `_onApply`。
* 测试：`test/reconstruction_test.dart` 新增第三个用例，覆盖「不填事由被拦下」
  与「提交后列表从 5 条变 6 条」。

### 7.2 详情页的姓名/学号/班级/院系可编辑 + 头像可换

**原版是只读的随机值**：`_buildLeaveRequestTab` 里直接用 `name()` / `code()` /
`RandomCollegeWidget(...)` 三个 StatelessWidget，而且它们把 `colect()` 写在
**`build` 里** —— 也就是说每重建一次就重新随机一次（会乱跳），也没任何入口能改。

实现内容（`lib/LeaveDetailPage.dart`）：

* 新增 `_EditableHeader`（StatefulWidget）：随机初值只在 `initState` 取一次，
  不再乱跳；四个字段每行右侧带小笔图标，点击弹输入框。
* 头像点一下弹底部菜单三个选项：
  - **从相册选择** —— `image_picker` 的 `pickImage(source: gallery, maxWidth: 800)`，
    `readAsBytes()` 后走 `Image.memory`（Web 上是文件选择框，Android 上是系统相册，
    两都不需要额外权限）
  - **输入图片链接** —— 走 `Image.network`
  - **重新随机一个** —— 回退到原来的 `randomuser.me` 逻辑
* 新增 `_TextInputDialog`（StatefulWidget）：自己持有并 `dispose` 控制器。
  （第一版把 `ctrl.dispose()` 写在 `showDialog` 返回之后，弹窗退场动画期间
  TextField 还在用这个 controller，报 `A TextEditingController was used after
  being disposed` —— 测试直接抓到了这个 bug，现已修。）
* 新增依赖 `image_picker: ^1.1.2`。
* 测试：`test/reconstruction_test.dart` 第四个用例覆盖
  「改姓名 → 改学号 → 头像菜单三个选项都在 → 输链接不崩」。

### 7.3 请假单 tab 所有字段可改 + 审批流程可增减 + 校园卡二维码

这三处**原版都是空实现**，反汇编里都是同一个空闭包 `0x3e8c44`：

| 位置 | 原版 | 现在 |
|---|---|---|
| 请假单 tab 的 8 个字段 | `_buildInfoRow(label, 字面量)` 写死 | 改成 `_LeaveRequestTab`(StatefulWidget)，每行可点改；类型/出行方式走候选项+自输入，请假时间走 `showDatePicker`+`showTimePicker` |
| 审批流程 tab | `_buildApprovalTimeline()` 里 `const nodes = [...]` 写死两句 | 改成 `_ApprovalProcessTab`(StatefulWidget)，每行可改（环节/角色/审批人）＋行尾删除＋右上“加一级审批”，二级及以后自动命名「（N 级审批）」 |
| 首页 AppBar 的 `Icons.qr_code` | `onPressed: () {}` | 新增 `lib/MyQrPage.dart`：点开显示真二维码（`qr_flutter`）+ 学籍/卡号/余额，字段均可改，二维码内容实时跟随；另带一个“自定义二维码内容”开关 |

新增依赖：`qr_flutter: ^4.1.0`。
新测试：第五个用例逐个验证（二维码页渲染 → 改姓名 → 请假单改具体事项/审批人 → 审批流程加一级/改审批人/删一级）。

### 7.4 影响

| 项 | 重建版 | 目前（全部新增功能后） |
|---|---|---|
| 子集图标字体 | 2,800 B（与原件字节相同） | 8,000+ B |
| release APK | 19.47 MB | 21.40 MB |
| `flutter analyze` / `flutter test` | 0 issue / 2 passed | 0 issue / **5 passed** |
| 业务文件 | 3 个 | 5 个（+`LeaveApplyPage` / +`MyQrPage`） |

## 8. 已知不精确 / 需要人工判断的地方

1. **`LeaveCard` 的卡片内部排版**：`RichText` 的标签/值文案、字号、`Colors.grey[500]/[800]`
   都是精确的；但绿灯徽章 `审批通过` 的位置（`Positioned`）与内边距是推断。
2. **免责弹窗按钮外框**：对象池里的 `BorderSide` 是 width=0、style=none（就是 `BorderSide.none`），
   重建时按常见写法给了 `BorderSide(color: Colors.black)`。
3. **`LeaveCard` 里那行 14 个空格 + `Color(0xFF0A82CD)` 的 `RichText`**：颜色/字号精确，
   原本用途（占位？）无法从机器码判断。
4. **`LeaveDetailPage` 时间轴**：`DashedLinePainter` 的虚线长度/间隔、`SizedBox` 高度为推断；
   节点图标 `Icons.check`（0xe156）、`审批流程:`/`提交申请`/`（申请人）`/`同意并终止`/`（一级审批）`
   等文案精确。
5. **`_buildLeaveRequestTab` 头图**：`Image.asset('assets/free.jpg')`、外层 `450×110`、
   `Clip` 为精确；`margin` / 圆角为推断。
6. **`LeavePage` 顶部渐变区域**：`LinearGradient(0.33/0.82...)` 的三个 `double` 是精确的，
   但 `0.33` 具体作用在 `height` 还是 `width`（我按 height=0.33H / width=0.33W 处理）有歧义。
7. **`assets/face.jpg` 在代码里没有被引用**（资源清单里有、业务代码无引用），已保留在 `assets/`。

---

## 9. 与原 APK 的行为差异（有意为之）

* **没有**拷贝原 APK 的 `libapp.so`；本工程是**重新编译**的 Dart 源码。
* 与原版一致：包名 `com.example.bag_school`、`flutterEmbedding=2`、仅 `INTERNET` 权限、
  `randomuser.me` 请求、Dart/Flutter 版本。
* 若只是本地跑，建议把 `android/app/build.gradle` 里的 `applicationId` 改掉，
  避免与原 APK（debug 签名）冲突导致覆盖安装失败。

---
