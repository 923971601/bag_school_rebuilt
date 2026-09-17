// ignore_for_file: file_names
// ============================================================================
// LeaveApplyPage.dart  —— 新增功能（原作者没实现，onPressed 是个空闭包）
//
// 反汇编证据：原版 LeavePage::build 里「立即申请」的 onPressed 指向
//   0x3e8c44 = 空闭包实例，和首页 9 个失效菜单项用的是同一个。
// 所以原版点了没反应是「真实行为」，这里补上完整实现。
// ============================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'LeaveRequestPage.dart';

class LeaveApplyPage extends StatefulWidget {
  const LeaveApplyPage({super.key});

  @override
  State<LeaveApplyPage> createState() => _LeaveApplyPageState();
}

class _LeaveApplyPageState extends State<LeaveApplyPage> {
  static const _types = ['事假', '病假', '公假', '其他'];
  static const _transports = ['步行/单车', '打车', '公交', '家长接送'];

  String _type = '事假';
  String _transport = '步行/单车';
  final _reasonCtrl = TextEditingController();
  final _destCtrl = TextEditingController(text: '快递小院，镇上餐馆。');
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(hours: 3));

  static final _fmt = DateFormat('yyyy-MM-dd HH:mm', 'en_US');

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  /// 选日期 + 时间
  Future<void> _pick(bool isStart) async {
    final base = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = picked;
      }
    });
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写申请事由')));
      return;
    }
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('结束时间不能早于开始时间')));
      return;
    }
    // 把新建的记录交回上一页
    Navigator.pop(
      context,
      LeaveRecord(
        _type,
        reason,
        _fmt.format(_start),
        _fmt.format(_end),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text('请假申请',
            style: TextStyle(
                color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _card('请假类型', _chips(_types, _type, (v) => setState(() => _type = v))),
          _card(
            '申请事由',
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '例如：取快递',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _card(
            '请假时间',
            Column(
              children: [
                _timeRow('开始时间', _start, () => _pick(true)),
                const Divider(height: 1),
                _timeRow('结束时间', _end, () => _pick(false)),
              ],
            ),
          ),
          _card(
            '目的地',
            TextField(
              controller: _destCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _card(
            '出行方式',
            _chips(_transports, _transport,
                (v) => setState(() => _transport = v)),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '(请在请假时问内按时返校，超时返校影响后续请假)',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _submit,
              child: const Text('提交申请',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _chips(List<String> options, String current, ValueChanged<String> onPick) {
    return Wrap(
      spacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: o == current,
            onSelected: (_) => onPick(o),
          ),
      ],
    );
  }

  Widget _timeRow(String label, DateTime t, VoidCallback onTap) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(_fmt.format(t),
          style: const TextStyle(fontSize: 14, color: Colors.black87)),
      onTap: onTap,
    );
  }
}
