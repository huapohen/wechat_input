import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class MigrationPage extends StatefulWidget {
  const MigrationPage({super.key});

  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  final TextEditingController _paste = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _status;
  int? _imported;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<File> _writePackage(AppState state) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/migration');
    await folder.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${folder.path}/wechat-input-migration-$stamp.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(state.exportPackage()));
    return file;
  }

  Future<void> _export(AppState state) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final file = await _writePackage(state);
      setState(() => _status = '迁移包已生成：${file.path}');
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        text: '微输入法迁移包',
        subject: '微输入法迁移包',
        sharePositionOrigin: shareOriginOf(context),
      ));
    } catch (e) {
      setState(() => _error = '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importText(AppState state, String raw, {String source = '粘贴内容'}) async {
    if (raw.trim().isEmpty) {
      setState(() => _error = '没有可导入的内容');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
      _imported = null;
    });
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schema'] != 'wechat-input-clone/migration/1') {
        throw const FormatException('不是微输入法迁移包（schema 不匹配）');
      }
      final count = await state.importPackage(Map<String, dynamic>.from(decoded));
      setState(() {
        _imported = count;
        _status = '已从$source导入 $count 项。设置与词库已更新。';
      });
    } catch (e) {
      setState(() => _error = '导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImport(AppState state) async {
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      String? raw;
      if (picked.bytes != null) {
        raw = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        raw = await File(picked.path!).readAsString();
      }
      if (raw == null) throw const FormatException('无法读取文件内容');
      await _importText(state, raw, source: picked.name);
    } catch (e) {
      setState(() => _error = '选择文件失败：$e');
    }
  }

  Future<void> _syncSettings(AppState state, {required bool upload}) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      if (!state.syncConnected) {
        throw ApiException('尚未配对设备，请先到「跨设备粘贴同步」完成配对。');
      }
      final api = ApiClient.fromState(state);
      final token = state.syncPeerToken.isEmpty ? state.syncToken : state.syncPeerToken;
      if (upload) {
        await api.pushSettings(token, state.exportPackage());
        setState(() => _status = '迁移包已上传到同步空间（${token.isEmpty ? '本机' : '配对设备'}）');
      } else {
        final payload = await api.pullSettings(token);
        if (payload.isEmpty) throw ApiException('同步空间中没有迁移数据');
        final count = await state.importPackage(payload);
        setState(() => _status = '已从同步空间恢复 $count 项');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '同步迁移失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final pkg = state.exportPackage();
    return SettingsScaffold(
      title: '换机助手',
      subtitle: '把设置、常用语、个人词典与录音会话带到新设备。迁移包只由你主动导出或同步。',
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.phonelink_setup_rounded,
                        color: AppColors.accentDark, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('本机迁移包',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('包含 ${pkg['phrases'] is List ? (pkg['phrases'] as List).length : 0} 条常用语、'
                            '${(pkg['userFreq'] as Map).length} 个学习词、'
                            '${(pkg['sessions'] as List).length} 条录音会话',
                            style: TextStyle(fontSize: 11, color: secondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _export(state),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('导出并分享'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickImport(state),
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: const Text('选择文件导入'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(
            message: _error!,
            onRetry: () => setState(() => _error = null),
            onDismiss: () => setState(() => _error = null),
          ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 10),
          InfoBanner(
              text: _status!,
              icon: Icons.check_circle_outline_rounded,
              trailing: _imported != null
                  ? Text('$_imported 项',
                      style: const TextStyle(fontSize: 11, color: AppColors.accentDark))
                  : null),
        ],
        const SizedBox(height: 12),
        SettingCard(
          title: '通过同步空间迁移',
          description: '不经过文件分享，直接把迁移包写入配对空间。',
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _syncSettings(state, upload: true),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('上传迁移包'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _syncSettings(state, upload: false),
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('恢复迁移包'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingCard(
          title: '粘贴 JSON 导入',
          description: '适合从旧设备复制迁移包内容后直接粘贴。',
          child: Column(
            children: [
              TextField(
                controller: _paste,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '{"schema":"wechat-input-clone/migration/1", ...}',
                ),
                style: const TextStyle(fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _importText(state, _paste.text),
                  icon: const Icon(Icons.input_rounded, size: 18),
                  label: const Text('导入粘贴内容'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings/sync'),
                icon: const Icon(Icons.devices_other_outlined, size: 18),
                label: const Text('配对设备'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/settings/privacy'),
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('数据说明'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoBanner(
          text: '导入会覆盖同名设置、常用语与个人词典。建议先导出当前设备作为备份。',
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }
}
