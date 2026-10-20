import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/app_state.dart';

class Candidate {
  final String text;
  final int score;
  final bool phrase;
  const Candidate(this.text, this.score, {this.phrase = false});
}

class EmojiCategory {
  final String name;
  final List<String> items;
  const EmojiCategory(this.name, this.items);
}

class LayoutFact {
  final String file;
  final int rows;
  final int keys;
  final int height;
  const LayoutFact(this.file, this.rows, this.keys, this.height);
}

class _PhraseEntry {
  final String text;
  final String code;
  final String initials;
  final String digits;
  _PhraseEntry(this.text, this.code, this.initials, this.digits);
}

/// Local language data and candidate engine. All lookups run on-device from
/// the shared dictionary assets; no network call is involved.
class KeyboardData {
  KeyboardData._();

  static KeyboardData? _instance;
  static Future<KeyboardData>? _loading;

  static Future<KeyboardData> ensureLoaded() {
    final existing = _instance;
    if (existing != null) return Future.value(existing);
    return _loading ??= _load().then((value) {
      _instance = value;
      return value;
    });
  }

  static KeyboardData? get maybeInstance => _instance;

  final Map<String, List<String>> charBySyllable = {};
  final Map<String, List<String>> charByWubiCode = {};
  final Map<String, List<String>> charByStrokeCode = {};
  final Map<String, List<String>> t9Syllables = {};
  final List<_PhraseEntry> phrases = [];
  final Map<String, String> codeToSyllable = {};
  final Map<String, List<String>> syllableToCode = {};
  final List<String> englishWords = [];
  final List<EmojiCategory> emoji = [];
  final List<LayoutFact> layouts = [];
  final Map<String, int> _commonRank = {};
  final List<String> allCommon = [];

  static const Map<String, String> t9Letters = {
    '2': 'abc',
    '3': 'def',
    '4': 'ghi',
    '5': 'jkl',
    '6': 'mno',
    '7': 'pqrs',
    '8': 'tuv',
    '9': 'wxyz',
  };

  static String digitsOf(String text) {
    final buffer = StringBuffer();
    for (final ch in text.split('')) {
      var found = false;
      for (final entry in t9Letters.entries) {
        if (entry.value.contains(ch)) {
          buffer.write(entry.key);
          found = true;
          break;
        }
      }
      if (!found) buffer.write(ch);
    }
    return buffer.toString();
  }

