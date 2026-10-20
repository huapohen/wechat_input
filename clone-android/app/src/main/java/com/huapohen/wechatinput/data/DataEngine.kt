package com.huapohen.wechatinput.data

import android.content.Context
import com.huapohen.wechatinput.Prefs
import org.json.JSONArray
import org.json.JSONObject

/**
 * Local dictionary and candidate engine. All proprietary Tencent assets are
 * absent: this uses the clean, factual tables from the study workspace plus
 * our own ranking and user learning.
 */
object DataEngine {
    data class Entry(
        val code: String,
        val text: String,
        val phrase: Boolean,
        val order: Int,
        val fuzzy: Boolean = false
    )

    data class Phrase(val text: String, val code: String)

    class SearchIndex(private val entries: List<Entry>) {
        fun prefix(q: String, cap: Int = 120): List<Entry> {
            if (q.isEmpty()) return emptyList()
            var lo = 0
            var hi = entries.size
            while (lo < hi) {
                val mid = (lo + hi) ushr 1
                if (entries[mid].code < q) lo = mid + 1 else hi = mid
            }
            val out = ArrayList<Entry>(minOf(cap, 40))
            var i = lo
            while (i < entries.size && out.size < cap) {
                val e = entries[i]
                if (!e.code.startsWith(q)) break
                out.add(e)
                i++
            }
            return out
        }
    }

    @Volatile private var loaded = false
    @Volatile private var basicLoaded = false
    private val lock = Any()

    private var pinyinIndex: SearchIndex? = null
    private var pinyinT9Index: SearchIndex? = null
    private var doublePinIndex: SearchIndex? = null
    private var wubiIndex: SearchIndex? = null
    private var strokeIndex: SearchIndex? = null
    private var englishWords: List<String> = emptyList()

    var emojiCategories: List<Pair<String, List<String>>> = emptyList()
        private set
    var assetPhrases: List<Phrase> = emptyList()
        private set

    private val commonRank: Map<String, Int> by lazy {
        val order = "的一是了我不人在他有这上们来到时大地为子中你说生国年着就那和要她出也得里后自以会家可下而过天去能对小多然于心学么之都好看起发当没成只如事把还用第样道想作种开美总从无情己面最女但现前些所同日手又行意动方期它头经长儿回位分爱老因很给名法间斯知世什两次使身者被高已亲其进此话常与活正感尼"
        val map = HashMap<String, Int>(order.length)
        order.forEachIndexed { i, c -> if (!map.containsKey(c.toString())) map[c.toString()] = i }
        map
    }

    private var freq: MutableMap<String, Int> = HashMap()
    private var fixed: MutableSet<String> = HashSet()
    private var deleted: MutableSet<String> = HashSet()
    private var freqDirty = false

    data class FuzzyOption(val id: String, val label: String, val a: String, val b: String)
    val fuzzyOptions = listOf(
        FuzzyOption("zhz", "zh ↔ z", "zh", "z"),
        FuzzyOption("chc", "ch ↔ c", "ch", "c"),
        FuzzyOption("shs", "sh ↔ s", "sh", "s"),
        FuzzyOption("nl", "n ↔ l", "n", "l"),
        FuzzyOption("rl", "r ↔ l", "r", "l"),
        FuzzyOption("anang", "an ↔ ang", "an", "ang"),
        FuzzyOption("eneng", "en ↔ eng", "en", "eng"),
        FuzzyOption("ining", "in ↔ ing", "in", "ing"),
        FuzzyOption("ianiang", "ian ↔ iang", "ian", "iang"),
        FuzzyOption("uanuang", "uan ↔ uang", "uan", "uang"),
        FuzzyOption("unong", "un ↔ ong", "un", "ong"),
        FuzzyOption("ongeng", "ong ↔ eng", "ong", "eng"),
        FuzzyOption("aiei", "ai ↔ ei", "ai", "ei"),
        FuzzyOption("uv", "u ↔ ü", "u", "v")
    )

    /** Emoji + bundled phrase list only: cheap, used by the app pages. */
    fun ensureBasic(context: Context): Boolean {
        if (basicLoaded) return true
        synchronized(lock) {
            if (basicLoaded) return true
            loadBasic(context.applicationContext)
            basicLoaded = true
        }
        return true
    }

