import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

class _Template {
  final String id;
  final String name;
  final List<Color> colors;
  final Color text;
  final Color muted;
  const _Template(this.id, this.name, this.colors, this.text, this.muted);
}

const _templates = [
  _Template('mint', '薄荷', [Color(0xFF0E8A68), Color(0xFF25C894)],
      Colors.white, Color(0xCCFFFFFF)),
  _Template('ink', '墨色', [Color(0xFF1F2422), Color(0xFF34423D)],
      Color(0xFFF2F7F4), Color(0xB3F2F7F4)),
  _Template('sunset', '落日', [Color(0xFFB85B3D), Color(0xFFE9A66E)],
      Color(0xFFFFF8F0), Color(0xCCFFF8F0)),
];

class PosterPage extends StatefulWidget {
  const PosterPage({super.key});

  @override
  State<PosterPage> createState() => _PosterPageState();
}

class _PosterPageState extends State<PosterPage> {
  final TextEditingController _text = TextEditingController(
      text: '把想说的话，排成一张好看的图。\n\n微输入法 · 排版成图');
  final GlobalKey _boundary = GlobalKey();
  String _template = 'mint';
  double _fontSize = 24;
  bool _saving = false;
  String? _savedPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (mounted) setState(() => _savedPath = null);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  _Template get _current => _templates.firstWhere((e) => e.id == _template);

  Future<File> _capture() async {
    final boundary =
        _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('预览尚未准备好');
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('图片编码失败');
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/posters');
    await folder.create(recursive: true);
    final file = File(
        '${folder.path}/poster-${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _save({bool share = false}) async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = '请先输入海报文字');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final file = await _capture();
      if (!mounted) return;
      setState(() {
        _savedPath = file.path;
        _saving = false;
      });
      if (share) {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '来自微输入法的排版成图',
          sharePositionOrigin: shareOriginOf(context),
        ));
      } else {
        if (mounted) showToast(context, '已保存到 ${file.path}');
      }
    } catch (e) {
      setState(() {
        _error = '保存失败：$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark ? AppColors.darkSecondary : AppColors.textSecondary;
    final template = _current;
    return Scaffold(
      appBar: AppBar(
        title: const Text('排版成图'),
        actions: [
          IconButton(
            tooltip: '分享',
            onPressed: _saving ? null : () => _save(share: true),
            icon: const Icon(Icons.ios_share_rounded, size: 20),
          ),
          IconButton(
            tooltip: '保存',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.download_outlined, size: 21),
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
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: RepaintBoundary(
                          key: _boundary,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: template.colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: template.text.withValues(alpha: .8),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('微输入法 · 排版成图',
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            letterSpacing: 1.2,
                                            color: template.muted)),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _text.text.trim().isEmpty
                                          ? '输入文字后，这里会实时预览。'
                                          : _text.text,
                                      style: TextStyle(
                                        fontSize: _fontSize,
                                        height: 1.55,
                                        fontWeight: FontWeight.w600,
                                        color: template.text,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: 36,
                                  height: 2,
                                  color: template.text.withValues(alpha: .5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '独立学习复刻 · ${DateTime.now().year}',
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: template.muted,
                                      letterSpacing: .5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SettingCard(
                    title: '海报文字',
                    description: '支持多行；文字会实时进入预览。',
                    child: TextField(
                      controller: _text,
                      maxLines: 6,
                      minLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: '写点什么…',
                      ),
                    ),
                  ),
                  SettingCard(
                    title: '模板',
                    description: '颜色与排版为本项目重建。',
                    child: Row(
                      children: _templates.map((item) {
                        final active = item.id == _template;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() {
                                _template = item.id;
                                _savedPath = null;
                              }),
                              child: Container(
                                height: 58,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: item.colors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.accentDark
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(item.name,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: item.text,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SettingCard(
                    title: '字号',
                    description: '${_fontSize.round()} px',
                    child: Slider(
                      value: _fontSize,
                      min: 16,
                      max: 38,
                      divisions: 22,
                      label: '${_fontSize.round()}',
                      onChanged: (v) => setState(() {
                        _fontSize = v;
                        _savedPath = null;
                      }),
                    ),
                  ),
                  if (_error != null) ...[
                    ErrorBanner(
                      message: _error!,
                      onRetry: () => _save(),
                      onDismiss: () => setState(() => _error = null),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_savedPath != null) ...[
                    InfoBanner(
                      text: '已保存：$_savedPath',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download_rounded, size: 18),
                          label: const Text('保存 PNG'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : () => _save(share: true),
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('分享'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '图片在设备本地用 Flutter Canvas 渲染，不上传任何内容。${state.standalone ? ' 单机模式下同样可用。' : ''}',
                    style: TextStyle(fontSize: 10.5, color: secondary, height: 1.5),
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
