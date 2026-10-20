package com.huapohen.wechatinput

import android.content.res.Configuration
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

abstract class BasePageActivity : AppCompatActivity() {
    protected lateinit var contentFrame: FrameLayout
    protected lateinit var content: LinearLayout
    protected lateinit var scroll: ScrollView
    protected lateinit var titleView: TextView
    protected lateinit var subtitleView: TextView
    protected lateinit var headerAction: TextView
    protected lateinit var backButton: ImageButton
    protected lateinit var pageColumn: LinearLayout

    protected val isTablet: Boolean
        get() = resources.configuration.smallestScreenWidthDp >= 600 ||
                resources.configuration.screenWidthDp >= 600

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_page)
        contentFrame = findViewById(R.id.contentFrame)
        titleView = findViewById(R.id.pageTitle)
        subtitleView = findViewById(R.id.pageSubtitle)
        headerAction = findViewById(R.id.headerAction)
        backButton = findViewById(R.id.backButton)
        pageColumn = findViewById(R.id.pageColumn)
        backButton.setOnClickListener { finish() }

        content = Ui.vertical(this)
        content.setPadding(
            Ui.dp(this, 18f), Ui.dp(this, 4f), Ui.dp(this, 18f), Ui.dp(this, 28f)
        )
        scroll = ScrollView(this).apply {
            isFillViewport = true
            clipToPadding = false
            addView(content, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        contentFrame.addView(scroll, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        ))

        if (isTablet) buildRail()
        onCreatePage()
    }

    protected open fun onCreatePage() {}

    protected fun setPageTitle(title: String, subtitle: String? = null) {
        titleView.text = title
        if (!subtitle.isNullOrBlank()) {
            subtitleView.text = subtitle
            subtitleView.visibility = View.VISIBLE
        } else {
            subtitleView.visibility = View.GONE
        }
    }

    protected fun setHeaderAction(label: String, action: () -> Unit) {
        headerAction.text = label
        headerAction.visibility = View.VISIBLE
        headerAction.setOnClickListener { action() }
    }

    /** Replaces the scrolling content with a custom view. */
    protected fun setCustomContent(view: View) {
        contentFrame.removeAllViews()
        contentFrame.addView(view, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        ))
    }

    protected fun addCard(card: View) {
        content.addView(card)
    }

    protected open fun buttonRow(vararg views: View) {
        val row = Ui.horizontal(this)
        views.forEachIndexed { i, v ->
            row.addView(v, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                if (i < views.size - 1) marginEnd = Ui.dp(this@BasePageActivity, 8f)
            })
        }
        content.addView(row, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = Ui.dp(this@BasePageActivity, 10f) })
    }

    private fun buildRail() {
        val railScroll = findViewById<ScrollView>(R.id.railScroll)
        val rail = findViewById<LinearLayout>(R.id.railContainer)
        railScroll.visibility = View.VISIBLE
        rail.addView(Ui.text(this, "微输入法", 20f, Ui.color(this, R.color.text_primary), true).apply {
            setPadding(Ui.dp(this@BasePageActivity, 10f), 0, 0, Ui.dp(this@BasePageActivity, 2f))
        })
        rail.addView(Ui.text(this, "设置中心", 12f, Ui.color(this, R.color.text_secondary)).apply {
            setPadding(Ui.dp(this@BasePageActivity, 10f), 0, 0, Ui.dp(this@BasePageActivity, 14f))
        })
        val currentId = currentPageId()
        Pages.settings.forEach { page ->
            val row = Ui.horizontal(this).apply {
                minimumHeight = Ui.dp(this@BasePageActivity, 40f)
                setPadding(Ui.dp(this@BasePageActivity, 10f), 0, Ui.dp(this@BasePageActivity, 8f), 0)
                background = Ui.rounded(
                    if (page.id == currentId) Ui.color(this@BasePageActivity, R.color.accent_soft)
                    else 0x00000000,
                    12f
                )
                addView(Ui.text(
                    this@BasePageActivity, page.title, 14f,
                    if (page.id == currentId) Ui.color(this@BasePageActivity, R.color.accent_dark)
                    else Ui.color(this@BasePageActivity, R.color.text_secondary),
                    page.id == currentId
                ), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
                isClickable = true
                setOnClickListener {
                    if (page.id != currentId) {
                        startActivity(Pages.intent(this@BasePageActivity, page.id))
                        finish()
                    }
                }
            }
            rail.addView(row, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = Ui.dp(this@BasePageActivity, 2f) })
        }
        rail.addView(Ui.spacer(this, 10f))
        val home = Ui.text(this, "← 返回首页", 14f, Ui.color(this, R.color.accent_dark), true).apply {
            setPadding(Ui.dp(this@BasePageActivity, 10f), Ui.dp(this@BasePageActivity, 12f), 0, 0)
            isClickable = true
            setOnClickListener {
                startActivity(Pages.intent(this@BasePageActivity, "home"))
                finish()
            }
        }
        rail.addView(home)
    }

    protected open fun currentPageId(): String = ""
}
