package com.huapohen.wechatinput

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import com.google.android.material.materialswitch.MaterialSwitch

object Ui {
    fun dp(context: Context, value: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, context.resources.displayMetrics).toInt()

    fun color(context: Context, id: Int): Int = ContextCompat.getColor(context, id)

    // Overloads so view builders can be called inside apply { } blocks without
    // accidentally passing the receiver (a View) where a Context is expected.
    fun dp(host: View, value: Float): Int = dp(host.context, value)
    fun color(host: View, id: Int): Int = color(host.context, id)

    fun text(
        host: View,
        value: CharSequence,
        sizeSp: Float = 15f,
        colorInt: Int = color(host.context, R.color.text_primary),
        bold: Boolean = false
    ): TextView = text(host.context, value, sizeSp, colorInt, bold)

    fun vertical(host: View, pad: Int = 0): LinearLayout = vertical(host.context, pad)
    fun horizontal(host: View, pad: Int = 0): LinearLayout = horizontal(host.context, pad)

    fun card(host: View, paddingDp: Int = 16): CardLayout = card(host.context, paddingDp)

    fun sectionTitle(host: View, title: String, trailing: String? = null): LinearLayout =
        sectionTitle(host.context, title, trailing)

    fun group(host: View): LinearLayout = group(host.context)

    fun row(
        host: View,
        title: String,
        subtitle: String? = null,
        trailing: String? = null,
        showChevron: Boolean = true,
        onClick: (() -> Unit)? = null
    ): LinearLayout = row(host.context, title, subtitle, trailing, showChevron, onClick)

    fun toggleRow(
        host: View,
        title: String,
        subtitle: String? = null,
        checked: Boolean,
        onChange: (Boolean) -> Unit
    ): LinearLayout = toggleRow(host.context, title, subtitle, checked, onChange)

    fun button(host: View, label: String, primary: Boolean = true, onClick: () -> Unit): MaterialButton =
        button(host.context, label, primary, onClick)

    fun pill(host: View, label: String, accent: Boolean = true): TextView = pill(host.context, label, accent)

    fun editText(host: View, hint: String, multiline: Boolean = false): EditText =
        editText(host.context, hint, multiline)

    fun statusChip(host: View, ok: Boolean, label: String): TextView = statusChip(host.context, ok, label)

    fun settingsGrid(host: View, columns: Int, items: List<View>, gapDp: Int = 12): android.widget.GridLayout =
        settingsGrid(host.context, columns, items, gapDp)

