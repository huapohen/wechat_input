package com.huapohen.wechatinput.store

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import com.huapohen.wechatinput.Prefs
import org.json.JSONArray
import org.json.JSONObject

object ClipboardStore {
    data class Item(val text: String, val time: Long, val pinned: Boolean)

    fun items(): List<Item> {
        val out = ArrayList<Item>()
        try {
            val arr = JSONArray(Prefs.str("clipboard_history", "[]"))
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val text = o.optString("text")
                if (text.isBlank()) continue
                out.add(Item(text, o.optLong("time"), o.optBoolean("pinned")))
            }
        } catch (_: Exception) {
        }
        return out.sortedWith(compareByDescending<Item> { it.pinned }.thenByDescending { it.time })
    }

    fun save(list: List<Item>) {
        val arr = JSONArray()
        list.take(60).forEach {
            arr.put(JSONObject().put("text", it.text).put("time", it.time).put("pinned", it.pinned))
        }
        Prefs.put("clipboard_history", arr.toString())
    }

    fun add(text: String): Boolean {
        if (text.isBlank()) return false
        val list = items().toMutableList()
        val existing = list.firstOrNull { it.text == text }
        if (existing != null) {
            list.remove(existing)
            list.add(existing.copy(time = System.currentTimeMillis()))
        } else {
            list.add(Item(text.take(20000), System.currentTimeMillis(), false))
        }
        save(list)
        return true
    }

    fun togglePin(item: Item) {
        save(items().map { if (it.text == item.text) it.copy(pinned = !it.pinned) else it })
    }

    fun remove(item: Item) {
        save(items().filterNot { it.text == item.text })
    }

    fun clear() = save(emptyList())

    fun copy(context: Context, text: String) {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        add(text)
    }

    fun current(context: Context): String {
        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = cm.primaryClip ?: return ""
        if (clip.itemCount == 0) return ""
        return clip.getItemAt(0).coerceToText(context).toString()
    }
}
