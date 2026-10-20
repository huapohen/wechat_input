package com.huapohen.wechatinput.ime

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.view.MotionEvent
import android.view.View
import androidx.core.content.ContextCompat
import com.huapohen.wechatinput.R
import com.huapohen.wechatinput.Ui
import kotlin.math.atan2
import kotlin.math.hypot

/** Basic ink canvas. Recognition is deliberately local and limited. */
class HandWriteView(context: Context) : View(context) {
    var onDirections: ((String) -> Unit)? = null
    var onInkChanged: (() -> Unit)? = null

    private val strokes = ArrayList<ArrayList<Pair<Float, Float>>>()
    private var current = ArrayList<Pair<Float, Float>>()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = ContextCompat.getColor(context, R.color.text_primary)
        style = Paint.Style.STROKE
        strokeWidth = Ui.dp(context, 5f).toFloat()
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val guide = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = ContextCompat.getColor(context, R.color.border)
        style = Paint.Style.STROKE
        strokeWidth = 1f
    }
    private val path = Path()

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width == 0 || height == 0) return
        canvas.drawLine(width / 2f, 0f, width / 2f, height.toFloat(), guide)
        canvas.drawLine(0f, height / 2f, width.toFloat(), height / 2f, guide)
        canvas.drawRect(
            Ui.dp(context, 18f).toFloat(), Ui.dp(context, 8f).toFloat(),
            (width - Ui.dp(context, 18f)).toFloat(), (height - Ui.dp(context, 8f)).toFloat(), guide
        )
        strokes.forEach { stroke -> drawStroke(canvas, stroke) }
        if (current.size > 1) drawStroke(canvas, current)
    }

    private fun drawStroke(canvas: Canvas, pts: List<Pair<Float, Float>>) {
        if (pts.size < 2) {
            if (pts.size == 1) canvas.drawCircle(pts[0].first, pts[0].second, paint.strokeWidth / 2f, paint)
            return
        }
        path.reset()
        path.moveTo(pts[0].first, pts[0].second)
        for (i in 1 until pts.size) path.lineTo(pts[i].first, pts[i].second)
        canvas.drawPath(path, paint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                current = ArrayList()
                current.add(event.x to event.y)
                onInkChanged?.invoke()
                invalidate()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                current.add(event.x to event.y)
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (current.size >= 1) {
                    strokes.add(ArrayList(current))
                    if (current.size == 1) {
                        current.add(event.x + 1f to event.y + 1f)
                    }
                    onDirections?.invoke(directions(current))
                }
                current = ArrayList()
                invalidate()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun directions(points: List<Pair<Float, Float>>): String {
        if (points.size < 2) return ""
        val resampled = ArrayList<Pair<Float, Float>>()
        var last = points[0]
        resampled.add(last)
        for (p in points.drop(1)) {
            if (hypot((p.first - last.first).toDouble(), (p.second - last.second).toDouble()) > 14.0) {
                resampled.add(p)
                last = p
            }
        }
        if (resampled.size < 2) return ""
        val sb = StringBuilder()
        for (i in 1 until resampled.size) {
            val dx = resampled[i].first - resampled[i - 1].first
            val dy = resampled[i].second - resampled[i - 1].second
            if (hypot(dx.toDouble(), dy.toDouble()) < 8.0) continue
            val angle = Math.toDegrees(atan2(dy.toDouble(), dx.toDouble()))
            val dir = when {
                angle >= -22.5 && angle < 22.5 -> 'e'
                angle >= 22.5 && angle < 67.5 -> 'd'
                angle >= 67.5 && angle < 112.5 -> 's'
                angle >= 112.5 && angle < 157.5 -> 'a'
                angle >= 157.5 || angle < -157.5 -> 'w'
                angle >= -157.5 && angle < -112.5 -> 'w'
                angle >= -112.5 && angle < -67.5 -> 'w'
                angle >= -67.5 && angle < -22.5 -> 'q'
                else -> 'z'
            }
            if (sb.isEmpty() || sb.last() != dir) sb.append(dir)
        }
        return sb.toString()
    }

    fun clearInk() {
        strokes.clear()
        current = ArrayList()
        invalidate()
    }
}
