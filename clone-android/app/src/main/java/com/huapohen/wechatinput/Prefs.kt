package com.huapohen.wechatinput

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Central persisted settings. The IME service and the app share this file. */
object Prefs {
    private const val FILE = "wetype_settings"
    private lateinit var sp: SharedPreferences

    fun init(context: Context) {
        if (!::sp.isInitialized) {
            sp = context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        }
    }

    fun raw(): SharedPreferences = sp

    fun bool(key: String, def: Boolean = false) = sp.getBoolean(key, def)
    fun put(key: String, value: Boolean) = sp.edit().putBoolean(key, value).apply()
    fun int(key: String, def: Int = 0) = sp.getInt(key, def)
    fun put(key: String, value: Int) = sp.edit().putInt(key, value).apply()
    fun long(key: String, def: Long = 0L) = sp.getLong(key, def)
    fun put(key: String, value: Long) = sp.edit().putLong(key, value).apply()
    fun str(key: String, def: String = "") = sp.getString(key, def) ?: def
    fun put(key: String, value: String) = sp.edit().putString(key, value).apply()
    fun strSet(key: String, def: Set<String> = emptySet()): Set<String> =
        sp.getStringSet(key, def)?.toSet() ?: def
    fun putStrSet(key: String, value: Set<String>) = sp.edit().putStringSet(key, value).apply()

    // --- General -----------------------------------------------------------
    var onboarded: Boolean
        get() = bool("onboarded", false)
        set(v) = put("onboarded", v)

    var baseUrl: String
        get() = str("base_url", "http://10.0.2.2:8787").trimEnd('/')
        set(v) = put("base_url", v.trim().trimEnd('/'))

    var standalone: Boolean
        get() = bool("standalone", false)
        set(v) = put("standalone", v)

    var displayName: String
        get() = str("display_name", "我的设备")
        set(v) = put("display_name", v)

    // --- Keyboard ---------------------------------------------------------
    var keyboardMode: String
        get() = str("keyboard_mode", "t9")
        set(v) = put("keyboard_mode", v)

    var keyboardHeightFactor: Int
        get() = int("keyboard_height", 100)
        set(v) = put("keyboard_height", v.coerceIn(80, 150))

    var displayTheme: Int
        get() = int("display_theme", 0)
        set(v) = put("display_theme", v)

    var candidateSize: Int
        get() = int("candidate_size", 22)
        set(v) = put("candidate_size", v.coerceIn(16, 30))

    var candidateCount: Int
        get() = int("candidate_count", 9)
        set(v) = put("candidate_count", v.coerceIn(5, 15))

    var keySound: Boolean
        get() = bool("key_sound", true)
        set(v) = put("key_sound", v)

    var keyVibrate: Boolean
        get() = bool("key_vibrate", true)
        set(v) = put("key_vibrate", v)

    var keyBubble: Boolean
        get() = bool("key_bubble", true)
        set(v) = put("key_bubble", v)

    var vibrateLevel: Int
        get() = int("vibrate_level", 1)
        set(v) = put("vibrate_level", v)

    var splitKeyboard: Boolean
        get() = bool("split_keyboard", false)
        set(v) = put("split_keyboard", v)

    var showKeyBorders: Boolean
        get() = bool("key_borders", true)
        set(v) = put("key_borders", v)

    var enterToSend: Boolean
        get() = bool("enter_send", false)
        set(v) = put("enter_send", v)

    var autoSpace: Boolean
        get() = bool("auto_space", true)
        set(v) = put("auto_space", v)

    var doubleSpacePeriod: Boolean
        get() = bool("double_space_period", false)
        set(v) = put("double_space_period", v)

    var smartCapitalize: Boolean
        get() = bool("smart_capitalize", true)
        set(v) = put("smart_capitalize", v)

    var autoPunctuation: Boolean
        get() = bool("auto_punctuation", true)
        set(v) = put("auto_punctuation", v)

    var directPreInput: Boolean
        get() = bool("direct_preinput", false)
        set(v) = put("direct_preinput", false)

    var fuzzyEnabled: Boolean
        get() = bool("fuzzy_enabled", true)
        set(v) = put("fuzzy_enabled", v)

    var fuzzyPairs: Set<String>
        get() = strSet("fuzzy_pairs", setOf("zhz", "chc", "shs", "nl", "rl", "anang", "eneng", "ining"))
        set(v) = putStrSet("fuzzy_pairs", v)

    var toolbarOrder: String
        get() = str("toolbar_order", "switch,voice,clipboard,phrases,emoji,handwrite,ai,translate,polish,settings")
        set(v) = put("toolbar_order", v)

    var emojiQuick: Boolean
        get() = bool("emoji_quick", false)
        set(v) = put("emoji_quick", v)

    var clipboardSuggestions: Boolean
        get() = bool("clipboard_suggestions", true)
        set(v) = put("clipboard_suggestions", v)

    // --- Voice ------------------------------------------------------------
    var voiceLongPress: Boolean
        get() = bool("voice_longpress", true)
        set(v) = put("voice_longpress", v)

