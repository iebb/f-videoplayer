package com.iebb.f_videoplayer_pip

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FVideoPictureInPictureLifecycleTest {
    @Test
    fun activeStopWaitsForOsExitAndBlocksAnotherEntry() {
        val lifecycle = FVideoPictureInPictureLifecycle()

        assertTrue(lifecycle.markEntered())
        assertTrue(lifecycle.requestStop())
        assertTrue(lifecycle.inPictureInPicture)
        assertTrue(lifecycle.stopRequested)
        assertTrue(lifecycle.blocksEntry)
        assertFalse(lifecycle.markEntered())

        assertEquals(
            FVideoPictureInPictureExitDisposition.STOP,
            lifecycle.onPictureInPictureModeExited(activityStarted = true),
        )
        assertTrue(lifecycle.markStopped())
        assertFalse(lifecycle.inPictureInPicture)
        assertFalse(lifecycle.stopRequested)
        assertFalse(lifecycle.blocksEntry)
        assertTrue(lifecycle.markEntered())
    }

    @Test
    fun activeStopAlsoCompletesWhenResumeArrivesBeforeModeCallback() {
        val lifecycle = FVideoPictureInPictureLifecycle()
        assertTrue(lifecycle.markEntered())
        assertTrue(lifecycle.requestStop())

        assertEquals(
            FVideoPictureInPictureExitDisposition.STOP,
            lifecycle.onActivityResumed(stillInPictureInPicture = false),
        )
    }

    @Test
    fun ordinaryExitRestoresOnlyAfterActivityResumes() {
        val lifecycle = FVideoPictureInPictureLifecycle()
        assertTrue(lifecycle.markEntered())

        assertEquals(
            FVideoPictureInPictureExitDisposition.AWAIT_RESUME,
            lifecycle.onPictureInPictureModeExited(activityStarted = true),
        )
        assertEquals(
            FVideoPictureInPictureExitDisposition.NONE,
            lifecycle.onActivityResumed(stillInPictureInPicture = true),
        )
        assertEquals(
            FVideoPictureInPictureExitDisposition.RESTORE,
            lifecycle.onActivityResumed(stillInPictureInPicture = false),
        )
        assertTrue(lifecycle.markRestored())
        assertFalse(lifecycle.inPictureInPicture)
    }

    @Test
    fun inactiveStopDoesNotPoisonTheNextSession() {
        val lifecycle = FVideoPictureInPictureLifecycle()

        assertFalse(lifecycle.requestStop())
        assertFalse(lifecycle.blocksEntry)
        assertTrue(lifecycle.markEntered())
    }
}
