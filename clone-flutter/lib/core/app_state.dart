import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhraseEntry {
  final String text;
  final String code;
  const PhraseEntry({required this.text, this.code = ''});

  Map<String, dynamic> toJson() => {'text': text, 'code': code};
  factory PhraseEntry.fromJson(Map<String, dynamic> json) =>
      PhraseEntry(text: (json['text'] ?? '').toString(), code: (json['code'] ?? '').toString());
}

class ChatEntry {
  final String role;
  final String content;
  final bool error;
  final DateTime createdAt;
  const ChatEntry({
    required this.role,
    required this.content,
    this.error = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'error': error,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory ChatEntry.fromJson(Map<String, dynamic> json) => ChatEntry(
        role: (json['role'] ?? 'assistant').toString(),
        content: (json['content'] ?? '').toString(),
        error: json['error'] == true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as num?)?.toInt() ?? 0),
      );
}

class RecorderSession {
  final String id;
  final String title;
  final String transcript;
  final String summary;
  final int durationSeconds;
  final DateTime createdAt;

  const RecorderSession({
    required this.id,
    required this.title,
    required this.transcript,
    this.summary = '',
    required this.durationSeconds,
    required this.createdAt,
  });

  RecorderSession copyWith({
    String? title,
    String? transcript,
    String? summary,
    int? durationSeconds,
  }) =>
      RecorderSession(
        id: id,
        title: title ?? this.title,
        transcript: transcript ?? this.transcript,
        summary: summary ?? this.summary,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'transcript': transcript,
        'summary': summary,
        'durationSeconds': durationSeconds,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory RecorderSession.fromJson(Map<String, dynamic> json) => RecorderSession(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '录音').toString(),
        transcript: (json['transcript'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as num?)?.toInt() ?? 0),
      );
}

class FeedbackEntry {
  final String id;
  final String category;
  final String text;
  final DateTime createdAt;
  const FeedbackEntry({
    required this.id,
    required this.category,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
        id: (json['id'] ?? '').toString(),
        category: (json['category'] ?? '其他').toString(),
        text: (json['text'] ?? '').toString(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as num?)?.toInt() ?? 0),
      );
}

const String kDefaultToolbarOrder =
    'switch,voice,clipboard,phrases,emoji,handwrite,ai,translate,polish,settings';
const String kDefaultModeOrder =
    't9,qwerty,handwrite,stroke,wubi,doublepin,english,number,symbols,emoji';

const List<String> kAllFuzzyPairs = [
  'zh_z', 'ch_c', 'sh_s', 'n_l', 'r_l', 'an_ang', 'en_eng', 'in_ing',
  'ian_iang', 'uan_uang', 'un_ong', 'ong_eng', 'ai_ei', 'u_v',
];

const List<String> kPlusItems = [
  'ask_ai', 'smart_spelling', 'spelling_correct', 'sticker', 'small_emoji',
  'kaomoji', 'rewrite', 'text_polish', 'poster', 'quick_send',
];

/// Central persisted state. Every toggle/segmented control in the app writes
/// through this class, backed by shared_preferences.
class AppState extends ChangeNotifier {
  AppState._(this.prefs);

  final SharedPreferences prefs;
  static late AppState instance;

  List<PhraseEntry> _phrases = [];
  List<ChatEntry> _chat = [];
  List<RecorderSession> _sessions = [];
  List<String> _clipboard = [];
  List<FeedbackEntry> _feedback = [];
  Map<String, int> _userFreq = {};
  Map<String, String> _fixed = {};
  Set<String> _deleted = {};

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppState._(prefs);
    state._readCollections();
    if (!prefs.containsKey('phrases.data')) {
      try {
        final raw = await rootBundle.loadString('assets/data/phrases.json');
        final list = (jsonDecode(raw) as List)
            .map((e) => PhraseEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        state._phrases = list;
        await prefs.setString('phrases.data', jsonEncode(list.map((e) => e.toJson()).toList()));
      } catch (_) {
        state._phrases = const [
          PhraseEntry(text: '你好', code: 'nihao'),
          PhraseEntry(text: '谢谢', code: 'xiexie'),
          PhraseEntry(text: '收到', code: 'shoudao'),
        ];
      }
    }
    instance = state;
    return state;
  }

