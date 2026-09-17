// ============================================================================
// MyQrPage.dart —— 【新增功能】二维码页
//
// 原版两处二维码入口都是空闭包（0x3e8c44）：
//   1. 首页 AppBar 的 IconButton，icon = IconData(0xe4f5) = Icons.qr_code
//   2. 余额卡里那个 Icon(Icons.qr_code, size:40, color:white)
// 现在两个都接到这里。
//
// 所有内容读写全局 AppState（会落盘），所以改一次、退出再进都还在。
// ============================================================================
// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'LeaveDetailPage.dart' show avatarWidget, showAvatarMenu, promptText;
import 'app_state.dart';

class MyQrPage extends StatelessWidget {
  const MyQrPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppState.I;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text('校园卡二维码',
            style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: '重新随机姓名+头像',
            icon: const Icon(Icons.casino, color: Colors.black),
            onPressed: st.randomizeIdentity,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: st,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // ---------------- 二维码卡片 ----------------
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              key: const ValueKey('qrAvatar'),
                              onTap: () => showAvatarMenu(context),
                              child: Stack(
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: avatarWidget(context),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.camera_alt,
                                          size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(st.name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('${st.school} · ${st.cardNo}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: QrImageView(
                            data: st.qrPayload,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            embeddedImage: const AssetImage('assets/logo.jpg'),
                            embeddedImageStyle: const QrEmbeddedImageStyle(
                              size: Size(40, 40),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('¥ ${st.balance}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w700)),
                        Text('${st.school} · 有效期至 ${st.cardValid}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        const Text('（点下面字段可改，二维码内容实时更新）',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),

                // ---------------- 可编辑字段 ----------------
                Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(context, '姓名:', st.name,
                            (v) => st.update(() => st.name = v)),
                        _row(context, '学号:', st.studentId,
                            (v) => st.update(() => st.studentId = v)),
                        _row(context, '班级:', st.className,
                            (v) => st.update(() => st.className = v)),
                        _row(context, '院系:', st.college,
                            (v) => st.update(() => st.college = v)),
                        _row(context, '卡号:', st.cardNo,
                            (v) => st.update(() => st.cardNo = v)),
                        _row(context, '余额:', st.balance,
                            (v) => st.update(() => st.balance = v)),
                        _row(context, '学校:', st.school,
                            (v) => st.update(() => st.school = v)),
                        _row(context, '有效期:', st.cardValid,
                            (v) => st.update(() => st.cardValid = v)),
                      ],
                    ),
                  ),
                ),

                // ---------------- 自定义二维码内容 ----------------
                SwitchListTile(
                  value: st.customQrPayload,
                  title: const Text('自定义二维码内容',
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(st.qrPayload,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                  onChanged: (v) =>
                      st.update(() => st.customQrPayload = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (st.customQrPayload)
                  TextButton.icon(
                    onPressed: () async {
                      final v = await promptText(
                          context, '修改二维码内容', st.qrPayloadOverride,
                          maxLines: 6);
                      if (v != null) {
                        st.update(() => st.qrPayloadOverride = v);
                      }
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('编辑二维码内容'),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      ValueChanged<String> save) {
    return InkWell(
      onTap: () async {
        final v = await promptText(context, '修改$label', value);
        if (v != null && v.isNotEmpty) save(v);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
                width: 56,
                child: Text(label,
                    style: const TextStyle(fontSize: 14, color: Colors.grey))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600))),
            const Icon(Icons.edit, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
