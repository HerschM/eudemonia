package com.eudemonia.eudemonia

import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify

class EudemoniaForegroundServiceTest {

    private lateinit var service: EudemoniaForegroundService

    @Before
    fun setUp() {
        EudemoniaForegroundService.isRunning = false
        TriggerDebouncer.shared.reset()
        service = EudemoniaForegroundService()
    }

    @After
    fun tearDown() {
        EudemoniaForegroundService.isRunning = false
        TriggerDebouncer.shared.reset()
    }

    @Test
    fun testServiceConstants() {
        assertEquals("eudemonia_background_channel", EudemoniaForegroundService.CHANNEL_ID)
        assertEquals(1001, EudemoniaForegroundService.NOTIFICATION_ID)
        assertEquals("com.eudemonia.eudemonia.HARDWARE_TRIGGER", EudemoniaForegroundService.TRIGGER_ACTION)
        assertEquals("com.eudemonia.eudemonia.START_FOREGROUND", ForegroundServiceCoordinator.ACTION_START)
        assertEquals("com.eudemonia.eudemonia.STOP_FOREGROUND", ForegroundServiceCoordinator.ACTION_STOP)
    }

    @Test
    fun testInitialServiceStateNotRunning() {
        assertFalse(EudemoniaForegroundService.isRunning)
    }

    @Test
    fun testOnCreateInitializesCoordinatorAndUpdatesRunningState() {
        service.onCreate()

        assertFalse(EudemoniaForegroundService.isRunning)

        // Starting foreground sets isRunning = true
        service.coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        assertTrue(EudemoniaForegroundService.isRunning)

        // Stopping foreground sets isRunning = false
        service.coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_STOP)
        assertFalse(EudemoniaForegroundService.isRunning)
    }

    @Test
    fun testTriggerReceiverDispatchesHardwareTriggerWhenLocked() {
        service.onCreate()
        service.registerTriggerReceiver()

        var receivedIsLocked: Boolean? = null
        var triggerDispatched = false

        val testCoordinator = ForegroundServiceCoordinator(
            onTriggerDelivered = { isLocked ->
                triggerDispatched = true
                receivedIsLocked = isLocked
            }
        )
        service.setCoordinatorForTesting(testCoordinator)

        val intent = mock(Intent::class.java)
        org.mockito.Mockito.`when`(intent.action).thenReturn(EudemoniaForegroundService.TRIGGER_ACTION)
        org.mockito.Mockito.`when`(intent.getBooleanExtra("isLocked", false)).thenReturn(true)

        service.triggerReceiver?.onReceive(null, intent)

        assertTrue(triggerDispatched)
        assertEquals(true, receivedIsLocked)
    }

    @Test
    fun testTriggerReceiverDispatchesHardwareTriggerWhenUnlocked() {
        TriggerDebouncer.shared.reset()
        service.onCreate()
        service.registerTriggerReceiver()

        var receivedIsLocked: Boolean? = null
        var triggerDispatched = false

        val testCoordinator = ForegroundServiceCoordinator(
            onTriggerDelivered = { isLocked ->
                triggerDispatched = true
                receivedIsLocked = isLocked
            }
        )
        service.setCoordinatorForTesting(testCoordinator)

        val intent = mock(Intent::class.java)
        org.mockito.Mockito.`when`(intent.action).thenReturn(EudemoniaForegroundService.TRIGGER_ACTION)
        org.mockito.Mockito.`when`(intent.getBooleanExtra("isLocked", false)).thenReturn(false)

        service.triggerReceiver?.onReceive(null, intent)

        assertTrue(triggerDispatched)
        assertEquals(false, receivedIsLocked)
    }

    @Test
    fun testTriggerReceiverIgnoresUnrelatedIntentAction() {
        service.onCreate()
        service.registerTriggerReceiver()

        var triggerDispatched = false

        val testCoordinator = ForegroundServiceCoordinator(
            onTriggerDelivered = {
                triggerDispatched = true
            }
        )
        service.setCoordinatorForTesting(testCoordinator)

        val intent = mock(Intent::class.java)
        org.mockito.Mockito.`when`(intent.action).thenReturn("com.unrelated.ACTION")

        service.triggerReceiver?.onReceive(null, intent)

        assertFalse(triggerDispatched)
    }

    @Test
    fun testDeliverTriggerInvokesMethodChannelWhenActive() {
        val mockChannel = mock(MethodChannel::class.java)

        val result = service.deliverTrigger(isLocked = true, channel = mockChannel)

        assertTrue(result)
        verify(mockChannel).invokeMethod("onHardwareTrigger", mapOf("isLocked" to true))
    }

    @Test
    fun testDeliverTriggerFallsBackToLaunchIntentWhenChannelNull() {
        // When channel is null, deliverTrigger returns false (attempting activity launch)
        val result = service.deliverTrigger(isLocked = false, channel = null)

        assertFalse(result)
    }

    @Test
    fun testOnDestroyCleansUpReceiverAndResetsState() {
        service.onCreate()
        service.registerTriggerReceiver()
        service.coordinator.handleCommand(ForegroundServiceCoordinator.ACTION_START)
        assertTrue(EudemoniaForegroundService.isRunning)

        service.onDestroy()

        assertFalse(EudemoniaForegroundService.isRunning)
        assertNull(service.triggerReceiver)
    }
}
