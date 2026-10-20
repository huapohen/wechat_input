package com.huapohen.wechatinput.store

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

object SessionStore {
    data class Session(
        val id: String,
        val title: String,
        val created: Long,
        val durationMs: Long,
        val transcript: String,
        val summary: String = "",
        val bullets: List<String> = emptyList()
    )

    private fun file(context: Context) = File(context.filesDir, "recorder_sessions.json")

    fun all(context: Context): MutableList<Session> {
        val out = ArrayList<Session>()
        try {
            val f = file(context)
            if (!f.exists()) return out
            val arr = JSONArray(f.readText())
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val bullets = ArrayList<String>()
                val ba = o.optJSONArray("bullets") ?: JSONArray()
                for (j in 0 until ba.length()) bullets.add(ba.optString(j))
                out.add(
                    Session(
                        o.optString("id"),
                        o.optString("title"),
                        o.optLong("created"),
                        o.optLong("duration"),
                        o.optString("transcript"),
                        o.optString("summary"),
                        bullets
                    )
                )
            }
        } catch (_: Exception) {
        }
        return out.sortedByDescending { it.created }.toMutableList()
    }

    fun save(context: Context, list: List<Session>) {
        val arr = JSONArray()
        list.forEach { s ->
            arr.put(
                JSONObject()
                    .put("id", s.id).put("title", s.title).put("created", s.created)
                    .put("duration", s.durationMs).put("transcript", s.transcript)
                    .put("summary", s.summary).put("bullets", JSONArray(s.bullets))
            )
        }
        file(context).writeText(arr.toString())
    }

    fun upsert(context: Context, session: Session) {
        val list = all(context)
        val idx = list.indexOfFirst { it.id == session.id }
        if (idx >= 0) list[idx] = session else list.add(0, session)
        save(context, list)
    }

    fun get(context: Context, id: String): Session? = all(context).firstOrNull { it.id == id }

    fun delete(context: Context, id: String) {
        save(context, all(context).filterNot { it.id == id })
    }

    fun newId(): String = UUID.randomUUID().toString()
}
