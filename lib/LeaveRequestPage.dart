// ============================================================================
// LeaveRequestPage.dart —— 由 libapp.so 的 ARM64 AOT 反汇编回译重建
// 原文: package:bag_school/LeaveRequestPage.dart
//
// 本文件的命名（LeavePage.Stime / Etime / 文件名大写驼峰）都是从 AOT 快照里
// 原样还原的原始命名，故意不改，因此屏蔽相关 lint。
// ============================================================================
// ignore_for_file: file_names, non_constant_identifier_names, unnecessary_late
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'LeaveApplyPage.dart';
import 'LeaveDetailPage.dart';

/// 请假记录（反汇编: class LeaveRecord extends Object，4 个 String 字段 + 1 个 bool）
class LeaveRecord {
  final String type; // 请假类型
  final String reason; // 申请事由
  final String startTime; // 开始时间
  final String endTime; // 结束时间
  final bool approved; // 是否审批通过

  LeaveRecord(
    this.type,
    this.reason,
    this.startTime,
    this.endTime, [
    this.approved = true,
  ]);
}

class LeaveCard extends StatelessWidget {
  const LeaveCard(this.record, {super.key});

  final LeaveRecord record;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaveDetailPage()),
        );
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('请假类型    ', record.type),
                  const SizedBox(height: 12),
                  _row('申请事由    ', record.reason),
                  const SizedBox(height: 12),
                  _row('请假时间    ', '${record.startTime} 至 ${record.endTime}'),
                  const SizedBox(height: 12),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: '              ',
                          style: TextStyle(
                            color: Color(0xFF0A82CD),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green, // 0xFF4CAF50
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Text(
                    '审批通过',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  /// 一行「标签 + 值」，反汇编里就是 RichText + 两个 TextSpan
  Widget _row(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ↓ 以下为【新增功能】改动：原版 LeavePage 是 StatelessWidget，构造函数里直接
//    new 出 5 条 LeaveRecord；「立即申请」的 onPressed 是空闭包（0x3e8c44），
//    点了没任何反应。这里改成 StatefulWidget，并把按钮接到新写的申请表单页。
// ============================================================================
class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  /// 以下三个是 `static late` 字段（反汇编里是带初始化表达式的 late getter）
  static late DateTime now = DateTime.now();
  static late String Stime =
      DateFormat('yyyy-MM-dd HH:mm', 'en_US').format(now.subtract(
    const Duration(minutes: 30), // movz #0xd200 / movk #0x6b49 => 1_800_000_000us
  ));
  static late String Etime =
      DateFormat('yyyy-MM-dd HH:mm', 'en_US').format(now.add(
    const Duration(hours: 3), // movz 0xec00 / movk 0x283 => 10_800_000_000us
  ));

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  /// 原版这 5 条是在构造函数里建的；改为 State 的初始列表，
  /// 这样「立即申请」提交后能往列表头部插新记录。
  final List<LeaveRecord> records = [
    LeaveRecord('事假', '取快递', LeavePage.Stime, LeavePage.Etime),
    LeaveRecord('事假', '取快递', '2024-9-05 17:35', '2024-9-05 18:35'),
    LeaveRecord('事假', '取快递', '2024-3-20 14:20', '2024-3-20 17:20'),
    LeaveRecord('事假', '取快递', '2023-6-10 12:00', '2023-5-10 16:00'),
    LeaveRecord('事假', '取快递', '2023-5-30 13:00', '2023-5-30 15:33'),
  ];

  /// 【新增功能】立即申请 → 打开表单页，拿回新记录插到列表最前面
  Future<void> _onApply() async {
    final created = await Navigator.push<LeaveRecord>(
      context,
      MaterialPageRoute(builder: (_) => const LeaveApplyPage()),
    );
    if (created == null || !mounted) return;
    setState(() => records.insert(0, created));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('申请已提交，等待审批')));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('请假', style: TextStyle(color: Colors.black)),
      ),
      body: Stack(
        children: [
          Container(
            height: size.height * 0.33,
            width: size.width * 0.33,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFD5860).withOpacity(0.82),
                  const Color(0xFFFF906C),
                ],
                tileMode: TileMode.clamp,
              ),
              borderRadius: BorderRadius.circular(0),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) =>
                      LeaveCard(records[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _onApply, // 新增功能：原来这里是空闭包 () {}
                    child: const Text('立即申请'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
