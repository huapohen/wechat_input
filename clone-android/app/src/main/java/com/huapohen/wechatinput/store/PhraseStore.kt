package com.huapohen.wechatinput.store

import com.huapohen.wechatinput.Prefs
import com.huapohen.wechatinput.data.DataEngine
import org.json.JSONArray
import org.json.JSONObject

object PhraseStore {
    data class Phrase(val text: String, val code: String, val custom: Boolean)

    fun custom(): MutableList<Phrase> {
        val out = ArrayList<Phrase>()
        try {
            val arr = JSONArray(Prefs.str("custom_phrases", "[]"))
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val t = o.optString("text")
                if (t.isNotBlank()) out.add(Phrase(t, o.optString("code"), true))
            }
        } catch (_: Exception) {
        }
        return out
    }

    fun saveCustom(list: List<Phrase>) {
        val arr = JSONArray()
        list.filter { it.custom }.forEach {
            arr.put(JSONObject().put("text", it.text).put("code", it.code))
        }
        Prefs.put("custom_phrases", arr.toString())
    }

    fun all(): List<Phrase> {
        val out = ArrayList<Phrase>()
        DataEngine.assetPhrases.forEach { out.add(Phrase(it.text, it.code, false)) }
        out.addAll(custom())
        return out
    }

    fun add(text: String, code: String = ""): Boolean {
        if (text.isBlank()) return false
        val list = custom()
        if (list.any { it.text == text } || DataEngine.assetPhrases.any { it.text == text }) return false
        list.add(0, Phrase(text.trim(), code.trim(), true))
        saveCustom(list)
        return true
    }

    fun update(oldText: String, text: String, code: String) {
        val list = custom()
        val idx = list.indexOfFirst { it.text == oldText }
        if (idx >= 0) {
            list[idx] = Phrase(text.trim(), code.trim(), true)
            saveCustom(list)
        }
    }

    fun remove(text: String) {
        saveCustom(custom().filterNot { it.text == text })
    }
}
