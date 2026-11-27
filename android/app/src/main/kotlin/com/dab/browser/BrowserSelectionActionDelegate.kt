package com.dab.browser

import android.app.Activity
import android.content.Intent
import android.view.MenuItem
import org.mozilla.geckoview.BasicSelectionActionDelegate
import org.mozilla.geckoview.GeckoSession

/**
 * Extends GeckoView's BasicSelectionActionDelegate to keep native floating text
 * selection actions (Cut, Copy, Paste, Select All) while adding Web Search and Share.
 */
class BrowserSelectionActionDelegate(
    private val hostActivity: Activity,
    private val onSearchText: (String) -> Unit
) : BasicSelectionActionDelegate(hostActivity, true) {

    companion object {
        private const val ACTION_WEB_SEARCH = "com.dab.browser.ACTION_WEB_SEARCH"
        private const val ACTION_SHARE_TEXT = "com.dab.browser.ACTION_SHARE_TEXT"
    }

    init {
        enableExternalActions(true)
    }

    override fun getAllActions(): Array<String> {
        return super.getAllActions() + arrayOf(ACTION_SHARE_TEXT, ACTION_WEB_SEARCH)
    }

    override fun isActionAvailable(id: String): Boolean {
        if (id == ACTION_WEB_SEARCH || id == ACTION_SHARE_TEXT) {
            val sel = mSelection ?: return false
            val isPassword = (sel.flags and GeckoSession.SelectionActionDelegate.FLAG_IS_PASSWORD) != 0
            return !sel.text.isNullOrBlank() && !isPassword
        }
        return super.isActionAvailable(id)
    }

    override fun prepareAction(id: String, item: MenuItem) {
        when (id) {
            ACTION_WEB_SEARCH -> item.title = "Web search"
            ACTION_SHARE_TEXT -> item.title = "Share"
            else -> super.prepareAction(id, item)
        }
    }

    override fun performAction(id: String, item: MenuItem): Boolean {
        val selected = mSelection?.text?.trim().orEmpty()
        when (id) {
            ACTION_WEB_SEARCH -> {
                if (selected.isNotEmpty()) {
                    onSearchText(selected)
                }
                clearSelection()
                return true
            }
            ACTION_SHARE_TEXT -> {
                if (selected.isNotEmpty()) {
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, selected)
                    }
                    val chooser = Intent.createChooser(shareIntent, "Share text").apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    hostActivity.startActivity(chooser)
                }
                clearSelection()
                return true
            }
            else -> return super.performAction(id, item)
        }
    }
}
