import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_state.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, {this.status});
  @override
  String toString() => message;
}

class UploadResult {
  final String id;
  final String name;
  final int size;
  final String sha256;
  const UploadResult(this.id, this.name, this.size, this.sha256);
}

class TransferItem {
  final String id;
  final String name;
  final int size;
  final String sha256;
  final DateTime createdAt;
  const TransferItem(this.id, this.name, this.size, this.sha256, this.createdAt);

  factory TransferItem.fromJson(Map<String, dynamic> json) => TransferItem(
        (json['id'] ?? '').toString(),
        (json['name'] ?? 'file').toString(),
        (json['size'] as num?)?.toInt() ?? 0,
        (json['sha256'] ?? '').toString(),
        DateTime.fromMillisecondsSinceEpoch(
            ((json['created'] as num?)?.toDouble() ?? 0).round() * 1000),
      );
}

/// HTTP bridge to the local replacement backend. The client never holds a
/// model key: only an optional short-lived app token configured by the user.
class ApiClient {
  final String baseUrl;
  final String appToken;
  final bool offline;
  http.Client? _activeStream;

  ApiClient({required this.baseUrl, this.appToken = '', this.offline = false});

  factory ApiClient.fromState(AppState state) => ApiClient(
        baseUrl: state.apiBaseUrl,
        appToken: state.appToken,
        offline: state.standalone,
      );

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ApiException('API 地址无效：$baseUrl');
    }
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        if (appToken.isNotEmpty) 'Authorization': 'Bearer $appToken',
      };

  void _guard() {
    if (offline) {
      throw ApiException('单机模式已开启。请先在「单机模式」中关闭联网能力。');
    }
  }

  String _error(int status, String body) {
    var detail = body.trim();
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        detail = decoded['detail'].toString();
      }
    } catch (_) {}
    if (detail.length > 300) detail = detail.substring(0, 300);
    if (detail.isEmpty) detail = 'HTTP $status';
    return '请求失败（$status）：$detail';
  }

  Future<Map<String, dynamic>> _jsonPost(String path, Map<String, dynamic> payload,
      {Duration timeout = const Duration(seconds: 120)}) async {
    _guard();
    final client = http.Client();
    try {
      final response = await client
          .post(_uri(path), headers: _headers, body: jsonEncode(payload))
          .timeout(timeout);
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode >= 400) {
        throw ApiException(_error(response.statusCode, body), status: response.statusCode);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw ApiException('服务返回格式不正确');
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw ApiException('请求超时。请确认后端已启动：$baseUrl');
    } on SocketException catch (e) {
      throw ApiException('无法连接后端 $baseUrl\n${e.message}');
    } on http.ClientException catch (e) {
      throw ApiException('网络请求失败：${e.message}');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _jsonGet(String path,
      {Map<String, String>? query, Duration timeout = const Duration(seconds: 15)}) async {
    _guard();
    final client = http.Client();
    try {
      final response = await client.get(_uri(path, query), headers: _headers).timeout(timeout);
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode >= 400) {
        throw ApiException(_error(response.statusCode, body), status: response.statusCode);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw ApiException('服务返回格式不正确');
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw ApiException('请求超时。请确认后端已启动：$baseUrl');
    } on SocketException catch (e) {
      throw ApiException('无法连接后端 $baseUrl\n${e.message}');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> health() => _jsonGet('/health',
      timeout: const Duration(seconds: 6));

  // ------------------------------------------------------------------- chat

  Future<String> chat(List<Map<String, String>> messages,
      {double temperature = .7, int maxTokens = 1200}) async {
    final data = await _jsonPost('/v1/ai/chat', {
      'messages': messages,
      'stream': false,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });
    return (data['text'] ?? '').toString();
  }

  /// SSE stream. [onDone] runs after a clean end.
  Stream<String> chatStream(List<Map<String, String>> messages,
      {double temperature = .7, int maxTokens = 1200}) async* {
    _guard();
    final client = http.Client();
    _activeStream = client;
    try {
      final request = http.Request('POST', _uri('/v1/ai/chat'))
        ..headers.addAll(_headers)
        ..body = jsonEncode({
          'messages': messages,
          'stream': true,
          'temperature': temperature,
          'max_tokens': maxTokens,
        });
      final response = await client.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode >= 400) {
        final body = await response.stream.bytesToString();
        throw ApiException(_error(response.statusCode, body), status: response.statusCode);
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('event: error')) {
          continue;
        }
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '{}') continue;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            if (decoded['error'] != null) {
              throw ApiException('模型服务错误：${decoded['error']}');
            }
            final text = decoded['text'];
            if (text is String && text.isNotEmpty) yield text;
          }
        } on FormatException {
          continue;
        }
      }
    } on TimeoutException {
      throw ApiException('连接超时。请确认后端已启动：$baseUrl');
    } on SocketException catch (e) {
      throw ApiException('无法连接后端 $baseUrl\n${e.message}');
    } on http.ClientException catch (e) {
      if (e.message.contains('closed') || e.message.contains('aborted')) {
        return;
      }
      throw ApiException('网络请求失败：${e.message}');
    } finally {
      client.close();
      if (identical(_activeStream, client)) _activeStream = null;
    }
  }

  void stopStream() {
    _activeStream?.close();
    _activeStream = null;
  }

  // -------------------------------------------------------------- text tools

  Future<String> polish(String text) async {
    final data = await _jsonPost('/v1/ai/polish', {'text': text});
    return (data['text'] ?? '').toString();
  }

  Future<List<String>> rewrite(String text, {String style = '自然', int count = 3}) async {
    final data = await _jsonPost('/v1/ai/rewrite', {
      'text': text,
      'style': style,
      'count': count,
    });
    final list = data['candidates'];
    if (list is List) {
      return list.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return const [];
  }

  Future<String> translate(String text, {String source = 'auto', String target = 'zh'}) async {
    final data = await _jsonPost('/v1/ai/translate', {
      'text': text,
      'source': source,
      'target': target,
    });
    return (data['text'] ?? '').toString();
  }

  Future<Map<String, dynamic>> summarize(String text, {String title = ''}) =>
      _jsonPost('/v1/ai/summary', {'text': text, 'title': title});

  // ------------------------------------------------------------------- sync

  Future<Map<String, dynamic>> pair(String code, {String name = '微输入法'}) =>
      _jsonPost('/v1/sync/pair', {'code': code, 'name': name});

  Future<List<String>> pushClipboard(String token, List<String> items) async {
    final data = await _jsonPost('/v1/sync/clipboard', {
      'token': token,
      'items': items.map((e) => {'text': e}).toList(),
    });
    final list = data['items'];
    if (list is List) {
      return list.map((e) => (e as Map)['text'].toString()).toList();
    }
    return const [];
  }

  Future<List<String>> pullClipboard(String token) async {
    final data = await _jsonGet('/v1/sync/clipboard', query: {'token': token});
    final list = data['items'];
    if (list is List) {
      return list.map((e) => (e as Map)['text'].toString()).toList();
    }
    return const [];
  }

  Future<List<PhraseEntry>> pushPhrases(String token, List<PhraseEntry> items) async {
    final data = await _jsonPost('/v1/sync/phrases', {
      'token': token,
      'items': items.map((e) => {'text': e.text, 'code': e.code}).toList(),
    });
    final list = data['items'];
    if (list is List) {
      return list
          .map((e) => PhraseEntry(
                text: (e as Map)['text'].toString(),
                code: (e['code'] ?? '').toString(),
              ))
          .toList();
    }
    return const [];
  }

  Future<void> pushSettings(String token, Map<String, dynamic> payload) =>
      _jsonPost('/v1/sync/settings', {'token': token, 'payload': payload});

  Future<Map<String, dynamic>> pullSettings(String token) async {
    final data = await _jsonGet('/v1/sync/settings', query: {'token': token});
    final payload = data['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : {};
  }

  // --------------------------------------------------------------- transfer

  Future<List<TransferItem>> transfers({String token = ''}) async {
    final data = await _jsonGet('/v1/transfer/list',
        query: token.isEmpty ? null : {'token': token});
    final list = data['items'];
    if (list is List) {
      return list
          .map((e) => TransferItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  Future<UploadResult> uploadFile(File file,
      {String token = '', void Function(double)? onProgress}) async {
    return _upload(
      filename: file.uri.pathSegments.isEmpty ? 'file' : file.uri.pathSegments.last,
      stream: file.openRead(),
      length: await file.length(),
      token: token,
      onProgress: onProgress,
    );
  }

  Future<UploadResult> uploadBytes(String filename, List<int> bytes,
      {String token = '', void Function(double)? onProgress}) {
    return _upload(
      filename: filename,
      stream: Stream.value(bytes),
      length: bytes.length,
      token: token,
      onProgress: onProgress,
    );
  }

  Future<UploadResult> _upload({
    required String filename,
    required Stream<List<int>> stream,
    required int length,
    required String token,
    void Function(double)? onProgress,
  }) async {
    _guard();
    final uri = _uri('/v1/transfer/upload', token.isEmpty ? null : {'token': token});
    final boundary = '----wechatinput${DateTime.now().microsecondsSinceEpoch}';
    final head = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="file"; filename="${filename.replaceAll('"', '')}"\r\n'
      'Content-Type: application/octet-stream\r\n\r\n',
    );
    final tail = utf8.encode('\r\n--$boundary--\r\n');
    final total = head.length + length + tail.length;

    final client = http.Client();
    final request = http.StreamedRequest('POST', uri)
      ..headers.addAll({
        'Content-Type': 'multipart/form-data; boundary=$boundary',
        if (appToken.isNotEmpty) 'Authorization': 'Bearer $appToken',
      })
      ..contentLength = total;
    var sent = 0;
    void report(int n) {
      sent += n;
      onProgress?.call(total == 0 ? 0 : (sent / total).clamp(0, 1));
    }

    final responseFuture = client.send(request);
    try {
      request.sink.add(head);
      report(head.length);
      await for (final data in stream) {
        request.sink.add(data);
        report(data.length);
      }
      request.sink.add(tail);
      report(tail.length);
      await request.sink.close();
      final response = await responseFuture.timeout(const Duration(minutes: 10));
      final body = await response.stream.bytesToString();
      if (response.statusCode >= 400) {
        throw ApiException(_error(response.statusCode, body), status: response.statusCode);
      }
      final data = jsonDecode(body);
      if (data is! Map) throw ApiException('上传响应格式不正确');
      return UploadResult(
        (data['id'] ?? '').toString(),
        (data['name'] ?? filename).toString(),
        (data['size'] as num?)?.toInt() ?? length,
        (data['sha256'] ?? '').toString(),
      );
    } on TimeoutException {
      throw ApiException('上传超时。');
    } on SocketException catch (e) {
      throw ApiException('无法连接后端：${e.message}');
    } finally {
      client.close();
    }
  }

  Future<File> download(String id, String name,
      {void Function(double)? onProgress}) async {
    _guard();
    final client = http.Client();
    try {
      final response = await client
          .send(http.Request('GET', _uri('/v1/transfer/$id')))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 400) {
        final body = await response.stream.bytesToString();
        throw ApiException(_error(response.statusCode, body), status: response.statusCode);
      }
      final dir = await getApplicationDocumentsDirectory();
      final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/downloads/$safe');
      await file.parent.create(recursive: true);
      final total = response.contentLength ?? 0;
      var read = 0;
      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        read += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call((read / total).clamp(0, 1));
      }
      await sink.flush();
      await sink.close();
      onProgress?.call(1);
      return file;
    } on TimeoutException {
      throw ApiException('下载超时。');
    } on SocketException catch (e) {
      throw ApiException('无法连接后端：${e.message}');
    } finally {
      client.close();
    }
  }
}

String humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
