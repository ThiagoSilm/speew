package com.speew.p2p

import android.content.Context
import android.content.SharedPreferences

object SharedPrefsUtil {
    private const val PREFS_NAME = "speew_prefs"
    private const val KEY_NODE_ID = "node_id"
    private const val KEY_P2P_PORT = "p2p_port"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun saveNodeState(context: Context, nodeId: String, port: Int) {
        getPrefs(context).edit().apply {
            putString(KEY_NODE_ID, nodeId)
            putInt(KEY_P2P_PORT, port)
            apply()
        }
    }

    fun loadNodeId(context: Context): String? {
        return getPrefs(context).getString(KEY_NODE_ID, null)
    }

    fun loadP2PPort(context: Context): Int {
        return getPrefs(context).getInt(KEY_P2P_PORT, 0)
    }
}
