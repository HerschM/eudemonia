package com.eudemonia.eudemonia

/** Sends the activity's task to the background; the real one is [android.app.Activity.moveTaskToBack]. */
fun interface TaskMover {
    fun moveTaskToBack(nonRoot: Boolean): Boolean
}

/**
 * What Back does once there is no route left to pop: the task goes to the background, the
 * activity is never finished.
 *
 * The foreground service keeps the process alive, but finishing the activity destroys its
 * Flutter engine, and with it every Dart isolate: the model eviction timer can no longer run
 * and a synthesis in progress is lost. Kept like this, the engine evicts the models when idle
 * exactly as with the app open.
 */
object RootBackNavigation {
    /** Always true (handled), so Flutter's default of finishing the activity never runs. */
    fun onRootBack(task: TaskMover): Boolean {
        task.moveTaskToBack(true)
        return true
    }
}
