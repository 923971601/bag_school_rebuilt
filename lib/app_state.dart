// ============================================================================
// app_state.dart —— 【新增功能】全局可变状态 + 本地持久化
//
// 为什么需要它：原来姓名/学号/院系/头像都存在各页面自己的 State 里，
// 一退出页面 State 就被销毁，再进来又 Random().nextInt(10) 重新随机一遍
// ——就是"头像换了、再进来又变了"的原因。
//
// 现在所有可编辑内容都放这里，并且用 shared_preferences 存盘，
// 只有你自己改了才会变（关掉 App 重开也还在）。
// ============================================================================
// ignore_for_file: file_names
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// 数据表：全部逐字来自原 APK 的 Dart 对象池
// ---------------------------------------------------------------------------
const List<String> kStudentNames = [
  '张益达', '李子柒', '王林', '叶钟鸣', '石昊',
  '杨庆同', '赵立刚', '黄子越', '周天子', '吴哲浩',
];

const List<String> kStudentIds = [
  '202302458', '202112487', '202200125', '202303698', '202010369',
  '202311256', '202106594', '202300256', '202112036', '202309610',
];

const List<String> kColleges = [
  '新闻学院', '计算机学院', '经济学院', '外语学院', '艺术学院',
  '法学院', '生物科学学院', '机械工程学院', '土木工程学院', '管理学院',
];

const List<String> kClassNames = [
  '新闻2301', '计科2101', '经济2204', '外语2304', '艺术2001',
  '法学2302', '生科2105', '机工2305', '土木2106', '管理2304',
];

/// 审批流程的一级
class ApprovalNode {
  ApprovalNode(this.title, this.role, this.person);
  String title;
  String role;
  String person;

  Map<String, dynamic> toJson() =>
      {'t': title, 'r': role, 'p': person};
  factory ApprovalNode.fromJson(Map<String, dynamic> j) =>
      ApprovalNode(j['t'] as String, j['r'] as String, j['p'] as String);
}

// ---------------------------------------------------------------------------
// 全局状态
// ---------------------------------------------------------------------------
class AppState extends ChangeNotifier {
  AppState._() {
    // 构造函数里先随机一套，保证即使没调 load()（比如单元测试直接 pumpWidget）
    // 也有合法初值；load() 若有存盘数据会覆盖掉。
    _randomizeIdentityFields();
  }

  static final AppState I = AppState._();

  static const _kStore = 'bag_school_state_v1';
  static const int _maxAvatarBytes = 400 * 1024; // 超过就不存盘，避免 prefs 爆掉

  // ---- 学籍 / 头像 ----
  String name = '';
  String studentId = '';
  String className = '';
  String college = '';
  Uint8List? avatarBytes;
  String? avatarUrl;

  // ---- 校园卡 ----
  String school = '荆州学院';
  String cardNo = '212310264';
  String cardValid = '2099-12-31';
  String balance = '520.1';

  // ---- 请假单 ----
  String type = '事假';
  String location = '湖北省-荆州市-荆州区';
  String matter = '去外面取快递、顺带吃饭。';
  String destination = '快递小院，镇上餐馆。';
  String transport = '步行/单车';
  String exitGate = '东大门';
  String entryGate = '东大门';
  String approver = '杨帆';
  DateTime start = DateTime.now().subtract(const Duration(minutes: 30));
  DateTime end = DateTime.now().add(const Duration(hours: 3));

  // ---- 审批流程 ----
  List<ApprovalNode> approvalNodes = [
    ApprovalNode('提交申请', '（申请人）', '杨帆'),
    ApprovalNode('同意并终止', '（一级审批）', '杨帆'),
  ];

  /// 扫码内容是否用自定义文本
  bool customQrPayload = false;
  String qrPayloadOverride = '';

  bool _loaded = false;
  bool get loaded => _loaded;

  static int _rnd10() => Random().nextInt(10);

  void _randomizeIdentityFields() {
    name = kStudentNames[_rnd10()];
    studentId = kStudentIds[_rnd10()];
    className = kClassNames[_rnd10()];
    college = kColleges[_rnd10()];
    avatarBytes = null;
    avatarUrl = null;
  }

  /// 只在这里随机一次
  void randomizeAll() {
    _randomizeIdentityFields();
    notifyListeners();
    save();
  }

  void randomizeIdentity() {
    _randomizeIdentityFields();
    notifyListeners();
    save();
  }

