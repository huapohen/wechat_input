import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final TextEditingController _text = TextEditingController();
  List<TransferItem> _items = const [];
  final Map<String, String> _downloaded = {};
  bool _loading = false;
  bool _uploading = false;
  double _progress = 0;
  String _uploadName = '';
  String? _downloadingId;
  double _downloadProgress = 0;
  String? _error;
  String? _status;
  String? _health;

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkHealth();
      _refresh();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _token => _state.syncConnected ? _state.syncToken : '';

  Future<void> _checkHealth() async {
    try {
      final data = await ApiClient.fromState(_state).health();
      if (mounted) setState(() => _health = '${data['model']} · ASR ${data['asr']}');
    } on ApiException {
      if (mounted) setState(() => _health = null);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiClient.fromState(_state).transfers(token: _token);
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '读取文件列表失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(withData: false);
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.size > 50 * 1024 * 1024) {
        setState(() => _error = '文件超过 50 MB 限制');
        return;
      }
      setState(() {
        _uploading = true;
        _progress = 0;
        _uploadName = picked.name;
      });
      final api = ApiClient.fromState(_state);
      UploadResult uploaded;
      if (picked.path != null) {
        uploaded = await api.uploadFile(File(picked.path!),
            token: _token,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            });
      } else if (picked.bytes != null) {
        uploaded = await api.uploadBytes(picked.name, picked.bytes!,
            token: _token,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            });
      } else {
        throw ApiException('无法读取文件内容');
      }
      setState(() {
        _status = '已上传「${uploaded.name}」· ${humanBytes(uploaded.size)}';
        _uploading = false;
        _progress = 1;
      });
      await _refresh();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _error = '上传失败：$e';
        _uploading = false;
      });
    }
  }

  Future<void> _uploadText() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请输入要发送的文本');
      return;
    }
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
      _status = null;
      _uploadName = '文本-${DateTime.now().millisecondsSinceEpoch}.txt';
    });
    try {
      final bytes = utf8.encode(text);
      final uploaded = await ApiClient.fromState(_state).uploadBytes(
        _uploadName,
        bytes,
        token: _token,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      setState(() {
        _status = '已上传文本「${uploaded.name}」· ${humanBytes(uploaded.size)}';
        _uploading = false;
      });
      _text.clear();
      await _refresh();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _error = '上传失败：$e';
        _uploading = false;
      });
    }
  }

  Future<void> _download(TransferItem item) async {
    if (_downloadingId != null) return;
    setState(() {
      _downloadingId = item.id;
      _downloadProgress = 0;
      _error = null;
      _status = null;
    });
    try {
      final file = await ApiClient.fromState(_state).download(
        item.id,
        item.name,
        onProgress: (value) {
          if (mounted) setState(() => _downloadProgress = value);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloaded[item.id] = file.path;
        _status = '已下载到 ${file.path}';
        _downloadingId = null;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _downloadingId = null;
      });
    } catch (e) {
      setState(() {
        _error = '下载失败：$e';
        _downloadingId = null;
      });
    }
  }

  Future<void> _share(TransferItem item) async {
    var path = _downloaded[item.id];
    if (path == null) {
      await _download(item);
      path = _downloaded[item.id];
    }
    if (path == null) return;
    if (!mounted) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      text: item.name,
      subject: item.name,
      sharePositionOrigin: shareOriginOf(context),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('隔空传送'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 21),
          ),
          IconButton(
            tooltip: '服务设置',
            onPressed: () => Navigator.pushNamed(context, '/settings/service'),
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.send_rounded,
                                  size: 23, color: AppColors.accentDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('跨设备发送文件',
                                      style: TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _health == null
                                        ? '正在检查后端…'
                                        : '后端在线 · $_health',
                                    style: TextStyle(fontSize: 10.5, color: secondary),
                                  ),
                                ],
                              ),
                            ),
                            if (_loading)
                              const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _uploading ? null : _pickAndUpload,
                                icon: const Icon(Icons.attach_file_rounded, size: 18),
                                label: const Text('选择文件上传'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _refresh,
                                icon: const Icon(Icons.sync_rounded, size: 18),
                                label: const Text('刷新列表'),
                              ),
                            ),
                          ],
                        ),
                        if (_uploading) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text('上传中 · $_uploadName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        TextStyle(fontSize: 11, color: secondary)),
                              ),
                              Text('${(_progress * 100).round()}%',
                                  style: TextStyle(fontSize: 11, color: secondary)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 5,
                              backgroundColor:
                                  secondary.withValues(alpha: .12),
                            ),
                          ),
                        ],
                        if (_status != null) ...[
                          const SizedBox(height: 10),
                          InfoBanner(
                              text: _status!,
                              icon: Icons.check_circle_outline_rounded),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          ErrorBanner(
                            message: _error!,
                            onRetry: _refresh,
                            onDismiss: () => setState(() => _error = null),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingCard(
                    title: '发送文本',
                    description: '无需文件选择器即可验证上传、列表与下载链路。',
                    child: Column(
                      children: [
                        TextField(
                          controller: _text,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: '粘贴一段文本，发送到传送空间…',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _uploading ? null : _uploadText,
                            icon: const Icon(Icons.text_snippet_outlined, size: 18),
                            label: const Text('上传为 .txt 文件'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('传送记录',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: dark ? AppColors.darkText : AppColors.text)),
                      const Spacer(),
                      Text('${_items.length} 个文件',
                          style: TextStyle(fontSize: 11, color: secondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: EmptyState(
                        icon: Icons.folder_zip_outlined,
                        title: _loading ? '正在读取列表…' : '传送空间为空',
                        subtitle: '选择文件或上传一段文本后，会出现在这里。',
                      ),
                    )
                  else
                    ..._items.map((item) {
                      final downloading = _downloadingId == item.id;
                      final downloaded = _downloaded[item.id];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: (dark
                                              ? AppColors.darkSurfaceAlt
                                              : AppColors.surfaceAlt),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.insert_drive_file_outlined,
                                        size: 19),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${humanBytes(item.size)} · ${formatDateTime(item.createdAt)}'
                                          '${downloaded != null ? ' · 已下载' : ''}',
                                          style: TextStyle(
                                              fontSize: 10, color: secondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '下载',
                                    onPressed: downloading ? null : () => _download(item),
                                    icon: downloading
                                        ? const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Icon(Icons.download_rounded, size: 19),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    tooltip: '分享',
                                    onPressed: () => _share(item),
                                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              if (downloading) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _downloadProgress,
                                    minHeight: 4,
                                    backgroundColor:
                                        secondary.withValues(alpha: .12),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                      '下载中 ${(_downloadProgress * 100).round()}%',
                                      style: TextStyle(
                                          fontSize: 9.5, color: secondary)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 10),
                  InfoBanner(
                    text: _token.isEmpty
                        ? '未配对设备：文件保存在公共传送空间。配对后可按设备隔离列表。'
                        : '已配对：列表与上传绑定到本机 token。下载会写入应用文稿目录，可再次分享。',
                    icon: Icons.devices_other_outlined,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '服务地址：${state.apiBaseUrl} · 单文件上限 50 MB · SHA-256 由服务端返回。',
                    style: TextStyle(fontSize: 10, color: secondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
