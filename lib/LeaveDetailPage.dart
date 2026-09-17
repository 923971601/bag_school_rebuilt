// ============================================================================
// LeaveDetailPage.dart —— 由 libapp.so 的 ARM64 AOT 反汇编回译重建
// 原文: package:bag_school/LeaveDetailPage.dart
//
// 类名 `name` / `code` 与文件名大写驼峰都是 AOT 快照里的原始命名，故意保留。
// 说明: 所有字符串/颜色/尺寸取自 Dart 对象池，逐字精确。
//
// 【新增功能】(原版没有的，见 RECONSTRUCTION.md 第 7 节)
//   1. 头像 + 姓名/学号/班级/院系 可编辑
//   2. 请假单 tab 的所有字段可编辑
//   3. 审批流程 tab 可编辑，并能增减审批级数
//   4. 以上所有改动都存在全局 AppState 里并落盘 —— 只有你自己改才会变，
//      退出页面再进来不会重新随机。
// ============================================================================
// ignore_for_file: file_names, camel_case_types, non_constant_identifier_names, unused_element
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'app_state.dart';

/// 反汇编: enum DisplayType { college, classType }
enum DisplayType { college, classType }

/// 反汇编: static int colect() => Random().nextInt(10)
/// 证明: nextInt 用的是「未标记 int」ABI（调用方有 BoxInt64Instr），故立即数 #0xa 就是 10
int colect() => Random().nextInt(10);

/// 随机亚洲用户头像。对象池:
///   https://randomuser.me/api/?nat=CN||nat=JP||nat=KR
///   "results" / "picture" / "large" / "Failed to load random user image"
Future<String> _fetchRandomAsianUserImageUrl() async {
  final response = await http.get(
    Uri.parse('https://randomuser.me/api/?nat=CN||nat=JP||nat=KR'),
  );
  final data = json.decode(response.body) as Map<String, dynamic>;
  final results = data['results'] as List;
  final first = results[0] as Map;
  final picture = first['picture'] as Map;
  return picture['large'] as String;
}

/// 姓名（数据表在 app_state.dart，与原来对象池里的 10 个名字逐字相同）
class name extends StatelessWidget {
  const name({super.key});

  static const List<String> names = kStudentNames;

