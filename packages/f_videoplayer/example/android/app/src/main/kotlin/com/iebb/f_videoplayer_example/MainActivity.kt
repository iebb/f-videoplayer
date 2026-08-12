package com.iebb.f_videoplayer_example

import android.content.res.Configuration
import android.os.Build
import com.iebb.f_videoplayer_pip.FVideoPictureInPicturePlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onStart() {
        super.onStart()
        FVideoPictureInPicturePlugin.onActivityStarted(this)
    }

    override fun onResume() {
        super.onResume()
        FVideoPictureInPicturePlugin.onActivityResumed(this)
    }

    override fun onPause() {
        FVideoPictureInPicturePlugin.onActivityPaused(this)
        super.onPause()
    }

    override fun onStop() {
        FVideoPictureInPicturePlugin.onActivityStopped(this)
        super.onStop()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        FVideoPictureInPicturePlugin.onUserLeaveHint(this)
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.R)
    override fun onPictureInPictureRequested(): Boolean =
        FVideoPictureInPicturePlugin.onPictureInPictureRequested(this) ||
            super.onPictureInPictureRequested()

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        FVideoPictureInPicturePlugin.onPictureInPictureModeChanged(
            this,
            isInPictureInPictureMode,
            newConfig,
        )
    }

    override fun onDestroy() {
        FVideoPictureInPicturePlugin.onActivityDestroyed(this)
        super.onDestroy()
    }
}