    private fun loadBasic(app: Context) {
        try {
            val arr = JSONArray(read(app, "emoji.json"))
            emojiCategories = (0 until arr.length()).map { i ->
                val o = arr.optJSONObject(i)
                val cat = o?.optString("category") ?: "表情"
                val items = o?.optJSONArray("items") ?: JSONArray()
                cat to (0 until items.length()).map { items.optString(it) }
            }
        } catch (_: Exception) {
        }
        try {
            val arr = JSONArray(read(app, "phrases.json"))
            assetPhrases = (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                Phrase(o.optString("text"), o.optString("code"))
            }
        } catch (_: Exception) {
        }
    }

    fun ensureLoaded(context: Context): Boolean {
        if (loaded) return true
        synchronized(lock) {
            if (loaded) return true
            val app = context.applicationContext
            val charEntries = ArrayList<Entry>(27000)
            val phraseEntries = ArrayList<Entry>(47000)
            val t9Entries = ArrayList<Entry>(74000)
            val dpEntries = ArrayList<Entry>(27000)
            try {
                val chars = JSONObject(read(app, "pinyin_chars.json"))
                val keys = chars.keys()
                var i = 0
                while (keys.hasNext()) {
                    val ch = keys.next()
                    val py = chars.optString(ch)
                    if (py.isBlank() || ch.isBlank()) continue
                    charEntries.add(Entry(py, ch, false, i))
                    t9Entries.add(Entry(toT9(py), ch, false, i))
                    dpEntries.add(Entry(encodeDoublePin(py), ch, false, i))
                    i++
                }
            } catch (_: Exception) {
            }
            try {
                val ph = JSONObject(read(app, "pinyin_phrases.json"))
                val keys = ph.keys()
                var i = 0
                while (keys.hasNext()) {
                    val text = keys.next()
                    val arr = ph.optJSONArray(text) ?: continue
                    val sb = StringBuilder()
                    for (j in 0 until arr.length()) sb.append(arr.optString(j))
                    val code = sb.toString()
                    if (code.isBlank()) continue
                    phraseEntries.add(Entry(code, text, true, i))
                    t9Entries.add(Entry(toT9(code), text, true, i))
                    i++
                }
            } catch (_: Exception) {
            }
            pinyinIndex = SearchIndex(charEntries.sortedWith(cmp) + phraseEntries.sortedWith(cmp))
            pinyinT9Index = SearchIndex(t9Entries.sortedWith(cmp))
            doublePinIndex = SearchIndex(dpEntries.sortedWith(cmp))

            try {
                val wubi = JSONObject(read(app, "wubi86.json"))
                val out = ArrayList<Entry>(30000)
                val keys = wubi.keys()
                var i = 0
                while (keys.hasNext()) {
                    val code = keys.next()
                    val arr = wubi.optJSONArray(code) ?: continue
                    for (j in 0 until arr.length()) {
                        out.add(Entry(code, arr.optString(j), false, i++))
                    }
                }
                wubiIndex = SearchIndex(out.sortedWith(cmp))
            } catch (_: Exception) {
            }
            try {
                val stroke = JSONObject(read(app, "stroke_codes.json"))
                val out = ArrayList<Entry>(6000)
                val keys = stroke.keys()
                var i = 0
                while (keys.hasNext()) {
                    val code = keys.next()
                    val arr = stroke.optJSONArray(code) ?: continue
                    for (j in 0 until arr.length()) {
                        out.add(Entry(code, arr.optString(j), false, i++))
                    }
                }
                strokeIndex = SearchIndex(out.sortedWith(cmp))
            } catch (_: Exception) {
            }
            try {
                val arr = JSONArray(read(app, "english_words.json"))
                englishWords = (0 until arr.length()).map { arr.optString(it) }.filter { it.isNotBlank() }
            } catch (_: Exception) {
            }
            if (!basicLoaded) {
                loadBasic(app)
                basicLoaded = true
            }
            freq = Prefs.userFreq()
            fixed = Prefs.fixedWords()
            deleted = Prefs.deletedWords()
            loaded = true
        }
        return true
    }

