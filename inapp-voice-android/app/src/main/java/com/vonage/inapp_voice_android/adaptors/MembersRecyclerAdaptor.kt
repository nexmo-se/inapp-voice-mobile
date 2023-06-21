package com.vonage.inapp_voice_android.adaptors

import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.vonage.inapp_voice_android.R
import com.vonage.inapp_voice_android.models.MemberState
import com.vonage.inapp_voice_android.utils.showToast

class MembersRecyclerAdaptor(private val filteredMembers: ArrayList<String>, private  val members: MemberState): RecyclerView.Adapter<MembersRecyclerAdaptor.ViewHolder>() {

    var onMemberClick: ((String) -> Unit)? = null

    class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val memberName: TextView = itemView.findViewById(R.id.tvMemberName)
        var memberState: ImageView = itemView.findViewById(R.id.ivMemberState)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val itemView = LayoutInflater.from(parent.context).inflate(R.layout.item_member, parent, false)
        return ViewHolder(itemView)
    }

    override fun getItemCount(): Int {
        return filteredMembers.size
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.memberName.text = filteredMembers[position]
        if (members.available.contains(filteredMembers[position])) {
            holder.memberState.setImageResource(R.drawable.active_circle)
        }
        else {
            holder.memberState.setImageResource(R.drawable.inactive_circle)
        }
        holder.memberName.setOnClickListener{
            onMemberClick?.invoke(filteredMembers[position])
        }
    }
}