  /// 测试用：把状态恢复成初始值
  @visibleForTesting
  void resetForTest() {
    _randomizeIdentityFields();
    school = '荆州学院';
    cardNo = '212310264';
    cardValid = '2099-12-31';
    balance = '520.1';
    type = '事假';
    location = '湖北省-荆州市-荆州区';
    matter = '去外面取快递、顺带吃饭。';
    destination = '快递小院，镇上餐馆。';
    transport = '步行/单车';
    exitGate = '东大门';
    entryGate = '东大门';
    approver = '杨帆';
    start = DateTime.now().subtract(const Duration(minutes: 30));
    end = DateTime.now().add(const Duration(hours: 3));
    approvalNodes = [
      ApprovalNode('提交申请', '（申请人）', '杨帆'),
      ApprovalNode('同意并终止', '（一级审批）', '杨帆'),
    ];
    customQrPayload = false;
    qrPayloadOverride = '';
    _loaded = true;
    notifyListeners();
  }

  /// 二维码内容
  String get qrPayload {
    if (customQrPayload && qrPayloadOverride.trim().isNotEmpty) {
      return qrPayloadOverride;
    }
    return [
      school,
      '卡号:$cardNo',
      '有效期:$cardValid',
      '余额:¥$balance',
      '姓名:$name',
      '学号:$studentId',
      '班级:$className',
      '院系:$college',
    ].join('\n');
  }

  // ------------------------------------------------------------------ 持久化
  Future<void> load() async {
    if (_loaded) return;
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kStore);
    if (raw == null || raw.isEmpty) {
      randomizeAll(); // 第一次用：随机一套
    } else {
      try {
        final j = json.decode(raw) as Map<String, dynamic>;
        _fromJson(j);
      } catch (_) {
        randomizeAll();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kStore, json.encode(_toJson()));
    } catch (_) {
      // 存盘失败不影响使用（比如 Web 隐私模式）
    }
  }

  Map<String, dynamic> _toJson() => {
        'name': name,
        'studentId': studentId,
        'className': className,
        'college': college,
        'avatarUrl': avatarUrl,
        'avatar': (avatarBytes != null && avatarBytes!.length <= _maxAvatarBytes)
            ? base64Encode(avatarBytes!)
            : null,
        'school': school,
        'cardNo': cardNo,
        'cardValid': cardValid,
        'balance': balance,
        'type': type,
        'location': location,
        'matter': matter,
        'destination': destination,
        'transport': transport,
        'exitGate': exitGate,
        'entryGate': entryGate,
        'approver': approver,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
        'nodes': approvalNodes.map((n) => n.toJson()).toList(),
        'customQr': customQrPayload,
        'qrOverride': qrPayloadOverride,
      };

  void _fromJson(Map<String, dynamic> j) {
    String s(String k, String def) => (j[k] as String?)?.isNotEmpty == true
        ? j[k] as String
        : def;
    name = s('name', kStudentNames[_rnd10()]);
    studentId = s('studentId', kStudentIds[_rnd10()]);
    className = s('className', kClassNames[_rnd10()]);
    college = s('college', kColleges[_rnd10()]);
    avatarUrl = j['avatarUrl'] as String?;
    final b64 = j['avatar'] as String?;
    if (b64 != null && b64.isNotEmpty) {
      try {
        avatarBytes = base64Decode(b64);
      } catch (_) {
        avatarBytes = null;
      }
    }
    school = s('school', '荆州学院');
    cardNo = s('cardNo', '212310264');
    cardValid = s('cardValid', '2099-12-31');
    balance = s('balance', '520.1');
    type = s('type', '事假');
    location = s('location', '湖北省-荆州市-荆州区');
    matter = s('matter', '去外面取快递、顺带吃饭。');
    destination = s('destination', '快递小院，镇上餐馆。');
    transport = s('transport', '步行/单车');
    exitGate = s('exitGate', '东大门');
    entryGate = s('entryGate', '东大门');
    approver = s('approver', '杨帆');
    final ms = j['start'];
    if (ms is int) start = DateTime.fromMillisecondsSinceEpoch(ms);
    final me = j['end'];
    if (me is int) end = DateTime.fromMillisecondsSinceEpoch(me);
    final ns = j['nodes'];
    if (ns is List && ns.isNotEmpty) {
      approvalNodes = ns
          .map((e) => ApprovalNode.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    customQrPayload = j['customQr'] == true;
    qrPayloadOverride = (j['qrOverride'] as String?) ?? '';
  }

  /// 改完统一走这里：改完 → 通知界面 → 存盘
  void update(VoidCallback fn) {
    fn();
    notifyListeners();
    save();
  }
}