    private val cmp = compareBy<Entry>({ it.code }, { if (it.phrase) 0 else 1 }, { it.order })

    private fun read(context: Context, name: String): String =
        context.assets.open("data/$name").bufferedReader().use { it.readText() }

    fun toT9(code: String): String {
        val sb = StringBuilder(code.length)
        for (c in code) {
            sb.append(
                when (c) {
                    in 'a'..'c' -> '2'
                    in 'd'..'f' -> '3'
                    in 'g'..'i' -> '4'
                    in 'j'..'l' -> '5'
                    in 'm'..'o' -> '6'
                    in 'p'..'s' -> '7'
                    in 't'..'v' -> '8'
                    in 'w'..'z' -> '9'
                    else -> c
                }
            )
        }
        return sb.toString()
    }

    private val initialMap: Map<String, String> by lazy {
        try {
            val root = JSONObject(read(com.huapohen.wechatinput.App.instance, "double_pinyin.json"))
            val o = root.optJSONObject("xiaobe") ?: root.optJSONObject("ziranma")
            val initials = o?.optJSONObject("initials") ?: JSONObject()
            val finals = o?.optJSONObject("finals") ?: JSONObject()
            val out = HashMap<String, String>()
            initials.keys().forEach { k -> out["i:$k"] = initials.optString(k) }
            finals.keys().forEach { k -> out["f:$k"] = finals.optString(k) }
            out
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun encodeDoublePin(syllable: String): String {
        if (syllable.isEmpty()) return syllable
        val initial = when {
            syllable.startsWith("zh") -> "zh"
            syllable.startsWith("ch") -> "ch"
            syllable.startsWith("sh") -> "sh"
            syllable[0] in "bpmfdtnlgkhjqxrzcsyw" -> syllable[0].toString()
            else -> ""
        }
        val final = syllable.substring(initial.length)
        val i = initialMap["i:$initial"] ?: initial
        val f = initialMap["f:$final"] ?: final
        return i + f
    }

    fun candidates(mode: String, raw: String, limit: Int = 9): List<String> {
        if (raw.isBlank()) return emptyList()
        return when (mode) {
            "t9" -> t9Candidates(raw, limit)
            "qwerty", "pinyin" -> pinyinCandidates(raw.lowercase(), limit)
            "doublepin" -> prefix(doublePinIndex, raw.lowercase(), limit)
            "wubi" -> prefix(wubiIndex, raw.lowercase(), limit)
            "stroke" -> prefix(strokeIndex, raw.lowercase(), limit)
            "english" -> englishCandidates(raw, limit)
            else -> emptyList()
        }
    }

    private fun prefix(index: SearchIndex?, q: String, limit: Int, fuzzy: Boolean = false): List<String> {
        if (index == null || q.isBlank()) return emptyList()
        return rank(index.prefix(q, 160), q, fuzzy).take(limit)
    }

    private fun pinyinCandidates(q: String, limit: Int): List<String> {
        val index = pinyinIndex ?: return emptyList()
        val found = ArrayList<Entry>()
        found.addAll(index.prefix(q, 200))
        if (Prefs.fuzzyEnabled) {
            fuzzyVariants(q).forEach { v ->
                if (v == q) return@forEach
                index.prefix(v, 30).forEach { e ->
                    if (found.none { it.text == e.text }) found.add(e.copy(fuzzy = true))
                }
            }
        }
        return rank(found, q, false).take(limit)
    }

    private fun t9Candidates(qRaw: String, limit: Int): List<String> {
        val q = qRaw.filter { it in '0'..'9' }
        val index = pinyinT9Index ?: return emptyList()
        return rank(index.prefix(q, 260), q, false).take(limit)
    }

    private fun rank(list: List<Entry>, query: String, forceFuzzy: Boolean): List<String> {
        if (list.isEmpty()) return emptyList()
        val scored = ArrayList<Pair<Entry, Int>>(list.size)
        val seen = HashSet<String>()
        for (e in list) {
            if (!seen.add(e.text)) continue
            if (e.text in deleted) continue
            var score = 0
            if (e.code == query) score += if (e.phrase) 260 else 820
            if (e.phrase) score += 500
            if (!e.phrase) score += (240 - (commonRank[e.text] ?: 240)).coerceAtLeast(0)
            if (e.fuzzy || forceFuzzy) score -= 180
            if (e.text in fixed) score += 100_000
            score += (freq[e.text] ?: 0) * 90
            score += (60 - minOf(60, e.order / 40))
            scored.add(e to score)
        }
        return scored.sortedWith(
            compareByDescending<Pair<Entry, Int>> { it.second }
                .thenBy { if (it.first.phrase) 1 else 0 }
                .thenBy { it.first.order }
        ).map { it.first.text }
    }

    private fun englishCandidates(raw: String, limit: Int): List<String> {
        val q = raw.lowercase()
        val out = LinkedHashSet<String>()
        if (raw.isNotBlank()) out.add(raw)
        englishWords.asSequence().filter { it.startsWith(q) }.take(limit * 2).forEach { out.add(it) }
        return out.take(limit).toList()
    }

    private fun fuzzyVariants(q: String): List<String> {
        val pairs = Prefs.fuzzyPairs
        val out = LinkedHashSet<String>()
        out.add(q)
        fuzzyOptions.forEach { opt ->
            if (opt.id in pairs) {
                if (q.contains(opt.a)) out.add(q.replace(opt.a, opt.b))
                if (q.contains(opt.b)) out.add(q.replace(opt.b, opt.a))
            }
        }
        val base = out.toList()
        base.forEach { b ->
            fuzzyOptions.forEach { opt ->
                if (opt.id in pairs && b.contains(opt.a) && out.size < 40) out.add(b.replace(opt.a, opt.b))
            }
        }
        return out.take(40).toList()
    }

    fun learn(text: String) {
        if (text.isBlank()) return
        synchronized(lock) {
            freq[text] = (freq[text] ?: 0) + 1
            freqDirty = true
            if (freq.size > 2500) {
                val keep = freq.entries.sortedByDescending { it.value }.take(2000)
                freq = keep.associate { it.key to it.value }.toMutableMap()
            }
        }
        Prefs.saveUserFreq(freq)
    }

    fun fix(text: String) {
        synchronized(lock) {
            fixed.add(text)
            deleted.remove(text)
            Prefs.saveFixedWords(fixed)
            Prefs.saveDeletedWords(deleted)
        }
    }

    fun delete(text: String) {
        synchronized(lock) {
            deleted.add(text)
            fixed.remove(text)
            Prefs.saveDeletedWords(deleted)
            Prefs.saveFixedWords(fixed)
        }
    }

    fun isFixed(text: String): Boolean = text in fixed
    fun isDeleted(text: String): Boolean = text in deleted
    fun frequency(text: String): Int = freq[text] ?: 0

    fun reloadLearning() {
        synchronized(lock) {
            freq = Prefs.userFreq()
            fixed = Prefs.fixedWords()
            deleted = Prefs.deletedWords()
        }
    }

    /** Handwriting: map 8-direction chain to stroke letters and match public tables. */
    fun handwritingCandidates(directions: String, limit: Int = 9): List<String> {
        if (directions.isBlank()) return emptyList()
        val mapped = buildString {
            for (d in directions) {
                append(
                    when (d) {
                        'e', 'w' -> 'h'
                        's' -> 's'
                        'a' -> 'p'
                        'd' -> 'n'
                        else -> 'z'
                    }
                )
            }
        }
        val templates = mapOf(
            "e" to "一", "ee" to "二", "eee" to "三", "es" to "十",
            "se" to "上", "sw" to "人", "esw" to "大", "ws" to "小",
            "esws" to "口", "ssz" to "中", "sz" to "日", "sze" to "目",
            "eswsz" to "木", "sww" to "火", "nz" to "心"
        )
        val out = LinkedHashSet<String>()
        templates.entries.firstOrNull { directions.startsWith(it.key) }?.let { out.add(it.value) }
        strokeIndex?.prefix(mapped.take(6), 80)?.forEach { e -> out.add(e.text) }
        if (out.isEmpty()) {
            templates.entries.firstOrNull { it.key.startsWith(directions) }?.let { out.add(it.value) }
        }
        return out.take(limit).toList()
    }

    /** Public test hook used by the in-app keyboard preview. */
    fun isLoaded(): Boolean = loaded
}
