package com.huapohen.wechatinput.store

import com.huapohen.wechatinput.Prefs
import org.json.JSONArray
import org.json.JSONObject

object ChatStore {
    data class Message(val role: String, val content: String)

    fun load(): MutableList<Message> {
        val out = ArrayList<Message>()
        try {
            val arr = JSONArray(Prefs.str("chat_history", "[]"))
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val role = o.optString("role")
                val content = o.optString("content")
                if (role.isNotBlank() && content.isNotBlank()) out.add(Message(role, content))
            }
        } catch (_: Exception) {
        }
        return out
    }

    fun save(list: List<Message>) {
        val arr = JSONArray()
        list.takeLast(80).forEach { arr.put(JSONObject().put("role", it.role).put("content", it.content)) }
        Prefs.put("chat_history", arr.toString())
    }

    fun clear() = Prefs.put("chat_history", "[]")
}