    fun text(
        context: Context,
        value: CharSequence,
        sizeSp: Float = 15f,
        colorInt: Int = color(context, R.color.text_primary),
        bold: Boolean = false
    ): TextView = TextView(context).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(colorInt)
        if (bold) typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
        includeFontPadding = false
    }

    fun vertical(context: Context, pad: Int = 0): LinearLayout = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(pad, pad, pad, pad)
    }

    fun horizontal(context: Context, pad: Int = 0): LinearLayout = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(pad, pad, pad, pad)
    }

    fun rounded(fill: Int, radiusDp: Float, stroke: Int? = null, strokeDp: Float = 1f): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(fill)
            cornerRadius = radiusDp * 3f
            if (stroke != null) setStroke(strokeDp.toInt().coerceAtLeast(1), stroke)
        }

    fun card(context: Context, paddingDp: Int = 16): CardLayout = CardLayout(context).apply {
        setPadding(
            dp(context, paddingDp.toFloat()), dp(context, paddingDp.toFloat()),
            dp(context, paddingDp.toFloat()), dp(context, paddingDp.toFloat())
        )
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(context, 12f) }
    }

    fun sectionTitle(context: Context, title: String, trailing: String? = null): LinearLayout =
        horizontal(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(context, 18f); bottomMargin = dp(context, 8f) }
            setPadding(dp(context, 4f), 0, dp(context, 4f), 0)
            addView(text(context, title, 16f, color(context, R.color.text_primary), true),
                LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            if (trailing != null) addView(text(context, trailing, 12f, color(context, R.color.text_secondary)))
        }

    fun group(context: Context): LinearLayout = vertical(context).apply {
        background = rounded(color(context, R.color.surface), 18f, color(context, R.color.border))
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(context, 14f) }
    }

    fun divider(context: Context): View = View(context).apply {
        setBackgroundColor(color(context, R.color.border))
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(context, 0.7f).coerceAtLeast(1)).apply {
            marginStart = dp(context, 16f)
        }
    }

    fun row(
        context: Context,
        title: String,
        subtitle: String? = null,
        trailing: String? = null,
        showChevron: Boolean = true,
        onClick: (() -> Unit)? = null
    ): LinearLayout = horizontal(context).apply {
        minimumHeight = dp(context, 56f)
        setPadding(dp(context, 16f), dp(context, 10f), dp(context, 14f), dp(context, 10f))
        background = ContextCompat.getDrawable(context, R.drawable.bg_row)
        if (onClick != null) {
            isClickable = true
            isFocusable = true
            setOnClickListener { onClick() }
        }
        val col = vertical(context)
        col.addView(text(context, title, 15f, color(context, R.color.text_primary)))
        if (!subtitle.isNullOrBlank()) {
            col.addView(text(context, subtitle, 12f, color(context, R.color.text_secondary)).apply {
                setPadding(0, dp(context, 3f), 0, 0)
            })
        }
        addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        if (trailing != null) {
            addView(text(context, trailing, 13f, color(context, R.color.text_secondary)).apply {
                setPadding(dp(context, 8f), 0, dp(context, 6f), 0)
            })
        }
        if (showChevron) {
            addView(ImageView(context).apply {
                setImageResource(R.drawable.ic_chevron_right)
                layoutParams = LinearLayout.LayoutParams(dp(context, 20f), dp(context, 20f))
            })
        }
    }

    fun toggleRow(
        context: Context,
        title: String,
        subtitle: String? = null,
        checked: Boolean,
        onChange: (Boolean) -> Unit
    ): LinearLayout = horizontal(context).apply {
        minimumHeight = dp(context, 56f)
        setPadding(dp(context, 16f), dp(context, 9f), dp(context, 12f), dp(context, 9f))
        val col = vertical(context)
        col.addView(text(context, title, 15f))
        if (!subtitle.isNullOrBlank()) {
            col.addView(text(context, subtitle, 12f, color(context, R.color.text_secondary)).apply {
                setPadding(0, dp(context, 3f), 0, 0)
            })
        }
        addView(col, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        val sw = MaterialSwitch(context).apply {
            isChecked = checked
            thumbTintList = ColorStateList.valueOf(color(context, R.color.accent))
            setOnCheckedChangeListener { _, v -> onChange(v) }
        }
        addView(sw, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    }

    fun choiceRow(
        context: Context,
        title: String,
        options: Array<String>,
        current: Int,
        subtitle: String? = null,
        onPick: (Int) -> Unit
    ): LinearLayout {
        val row = row(context, title, subtitle, options.getOrElse(current) { "" }, true) { }
        val value = row.getChildAt(1) as TextView
        row.setOnClickListener {
            androidx.appcompat.app.AlertDialog.Builder(context)
                .setTitle(title)
                .setSingleChoiceItems(options, current) { dialog, which ->
                    value.text = options[which]
                    onPick(which)
                    dialog.dismiss()
                }
                .setNegativeButton("取消", null)
                .show()
        }
        return row
    }

    fun sliderRow(
        context: Context,
        title: String,
        summary: (Int) -> String,
        value: Int,
        min: Int,
        max: Int,
        step: Int = 1,
        onChange: (Int) -> Unit
    ): LinearLayout {
        val col = vertical(context).apply {
            setPadding(dp(context, 16f), dp(context, 12f), dp(context, 16f), dp(context, 10f))
        }
        val head = horizontal(context)
        val label = text(context, summary(value), 13f, color(context, R.color.text_secondary))
        head.addView(text(context, title, 15f), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        head.addView(label)
        col.addView(head)
        val seek = SeekBar(context).apply {
            this.max = (max - min) / step
            progress = ((value - min) / step).coerceIn(0, this.max)
            progressTintList = ColorStateList.valueOf(color(context, R.color.accent))
            thumbTintList = ColorStateList.valueOf(color(context, R.color.accent_dark))
        }
        seek.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val v = min + progress * step
                label.text = summary(v)
                if (fromUser) onChange(v)
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
        col.addView(seek, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(context, 34f)))
        return col
    }

    fun button(context: Context, label: String, primary: Boolean = true, onClick: () -> Unit): MaterialButton =
        MaterialButton(context).apply {
            text = label
            textSize = 14f
            isAllCaps = false
            cornerRadius = dp(context, 14f)
            if (primary) {
                setBackgroundTintList(ColorStateList.valueOf(color(context, R.color.accent)))
                setTextColor(Color.WHITE)
            } else {
                setBackgroundTintList(ColorStateList.valueOf(color(context, R.color.surface)))
                setTextColor(color(context, R.color.text_primary))
                strokeWidth = dp(context, 1f)
                strokeColor = ColorStateList.valueOf(color(context, R.color.border))
            }
            setOnClickListener { onClick() }
        }

    fun pill(context: Context, label: String, accent: Boolean = true): TextView = text(
        context, label, 12f,
        if (accent) color(context, R.color.accent_dark) else color(context, R.color.text_secondary)
    ).apply {
        background = rounded(
            if (accent) color(context, R.color.accent_soft) else color(context, R.color.surface_alt),
            99f
        )
        setPadding(dp(context, 10f), dp(context, 5f), dp(context, 10f), dp(context, 5f))
        isSingleLine = true
    }

    fun editText(context: Context, hint: String, multiline: Boolean = false): EditText = EditText(context).apply {
        this.hint = hint
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        setTextColor(color(context, R.color.text_primary))
        setHintTextColor(color(context, R.color.muted))
        background = rounded(color(context, R.color.surface), 14f, color(context, R.color.border))
        setPadding(dp(context, 14f), dp(context, 12f), dp(context, 14f), dp(context, 12f))
        if (multiline) {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            minLines = 4
            gravity = Gravity.TOP or Gravity.START
        }
    }

    fun spacer(context: Context, h: Float = 12f): View = View(context).apply {
        layoutParams = LinearLayout.LayoutParams(1, dp(context, h))
    }

    fun statusChip(context: Context, ok: Boolean, label: String): TextView = text(
        context, label, 12f,
        if (ok) color(context, R.color.accent_dark) else color(context, R.color.warning)
    ).apply {
        background = rounded(
            if (ok) color(context, R.color.accent_soft) else 0xFFFFF3E0.toInt(),
            99f
        )
        setPadding(dp(context, 10f), dp(context, 5f), dp(context, 10f), dp(context, 5f))
    }

    fun scrollable(context: Context, child: View): ScrollView = ScrollView(context).apply {
        isFillViewport = true
        addView(child, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    }

    fun maxWidth(container: LinearLayout, context: Context, maxDp: Int = 1180) {
        container.layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        )
        val max = dp(context, maxDp.toFloat())
        container.addOnLayoutChangeListener { v, l, t, r, b, ol, ot, or_, ob ->
            if (r - l > max) {
                v.layoutParams = LinearLayout.LayoutParams(max, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                }
            }
        }
    }

    fun grid(context: Context, columns: Int, gapDp: Int = 12): LinearLayout = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        for (i in 0 until columns) {
            val col = vertical(context)
            col.tag = "gridcol$i"
            // each row is added horizontally below
            if (i == 0) {
                // placeholder; real grid built by GridLayout
            }
        }
        // Actually use GridLayout for robust equal-width cells.
    }

    class CardLayout(context: Context) : LinearLayout(context) {
        private var fill = Ui.color(context, R.color.surface)
        var strokeColor: Int = Ui.color(context, R.color.border)
            set(value) {
                field = value
                refresh()
            }
        private var corner = 20f

        init {
            orientation = VERTICAL
            refresh()
        }

        fun setFillColor(colorInt: Int) {
            fill = colorInt
            refresh()
        }

        fun setCardBackgroundColor(colorInt: Int) = setFillColor(colorInt)

        private fun refresh() {
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(fill)
                cornerRadius = Ui.dp(context, corner).toFloat()
                setStroke(Ui.dp(context, 1f).coerceAtLeast(1), strokeColor)
            }
        }
    }

    fun settingsGrid(context: Context, columns: Int, items: List<View>, gapDp: Int = 12): android.widget.GridLayout {
        val grid = android.widget.GridLayout(context)
        grid.columnCount = columns
        items.forEachIndexed { index, view ->
            val lp = android.widget.GridLayout.LayoutParams().apply {
                columnSpec = android.widget.GridLayout.spec(index % columns, 1f)
                rowSpec = android.widget.GridLayout.spec(index / columns, 1f)
                width = 0
                height = ViewGroup.LayoutParams.WRAP_CONTENT
                setMargins(gapDp / 2, gapDp / 2, gapDp / 2, gapDp / 2)
            }
            grid.addView(view, lp)
        }
        return grid
    }
}
