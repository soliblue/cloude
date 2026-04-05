package com.cloude.app.UI.whiteboard

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import android.graphics.Paint
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

@Composable
fun WhiteboardCanvas(
    state: WhiteboardCanvasState,
    modifier: Modifier = Modifier
) {
    val vp = state.viewport

    Canvas(modifier = modifier.fillMaxSize()) {
        val cx = size.width / 2f
        val cy = size.height / 2f

        drawGrid(cx, cy, vp)

        val sorted = state.elements.sortedBy { it.z ?: 0 }
        sorted.forEach { el ->
            val alpha = (el.opacity ?: 1.0).toFloat()
            val fillColor = parseColor(el.fill)?.copy(alpha = alpha)
            val strokeColor = parseColor(el.stroke ?: "#FFFFFF")?.copy(alpha = alpha)
            val sw = (el.strokeWidth ?: 1.0).toFloat() * vp.zoom.toFloat()
            val pathEffect = strokePathEffect(el.strokeStyle, sw)
            val isSelected = el.id in state.selectedIds

            when (el.type) {
                "rect" -> drawRect(el, cx, cy, vp, fillColor, strokeColor, sw, pathEffect, isSelected)
                "ellipse" -> drawEllipse(el, cx, cy, vp, fillColor, strokeColor, sw, pathEffect, isSelected)
                "triangle" -> drawTriangle(el, cx, cy, vp, fillColor, strokeColor, sw, pathEffect, isSelected)
                "text" -> drawText(el, cx, cy, vp, fillColor, alpha)
                "path" -> drawPath(el, cx, cy, vp, strokeColor, sw, pathEffect)
                "arrow" -> drawArrow(el, cx, cy, vp, strokeColor, sw, sorted)
            }
        }
    }
}

private fun DrawScope.toScreen(x: Double, y: Double, cx: Float, cy: Float, vp: WhiteboardViewport): Offset {
    val z = vp.zoom.toFloat()
    return Offset(cx + ((x - 500 - vp.x) * z).toFloat(), cy + ((y - 500 - vp.y) * z).toFloat())
}

private fun DrawScope.drawGrid(cx: Float, cy: Float, vp: WhiteboardViewport) {
    val gridColor = Color.White.copy(alpha = 0.05f)
    val z = vp.zoom.toFloat()
    val step = 50.0
    for (i in 0..20) {
        val v = i * step
        val p1 = toScreen(v, 0.0, cx, cy, vp)
        val p2 = toScreen(v, 1000.0, cx, cy, vp)
        drawLine(gridColor, p1, p2, strokeWidth = 1f)
        val h1 = toScreen(0.0, v, cx, cy, vp)
        val h2 = toScreen(1000.0, v, cx, cy, vp)
        drawLine(gridColor, h1, h2, strokeWidth = 1f)
    }
}

private fun DrawScope.drawRect(
    el: WhiteboardElement, cx: Float, cy: Float, vp: WhiteboardViewport,
    fill: Color?, stroke: Color?, sw: Float, pe: PathEffect?, selected: Boolean
) {
    val z = vp.zoom.toFloat()
    val tl = toScreen(el.x, el.y, cx, cy, vp)
    val s = Size((el.w * z).toFloat(), (el.h * z).toFloat())
    val cr = CornerRadius(4f * z)
    fill?.let { drawRoundRect(it, tl, s, cr, style = Fill) }
    stroke?.let { drawRoundRect(it, tl, s, cr, style = Stroke(width = sw, pathEffect = pe)) }
    if (selected) drawRoundRect(Color(0xFFCC7257), tl, s, cr, style = Stroke(width = 2f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 4f))))
    el.label?.let { drawLabel(it, tl, s, el.fontSize, fill, z) }
}

private fun DrawScope.drawEllipse(
    el: WhiteboardElement, cx: Float, cy: Float, vp: WhiteboardViewport,
    fill: Color?, stroke: Color?, sw: Float, pe: PathEffect?, selected: Boolean
) {
    val z = vp.zoom.toFloat()
    val tl = toScreen(el.x, el.y, cx, cy, vp)
    val s = Size((el.w * z).toFloat(), (el.h * z).toFloat())
    val center = Offset(tl.x + s.width / 2, tl.y + s.height / 2)
    fill?.let { drawOval(it, tl, s, style = Fill) }
    stroke?.let { drawOval(it, tl, s, style = Stroke(width = sw, pathEffect = pe)) }
    if (selected) drawOval(Color(0xFFCC7257), tl, s, style = Stroke(width = 2f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 4f))))
    el.label?.let { drawLabel(it, tl, s, el.fontSize, fill, z) }
}

private fun DrawScope.drawTriangle(
    el: WhiteboardElement, cx: Float, cy: Float, vp: WhiteboardViewport,
    fill: Color?, stroke: Color?, sw: Float, pe: PathEffect?, selected: Boolean
) {
    val z = vp.zoom.toFloat()
    val tl = toScreen(el.x, el.y, cx, cy, vp)
    val w = (el.w * z).toFloat()
    val h = (el.h * z).toFloat()
    val path = Path().apply {
        moveTo(tl.x + w / 2, tl.y)
        lineTo(tl.x + w, tl.y + h)
        lineTo(tl.x, tl.y + h)
        close()
    }
    fill?.let { drawPath(path, it, style = Fill) }
    stroke?.let { drawPath(path, it, style = Stroke(width = sw, pathEffect = pe)) }
    if (selected) drawPath(path, Color(0xFFCC7257), style = Stroke(width = 2f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 4f))))
}

