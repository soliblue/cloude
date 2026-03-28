package com.cloude.app.Models

import kotlinx.serialization.Serializable

@Serializable
data class ServerEnvironment(
    val id: String,
    val host: String,
    val port: Int = 8765,
    val token: String,
    val symbol: String = "laptop"
)
