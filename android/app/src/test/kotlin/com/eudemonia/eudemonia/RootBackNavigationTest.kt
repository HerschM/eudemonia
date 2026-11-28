package com.eudemonia.eudemonia

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RootBackNavigationTest {

    private class FakeTask(private val moved: Boolean) : TaskMover {
        val calls = mutableListOf<Boolean>()

        override fun moveTaskToBack(nonRoot: Boolean): Boolean {
            calls.add(nonRoot)
            return moved
        }
    }

    @Test
    fun `back at the root moves the whole task to the background`() {
        val task = FakeTask(moved = true)

        RootBackNavigation.onRootBack(task)

        // nonRoot = true: the task moves even when this activity is not its root, so the
        // activity is never finished and the Flutter engine stays alive.
        assertEquals(listOf(true), task.calls)
    }

    @Test
    fun `back at the root is always reported as handled so Flutter never finishes the activity`() {
        assertTrue(RootBackNavigation.onRootBack(FakeTask(moved = true)))
        // Even when the system refuses to move the task, finishing would destroy the engine.
        assertTrue(RootBackNavigation.onRootBack(FakeTask(moved = false)))
    }
}