  static Future<KeyboardData> _load() async {
    final data = KeyboardData._();
    data._buildCommon();
    final rawChars = jsonDecode(await rootBundle.loadString('assets/data/pinyin_chars.json'));
    final chars = Map<String, dynamic>.from(rawChars as Map);
    for (final entry in chars.entries) {
      final syllable = entry.value.toString();
      if (syllable.isEmpty) continue;
      data.charBySyllable.putIfAbsent(syllable, () => []).add(entry.key);
    }
    for (final list in data.charBySyllable.values) {
      list.sort((a, b) => data.rank(a).compareTo(data.rank(b)));
    }

    final rawPhrases = jsonDecode(await rootBundle.loadString('assets/data/pinyin_phrases.json'));
    final phraseMap = Map<String, dynamic>.from(rawPhrases as Map);
    for (final entry in phraseMap.entries) {
      final syllables = (entry.value as List).map((e) => e.toString()).toList();
      if (syllables.isEmpty) continue;
      final code = syllables.join();
      final initials = syllables.map((s) => s.isEmpty ? '' : s.substring(0, 1)).join();
      data.phrases.add(_PhraseEntry(entry.key, code, initials, digitsOf(code)));
    }

    final rawWubi = jsonDecode(await rootBundle.loadString('assets/data/wubi86.json'));
    for (final entry in (rawWubi as Map).entries) {
      final list = (entry.value as List).map((e) => e.toString()).toList();
      list.sort((a, b) => data.rank(a).compareTo(data.rank(b)));
      data.charByWubiCode[entry.key.toString()] = list;
    }

    final rawStroke = jsonDecode(await rootBundle.loadString('assets/data/stroke_codes.json'));
    for (final entry in (rawStroke as Map).entries) {
      final list = (entry.value as List).map((e) => e.toString()).toList();
      list.sort((a, b) => data.rank(a).compareTo(data.rank(b)));
      data.charByStrokeCode[entry.key.toString()] = list;
    }

    for (final entry in data.charBySyllable.entries) {
      final digits = digitsOf(entry.key);
      data.t9Syllables.putIfAbsent(digits, () => []).add(entry.key);
    }

    final rawDouble = jsonDecode(await rootBundle.loadString('assets/data/double_pinyin.json'));
    final doubleMap = Map<String, dynamic>.from(rawDouble as Map);
    final xiaobe = Map<String, dynamic>.from(doubleMap['xiaobe'] as Map);
    final initials = Map<String, String>.from(
        (xiaobe['initials'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
    final finals = Map<String, String>.from(
        (xiaobe['finals'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
    final rawSyllables = jsonDecode(await rootBundle.loadString('assets/data/pinyin_syllables.json')) as List;
    const initialSet = {
      'zh', 'ch', 'sh', 'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k',
      'h', 'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w',
    };
    for (final item in rawSyllables) {
      final syllable = item.toString();
      String? initial;
      if (syllable.startsWith('zh') || syllable.startsWith('ch') || syllable.startsWith('sh')) {
        initial = syllable.substring(0, 2);
      } else if (syllable.isNotEmpty && initialSet.contains(syllable.substring(0, 1))) {
        initial = syllable.substring(0, 1);
      }
      String code;
      if (initial == null) {
        code = finals[syllable] ?? syllable;
      } else {
        final finalPart = syllable.substring(initial.length);
        if (finalPart.isEmpty) continue;
        final ic = initials[initial] ?? initial;
        final fc = finals[finalPart] ?? finalPart;
        code = '$ic$fc';
      }
      data.codeToSyllable.putIfAbsent(code, () => syllable);
      data.syllableToCode.putIfAbsent(syllable, () => []).add(code);
    }

    final rawEnglish = jsonDecode(await rootBundle.loadString('assets/data/english_words.json')) as List;
    data.englishWords.addAll(rawEnglish.map((e) => e.toString()));
    data.englishWords.sort((a, b) {
      final byLength = a.length.compareTo(b.length);
      return byLength != 0 ? byLength : a.compareTo(b);
    });

    final rawEmoji = jsonDecode(await rootBundle.loadString('assets/data/emoji.json')) as List;
    for (final item in rawEmoji) {
      final map = Map<String, dynamic>.from(item as Map);
      data.emoji.add(EmojiCategory(
        (map['category'] ?? '表情').toString(),
        (map['items'] as List).map((e) => e.toString()).toList(),
      ));
    }

    try {
      final rawLayouts = jsonDecode(await rootBundle.loadString('assets/spec/keyboard_layouts.json')) as List;
      for (final item in rawLayouts) {
        final map = Map<String, dynamic>.from(item as Map);
        final lines = map['lines'] as List? ?? const [];
        var keys = 0;
        for (final line in lines) {
          keys += ((line as Map)['keys'] as List? ?? const []).length;
        }
        data.layouts.add(LayoutFact(
          (map['file'] ?? '').toString(),
          (map['line_count'] as num?)?.toInt() ?? 0,
          keys,
          (map['vheight'] as num?)?.toInt() ?? 0,
        ));
      }
    } catch (_) {
      // Layout facts are reference metadata only; keyboard rendering is ours.
    }
    return data;
  }

  void _buildCommon() {
    const raw =
        '的一是不了在人有我他这个们中来上大为和国地到以说时要就出会可也你对生能而子那得于着下自之年过发后作里'
        '用道行所然家种事成方多经么去法学如都同现当没动面起看定天分还进好小部其些主样理心她本前开但因只从'
        '想实日军者意无力它与长把机十民第公此已工使情明性知全三又关点正业外将两高间由问很最重并物手应战'
        '向头文体政美相见被利什二等产或新己制身果加西斯月话合回特代内信表化老给世位次度门任常先海通教儿'
        '原东声提立及比员解水名真论处走义各入几口认条平系气题活尔更别打女变四神总何电数安少报才结反受目'
        '太量再感建务做接必场件计管期市直德资命山金指克许统区保至队形社便空决治展马科司五基眼书非则听白'
        '却界达光放强即像难且权思王象完设式色路记南品住告类求据程北边死张该交规万取拉格望觉术领共确传师'
        '观清今切院让识候带导争运笑飞风步改收根干造言联持组每济车亲极林服快办议往元英士证近失转夫令准布'
        '始怎呢存未远叫台单影具罗字爱击流备兵连调深商算质团集百需价花党华城石级整府离况亚请技际约示复病'
        '息究线似官火断精满支视消越器容照须九增研写称企八功吗包片史委乎查轻易早曾除农找装广显吧阿李标谈'
        '吃图念六引历首医局突专费号尽另周较注语仅考落青随选列武红响虽推势参希古众构房半节土投某案黑维革'
        '划敌致陈律足态护七兴派孩验责营星够章音跟志底站严巴例防族供效续施留讲型料终答紧黄绝奇察母京段依'
        '批群项故按河米围江织害斗双境客纪采举杀攻父苏密低朝友诉止细愿千值仍男钱破网热助倒育属坐帝限船脸'
        '职速刻乐否刚威毛状率甚独球般普怕弹校苦创假久错承印晚兰试股拿脑预谁益阳若哪微尼继送急血惊伤素药'
        '适波夜省初喜卫源食险待述陆习置居劳财环排福纳欢雷警获模充负云停木游龙树疑层冷洲冲射略范竟句室异'
        '激汉村哈策演简卡罪判担州静退既衣您宗积余痛检差富灵协角占配征修皮挥胜降阶审沉坚善妈刘读啊超免压'
        '银买皇养伊怀执副乱抗犯追帮宣佛岁航优怪香著田铁控税左右份穿艺背阵草脚概恶块顿敢守酒岛托央户烈洋'
        '哥索胡款靠评版宝座释景顾弟登货互付伯慢欧换闻危忙核暗姐介坏讨丽良序升监临亮露永呼味野架域沙掉括'
        '舰鱼杂误湾吉减编楚肯测败屋跑梦散温困剑渐封救贵枪缺楼县尚毫移娘朋画班智亦耳恩短掌恐遗固席松秘谢'
        '鲁遇康虑幸均销钟诗藏赶剧票损忽巨炮旧端探湖录叶春乡附吸予礼港雨呀板庭妇归睛饭额含顺输摇招婚脱补'
        '谓督毒油疗旅泽材灭逐莫笔亡鲜词圣择寻厂睡博勒烟授诺伦岸奥唐卖俄炸载洛健堂旁宫喝借君禁阴园谋宋避'
        '抓荣姑孙逃牙束跳顶玉镇雪午练迫爷篇肉嘴馆遍凡础洞卷坦牛宁纸诸训私庄祖丝翻暴森塔默握戏隐熟骨访弱'
        '蒙歌店鬼软典欲萨伙遭盘爸扩盖弄雄稳忘亿刺拥徒姆杨齐赛趣曲刀床迎冰虚玩析窗醒妻透购替塞努休虎扬途'
        '侵刑绿兄迅套贸毕唯谷轮库迹尤竞街促延震弃甲伟麻川申缓潜闪售灯针哲络抵朱埃抱鼓植纯夏忍页杰筑折郑'
        '贝尊吴秀混臣雅振染盛怒舞圆搞狂措姓残秋培迷诚宽宇猛摆梅毁伸摩盟末乃悲拍丁赵硬麦蒋操耶阻订彩抽赞'
        '魔纷沿喊违妹浪汇币丰蓝殊献桌啦瓦莱援译夺汽烧距裁偏符勇触课敬哭懂墙袭召罚侠厅拜巧侧韩冒债曼融惯'
        '享戴童犹乘挂奖绍厚纵障讯涉彻刊丈爆乌役描洗玛患妙镜唱烦签仙彼弗症仿倾牌陷鸟轰咱菜闭奋庆撤泪茶疾'
        '缘播朗杜奶季丹狗尾仪偷奔珠虫驻孔宜艾桥淡翼恨繁寒伴叹旦愈潮粮缩罢聚径恰挑袋灰捕徐珍幕映裂泰隔启'
        '尖忠累炎暂估泛荒偿横拒瑞忆孤鼻闹羊呆厉衡胞零穷舍码赫婆魂灾洪腿胆津俗辩胸晓劲贫仁偶辑邦恢赖圈摸'
        '仰润堆碰艇稍迟辆废净凶署壁御奉旋冬矿抬蛋晨伏吹鸡倍糊秦盾杯租骑乏隆诊奴摄丧污渡旗甘耐凭扎抢绪粗'
        '肩梁幻菲皆碎宙叔岩荡综爬荷悉蒂返井壮薄悄扫敏碍殖详迪矛霍允幅撒剩凯颗骂赏液番箱贴漫酸郎腰舒眉忧'
        '浮辛恋餐吓挺励辞艘键伍峰尺昨黎辈贯侦滑券崇扰宪绕趋慈乔阅汗枝拖墨胁插箭腊粉泥氏彭拔骗凤慧媒佩愤'
        '扑龄驱惜豪掩兼跃尸肃帕驶堡届欣惠册储飘桑闲惨洁踪勃宾频仇磨递邪撞拟滚奏巡颜剂绩贡疯坡瞧截燃焦殿'
        '伪柳锁逼颇昏劝呈搜勤戒驾漂饮曹朵仔柔俩孟腐幼践籍牧凉牲佳娜浓芳稿竹腹跌逻垂遵脉貌柏狱猜怜惑陶兽'
        '帐饰贷昌叙躺钢沟寄扶铺邓寿惧询汤盗肥尝匆辉奈扣廷澳嘛董迁凝慰厌脏腾幽怨鞋丢埋泉涌辖躲晋紫艰魏吾'
        '慌祝邮吐狠鉴曰械咬邻赤挤弯椅陪割揭韦悟聪雾锋梯猫祥阔誉筹丛牵鸣沈媒忍';
    for (var i = 0; i < raw.length; i++) {
      final ch = raw.substring(i, i + 1);
      if (!_commonRank.containsKey(ch)) _commonRank[ch] = i;
    }
    allCommon.addAll(_commonRank.keys);
  }

  int rank(String text) {
    if (text.isEmpty) return 9999;
    final r = _commonRank[text.substring(0, 1)];
    if (r == null) return 5000 + text.codeUnitAt(0) % 2000;
    return r;
  }

  int commonBonus(String text) {
    final r = _commonRank[text.isEmpty ? '' : text.substring(0, 1)];
    if (r == null) return 0;
    return math.max(0, 70 - (r ~/ 8));
  }

  // --------------------------------------------------------------- pinyin

  List<Candidate> pinyinCandidates(String raw, AppState state,
      {bool enableFuzzy = true, int limit = 50}) {
    final q = raw.toLowerCase().replaceAll(RegExp(r"['\s]"), '');
    if (q.isEmpty) return const [];
    final scores = <String, int>{};
    final phraseFlags = <String>{};

    void add(String text, int score, {bool phrase = false}) {
      if (text.isEmpty || state.isDeleted(text)) return;
      final adjusted = score + state.freqOf(text) * 18;
      final current = scores[text];
      if (current == null || adjusted > current) scores[text] = adjusted;
      if (phrase) phraseFlags.add(text);
    }

    // Fixed/user words always lead their matching prefix.
    for (final entry in state.fixedWords.entries) {
      if (entry.key.startsWith(q)) {
        add(entry.value, 400 + entry.key.length * 2, phrase: entry.value.length > 1);
      }
    }

    final variants = <String>{};
    if (enableFuzzy && q.length >= 2 && state.fuzzyEnabled) {
      variants.addAll(_fuzzyVariants(q, state.fuzzyPairs));
    }

    for (final entry in phrases) {
      var matched = 0;
      if (entry.code.startsWith(q)) {
        matched = 1;
      } else if (q.length >= 2 && entry.initials.startsWith(q)) {
        matched = 2;
      } else if (variants.isNotEmpty) {
        for (final variant in variants) {
          if (entry.code.startsWith(variant)) {
            matched = 3;
            break;
          }
        }
      }
      if (matched == 0) continue;
      var score = matched == 1 ? 120 : matched == 2 ? 90 : 60;
      if (entry.code == q) score += 50;
      score += commonBonus(entry.text);
      score -= math.min(18, entry.text.length * 2);
      add(entry.text, score, phrase: true);
    }

    for (final entry in charBySyllable.entries) {
      var matched = false;
      var fuzzy = false;
      if (entry.key.startsWith(q)) {
        matched = true;
      } else if (variants.isNotEmpty) {
        for (final variant in variants) {
          if (entry.key.startsWith(variant)) {
            matched = true;
            fuzzy = true;
            break;
          }
        }
      }
      if (!matched) continue;
      var taken = 0;
      for (final ch in entry.value) {
        if (taken >= 26) break;
        if (state.isDeleted(ch)) continue;
        var score = (entry.key == q ? 65 : 40) + commonBonus(ch) - (fuzzy ? 12 : 0);
        add(ch, score);
        taken++;
      }
    }
    return _ranked(scores, phraseFlags, limit);
  }

  List<Candidate> t9Candidates(String raw, AppState state, {int limit = 50}) {
    final q = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (q.isEmpty) return const [];
    final scores = <String, int>{};
    final phraseFlags = <String>{};
    void add(String text, int score, {bool phrase = false}) {
      if (text.isEmpty || state.isDeleted(text)) return;
      final adjusted = score + state.freqOf(text) * 18;
      final current = scores[text];
      if (current == null || adjusted > current) scores[text] = adjusted;
      if (phrase) phraseFlags.add(text);
    }

    for (final entry in state.fixedWords.entries) {
      final digits = digitsOf(entry.key);
      if (digits.startsWith(q)) add(entry.value, 400, phrase: true);
    }
    for (final entry in phrases) {
      if (!entry.digits.startsWith(q)) continue;
      var score = (entry.digits == q ? 150 : 110) + commonBonus(entry.text);
      score -= math.min(16, entry.text.length * 2);
      add(entry.text, score, phrase: true);
    }
    for (final entry in t9Syllables.entries) {
      if (!entry.key.startsWith(q)) continue;
      for (final syllable in entry.value.take(18)) {
        final chars = charBySyllable[syllable];
        if (chars == null) continue;
        var taken = 0;
        for (final ch in chars) {
          if (taken >= 14) break;
          if (state.isDeleted(ch)) continue;
          add(ch, (entry.key == q ? 70 : 50) + commonBonus(ch));
          taken++;
        }
      }
    }
    return _ranked(scores, phraseFlags, limit);
  }

  List<Candidate> wubiCandidates(String raw, AppState state, {int limit = 50}) {
    final q = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (q.isEmpty) return const [];
    final scores = <String, int>{};
    for (final entry in charByWubiCode.entries) {
      if (!entry.key.startsWith(q)) continue;
      var taken = 0;
      for (final ch in entry.value) {
        if (taken >= 12) break;
        if (state.isDeleted(ch)) continue;
        var score = (entry.key == q ? 95 : 60) + commonBonus(ch);
        score += state.freqOf(ch) * 18;
        if ((scores[ch] ?? -1) < score) scores[ch] = score;
        taken++;
      }
    }
    return _ranked(scores, const {}, limit);
  }

  List<Candidate> strokeCandidates(String raw, AppState state, {int limit = 50}) {
    final q = raw.toLowerCase().replaceAll(RegExp(r'[^hspnz?]'), '');
    if (q.isEmpty) return const [];
    final scores = <String, int>{};
    for (final entry in charByStrokeCode.entries) {
      if (!_wildcardMatch(entry.key, q)) continue;
      var taken = 0;
      for (final ch in entry.value) {
        if (taken >= 12) break;
        if (state.isDeleted(ch)) continue;
        var score = (entry.key == q ? 90 : 55) + commonBonus(ch);
        score += state.freqOf(ch) * 18;
        if ((scores[ch] ?? -1) < score) scores[ch] = score;
        taken++;
      }
    }
    return _ranked(scores, const {}, limit);
  }

  static bool _wildcardMatch(String code, String query) {
    if (code.length < query.length) return false;
    for (var i = 0; i < query.length; i++) {
      final q = query.substring(i, i + 1);
      if (q != '?' && q != code.substring(i, i + 1)) return false;
    }
    return true;
  }

  List<Candidate> doublePinCandidates(String raw, AppState state, {int limit = 50}) {
    final q = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (q.length < 2) return const [];
    final buffer = StringBuffer();
    var i = 0;
    while (i + 1 < q.length) {
      final pair = q.substring(i, i + 2);
      final syllable = codeToSyllable[pair];
      if (syllable == null) break;
      buffer.write(syllable);
      i += 2;
    }
    if (buffer.isEmpty) return const [];
    return pinyinCandidates(buffer.toString(), state, enableFuzzy: false, limit: limit);
  }

  String decodeDoublePin(String raw) {
    final q = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final buffer = StringBuffer();
    var i = 0;
    while (i + 1 < q.length) {
      final pair = q.substring(i, i + 2);
      final syllable = codeToSyllable[pair];
      if (syllable == null) break;
      buffer.write(syllable);
      i += 2;
    }
    return buffer.toString();
  }

  List<String> _fuzzyVariants(String q, Set<String> enabled) {
    const map = {
      'zh_z': ['zh', 'z'],
      'ch_c': ['ch', 'c'],
      'sh_s': ['sh', 's'],
      'n_l': ['n', 'l'],
      'r_l': ['r', 'l'],
      'an_ang': ['an', 'ang'],
      'en_eng': ['en', 'eng'],
      'in_ing': ['in', 'ing'],
      'ian_iang': ['ian', 'iang'],
      'uan_uang': ['uan', 'uang'],
      'un_ong': ['un', 'ong'],
      'ong_eng': ['ong', 'eng'],
      'ai_ei': ['ai', 'ei'],
      'u_v': ['u', 'v'],
    };
    var current = <String>{q};
    var next = <String>{};
    for (var round = 0; round < 2; round++) {
      next = <String>{};
      for (final variant in current) {
        for (final entry in map.entries) {
          if (!enabled.contains(entry.key)) continue;
          final a = entry.value[0];
          final b = entry.value[1];
          if (variant.contains(a)) next.add(variant.replaceAll(a, b));
          if (variant.contains(b)) next.add(variant.replaceAll(b, a));
          if (next.length > 32) break;
        }
        if (next.length > 32) break;
      }
      next.remove(q);
      current = next;
      if (current.isEmpty) break;
    }
    return next.where((e) => e.length <= 14).toList();
  }

  List<Candidate> englishSuggestions(String raw, AppState state, {int limit = 6}) {
    final q = raw.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final scores = <String, int>{};
    for (final word in englishWords) {
      if (!word.startsWith(q)) continue;
      var score = 100 - (word.length - q.length) * 2;
      if (word == q) score += 20;
      score += state.freqOf(word) * 10;
      if ((scores[word] ?? -100) < score) scores[word] = score;
    }
    for (final word in state.fixedWords.values) {
      if (word.toLowerCase().startsWith(q)) scores[word] = 300;
    }
    final list = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(limit).map((e) => Candidate(e.key, e.value)).toList();
  }

  List<Candidate> _ranked(Map<String, int> scores, Set<String> phraseFlags, int limit) {
    final list = scores.entries
        .map((e) => Candidate(e.key, e.value, phrase: phraseFlags.contains(e.key)))
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byLength = a.text.length.compareTo(b.text.length);
        if (byLength != 0) return byLength;
        return a.text.compareTo(b.text);
      });
    return list.take(limit).toList();
  }

  // ------------------------------------------------------------ handwriting

  /// Lightweight template recognizer: each stroke is reduced to one of the
  /// five basic stroke types, then matched against the shared stroke table as
  /// an exact or prefix code. It covers common characters only and is labelled
  /// as such in About and Settings.
  List<Candidate> recognizeStrokes(List<List<Offset>> strokes, AppState state,
      {int limit = 24}) {
    if (strokes.isEmpty) return const [];
    final code = StringBuffer();
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      code.write(_strokeType(stroke));
    }
    if (code.isEmpty) return const [];
    final exact = strokeCandidates(code.toString(), state, limit: limit);
    if (exact.isNotEmpty) return exact;
    return const [];
  }

  String _strokeType(List<Offset> points) {
    var dx = 0.0;
    var dy = 0.0;
    var turns = 0;
    double? lastAngle;
    for (var i = 1; i < points.length; i++) {
      final delta = points[i] - points[i - 1];
      if (delta.distance < 2) continue;
      dx += delta.dx;
      dy += delta.dy;
      final angle = math.atan2(delta.dy, delta.dx);
      if (lastAngle != null && (angle - lastAngle).abs() > 1.1) turns++;
      lastAngle = angle;
    }
    if (turns >= 2) return 'z';
    if (dx.abs() < 6 && dy.abs() < 6) return 'n';
    if (dx.abs() > dy.abs() * 1.6) return dx > 0 ? 'h' : 'p';
    if (dy.abs() > dx.abs() * 1.6) return dy > 0 ? 's' : 'n';
    if (dy > 0) return dx < 0 ? 'p' : 'n';
    return 'h';
  }

  List<String> get kaomoji => const [
        '(＾▽＾)', '(￣▽￣)', '(｡•́︿•̀｡)', 'ʕ•ᴥ•ʔ', '(ง •̀_•́)ง',
        '(づ｡◕‿‿◕｡)づ', '( ˘ ³˘)♥', '¯\\_(ツ)_/¯', '(•̀ᴗ•́)و',
        '(๑•̀ㅂ•́)و✧', '(*≧ω≦)', '(￣ー￣)', '(╯°□°）╯︵ ┻━┻',
        '┬─┬ノ( º _ ºノ)', '(๑>؂<๑）', 'ヽ(￣ω￣(￣ω￣〃)ゝ',
      ];

  static const List<String> punctuation = [
    '，', '。', '？', '！', '、', '；', '：', '“', '”', '‘', '’',
    '（', '）', '《', '》', '…', '—', '～', '·', '￥', '@', '#', '%',
    '&', '*', '+', '=', '/', '\\', '|', '<', '>', '[', ']', '{', '}',
  ];

  static List<String> get numbers => const [
        '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
        '-', '+', '×', '÷', '=', '%', ',', '.', '(', ')', ':',
      ];
}
