package com.cloude.app.UI.whiteboard

import kotlinx.serialization.Serializable

@Serializable
data class WhiteboardElement(
    val id: String,
    var type: String,
    var x: Double = 0.0,
    var y: Double = 0.0,
    var w: Double = 100.0,
    var h: Double = 60.0,
    var label: String? = null,
    var fill: String? = null,
    var stroke: String? = null,
    var points: List<List<Double>>? = null,
    var closed: Boolean? = null,
    var from: String? = null,
    var to: String? = null,
    var z: Int? = null,
    var fontSize: Double? = null,
    var strokeWidth: Double? = null,
    var strokeStyle: String? = null,
    var opacity: Double? = null,
    var groupId: String? = null
)

@Serializable
data class WhiteboardViewport(
    var x: Double = 0.0,
    var y: Double = 0.0,
    var zoom: Double = 1.0
)

data class WhiteboardCanvasState(
    val elements: List<WhiteboardElement> = emptyList(),
    val viewport: WhiteboardViewport = WhiteboardViewport(),
    val selectedIds: Set<String> = emptySet(),
    val activeTool: ActiveTool = ActiveTool.Hand,
    val activeColor: String = "#4ECDC4"
)

enum class ActiveTool {
    Hand, Rect, Ellipse, Triangle, Text, Pencil, Arrow
}

val paletteColors = listOf("#FFFFFF", "#FF6B6B", "#4ECDC4", "#FFE66D", "#A78BFA", "#FF8C42")
