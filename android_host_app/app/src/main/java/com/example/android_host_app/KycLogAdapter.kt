package com.example.android_host_app

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class KycLogAdapter(
    private var items: List<KycLogStore.LogEntry>
) : RecyclerView.Adapter<KycLogAdapter.LogViewHolder>() {

    private val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())

    fun update(newItems: List<KycLogStore.LogEntry>) {
        items = newItems
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): LogViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_kyc_log, parent, false)
        return LogViewHolder(view)
    }

    override fun onBindViewHolder(holder: LogViewHolder, position: Int) {
        val item = items[position]
        holder.bind(item, timeFormat)
    }

    override fun getItemCount(): Int = items.size

    class LogViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val titleView: TextView = itemView.findViewById(R.id.logTitle)
        private val timeView: TextView = itemView.findViewById(R.id.logTime)
        private val messageView: TextView = itemView.findViewById(R.id.logMessage)
        private val metaView: TextView = itemView.findViewById(R.id.logMeta)

        fun bind(entry: KycLogStore.LogEntry, timeFormat: SimpleDateFormat) {
            val title = "${entry.type} · ${entry.step ?: "-"}"
            titleView.text = title

            val time = timeFormat.format(Date(entry.timestampMillis))
            timeView.text = time

            messageView.text = entry.message

            if (!entry.meta.isNullOrEmpty()) {
                metaView.visibility = View.VISIBLE
                metaView.text = "Meta: ${entry.meta}"
            } else {
                metaView.visibility = View.GONE
            }
        }
    }
}
