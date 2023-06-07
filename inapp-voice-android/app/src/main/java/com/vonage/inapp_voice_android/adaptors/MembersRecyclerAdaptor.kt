package com.vonage.inapp_voice_android.adaptors

import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.vonage.inapp_voice_android.R

class MembersRecyclerAdaptor(private val members: ArrayList<String>): RecyclerView.Adapter<MembersRecyclerAdaptor.ViewHolder>() {

    var onMemberClick: ((String) -> Unit)? = null

    class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val memberName: TextView = itemView.findViewById(R.id.tvMemberName)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val itemView = LayoutInflater.from(parent.context).inflate(R.layout.item_member, parent, false)
        return ViewHolder(itemView)
    }

    override fun getItemCount(): Int {
        return members.size
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.memberName.text = members[position]

        holder.memberName.setOnClickListener{
            onMemberClick?.invoke(members[position])
        }
    }
}