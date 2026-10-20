package com.huapohen.wechatinput.net

import android.content.Context
import com.huapohen.wechatinput.Prefs
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.atomic.AtomicBoolean

class ApiException(message: String, val status: Int = 0) : Exception(message)

object ApiClient {
    private const val CONNECT_TIMEOUT = 15_000
    private const val READ_TIMEOUT = 120_000
    @Volatile private var activeChat: HttpURLConnection? = null

    fun cancelChat() {
        try {
            activeChat?.disconnect()
        } catch (_: Exception) {
        }
        activeChat = null
    }

    private fun base(): String {
        if (Prefs.standalone) throw ApiException("单机模式已开启，网络请求已禁用", 0)
        return Prefs.baseUrl.trimEnd('/')
    }

    fun health(): JSONObject = get("/health")

    fun get(path: String, timeoutMs: Int = READ_TIMEOUT): JSONObject {
        val conn = open(path, "GET", timeoutMs)
        return try {
            val code = conn.responseCode
            val body = readBody(conn, code)
            if (code !in 200..299) throw ApiException(extractError(body, code), code)
            JSONObject(body)
        } finally {
            conn.disconnect()
        }
    }

    fun postJson(path: String, payload: JSONObject, timeoutMs: Int = READ_TIMEOUT): JSONObject {
        val conn = open(path, "POST", timeoutMs)
        conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
        conn.doOutput = true
        return try {
            conn.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            val body = readBody(conn, code)
            if (code !in 200..299) throw ApiException(extractError(body, code), code)
            JSONObject(body)
        } finally {
            conn.disconnect()
        }
    }

    private fun open(path: String, method: String, timeoutMs: Int): HttpURLConnection {
        val url = URL(base() + path)
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = method
        conn.connectTimeout = CONNECT_TIMEOUT
        conn.readTimeout = timeoutMs
        conn.setRequestProperty("Accept", "application/json, text/event-stream")
        return conn
    }

    private fun readBody(conn: HttpURLConnection, code: Int): String {
        val stream: InputStream = if (code in 200..299) conn.inputStream else (conn.errorStream ?: conn.inputStream)
        return stream.bufferedReader().use { it.readText() }
    }

    private fun extractError(body: String, code: Int): String {
        return try {
            val o = JSONObject(body)
            o.optString("detail").ifBlank { o.optString("error") }.ifBlank { "HTTP $code" }
        } catch (_: Exception) {
            if (body.isBlank()) "HTTP $code" else body.take(240)
        }
    }

    fun chat(
        messages: List<Pair<String, String>>,
        onDelta: (String) -> Unit,
        onDone: () -> Unit,
        onError: (String) -> Unit,
        cancelled: AtomicBoolean
    ) {
        val payload = JSONObject().apply {
            put("stream", true)
            put("temperature", 0.6)
            put("max_tokens", 1200)
            put("messages", JSONArray().apply {
                messages.forEach { (role, content) ->
                    put(JSONObject().put("role", role).put("content", content))
                }
            })
        }
        var conn: HttpURLConnection? = null
        try {
            conn = open("/v1/ai/chat", "POST", 180_000)
            activeChat = conn
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.setRequestProperty("Accept", "text/event-stream")
            conn.doOutput = true
            conn.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            if (code !in 200..299) {
                val err = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                onError(extractError(err, code))
                return
            }
            val reader = conn.inputStream.bufferedReader(Charsets.UTF_8)
            var event = "message"
            var done = false
            reader.use { r ->
                while (!cancelled.get() && !done) {
                    val line = r.readLine() ?: break
                    when {
                        line.startsWith("event:") -> event = line.substring(6).trim()
                        line.startsWith("data:") -> {
                            val data = line.substring(5).trim()
                            if (event == "error") {
                                val msg = try {
                                    JSONObject(data).optString("error")
                                } catch (_: Exception) {
                                    data
                                }
                                onError(msg.ifBlank { "生成失败" })
                                done = true
                            } else if (event == "done" || data == "[DONE]") {
                                done = true
                            } else {
                                try {
                                    val o = JSONObject(data)
                                    val text = o.optString("text")
                                    if (text.isNotEmpty()) onDelta(text)
                                } catch (_: Exception) {
                                }
                            }
                        }
                    }
                }
            }
            if (cancelled.get()) onError("已停止生成") else if (!done) onDone() else onDone()
        } catch (e: Exception) {
            if (cancelled.get()) onError("已停止生成") else onError(friendly(e))
        } finally {
            activeChat = null
            conn?.disconnect()
        }
    }

    fun polish(text: String): String =
        postJson("/v1/ai/polish", JSONObject().put("text", text)).optString("text")