    var voiceReleaseSend: Boolean
        get() = bool("voice_release_send", true)
        set(v) = put("voice_release_send", v)

    var voiceSmartPolish: Boolean
        get() = bool("voice_polish", false)
        set(v) = put("voice_polish", v)

    var voiceOffline: Boolean
        get() = bool("voice_offline", false)
        set(v) = put("voice_offline", false)

    var voiceLanguage: String
        get() = str("voice_language", "zh-CN")
        set(v) = put("voice_language", v)

    var voiceLanguageLabel: String
        get() = str("voice_language_label", "普通话")
        set(v) = put("voice_language_label", v)

    var voicePunctuation: Boolean
        get() = bool("voice_punctuation", true)
        set(v) = put("voice_punctuation", true)

    var voicePunctuationStyle: Int
        get() = int("voice_punct_style", 0)
        set(v) = put("voice_punct_style", v)

    // --- Plus -------------------------------------------------------------
    var plusEnabled: Boolean
        get() = bool("plus_enabled", true)
        set(v) = put("plus_enabled", v)

    var plusAskAi: Boolean
        get() = bool("plus_ask_ai", true)
        set(v) = put("plus_ask_ai", v)

    var plusSmartSpelling: Boolean
        get() = bool("plus_smart_spelling", true)
        set(v) = put("plus_smart_spelling", v)

    var plusSpellingCorrect: Boolean
        get() = bool("plus_spelling_correct", true)
        set(v) = put("plus_spelling_correct", v)

    var plusSticker: Boolean
        get() = bool("plus_sticker", true)
        set(v) = put("plus_sticker", v)

    var plusSmallEmoji: Boolean
        get() = bool("plus_small_emoji", true)
        set(v) = put("plus_small_emoji", v)

    var plusKaomoji: Boolean
        get() = bool("plus_kaomoji", true)
        set(v) = put("plus_kaomoji", true)

    var plusRewrite: Boolean
        get() = bool("plus_rewrite", true)
        set(v) = put("plus_rewrite", v)

    var plusPolish: Boolean
        get() = bool("plus_polish", true)
        set(v) = put("plus_polish", true)

    var plusPoster: Boolean
        get() = bool("plus_poster", true)
        set(v) = put("plus_poster", true)

    var plusQuickSend: Boolean
        get() = bool("plus_quick_send", false)
        set(v) = put("plus_quick_send", false)

    // --- Clipboard / sync -------------------------------------------------
    var clipboardEnabled: Boolean
        get() = bool("clipboard_enabled", true)
        set(v) = put("clipboard_enabled", v)

    var statusBarClipboard: Boolean
        get() = bool("statusbar_clipboard", false)
        set(v) = put("statusbar_clipboard", v)

    var syncToken: String
        get() = str("sync_token", "")
        set(v) = put("sync_token", v)

    var syncCode: String
        get() = str("sync_code", "")
        set(v) = put("sync_code", v)

    var syncClipboard: Boolean
        get() = bool("sync_clipboard", true)
        set(v) = put("sync_clipboard", v)

    var syncPhrases: Boolean
        get() = bool("sync_phrases", true)
        set(v) = put("sync_phrases", v)

    var syncSettings: Boolean
        get() = bool("sync_settings", false)
        set(v) = put("sync_settings", v)

    val desktopCode: String
        get() = sp.getString("desktop_code", null) ?: (100000 + (UUID.randomUUID().mostSignificantBits and 0x7fffffff) % 900000)
            .toString().also { put("desktop_code", it) }

    // --- Data -------------------------------------------------------------
    fun userFreq(): MutableMap<String, Int> {
        val map = HashMap<String, Int>()
        try {
            val obj = JSONObject(str("user_freq", "{}"))
            obj.keys().forEach { k -> map[k] = obj.optInt(k, 0) }
        } catch (_: Exception) {
        }
        return map
    }

    fun saveUserFreq(map: Map<String, Int>) {
        val obj = JSONObject()
        map.entries.sortedByDescending { it.value }.take(2000).forEach { obj.put(it.key, it.value) }
        put("user_freq", obj.toString())
    }

    fun fixedWords(): MutableSet<String> {
        val out = HashSet<String>()
        try {
            val arr = JSONArray(str("fixed_words", "[]"))
            for (i in 0 until arr.length()) out.add(arr.getString(i))
        } catch (_: Exception) {
        }
        return out
    }

    fun saveFixedWords(words: Set<String>) {
        put("fixed_words", JSONArray(words.toList()).toString())
    }

    fun deletedWords(): MutableSet<String> {
        val out = HashSet<String>()
        try {
            val arr = JSONArray(str("deleted_words", "[]"))
            for (i in 0 until arr.length()) out.add(arr.getString(i))
        } catch (_: Exception) {
        }
        return out
    }

    fun saveDeletedWords(words: Set<String>) {
        put("deleted_words", JSONArray(words.toList()).toString())
    }

    fun clearLearning() {
        put("user_freq", "{}")
        put("fixed_words", "[]")
        put("deleted_words", "[]")
    }

    fun resetAll() {
        sp.edit().clear().apply()
    }

    fun hasToken() = syncToken.isNotBlank()
}