  void _readCollections() {
    _phrases = _decodeList('phrases.data', (m) => PhraseEntry.fromJson(m));
    _chat = _decodeList('chat.history', (m) => ChatEntry.fromJson(m));
    _sessions = _decodeList('recorder.sessions', (m) => RecorderSession.fromJson(m));
    _feedback = _decodeList('help.feedback', (m) => FeedbackEntry.fromJson(m));
    _clipboard = _decodeStrings('clipboard.history');
    final freq = prefs.getString('ime.userFreq');
    if (freq != null) {
      try {
        _userFreq = (jsonDecode(freq) as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()));
      } catch (_) {
        _userFreq = {};
      }
    }
    final fixed = prefs.getString('ime.fixed');
    if (fixed != null) {
      try {
        _fixed = (jsonDecode(fixed) as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (_) {
        _fixed = {};
      }
    }
    _deleted = prefs.getStringList('ime.deleted')?.toSet() ?? <String>{};
  }

  List<T> _decodeList<T>(String key, T Function(Map<String, dynamic>) from) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => from(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _decodeStrings(String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------- generic

  bool flag(String key, [bool fallback = false]) =>
      prefs.getBool(key) ?? fallback;
  Future<void> setFlag(String key, bool value) async {
    await prefs.setBool(key, value);
    notifyListeners();
  }

  String text(String key, [String fallback = '']) =>
      prefs.getString(key) ?? fallback;
  Future<void> setText(String key, String value) async {
    await prefs.setString(key, value);
    notifyListeners();
  }

  double number(String key, [double fallback = 0]) =>
      prefs.getDouble(key) ?? fallback;
  Future<void> setNumber(String key, double value) async {
    await prefs.setDouble(key, value);
    notifyListeners();
  }

  int integer(String key, [int fallback = 0]) =>
      prefs.getInt(key) ?? fallback;
  Future<void> setInteger(String key, int value) async {
    await prefs.setInt(key, value);
    notifyListeners();
  }

  List<String> strings(String key, List<String> fallback) =>
      prefs.getStringList(key) ?? fallback;

  Future<void> setStrings(String key, List<String> value) async {
    await prefs.setStringList(key, value);
    notifyListeners();
  }

  // --------------------------------------------------------------- settings

  bool get acceptedPrivacy => flag('privacy.accepted');
  Future<void> acceptPrivacy() => setFlag('privacy.accepted', true);

  String get themeMode => text('ui.theme', 'system');
  Future<void> setThemeMode(String value) => setText('ui.theme', value);

  static String get defaultApiBase {
    if (Platform.isAndroid) return 'http://10.0.2.2:8787';
    return 'http://127.0.0.1:8787';
  }

  String get apiBaseUrl => text('api.base', defaultApiBase);
  Future<void> setApiBaseUrl(String value) =>
      setText('api.base', value.trim().replaceAll(RegExp(r'/+$'), ''));

  String get appToken => text('api.appToken');
  Future<void> setAppToken(String value) => setText('api.appToken', value.trim());

  bool get standalone => flag('mode.standalone');
  Future<void> setStandalone(bool value) => setFlag('mode.standalone', value);

  double get candidateSize => number('display.candidateSize', 18).clamp(14, 26);
  Future<void> setCandidateSize(double v) => setNumber('display.candidateSize', v);

  double get keyboardScale => number('display.keyboardScale', 1).clamp(.75, 1.35);
  Future<void> setKeyboardScale(double v) => setNumber('display.keyboardScale', v);

  String get numberLayout => text('display.numberLayout', 'grid');
  Future<void> setNumberLayout(String v) => setText('display.numberLayout', v);

  bool get slideInput => flag('display.slideInput');
  bool get showEmojiKey => flag('display.emojiKey', true);
  bool get showToolbar => flag('display.toolbar', true);
  bool get splitKeyboard => flag('display.split');

  bool get keySound => flag('keys.sound');
  bool get keyVibrate => flag('keys.vibrate', true);
  bool get keyBubble => flag('keys.bubble', true);
  double get keyVolume => number('keys.volume', .6);
  double get vibrateLevel => number('keys.vibrateLevel', .6);

  bool get enterSend => flag('aux.enterSend');
  bool get autoSpace123 => flag('aux.autoSpace123', true);
  bool get autoSpaceAbc => flag('aux.autoSpaceAbc', true);
  bool get smsCode => flag('aux.smsCode', true);
  bool get capitalize => flag('aux.capitalize', true);
  bool get doubleSpacePeriod => flag('aux.doubleSpacePeriod', true);
  bool get englishAutoCorrect => flag('aux.englishCorrect', true);
  bool get directPreInput => flag('aux.directPreInput');
  bool get associate => flag('aux.associate', true);

  String get voiceLanguage => text('voice.language', 'zh_CN');
  Future<void> setVoiceLanguage(String v) => setText('voice.language', v);

  String get voicePunctuation => text('voice.punctuation', 'smart');
  Future<void> setVoicePunctuation(String v) => setText('voice.punctuation', v);

  bool get longPressSpaceVoice => flag('voice.longPressSpace', true);
  bool get releaseToSend => flag('voice.releaseSend', true);
  bool get smartPolish => flag('voice.smartPolish');
  bool get offlineSpeech => flag('voice.offline');
  bool get showVoiceIcon => flag('voice.showIcon', true);
  String get standby => text('voice.standby', '10');

  bool get fuzzyEnabled => flag('fuzzy.enabled', true);
  Set<String> get fuzzyPairs =>
      prefs.getStringList('fuzzy.pairs')?.toSet() ?? kAllFuzzyPairs.toSet();
  Future<void> setFuzzyPair(String id, bool enabled) async {
    final set = fuzzyPairs;
    if (enabled) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await prefs.setStringList('fuzzy.pairs', set.toList());
    notifyListeners();
  }

  bool get plusEnabled => flag('plus.enabled', true);
  Future<void> setPlusEnabled(bool v) => setFlag('plus.enabled', v);
  bool plusItem(String id) => flag('plus.$id', true);
  Future<void> setPlusItem(String id, bool v) => setFlag('plus.$id', v);

  List<String> get enabledModes => strings('ime.modes', kDefaultModeOrder.split(','));
  Future<void> setModeEnabled(String id, bool enabled) async {
    final list = enabledModes.toList();
    if (enabled) {
      if (!list.contains(id)) list.add(id);
    } else {
      if (list.length <= 1) return;
      list.remove(id);
    }
    await setStrings('ime.modes', list);
  }

  List<String> get modeOrder => strings('ime.modeOrder', kDefaultModeOrder.split(','));
  Future<void> setModeOrder(List<String> order) => setStrings('ime.modeOrder', order);

  String get lastMode => text('ime.lastMode', 't9');
  Future<void> setLastMode(String mode) => setText('ime.lastMode', mode);

  List<String> get toolbarOrder =>
      strings('toolbar.order', kDefaultToolbarOrder.split(','));
  Future<void> setToolbarOrder(List<String> order) =>
      setStrings('toolbar.order', order);

  List<String> get toolbarHidden => strings('toolbar.hidden', const []);
  Future<void> setToolbarHidden(List<String> hidden) =>
      setStrings('toolbar.hidden', hidden);

  // ------------------------------------------------------------------ lists

  List<PhraseEntry> get phrases => List.unmodifiable(_phrases);
  Future<void> addPhrase(PhraseEntry entry) async {
    if (entry.text.trim().isEmpty) return;
    _phrases.add(entry);
    await _persistPhrases();
  }

  Future<void> updatePhrase(int index, PhraseEntry entry) async {
    if (index < 0 || index >= _phrases.length) return;
    _phrases[index] = entry;
    await _persistPhrases();
  }

  Future<void> removePhrase(int index) async {
    if (index < 0 || index >= _phrases.length) return;
    _phrases.removeAt(index);
    await _persistPhrases();
  }

  Future<void> setPhrases(List<PhraseEntry> list) async {
    _phrases = list;
    await _persistPhrases();
  }

  Future<void> _persistPhrases() async {
    await prefs.setString(
        'phrases.data', jsonEncode(_phrases.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  List<String> get clipboard => List.unmodifiable(_clipboard);
  Future<void> addClipboard(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    _clipboard.remove(v);
    _clipboard.insert(0, v);
    if (_clipboard.length > 50) _clipboard = _clipboard.sublist(0, 50);
    await prefs.setString('clipboard.history', jsonEncode(_clipboard));
    notifyListeners();
  }

  Future<void> removeClipboardAt(int index) async {
    if (index < 0 || index >= _clipboard.length) return;
    _clipboard.removeAt(index);
    await prefs.setString('clipboard.history', jsonEncode(_clipboard));
    notifyListeners();
  }

  Future<void> setClipboard(List<String> list) async {
    _clipboard = list.take(50).toList();
    await prefs.setString('clipboard.history', jsonEncode(_clipboard));
    notifyListeners();
  }

  List<ChatEntry> get chat => List.unmodifiable(_chat);
  Future<void> addChat(ChatEntry entry) async {
    _chat.add(entry);
    if (_chat.length > 200) _chat = _chat.sublist(_chat.length - 200);
    await prefs.setString('chat.history', jsonEncode(_chat.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> updateLastChat(ChatEntry entry) async {
    if (_chat.isEmpty) return;
    _chat[_chat.length - 1] = entry;
    await prefs.setString('chat.history', jsonEncode(_chat.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> clearChat() async {
    _chat = [];
    await prefs.remove('chat.history');
    notifyListeners();
  }

  Future<void> setChat(List<ChatEntry> list) async {
    _chat = List<ChatEntry>.from(list);
    await prefs.setString('chat.history', jsonEncode(_chat.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  List<RecorderSession> get sessions => List.unmodifiable(_sessions);
  Future<void> saveSession(RecorderSession session) async {
    _sessions.removeWhere((e) => e.id == session.id);
    _sessions.insert(0, session);
    await _persistSessions();
  }

  Future<void> updateSession(RecorderSession session) => saveSession(session);

  Future<void> removeSession(String id) async {
    _sessions.removeWhere((e) => e.id == id);
    await _persistSessions();
  }

  Future<void> _persistSessions() async {
    await prefs.setString('recorder.sessions',
        jsonEncode(_sessions.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  List<FeedbackEntry> get feedback => List.unmodifiable(_feedback);
  Future<void> addFeedback(FeedbackEntry entry) async {
    _feedback.insert(0, entry);
    await prefs.setString('help.feedback', jsonEncode(_feedback.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> removeFeedback(String id) async {
    _feedback.removeWhere((e) => e.id == id);
    await prefs.setString('help.feedback', jsonEncode(_feedback.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  // --------------------------------------------------------------- learning

  int freqOf(String text) => _userFreq[text] ?? 0;
  Map<String, int> get userFreq => Map.unmodifiable(_userFreq);
  Future<void> learn(String text) async {
    if (text.trim().isEmpty) return;
    _userFreq[text] = (_userFreq[text] ?? 0) + 1;
    await prefs.setString('ime.userFreq', jsonEncode(_userFreq));
    notifyListeners();
  }

  Map<String, String> get fixedWords => Map.unmodifiable(_fixed);
  Future<void> fixWord(String code, String text) async {
    if (code.isEmpty || text.isEmpty) return;
    _fixed[code] = text;
    await prefs.setString('ime.fixed', jsonEncode(_fixed));
    notifyListeners();
  }

  Future<void> unfixWord(String code) async {
    _fixed.remove(code);
    await prefs.setString('ime.fixed', jsonEncode(_fixed));
    notifyListeners();
  }

  Set<String> get deletedWords => Set.unmodifiable(_deleted);
  bool isDeleted(String text) => _deleted.contains(text);
  Future<void> deleteWord(String text) async {
    _deleted.add(text);
    _fixed.removeWhere((_, value) => value == text);
    _userFreq.remove(text);
    await prefs.setStringList('ime.deleted', _deleted.toList());
    await prefs.setString('ime.fixed', jsonEncode(_fixed));
    await prefs.setString('ime.userFreq', jsonEncode(_userFreq));
    notifyListeners();
  }

  Future<void> restoreWord(String text) async {
    _deleted.remove(text);
    await prefs.setStringList('ime.deleted', _deleted.toList());
    notifyListeners();
  }

  Future<void> clearPersonalDictionary() async {
    _userFreq = {};
    _fixed = {};
    _deleted = {};
    await prefs.remove('ime.userFreq');
    await prefs.remove('ime.fixed');
    await prefs.remove('ime.deleted');
    notifyListeners();
  }

  // ------------------------------------------------------------------ sync

  String get syncCode => text('sync.code');
  String get syncToken => text('sync.token');
  String get syncPeer => text('sync.peer');
  String get syncPeerToken => text('sync.peerToken');
  bool get syncConnected => syncToken.isNotEmpty;
  bool get syncClipboard => flag('sync.clipboard', true);
  bool get syncPhrases => flag('sync.phrases', true);
  bool get syncSettings => flag('sync.settings', true);

  Future<void> saveSync({required String code, required String token, required String peer, String peerToken = ''}) async {
    await prefs.setString('sync.code', code);
    await prefs.setString('sync.token', token);
    await prefs.setString('sync.peer', peer);
    await prefs.setString('sync.peerToken', peerToken);
    notifyListeners();
  }

  Future<void> clearSync() async {
    await prefs.remove('sync.code');
    await prefs.remove('sync.token');
    await prefs.remove('sync.peer');
    await prefs.remove('sync.peerToken');
    notifyListeners();
  }

  String generatePairCode() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  // ------------------------------------------------------------- migration

  Map<String, dynamic> exportPackage() => {
        'schema': 'wechat-input-clone/migration/1',
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': {
          'api.base': apiBaseUrl,
          'ui.theme': themeMode,
          'display.candidateSize': candidateSize,
          'display.keyboardScale': keyboardScale,
          'voice.language': voiceLanguage,
          'fuzzy.pairs': fuzzyPairs.toList(),
          'toolbar.order': toolbarOrder,
          'ime.modes': enabledModes,
          'plus.enabled': plusEnabled,
        },
        'phrases': _phrases.map((e) => e.toJson()).toList(),
        'userFreq': _userFreq,
        'fixed': _fixed,
        'deleted': _deleted.toList(),
        'sessions': _sessions.map((e) => e.toJson()).toList(),
      };

  Future<int> importPackage(Map<String, dynamic> data) async {
    var count = 0;
    final settings = data['settings'];
    if (settings is Map) {
      for (final entry in settings.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is num) {
          await prefs.setDouble(key, value.toDouble());
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.map((e) => e.toString()).toList());
        }
        count++;
      }
    }
    if (data['phrases'] is List) {
      _phrases = (data['phrases'] as List)
          .map((e) => PhraseEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await prefs.setString('phrases.data', jsonEncode(_phrases.map((e) => e.toJson()).toList()));
      count += _phrases.length;
    }
    if (data['userFreq'] is Map) {
      _userFreq = (data['userFreq'] as Map)
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      await prefs.setString('ime.userFreq', jsonEncode(_userFreq));
    }
    if (data['fixed'] is Map) {
      _fixed = (data['fixed'] as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
      await prefs.setString('ime.fixed', jsonEncode(_fixed));
    }
    if (data['deleted'] is List) {
      _deleted = (data['deleted'] as List).map((e) => e.toString()).toSet();
      await prefs.setStringList('ime.deleted', _deleted.toList());
    }
    if (data['sessions'] is List) {
      _sessions = (data['sessions'] as List)
          .map((e) => RecorderSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await prefs.setString('recorder.sessions', jsonEncode(_sessions.map((e) => e.toJson()).toList()));
    }
    notifyListeners();
    return count;
  }

  Future<void> resetEverything() async {
    await prefs.clear();
    _phrases = [];
    _chat = [];
    _sessions = [];
    _clipboard = [];
    _feedback = [];
    _userFreq = {};
    _fixed = {};
    _deleted = {};
    notifyListeners();
  }

  int get storageBytes {
    var total = 0;
    for (final k in prefs.getKeys()) {
      final v = prefs.get(k);
      total += k.length + (v?.toString().length ?? 0);
    }
    return total;
  }
}