    fun rewrite(text: String, style: String, count: Int = 3): List<String> {
        val o = postJson(
            "/v1/ai/rewrite",
            JSONObject().put("text", text).put("style", style).put("count", count)
        )
        val arr = o.optJSONArray("candidates") ?: JSONArray()
        return (0 until arr.length()).map { arr.optString(it) }.filter { it.isNotBlank() }
    }

    fun translate(text: String, source: String = "auto", target: String = "zh"): String =
        postJson(
            "/v1/ai/translate",
            JSONObject().put("text", text).put("source", source).put("target", target)
        ).optString("text")

    fun summary(text: String): JSONObject =
        postJson("/v1/ai/summary", JSONObject().put("text", text))

    // --- Sync -------------------------------------------------------------
    fun pair(code: String, name: String): JSONObject =
        postJson("/v1/sync/pair", JSONObject().put("code", code).put("name", name), 20_000)

    fun syncClipboard(token: String, items: List<JSONObject>, timeoutMs: Int = 20_000): JSONObject =
        postJson(
            "/v1/sync/clipboard",
            JSONObject().put("token", token).put("items", JSONArray(items)),
            timeoutMs
        )

    fun listClipboard(token: String): JSONObject =
        get("/v1/sync/clipboard?token=" + URLEncoder.encode(token, "UTF-8"), 20_000)

    fun syncPhrases(token: String, items: List<JSONObject>): JSONObject =
        postJson(
            "/v1/sync/phrases",
            JSONObject().put("token", token).put("items", JSONArray(items)),
            20_000
        )

    fun getSettings(token: String): JSONObject =
        get("/v1/sync/settings?token=" + URLEncoder.encode(token, "UTF-8"), 20_000)

    fun putSettings(token: String, payload: JSONObject): JSONObject =
        postJson(
            "/v1/sync/settings",
            JSONObject().put("token", token).put("payload", payload),
            20_000
        )

    // --- Transfer ---------------------------------------------------------
    fun transferList(token: String = ""): JSONArray {
        val suffix = if (token.isBlank()) "" else "?token=" + URLEncoder.encode(token, "UTF-8")
        return get("/v1/transfer/list$suffix", 20_000).optJSONArray("items") ?: JSONArray()
    }

    fun upload(
        context: Context,
        displayName: String,
        mime: String,
        input: InputStream,
        token: String = "",
        onProgress: (Long) -> Unit = {}
    ): JSONObject {
        val boundary = "----WeTypeClone" + System.currentTimeMillis()
        val suffix = if (token.isBlank()) "" else "?token=" + URLEncoder.encode(token, "UTF-8")
        val conn = open("/v1/transfer/upload$suffix", "POST", 180_000)
        conn.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
        conn.doOutput = true
        try {
            val out = conn.outputStream.buffered()
            val safeName = displayName.replace("\"", "_")
            val head = "--$boundary\r\n" +
                    "Content-Disposition: form-data; name=\"file\"; filename=\"$safeName\"\r\n" +
                    "Content-Type: ${mime.ifBlank { "application/octet-stream" }}\r\n\r\n"
            out.write(head.toByteArray(Charsets.UTF_8))
            var total = 0L
            val buf = ByteArray(64 * 1024)
            input.use { ins ->
                while (true) {
                    val n = ins.read(buf)
                    if (n < 0) break
                    out.write(buf, 0, n)
                    total += n
                    onProgress(total)
                    if (total > 50L * 1024 * 1024) throw ApiException("文件超过 50 MB 上限")
                }
            }
            out.write("\r\n--$boundary--\r\n".toByteArray(Charsets.UTF_8))
            out.flush()
            val code = conn.responseCode
            val body = readBody(conn, code)
            if (code !in 200..299) throw ApiException(extractError(body, code), code)
            return JSONObject(body)
        } finally {
            conn.disconnect()
        }
    }

    fun download(id: String, target: File, onProgress: (Long) -> Unit = {}): File {
        val conn = open("/v1/transfer/" + URLEncoder.encode(id, "UTF-8"), "GET", 180_000)
        try {
            val code = conn.responseCode
            if (code !in 200..299) throw ApiException("下载失败 HTTP $code", code)
            target.parentFile?.mkdirs()
            var total = 0L
            BufferedInputStream(conn.inputStream).use { ins ->
                FileOutputStream(target).use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = ins.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        total += n
                        onProgress(total)
                    }
                }
            }
            return target
        } finally {
            conn.disconnect()
        }
    }

    fun friendly(e: Throwable): String = when (e) {
        is ApiException -> e.message ?: "请求失败"
        is java.net.ConnectException -> "无法连接后端（${Prefs.baseUrl}）。请确认服务已启动。"
        is java.net.SocketTimeoutException -> "请求超时，请重试"
        is java.net.UnknownHostException -> "无法解析主机地址"
        else -> e.message?.take(240) ?: e.javaClass.simpleName
    }
}
