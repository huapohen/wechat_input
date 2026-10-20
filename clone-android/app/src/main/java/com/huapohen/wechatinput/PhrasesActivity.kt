package com.huapohen.wechatinput

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.Toast
import com.huapohen.wechatinput.store.ClipboardStore
import com.huapohen.wechatinput.store.PhraseStore

class PhrasesActivity : BasePageActivity() {
    private var query = ""
    private var editing: PhraseStore.Phrase? = null

    override fun onCreatePage() {
        com.huapohen.wechatinput.data.DataEngine.ensureBasic(this)
        setPageTitle("常用语", "本机保存 · 键盘工具栏可直接调用")
        setHeaderAction("全部") { query = ""; render() }
        render()
    }

    private fun render() {
        content.removeAllViews()
        addInfo(
            "常用语会出现在这里和键盘工具栏",
            "带拼音编码的常用语会在拼音候选中排序靠前；自定义项可以编辑或删除，内置项只读。"
        )
        val form = Ui.card(this, 14)
        val input = Ui.editText(this, "输入常用语，例如：收到，谢谢").apply {
            setText(editing?.text ?: "")
            setSingleLine(true)
        }
        form.addView(input, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 48f)))
        val code = Ui.editText(this, "拼音编码（可选），例如：shoudaoxiexie").apply {
            setText(editing?.code ?: "")
            setSingleLine(true)
        }
        form.addView(code, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this@PhrasesActivity, 48f)).apply {
            topMargin = Ui.dp(this@PhrasesActivity, 8f)
        })
        val buttons = Ui.horizontal(this).apply { setPadding(0, Ui.dp(this@PhrasesActivity, 8f), 0, 0) }
        buttons.addView(Ui.button(this, if (editing == null) "添加常用语" else "保存修改", true) {
            val text = input.text.toString().trim()
            if (text.isBlank()) {
                toast("请输入常用语")
                return@button
            }
            if (editing == null) {
                if (PhraseStore.add(text, code.text.toString().trim())) toast("已添加")
                else toast("该常用语已存在")
            } else {
                PhraseStore.update(editing!!.text, text, code.text.toString().trim())
                editing = null
                toast("已保存")
            }
            render()
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
            marginEnd = Ui.dp(this@PhrasesActivity, 8f)
        })
        if (editing != null) {
            buttons.addView(Ui.button(this, "取消编辑", false) {
                editing = null
                render()
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        } else {
            buttons.addView(Ui.button(this, "清空输入", false) {
                input.setText("")
                code.setText("")
            }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        }
        form.addView(buttons)
        content.addView(form)

        val search = Ui.editText(this, "搜索常用语").apply {
            setText(query)
            setSingleLine(true)
            addTextChangedListener(object : android.text.TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                    query = s?.toString() ?: ""
                }
                override fun afterTextChanged(s: android.text.Editable?) {
                    renderList(s?.toString() ?: "")
                }
            })
        }
        content.addView(search, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this@PhrasesActivity, 46f)).apply {
            bottomMargin = Ui.dp(this@PhrasesActivity, 8f)
        })

        val listHost = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(listHost)
        renderList(query, listHost)
    }

    private fun renderList(q: String, target: LinearLayout? = null) {
        val host = target ?: content.findViewWithTag<LinearLayout>("phraseList") ?: return
        host.tag = "phraseList"
        host.removeAllViews()
        val all = PhraseStore.all().filter {
            q.isBlank() || it.text.contains(q, true) || it.code.contains(q, true)
        }
        host.addView(Ui.sectionTitle(this, "全部常用语", "${all.size} 条"))
        if (all.isEmpty()) {
            val card = Ui.card(this, 16)
            card.addView(Ui.text(this, "没有匹配的常用语", 14f, Ui.color(this, R.color.text_secondary)))
            host.addView(card)
            return
        }
        val group = Ui.group(this)
        all.forEachIndexed { index, phrase ->
            val row = Ui.horizontal(this).apply {
                minimumHeight = Ui.dp(this@PhrasesActivity, 52f)
                setPadding(Ui.dp(this@PhrasesActivity, 14f), Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f))
                isClickable = true
                setOnClickListener {
                    copy(phrase.text)
                }
            }
            val col = Ui.vertical(this)
            col.addView(Ui.text(this, phrase.text, 15f, Ui.color(this, R.color.text_primary)))
            col.addView(Ui.text(
                this, (if (phrase.custom) "自定义" else "内置") + if (phrase.code.isNotBlank()) " · ${phrase.code}" else "",
                11f, Ui.color(this, R.color.text_secondary)
            ).apply { setPadding(0, Ui.dp(this@PhrasesActivity, 2f), 0, 0) })
            row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            if (phrase.custom) {
                row.addView(Ui.text(this, "编辑", 12f, Ui.color(this, R.color.accent_dark), true).apply {
                    setPadding(Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f))
                    setOnClickListener {
                        editing = phrase
                        render()
                    }
                })
                row.addView(Ui.text(this, "删除", 12f, Ui.color(this, R.color.danger), true).apply {
                    setPadding(Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f))
                    setOnClickListener {
                        PhraseStore.remove(phrase.text)
                        toast("已删除")
                        render()
                    }
                })
            } else {
                row.addView(Ui.text(this, "复制", 12f, Ui.color(this, R.color.accent_dark), true).apply {
                    setPadding(Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f), Ui.dp(this@PhrasesActivity, 8f))
                })
            }
            group.addView(row)
            if (index < all.size - 1) group.addView(Ui.divider(this))
        }
        host.addView(group)
    }

    private fun copy(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("微输入法", text))
        ClipboardStore.add(text)
        toast("已复制：$text")
    }

    private fun addInfo(title: String, body: String) {
        val card = Ui.card(this, 16)
        card.addView(Ui.text(this, title, 15f, Ui.color(this, R.color.text_primary), true))
        card.addView(Ui.text(this, body, 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@PhrasesActivity, 5f), 0, 0)
        })
        content.addView(card)
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
}
