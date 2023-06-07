package com.vonage.inapp_voice_android.adaptors

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.vonage.inapp_voice_android.R

class RegionRecyclerAdaptor(private val regions: ArrayList<String>): RecyclerView.Adapter<RegionRecyclerAdaptor.ViewHolder>(){
    var onRegionClick: ((String) -> Unit)? = null

    class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val region: TextView = itemView.findViewById(R.id.tvRegionOption)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val itemView = LayoutInflater.from(parent.context).inflate(R.layout.item_region, parent, false)
        return ViewHolder(itemView)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.region.text = regions[position]
        holder.itemView.setOnClickListener {
            onRegionClick?.invoke(regions[position])
        }
    }

    override fun getItemCount(): Int {
        return regions.size
    }

}