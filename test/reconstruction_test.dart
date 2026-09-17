// 重建工程的冒烟测试：验证应用能真正跑起来，且关键内容与 APK 中的常量一致
// 注意：LeaveCard 用的是 RichText + TextSpan，所以断言要带 findRichText: true
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:bag_school/main.dart';
import 'package:bag_school/LeaveRequestPage.dart';
import 'package:bag_school/app_state.dart';

void main() {
  // 用一个足够高的手机视口，避免菜单被挤出屏幕导致点不到
  Future<void> boot(WidgetTester tester) async {
    AppState.I.resetForTest(); // 每一步测试都从干净状态开始
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MyApp());
    // 等首帧回调把免责声明弹窗弹出来（动画走完）
    await tester.pumpAndSettle();
  }

  testWidgets('免责声明弹窗 + 校园卡首页 + 10 项菜单', (WidgetTester tester) async {
    await boot(tester);
    await tester.pumpAndSettle();

    // 1) 启动首帧后弹出免责声明（原文逐字）
    expect(find.text('警告！'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
    expect(find.textContaining('一、该软件仅供学习交流'), findsOneWidget);

    // 2) 点确认关闭弹窗
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // 3) 首页 AppBar 与余额卡
    expect(find.text('校园卡'), findsOneWidget);
    expect(find.text('荆州学院'), findsOneWidget);
    expect(find.text('212310264 (有效期:2099-12-31)'), findsOneWidget);
    expect(find.text('¥ 520.1'), findsOneWidget);
    expect(find.text('以上余额由于网络原因可能延迟更新'), findsOneWidget);
    expect(find.text('注意：本服务由完蛋校园提供技术支持'), findsOneWidget);

    // 4) 10 项菜单一项不少
    const titles = [
      '虚拟卡', '充值', '交易明细', '卡挂失', '修改密码',
      '缴费', '校园卡解绑', '请假', '教师审批', '点餐',
    ];
    for (final t in titles) {
      expect(find.text(t), findsOneWidget, reason: '菜单项缺失: $t');
    }
    expect(find.byType(ListTile), findsNWidgets(10));

    // 5) 点「请假」进入请假列表页（列表较长，先滚动到可见）
    final leaveItem = find.text('请假');
    await tester.ensureVisible(leaveItem);
    await tester.pumpAndSettle();
    await tester.tap(leaveItem);
    await tester.pumpAndSettle();
    expect(find.text('立即申请'), findsOneWidget);

    // 6) 5 条请假记录（事由全部是「取快递」）
    //    LeaveCard 用 RichText，整串是「请假类型    事假」，所以只能 contains
    expect(find.textContaining('事假', findRichText: true), findsNWidgets(5));
    expect(
        find.textContaining('取快递', findRichText: true), findsNWidgets(5));
    expect(
        find.textContaining('2024-9-05 17:35', findRichText: true),
        findsOneWidget);
    expect(
        find.textContaining('2024-3-20 14:20', findRichText: true),
        findsOneWidget);
    expect(
        find.textContaining('2023-6-10 12:00', findRichText: true),
        findsOneWidget);
    expect(
        find.textContaining('2023-5-30 13:00', findRichText: true),
        findsOneWidget);
    expect(find.byType(LeaveCard), findsNWidgets(5));
  });

  testWidgets('详情页：随机姓名/学号/院系/班级都落在对象池名单内',
      (WidgetTester tester) async {
    await boot(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    final leaveItem = find.text('请假');
    await tester.ensureVisible(leaveItem);
    await tester.pumpAndSettle();
    await tester.tap(leaveItem);
    await tester.pumpAndSettle();

    // 点第一张请假卡进详情页
    await tester.tap(find.byType(LeaveCard).first);
    // 详情页有网络 FutureBuilder，只 pump 不 settle，避免等网络超时
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('姓名:'), findsOneWidget);
    expect(find.text('学号:'), findsOneWidget);
    expect(find.text('班级:'), findsOneWidget);
    expect(find.text('院系:'), findsOneWidget);
    expect(find.text('请假单'), findsOneWidget);
    expect(find.text('审批流程'), findsOneWidget);
    expect(find.text('请假位置'), findsOneWidget);
    expect(find.text('湖北省-荆州市-荆州区'), findsOneWidget);
    expect(find.text('去外面取快递、顺带吃饭。'), findsOneWidget);
    expect(find.text('快递小院，镇上餐馆。'), findsOneWidget);
    expect(find.text('步行/单车'), findsOneWidget);
    expect(find.text('杨帆'), findsWidgets);

    const names = [
      '张益达', '李子柒', '王林', '叶钟鸣', '石昊',
      '杨庆同', '赵立刚', '黄子越', '周天子', '吴哲浩',
    ];
    const codes = [
      '202302458', '202112487', '202200125', '202303698', '202010369',
      '202311256', '202106594', '202300256', '202112036', '202309610',
    ];
    const colleges = [
      '新闻学院', '计算机学院', '经济学院', '外语学院', '艺术学院',
      '法学院', '生物科学学院', '机械工程学院', '土木工程学院', '管理学院',
    ];
    expect(names.where((n) => find.text(n).evaluate().isNotEmpty).length, 1,
        reason: '姓名必须命中对象池名单且只有一个');
    expect(codes.where((n) => find.text(n).evaluate().isNotEmpty).length, 1,
        reason: '学号必须命中对象池名单且只有一个');
    expect(colleges.where((n) => find.text(n).evaluate().isNotEmpty).length, 1,
        reason: '院系必须命中对象池名单且只有一个');
  });

  // ==========================================================================
  // 【新增功能】原版「立即申请」是空闭包（0x3e8c44），这里验证补上的申请流程
  // ==========================================================================
  testWidgets('新增功能：立即申请 → 填表单 → 提交后列表多一条',
      (WidgetTester tester) async {
    await boot(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('请假'));
    await tester.pumpAndSettle();

    expect(find.byType(LeaveCard), findsNWidgets(5));

    // 进申请页
    await tester.tap(find.text('立即申请'));
    await tester.pumpAndSettle();
    expect(find.text('请假申请'), findsOneWidget);
    expect(find.text('提交申请'), findsOneWidget);

    // 不填事由直接提交 → 应该被拦下
    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();
    expect(find.text('请填写申请事由'), findsOneWidget);
    expect(find.text('请假申请'), findsOneWidget, reason: '不应该退出申请页');

    // 填上事由再提交
    await tester.enterText(find.byType(TextField).first, '去校医院拿药');
    await tester.pump();
    await tester.tap(find.text('提交申请'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 回到列表页，并多出一条新记录
    expect(find.text('立即申请'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(LeaveCard), findsNWidgets(6));
    expect(find.textContaining('去校医院拿药', findRichText: true),
        findsOneWidget);
  });

  // ==========================================================================
  // 【新增功能】详情页的姓名/学号/班级/院系可编辑，头像可换
  // ==========================================================================
  testWidgets('新增功能：详情页可改姓名，头像可换', (WidgetTester tester) async {
    await boot(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('请假'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LeaveCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 四个可编辑行都在
    for (final l in ['姓名:', '学号:', '班级:', '院系:']) {
      expect(find.text(l), findsOneWidget, reason: '缺少 $l');
    }

    // ---- 改姓名 ----
    await tester.tap(find.text('姓名:'));
    await tester.pumpAndSettle();
    expect(find.text('修改姓名'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '李四');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('李四'), findsOneWidget, reason: '改名后应显示新名字');

    // ---- 改学号 ----
    await tester.tap(find.text('学号:'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '2023999999');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('2023999999'), findsOneWidget);

    // ---- 头像菜单（头像角标 和 「换头像」按钮 都要能开）----
    await tester.tap(find.byKey(const ValueKey('changeAvatarBtn')));
    await tester.pumpAndSettle();
    expect(find.text('换头像'), findsWidgets);
    expect(find.text('从相册选择'), findsOneWidget);
    expect(find.text('输入图片链接'), findsOneWidget);
    expect(find.text('重新随机姓名+头像'), findsOneWidget);

    // 点「重新随机一个」应该关菜单且不报错
    await tester.tap(find.text('重新随机姓名+头像'));
    await tester.pumpAndSettle();
    expect(find.text('从相册选择'), findsNothing);

    // 头像本身也能点开
    await tester.tap(find.byKey(const ValueKey('avatar')));
    await tester.pumpAndSettle();
    expect(find.text('从相册选择'), findsOneWidget);
    await tester.tap(find.text('输入图片链接'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'https://example.com/a.jpg');
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // 不需要真的能下载，只要不崩就行
    expect(find.text('姓名:'), findsOneWidget);
  });

  // ==========================================================================
  // 【新增功能】请假单字段全可改 + 审批流程可增减 + 首页二维码
  // ==========================================================================
  testWidgets('新增功能：请假单/审批流程可编辑 + 校园卡二维码',
      (WidgetTester tester) async {
    await boot(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // ---------------- 首页二维码（右上角图标 和 卡片上的二维码 都能进）----------------
    await tester.tap(find.byIcon(Icons.qr_code).first);
    await tester.pumpAndSettle();
    expect(find.text('校园卡二维码'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget, reason: '二维码应渲染出来');

    // 改姓名 → 二维码卡片上的姓名跟着变
    await tester.tap(find.text('姓名:'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '王小明');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('王小明'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // ---------------- 进详情页 ----------------
    await tester.tap(find.text('请假'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LeaveCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 请假单 tab：改「具体事项」
    await tester.tap(find.text('具体事项'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '去食堂吃饭');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('去食堂吃饭'), findsOneWidget);

    // 改「审批人」（请假单里那个）
    await tester.tap(find.text('审批人:'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '李老师');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('李老师'), findsOneWidget);

    // ---------------- 审批流程 tab ----------------
    await tester.tap(find.text('审批流程'));
    await tester.pumpAndSettle();
    expect(find.text('（一级审批）'), findsOneWidget);

    // 加一级
    await tester.tap(find.text('加一级审批'));
    await tester.pumpAndSettle();
    expect(find.text('（二级审批）'), findsOneWidget);

    // 改最新一级的审批人
    await tester.tap(find.text('杨帆').last);
    await tester.pumpAndSettle();
    expect(find.text('修改审批人'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '张主任');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('张主任'), findsOneWidget);

    // 删掉一级
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('（二级审批）'), findsNothing);
  });

  // ==========================================================================
  // 修复：以前每个页面自己存 State，退出就销毁 —— 再进来又 Random 一遍。
  // 现在改成全局 AppState，验证「退出再进不会变」。
  // ==========================================================================
  testWidgets('修复：改过的姓名退出页面再进来不会变回去',
      (WidgetTester tester) async {
    await boot(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('请假'));
    await tester.pumpAndSettle();

    // 进详情页改姓名
    await tester.tap(find.byType(LeaveCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('姓名:'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '赵小六');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('赵小六'), findsOneWidget);

    // 退回列表 → 再进详情页，名字应当不变
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LeaveCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('赵小六'), findsOneWidget,
        reason: '再进详情页应该还是赵小六（以前会重新随机）');

    // 退到首页，从二维码页看也应该是同一个名字
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.qr_code).first);
    await tester.pumpAndSettle();
    expect(find.text('赵小六'), findsWidgets,
        reason: '二维码页也应该显示同一个名字');
  });
}