private fun DrawScope.drawText(
    el: WhiteboardElement, cx: Float, cy: Float, vp: WhiteboardViewport,
    fill: Color?, alpha: Float
) {
    val z = vp.zoom.toFloat()
    val tl = toScreen(el.x, el.y, cx, cy, vp)
    val text = el.label ?: return
    val fs = ((el.fontSize ?: 14.0) * z).toFloat()
    val paint = Paint().apply {
        color = android.graphics.Color.WHITE
        textSize = fs
        textAlign = Paint.Align.CENTER
        isAntiAlias = true
        this.alpha = (alpha * 255).toInt()
    }
    val centerX = tl.x + (el.w * z).toFloat() / 2
    val centerY = tl.y + (el.h * z).toFloat() / 2 + fs / 3
    drawContext.canvas.nativeCanvas.drawText(text, centerX, centerY, paint)
}

private fun DrawScope.drawPath(
    el: WhiteboardElement, cx: Float, cy: Float, vp: WhiteboardViewport,
    stroke: Color?, sw: Float, pe: PathEffect?
) {
    val pts = el.points ?: return
    if (pts.size < 2) return
    val path = Path()
    val first = toScreen(pts[0][0], pts[0][1], cx, cy, vp)
    path.moveTo(first.x, first.y)
    for (i in 1 until pts.size) {
        val p = toScreen(pts[i][0], pts[i][1], cx, cy, vp)
        path.lineTo(p.x, p.y)
    }
    if (el.closed == true) path.close()
    stroke?.let { drawPath(path, it, style = Stroke(width = sw, pathEffect = pe)) }
}

private fun DrawScope.drawArrow(
    el: WhiteboardElement, cx: Float, cy: Float, vp: WhiteboardViewport,
    stroke: Color?, sw: Float, elements: List<WhiteboardElement>
) {
    val fromEl = el.from?.let { fid -> elements.firstOrNull { it.id == fid } }
    val toEl = el.to?.let { tid -> elements.firstOrNull { it.id == tid } }
    if (fromEl == null || toEl == null) return

    val fromCenter = toScreen(fromEl.x + fromEl.w / 2, fromEl.y + fromEl.h / 2, cx, cy, vp)
    val toCenter = toScreen(toEl.x + toEl.w / 2, toEl.y + toEl.h / 2, cx, cy, vp)

    val color = stroke ?: Color.White
    drawLine(color, fromCenter, toCenter, strokeWidth = sw)

    val angle = atan2((toCenter.y - fromCenter.y).toDouble(), (toCenter.x - fromCenter.x).toDouble())
    val headLen = 12f * vp.zoom.toFloat()
    val headAngle = Math.toRadians(25.0)
    val p1 = Offset(
        toCenter.x - (headLen * cos(angle - headAngle)).toFloat(),
        toCenter.y - (headLen * sin(angle - headAngle)).toFloat()
    )
    val p2 = Offset(
        toCenter.x - (headLen * cos(angle + headAngle)).toFloat(),
        toCenter.y - (headLen * sin(angle + headAngle)).toFloat()
    )
    val head = Path().apply { moveTo(toCenter.x, toCenter.y); lineTo(p1.x, p1.y); lineTo(p2.x, p2.y); close() }
    drawPath(head, color, style = Fill)
}

private fun DrawScope.drawLabel(text: String, tl: Offset, size: Size, fontSize: Double?, fill: Color?, zoom: Float) {
    val fs = ((fontSize ?: 12.0) * zoom).toFloat()
    val luminance = fill?.let { it.red * 0.299f + it.green * 0.587f + it.blue * 0.114f } ?: 0f
    val textColor = if (luminance > 0.5f) android.graphics.Color.BLACK else android.graphics.Color.WHITE
    val paint = Paint().apply {
        color = textColor
        textSize = fs
        textAlign = Paint.Align.CENTER
        isAntiAlias = true
    }
    drawContext.canvas.nativeCanvas.drawText(
        text,
        tl.x + size.width / 2,
        tl.y + size.height / 2 + fs / 3,
        paint
    )
}

private fun parseColor(hex: String?): Color? {
    if (hex == null) return null
    val clean = hex.removePrefix("#")
    if (clean.length != 6) return null
    val r = clean.substring(0, 2).toIntOrNull(16) ?: return null
    val g = clean.substring(2, 4).toIntOrNull(16) ?: return null
    val b = clean.substring(4, 6).toIntOrNull(16) ?: return null
    return Color(r, g, b)
}

private fun strokePathEffect(style: String?, sw: Float): PathEffect? = when (style) {
    "dashed" -> PathEffect.dashPathEffect(floatArrayOf(sw * 6, sw * 8))
    "dotted" -> PathEffect.dashPathEffect(floatArrayOf(sw * 2, sw * 2))
    else -> null
}