  @override
  Widget build(BuildContext context) {
    return Text(
      names[colect()],
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

/// 学号。反汇编: _getcode() => _codes[colect()]
class code extends StatelessWidget {
  const code({super.key});

  static const List<String> _codes = kStudentIds;

  static String _getcode() => _codes[colect()];

  /// 【新增功能】给库外（MyQrPage）用的公开入口，逻辑与 _getcode 相同
  static String randomCode() => _getcode();

  @override
  Widget build(BuildContext context) {
    return Text(
      _getcode(),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

/// 随机学院 / 班级
class RandomCollegeWidget extends StatelessWidget {
  const RandomCollegeWidget(this.displayType, {super.key});

  final DisplayType displayType;

  static const List<String> colleges = kColleges;
  static const List<String> classNames = kClassNames;

  @override
  Widget build(BuildContext context) {
    // 反汇编: cmp displayType, DisplayType.college ; b.ne -> 班级
    return Text(
      displayType == DisplayType.college
          ? colleges[colect()]
          : classNames[colect()],
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

class LeaveDetailPage extends StatelessWidget {
  const LeaveDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            '请假',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.deepOrangeAccent, // 0xFFFF6E40
            labelColor: Colors.orange, // 0xFFFF9800
            unselectedLabelColor: Colors.grey, // 0xFF9E9E9E
            tabs: [
              Tab(text: '请假单'),
              Tab(text: '审批流程'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LeaveRequestTab(),
            _ApprovalProcessTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 公用
// ============================================================================
const TextStyle _labelStyle = TextStyle(fontSize: 15, color: Colors.grey);

/// 通用的「单行输入」弹窗。必须自己持有 controller 并在 dispose 里释放 ——
/// 如果在 showDialog 返回后立刻 dispose，弹窗退场动画期间 TextField 还在用它。
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    this.initial = '',
    this.hint,
    this.maxLines = 1,
  });

  final String title;
  final String initial;
  final String? hint;
  final int maxLines;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(
            onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
            child: const Text('确定')),
      ],
    );
  }
}

/// 弹输入框改文字，返回 null 表示取消
Future<String?> promptText(BuildContext context, String title, String cur,
    {String? hint, int maxLines = 1}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      initial: cur,
      hint: hint,
      maxLines: maxLines,
    ),
  );
}

/// 一行「标签 + 值」。onTap 为 null 时不可编辑（不显示小笔图标）
class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
    this.highlight = false,
    this.labelWidth = 76,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool highlight;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(label, style: _labelStyle),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 3),
                child: Icon(Icons.edit, size: 14, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 【新增功能】请假单 tab —— 所有字段都能点着改
// ============================================================================
class _LeaveRequestTab extends StatelessWidget {
  const _LeaveRequestTab();

  @override
  Widget build(BuildContext context) {
    final st = AppState.I;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        return SingleChildScrollView(
          child: Column(
            children: [
              // 顶部大图 assets/free.jpg（对象池 assets/free.jpg / 450x110）
              Container(
                width: 450,
                height: 110,
                margin: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/free.jpg', fit: BoxFit.cover),
                ),
              ),
              const _EditableHeader(),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditRow(
                      label: '请假类型',
                      value: st.type,
                      highlight: true,
                      onTap: () => _pickFromList(
                          context, '修改请假类型', st.type,
                          const ['事假', '病假', '公假', '其他'],
                          (v) => st.update(() => st.type = v)),
                    ),
                    _EditRow(
                      label: '请假位置',
                      value: st.location,
                      onTap: () async {
                        final v = await promptText(
                            context, '修改请假位置', st.location);
                        if (v != null && v.isNotEmpty) {
                          st.update(() => st.location = v);
                        }
                      },
                      // 对象池 [pp+0xeba8] IconData(0xe3ab)=Icons.location_on
                      trailing: const Icon(Icons.location_on,
                          size: 18, color: Color(0xFF0A82CD)),
                    ),
                    _EditRow(
                      label: '具体事项',
                      value: st.matter,
                      onTap: () async {
                        final v =
                            await promptText(context, '修改具体事项', st.matter);
                        if (v != null && v.isNotEmpty) {
                          st.update(() => st.matter = v);
                        }
                      },
                    ),
                    _EditRow(
                      label: '目的地',
                      value: st.destination,
                      onTap: () async {
                        final v = await promptText(
                            context, '修改目的地', st.destination);
                        if (v != null && v.isNotEmpty) {
                          st.update(() => st.destination = v);
                        }
                      },
                    ),
                    _EditRow(
                      label: '出行方式',
                      value: st.transport,
                      onTap: () => _pickFromList(
                          context, '修改出行方式', st.transport,
                          const ['步行/单车', '打车', '公交', '家长接送'],
                          (v) => st.update(() => st.transport = v)),
                    ),
                    _EditRow(
                      label: '出口',
                      value: st.exitGate,
                      onTap: () async {
                        final v =
                            await promptText(context, '修改出口', st.exitGate);
                        if (v != null && v.isNotEmpty) {
                          st.update(() => st.exitGate = v);
                        }
                      },
                    ),
                    _EditRow(
                      label: '入口',
                      value: st.entryGate,
                      onTap: () async {
                        final v =
                            await promptText(context, '修改入口', st.entryGate);
                        if (v != null && v.isNotEmpty) {
                          st.update(() => st.entryGate = v);
                        }
                      },
                    ),
                    // 请假时间：点文字改开始时间，点右边日历图标改结束时间
                    _EditRow(
                      label: '请假时间:',
                      labelWidth: 76,
                      value: '${_fmt(st.start)}    ${_fmt(st.end)}',
                      onTap: () => _pickTime(context, true),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        tooltip: '修改结束时间',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _pickTime(context, false),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 76, top: 2),
                      child: Text(
                        '(请在请假时问内按时返校，超时返校影响后续请假)',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _EditRow(
                      label: '审批人:',
                      value: st.approver,
                      onTap: () async {
                        final v = await promptText(
                            context, '修改审批人', st.approver);
                        if (v != null && v.isNotEmpty) {
                          st.update(() => st.approver = v);
                        }
                      },
                    ),
                    const SizedBox(height: 85),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmt(DateTime t) =>
      DateFormat('yyyy-MM-dd HH:mm', 'en_US').format(t);

  /// 从候选列表里选一个（也能手打）
  Future<void> _pickFromList(BuildContext context, String title, String cur,
      List<String> options, ValueChanged<String> save) async {
    const custom = '\u0000custom';
    final v = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final o in options)
              ListTile(
                title: Text(o),
                trailing: o == cur ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, o),
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('自己输入…'),
              onTap: () => Navigator.pop(ctx, custom),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v == null) return;
    if (v == custom) {
      if (!context.mounted) return;
      final t = await promptText(context, title, cur);
      if (t != null && t.isNotEmpty) save(t);
      return;
    }
    save(v);
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final st = AppState.I;
    final base = isStart ? st.start : st.end;
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    if (!context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;
    final picked = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    st.update(() {
      if (isStart) {
        st.start = picked;
        if (st.end.isBefore(st.start)) {
          st.end = st.start.add(const Duration(hours: 1));
        }
      } else {
        st.end = picked;
      }
    });
  }
}

// ============================================================================
// 【新增功能】审批流程 tab —— 可编辑 + 可增减审批级数
// ============================================================================
class _ApprovalProcessTab extends StatelessWidget {
  const _ApprovalProcessTab();

  static const _cnNum = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];

  @override
  Widget build(BuildContext context) {
    final st = AppState.I;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final nodes = st.approvalNodes;
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('审批流程:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _addLevel(st),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('加一级审批',
                          style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 12,
                      bottom: 12,
                      child: CustomPaint(
                        size: const Size(1.5, 200),
                        painter: const DashedLinePainter(),
                      ),
                    ),
                    Column(
                      children: [
                        for (var i = 0; i < nodes.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _timelineNode(),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _EditRow(
                                        label: '环节',
                                        labelWidth: 52,
                                        value: nodes[i].title,
                                        onTap: () async {
                                          final v = await promptText(context,
                                              '修改环节名', nodes[i].title);
                                          if (v != null && v.isNotEmpty) {
                                            st.update(() =>
                                                nodes[i].title = v);
                                          }
                                        },
                                      ),
                                      _EditRow(
                                        label: '角色',
                                        labelWidth: 52,
                                        value: nodes[i].role,
                                        onTap: () async {
                                          final v = await promptText(context,
                                              '修改角色', nodes[i].role);
                                          if (v != null && v.isNotEmpty) {
                                            st.update(() =>
                                                nodes[i].role = v);
                                          }
                                        },
                                      ),
                                      _EditRow(
                                        label: '审批人',
                                        labelWidth: 52,
                                        value: nodes[i].person,
                                        highlight: true,
                                        onTap: () async {
                                          final v = await promptText(context,
                                              '修改审批人', nodes[i].person);
                                          if (v != null && v.isNotEmpty) {
                                            st.update(() =>
                                                nodes[i].person = v);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20),
                                  tooltip: '删除这一级',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _removeLevel(context, st, i),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('（点任意一行改文字，右上角可加减审批级数）',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addLevel(AppState st) {
    final lv = st.approvalNodes.where((n) => n.role.contains('级审批')).length + 1;
    st.update(() {
      st.approvalNodes.add(ApprovalNode(
        '同意并终止',
        '（${_cnNum[(lv - 1) % 10]}级审批）',
        st.approvalNodes.isEmpty ? '杨帆' : st.approvalNodes.last.person,
      ));
    });
  }

  void _removeLevel(BuildContext context, AppState st, int i) {
    if (st.approvalNodes.length <= 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('至少保留一级')));
      return;
    }
    st.update(() => st.approvalNodes.removeAt(i));
  }

  Widget _timelineNode() {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.orange, // 0xFFFF9800
        shape: BoxShape.circle,
        border: Border.all(color: Colors.orange),
      ),
      child: const Icon(Icons.check, size: 14, color: Colors.white),
    );
  }
}

// ============================================================================
// 【新增功能】可编辑的头像 + 学籍信息区（数据来自全局 AppState）
// ============================================================================
class _EditableHeader extends StatelessWidget {
  const _EditableHeader();

  @override
  Widget build(BuildContext context) {
    final st = AppState.I;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                GestureDetector(
                  key: const ValueKey('avatar'),
                  onTap: () => showAvatarMenu(context),
                  child: Stack(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 110,
                          height: 110,
                          child: avatarWidget(context),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 32,
                  child: TextButton.icon(
                    key: const ValueKey('changeAvatarBtn'),
                    onPressed: () => showAvatarMenu(context),
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('换头像', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EditRow(
                    label: '姓名:',
                    labelWidth: 48,
                    value: st.name,
                    onTap: () async {
                      final v = await promptText(context, '修改姓名', st.name);
                      if (v != null && v.isNotEmpty) {
                        st.update(() => st.name = v);
                      }
                    },
                  ),
                  _EditRow(
                    label: '学号:',
                    labelWidth: 48,
                    value: st.studentId,
                    onTap: () async {
                      final v =
                          await promptText(context, '修改学号', st.studentId);
                      if (v != null && v.isNotEmpty) {
                        st.update(() => st.studentId = v);
                      }
                    },
                  ),
                  _EditRow(
                    label: '班级:',
                    labelWidth: 48,
                    value: st.className,
                    onTap: () async {
                      final v =
                          await promptText(context, '修改班级', st.className);
                      if (v != null && v.isNotEmpty) {
                        st.update(() => st.className = v);
                      }
                    },
                  ),
                  _EditRow(
                    label: '院系:',
                    labelWidth: 48,
                    value: st.college,
                    onTap: () async {
                      final v =
                          await promptText(context, '修改院系', st.college);
                      if (v != null && v.isNotEmpty) {
                        st.update(() => st.college = v);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text('（点头像或右侧小笔图标即可修改，改完会记住）',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 头像本体：自己选的 > 输入的链接 > 网络随机（只随机一次）
Widget avatarWidget(BuildContext context) {
  final st = AppState.I;
  if (st.avatarBytes != null) {
    return Image.memory(st.avatarBytes!, fit: BoxFit.cover);
  }
  if (st.avatarUrl != null && st.avatarUrl!.isNotEmpty) {
    return Image.network(st.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Text('加载失败')));
  }
  // 原逻辑不动：randomuser.me
  return FutureBuilder<String>(
    future: _fetchRandomAsianUserImageUrl(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return const Center(child: Text('加载失败'));
      }
      return Image.network(snapshot.data!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Text('加载失败')));
    },
  );
}

/// 换头像菜单（详情页和二维码页共用）
Future<void> showAvatarMenu(BuildContext context) async {
  final st = AppState.I;
  final picker = ImagePicker();
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('换头像',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('从相册选择'),
            subtitle: const Text('换完会记住，进别的页面也不会变',
                style: TextStyle(fontSize: 11)),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                final f = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 800,
                    imageQuality: 90);
                if (f == null) return;
                final b = await f.readAsBytes();
                st.update(() {
                  st.avatarBytes = b;
                  st.avatarUrl = null;
                });
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('选择图片失败：$e')));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('输入图片链接'),
            onTap: () async {
              Navigator.pop(ctx);
              final u = await promptText(context, '输入图片链接', st.avatarUrl ?? '',
                  hint: 'https://... 以 .jpg/.png 结尾');
              if (u == null || u.isEmpty) return;
              st.update(() {
                st.avatarUrl = u;
                st.avatarBytes = null;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.casino),
            title: const Text('重新随机姓名+头像'),
            onTap: () {
              Navigator.pop(ctx);
              st.randomizeIdentity();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 反汇编: class DashedLinePainter extends CustomPainter
class DashedLinePainter extends CustomPainter {
  const DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.5;
    const dash = 4.0;
    const gap = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dash),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
