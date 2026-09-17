// ============================================================================
// main.dart  —— 由 libapp.so 的 ARM64 AOT 反汇编回译重建
// 原文: package:bag_school/main.dart
// 说明: 字符串/颜色/图标码点/尺寸数值 100% 取自 Dart 对象池（精确），
//       控制流按反汇编还原；变量名与代码排版为重建时整理。
// WillPopScope 是原程序的真实用法（Flutter 3.24 仍可用），故意不改。
// ============================================================================
// ignore_for_file: deprecated_member_use, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'LeaveRequestPage.dart';
import 'MyQrPage.dart';
import 'app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 先把上次改过的姓名/头像/字段读回来（只有第一次用才会随机一套）
  await AppState.I.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      theme: ThemeData(
        primarySwatch: Colors.blue, // 对象池 MaterialColor 0xFF2196F3
      ),
      home: const CampusCardPage(),
    );
  }
}

class CampusCardPage extends StatefulWidget {
  const CampusCardPage({super.key});

  @override
  State<CampusCardPage> createState() => _CampusCardPageState();
}

class _CampusCardPageState extends State<CampusCardPage> {
  /// 免责声明原文（对象池逐字）
  static const String kDisclaimer = '一、该软件仅供学习交流,请在安装完成后的24小时内卸载该软件！\n'
      '二、有该软件参与的任何事件均与开发者无关！\n'
      '三、因使用该软件造成的任何后果开发者不予承担！\n'
      '四、使用者点击确认即被视为同意以上三条规则。';

  @override
  void initState() {
    super.initState();
    // 反汇编: addPostFrameCallback((Duration _) => _showConfirmationDialog())
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showConfirmationDialog();
    });
  }

  void _showConfirmationDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false, // 反汇编: 返回常量 false，屏蔽返回键
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '警告！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red, // 0xFFF44336
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(kDisclaimer, textAlign: TextAlign.left),
                const SizedBox(height: 20),
                SizedBox(
                  width: 150,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 5,
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.black),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      '确认',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      // 反汇编: Scaffold 的 field_33 存的是 Colors.grey[100] 这个 Color 对象
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          '校园卡',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            // 对象池 IconData(0xe4f5) == Icons.qr_code
            // 【新增功能】原版这里是空闭包（0x3e8c44），点了没反应；现在打开二维码页
            icon: const Icon(Icons.qr_code, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyQrPage()),
              );
            },
          ),
        ],
      ),
      // 反汇编: body = Column(children: [Container(滚动区), _buildBottomAd()])
      // 包一层 ListenableBuilder，改完卡号/校名/余额后首页会跟着刷新
      body: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) => Column(
          children: [
            Container(
              width: size.width * 0.93,
              height: size.height * 0.72,
              margin: const EdgeInsets.only(top: 15),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.rectangle,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildBalanceCard(),
                    _buildMenuItems(context),
                  ],
                ),
              ),
            ),
            _buildBottomAd(),
          ],
        ),
      ),
    );
  }

  /// 底部广告条
  Widget _buildBottomAd() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/bottom1.jpg', fit: BoxFit.fill),
        const SizedBox(height: 12),
        const Text(
          '注意：本服务由完蛋校园提供技术支持',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  /// 余额卡片
  ///
  /// 修正：第一版把「校徽+校名 / 卡号 / 余额」三块全塞进同一个 Stack 并用
  /// Align 定位，结果它们叠在一起了（"字重叠"）。现在按反汇编里的对齐信息
  /// 分开定位：topStart / center / bottomLeft，再补上对象池里那个
  /// Icon(Icons.qr_code, size:40, color:white)（原来漏了）。
  Widget _buildBalanceCard() {
    final st = AppState.I;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 350,
          height: 200,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFD5860),
                Color(0xFFFF906C),
              ],
              tileMode: TileMode.clamp,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                blurStyle: BlurStyle.normal,
              ),
            ],
            shape: BoxShape.rectangle,
          ),
          child: Stack(
            fit: StackFit.loose,
            children: [
              // 左上：校徽 + 校名
              Positioned(
                left: 18,
                top: 18,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      color: Colors.white,
                      child: Image.asset('assets/logo.jpg'),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      st.school,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // 中上：卡号 + 有效期
              // 卡号 + 有效期（给右上角二维码让位）
              Positioned(
                left: 18,
                right: 96,
                top: 70,
                child: Text(
                  '${st.cardNo} (有效期:${st.cardValid})',
                  style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 8),
                ),
              ),
              // 左下：余额
              Positioned(
                left: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¥ ${st.balance}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '以上余额由于网络原因可能延迟更新',
                      style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 11),
                    ),
                  ],
                ),
              ),
              // 右上角：真二维码 —— 按参考图做成「白色模块直接画在渐变色卡上、无白底」
              // （qr_flutter 支持自定义 dataModule / eye 颜色，backgroundColor 透明）
              Positioned(
                right: 12,
                top: 12,
                child: GestureDetector(
                  key: const ValueKey('cardQr'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyQrPage()),
                    );
                  },
                  child: QrImageView(
                    data: st.qrPayload,
                    version: QrVersions.auto,
                    size: 74,
                    padding: const EdgeInsets.all(2),
                    backgroundColor: Colors.transparent,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.white,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 10 项功能菜单（对象池 List<Map<String,dynamic>>(10) 逐字还原）
  Widget _buildMenuItems(BuildContext context) {
    return Column(children: [
      for (int i = 0; i < 10; i++)
        _buildMenuItem(
          kMenuItems[i]['icon'] as IconData,
          kMenuItems[i]['title'] as String,
          kMenuItems[i]['color'] as Color,
        ),
    ]);
  }

  Widget _buildMenuItem(IconData icon, String title, Color color) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(
        Icons.arrow_forward_ios, // 对象池 IconData(0xe09c)
        size: 18,
        color: Color(0xFF616161), // Colors.grey[350] 的 Smi 编码 0x2bc
      ),
      onTap: () {
        // 反汇编证据: 只有 title == '请假' 才 push(LeavePage)，
        // 其余分支调用一个空闭包（原始工程里就是什么都不做）
        if (title == '请假') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LeavePage()),
          );
        }
      },
    );
  }

  /// 菜单数据。图标码点取自对象池的 IconData 对象，再对 Flutter 3.24.3 的
  /// icons.dart 反查得到 Icons.* 名称；颜色为对象池中的精确 ARGB。
  static const List<Map<String, Object>> kMenuItems = [
    {'icon': Icons.credit_card, 'title': '虚拟卡', 'color': Color(0xFFF36B14)},
    {'icon': Icons.attach_money, 'title': '充值', 'color': Color(0xFF858EFA)},
    {'icon': Icons.receipt, 'title': '交易明细', 'color': Color(0xFF7EDC54)},
    {'icon': Icons.lock, 'title': '卡挂失', 'color': Color(0xFF1D8BD7)},
    {'icon': Icons.vpn_key, 'title': '修改密码', 'color': Color(0xFF7ADE4B)},
    {'icon': Icons.payment, 'title': '缴费', 'color': Color(0xFFFF7700)},
    {'icon': Icons.link_off, 'title': '校园卡解绑', 'color': Color(0xFF858EFA)},
    {'icon': Icons.timer, 'title': '请假', 'color': Color(0xFF38D862)},
    {'icon': Icons.check_circle, 'title': '教师审批', 'color': Color(0xFFFCBF4C)},
    {'icon': Icons.fastfood, 'title': '点餐', 'color': Color(0xFF38D862)},
  ];
}
