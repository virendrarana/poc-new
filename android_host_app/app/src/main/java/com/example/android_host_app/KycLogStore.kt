package com.example.android_host_app

object KycLogStore {

    data class LogEntry(
        val type: String,
        val step: String?,
        val message: String,
        val meta: String?,
        val timestampMillis: Long
    )

    private val _events = mutableListOf<LogEntry>()

    val events: List<LogEntry>
        get() = _events.toList()

    fun add(entry: LogEntry) {
        // latest first
        _events.add(0, entry)
    }

    fun clear() {
        _events.clear()
    }
}
