package com.example.bg_location_tracker.sync

import android.app.job.JobParameters
import android.app.job.JobService
import java.util.concurrent.Executors

class SyncJobService : JobService() {
    private val executor = Executors.newSingleThreadExecutor()

    override fun onStartJob(params: JobParameters?): Boolean {
        executor.submit {
            val success = UploadManager(this).sync()
            jobFinished(params, !success)
        }
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }
}
