package com.vonage.inapp_voice_android.views.fragments

import android.app.Activity
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import androidx.core.widget.doOnTextChanged
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.recyclerview.widget.LinearLayoutManager
import com.vonage.inapp_voice_android.App
import com.vonage.inapp_voice_android.R
import com.vonage.inapp_voice_android.adaptors.MembersRecyclerAdaptor
import com.vonage.inapp_voice_android.api.APIRetrofit
import com.vonage.inapp_voice_android.api.MemberInformation
import com.vonage.inapp_voice_android.core.CoreContext
import com.vonage.inapp_voice_android.databinding.FragmentIdlecallBinding
import com.vonage.inapp_voice_android.models.FcmEvents
import com.vonage.inapp_voice_android.models.Members
import com.vonage.inapp_voice_android.models.User
import com.vonage.inapp_voice_android.utils.Constants
import com.vonage.inapp_voice_android.utils.contains
import com.vonage.inapp_voice_android.utils.showAlert
import com.vonage.inapp_voice_android.utils.showToast
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response

class FragmentIdleCall: Fragment(R.layout.fragment_idlecall) {
    private var _binding: FragmentIdlecallBinding? = null
    private val binding get() = _binding!!

    private val coreContext = App.coreContext
    private val clientManager = coreContext.clientManager
    private var isMembersLoading = false
    private var members = ArrayList<String>()
    private var filteredMembers = ArrayList<String>()
    private val membersAdaptor = MembersRecyclerAdaptor(filteredMembers);

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentIdlecallBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        val user = coreContext.user ?: return
        binding.tvLoggedUsername.text =   "${user.username} (${user.region})"

        // Focus button at the start
        binding.btCallAUser.isFocusableInTouchMode = true;
        binding.btCallAUser.requestFocus()

        // Set members adaptors
        val membersRecyclerView = binding.rvCallUser
        membersRecyclerView.layoutManager = LinearLayoutManager(context)
        membersRecyclerView.adapter = membersAdaptor

        membersAdaptor.onMemberClick = {
            binding.etCallUser.setText(it)
            hideKeyboard()
        }

        binding.etCallUser.setOnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                loadMembers(user)
                binding.rvCallUser.visibility = View.VISIBLE
            }
            else {
                binding.rvCallUser.visibility = View.GONE
            }
        }

        //Filter members
        binding.etCallUser.doOnTextChanged { text, _, _, _ ->
            filteredMembers.clear()

            if (text !== "") {
                val newList = ArrayList(members.filter { it ->
                    it.lowercase().contains(text.toString().lowercase())
                })
                filteredMembers.addAll(newList)
            }
            else {
                val newList = members
                filteredMembers.addAll(newList)
            }
            membersAdaptor.notifyDataSetChanged()
        }

        // Call Button
        binding.btCallAUser.setOnClickListener {
            val member = binding.etCallUser.text.toString()
            if (!members.contains(member)) {
                showToast(context!!, "Invalid Member Or User Busy")
                return@setOnClickListener
            }
            // prevent double submit
            binding.btCallAUser.isEnabled = false
            call(member)
        }

        // Clear Focus when click outside
        view.setOnClickListener {
            hideKeyboard()
        }
        FcmEvents.serviceEvent.observe(viewLifecycleOwner, Observer {
            if (binding.etCallUser.isFocused || binding.etCallUser.text.toString() != "") {
                loadMembers(user)
            }
        })
    }

    private fun hideKeyboard() {
        binding.etCallUser.clearFocus()
        binding.btCallAUser.isFocusableInTouchMode = true;
        binding.btCallAUser.requestFocus()

        val imm = activity?.getSystemService(Activity.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(binding.etCallUser.windowToken, 0)
    }

    private fun loadMembers(user: User) {
        // Get members from backend
        if (isMembersLoading) {
            return
        }
        isMembersLoading = true
        APIRetrofit.instance.getMembers(MemberInformation(user.dc, user.username, user.token)).enqueue(object:
            Callback<Members> {
            override fun onResponse(call: Call<Members>, response: Response<Members>) {
                response.body()?.let { it1 ->
                    isMembersLoading = false
                    filteredMembers.clear()
                    members.clear()
                    members.addAll(it1.members)
                    filteredMembers.addAll(it1.members)
                    membersAdaptor.notifyDataSetChanged()
                }
            }

            override fun onFailure(call: Call<Members>, t: Throwable) {
                isMembersLoading = false
                if (context !== null) {
                    showAlert(context!!, "Failed to Load Members", false)
                }
            }

        })
    }

    private fun call(member: String) {
        val callContext = mapOf(
            Constants.CONTEXT_KEY_RECIPIENT to member,
            Constants.CONTEXT_KEY_TYPE to Constants.APP_TYPE
        )
        clientManager.startOutboundCall(callContext)
    }
}