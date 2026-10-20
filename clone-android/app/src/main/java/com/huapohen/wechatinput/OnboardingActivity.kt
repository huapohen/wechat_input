package com.huapohen.wechatinput

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.material.button.MaterialButton

class OnboardingActivity : BasePageActivity() {
    private lateinit var status: android.widget.TextView
    private lateinit var consent: CheckBox

    override fun onCreatePage() {
        setPageTitle("启用与隐私", "三步开始使用；所有输入在本机完成候选计算")

        val hero = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(0xFF24C891.toInt(), 0xFF0E8A68.toInt())
            ).apply { cornerRadius = Ui.dp(this@OnboardingActivity, 24f).toFloat() }
            setPadding(Ui.dp(this@OnboardingActivity, 20f), Ui.dp(this@OnboardingActivity, 20f), Ui.dp(this@OnboardingActivity, 20f), Ui.dp(this@OnboardingActivity, 18f))
        }
        hero.addView(Ui.text(this, "欢迎使用", 13f, 0xFFE6FFF7.toInt()))
        hero.addView(Ui.text(this, "微输入法", 30f, Color.WHITE, true).apply {
            setPadding(0, Ui.dp(this@OnboardingActivity, 2f), 0, 0)
        })
        hero.addView(Ui.text(this, "简洁、好用、打字快 · 一台设备，六种中文键盘", 13f, 0xFFE6FFF7.toInt()).apply {
            setPadding(0, Ui.dp(this@OnboardingActivity, 6f), 0, Ui.dp(this@OnboardingActivity, 12f))
        })
        hero.addView(Ui.text(this, "本地候选计算  ·  真实系统 IME  ·  AI 可选", 12f, Color.WHITE, true))
        content.addView(hero, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            bottomMargin = Ui.dp(this@OnboardingActivity, 4f)
        })

        content.addView(Ui.sectionTitle(this, "键盘状态"))
        val statusCard = Ui.card(this, 16)
        val row = Ui.horizontal(this)
        row.addView(Ui.text(this, "⌨", 22f, Ui.color(this, R.color.accent_dark), true).apply {
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(Ui.dp(this, 46f), Ui.dp(this, 46f)))
        val col = Ui.vertical(this)
        status = Ui.text(this, "检查中…", 16f, Ui.color(this, R.color.text_primary), true)
        col.addView(status)
        col.addView(Ui.text(this, "需在系统设置中启用并选择微输入法", 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@OnboardingActivity, 3f), 0, 0)
        })
        row.addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        statusCard.addView(row)
        content.addView(statusCard)

        val buttons = Ui.horizontal(this)
        buttons.addView(Ui.button(this, "① 启用输入法", true) {
            ImeHelper.openEnableSettings(this)
            Toast.makeText(this, "找到“微输入法”并打开开关，然后返回", Toast.LENGTH_LONG).show()
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = Ui.dp(this@OnboardingActivity, 8f) })
        buttons.addView(Ui.button(this, "② 选择输入法", false) {
            if (ImeHelper.enabled(this)) ImeHelper.showPicker(this)
            else {
                toast("请先在系统设置中启用微输入法")
                ImeHelper.openEnableSettings(this)
            }
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        content.addView(buttons)

        content.addView(Ui.sectionTitle(this, "数据与隐私"))
        val privacy = Ui.group(this)
        listOf(
            "本地候选引擎" to "拼音、五笔、笔画、双拼词表随应用安装，候选计算不联网。",
            "AI 与语音" to "仅在您主动使用时，将当前文本/转写发送到您配置的后端；密钥只在服务端。",
            "剪贴板" to "默认只保存您主动读取或复用过的剪贴板文本，可随时清空。",
            "麦克风" to "用于语音输入与录音笔；拒绝后仍可使用键盘输入。"
        ).forEachIndexed { index, pair ->
            privacy.addView(Ui.row(this, pair.first, pair.second, null, false))
            if (index < 3) privacy.addView(Ui.divider(this))
        }
        content.addView(privacy)

        val permCard = Ui.card(this, 16)
        permCard.addView(Ui.text(this, "可选权限", 15f, Ui.color(this, R.color.text_primary), true))
        permCard.addView(Ui.text(this, "麦克风权限用于语音转文字；可稍后在“隐私与权限”中开启。", 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(0, Ui.dp(this@OnboardingActivity, 4f), 0, Ui.dp(this@OnboardingActivity, 10f))
        })
        permCard.addView(Ui.button(this, "授予麦克风权限", false) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 41)
        })
        content.addView(permCard)

        consent = CheckBox(this).apply {
            text = "我已阅读并同意：这是独立研究复刻，不隶属于腾讯；不包含其资源或密钥。"
            setTextColor(Ui.color(this@OnboardingActivity, R.color.text_primary))
            textSize = 13f
            buttonTintList = android.content.res.ColorStateList.valueOf(Ui.color(this@OnboardingActivity, R.color.accent))
            isChecked = Prefs.onboarded
        }
        content.addView(consent, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@OnboardingActivity, 4f)
        })

        val start = Ui.button(this, "进入微输入法", true) {
            if (!consent.isChecked) {
                toast("请先勾选确认项")
                return@button
            }
            Prefs.onboarded = true
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP))
            finish()
        }
        content.addView(start, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@OnboardingActivity, 10f)
        })

        val test = Ui.button(this, "跳过，先体验键盘", false) {
            startActivity(Intent(this, KeyboardTestActivity::class.java))
        }
        content.addView(test, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = Ui.dp(this@OnboardingActivity, 8f)
        })

        val footnote = Ui.text(
            this,
            "微输入法 1.0 · 独立互操作复刻\n不使用腾讯的二进制资源、字体、图标或模型密钥。",
            11f, Ui.color(this, R.color.text_secondary)
        ).apply { gravity = Gravity.CENTER; setPadding(0, Ui.dp(this@OnboardingActivity, 16f), 0, 0) }
        content.addView(footnote)
    }

    override fun onResume() {
        super.onResume()
        if (!::status.isInitialized) return
        val enabled = ImeHelper.enabled(this)
        val selected = ImeHelper.selected(this)
        status.text = when {
            selected -> "● 微输入法已启用并选中"
            enabled -> "● 已启用，尚未选中"
            else -> "● 尚未启用"
        }
        status.setTextColor(
            if (enabled) ContextCompat.getColor(this, R.color.accent_dark)
            else ContextCompat.getColor(this, R.color.warning)
        )
    }

    private fun toast(msg: String) = Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()

    override fun currentPageId(): String = "onboarding"
}
