package com.example.bg_location_tracker.sync

import android.content.Context
import android.util.Log
import com.example.bg_location_tracker.store.ConfigStore
import com.example.bg_location_tracker.store.LocationDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Uploads queued locations to the backend in bulk.
 *
 * Every request body has this shape:
 *
 * {
 *   "userId": "samsung",
 *   "locations": [ { ...point... }, { ...point... } ]
 * }
 *
 * `config.batchSize` is the maximum number of points per request.
 * A single [sync] call keeps sending batches until the queue is empty
 * (or a batch fails), so an offline backlog drains in one run.
 */
class UploadManager(
    private val context: Context
) {

    companion object {
        private const val TAG = "BgLocationTracker"

        private const val CONNECT_TIMEOUT = 15_000
        private const val READ_TIMEOUT = 30_000

        /**
         * Safety cap: at most this many requests per sync run.
         * Anything left is picked up by the next sync.
         */
        private const val MAX_BATCHES_PER_RUN = 50
    }

    private val db = LocationDatabase.getInstance(context)
    private val config = ConfigStore(context)

    /** ISO-8601 UTC, e.g. 2026-09-21T11:30:10.589Z */
    private val utcFormatter =
        DateTimeFormatter
            .ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
            .withZone(ZoneId.of("UTC"))

    /** ISO-8601 device-local with offset, e.g. 2026-09-21T17:00:10.589+05:30 */
    private val localFormatter =
        DateTimeFormatter
            .ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSXXX")
            .withZone(ZoneId.systemDefault())

    /**
     * @return true when everything pending was uploaded (or there was
     * nothing to do); false when a request failed and should be retried.
     */
    fun sync(): Boolean {

        val urlStr = config.syncUrl

        if (urlStr.isNullOrBlank()) {
            Log.d(TAG, "Sync URL is not configured")
            return true
        }

        /*
         * Parse headers once for the whole run.
         */
        val headersJson = config.syncHeaders
            ?.takeIf { it.isNotBlank() }
            ?.let {
                try {
                    JSONObject(it)
                } catch (e: Exception) {
                    Log.e(TAG, "Invalid syncHeaders JSON: ${e.message}")
                    null
                }
            }

        /*
         * userId travels inside syncHeaders (app metadata, not an
         * HTTP header). It is added to the body and to every point.
         */
        val userId = headersJson
            ?.optString("userId")
            ?.takeIf { it.isNotBlank() }

        val batchSize = config.batchSize.coerceAtLeast(1)

        var batchesSent = 0
        var pointsSent = 0

        while (batchesSent < MAX_BATCHES_PER_RUN) {

            val locations = db.getUnsynced(batchSize)

            if (locations.isEmpty()) {
                if (batchesSent == 0) {
                    Log.d(TAG, "No unsynced locations")
                } else {
                    Log.d(
                        TAG,
                        "Backlog drained: $pointsSent location(s) in $batchesSent request(s)"
                    )
                }
                return true
            }

            /*
             * Build the "locations" array.
             */
            val jsonArray = JSONArray()

            locations.forEach { loc ->

                val instant = Instant.ofEpochMilli(loc.time)

                val obj = JSONObject().apply {

                    put("id", loc.id)
                    put("latitude", loc.latitude)
                    put("longitude", loc.longitude)
                    put("accuracy", loc.accuracy)

                    // Epoch milliseconds
                    put("timestamp", loc.time)

                    // UTC ISO-8601
                    put("timestampString", utcFormatter.format(instant))

                    // Device local ISO-8601 with offset
                    put("timestampLocal", localFormatter.format(instant))

                    put("saved_from", "Native")
                    put("platform", "Android")

                    if (!userId.isNullOrEmpty()) {
                        put("userId", userId)
                    }
                }

                jsonArray.put(obj)
            }

            /*
             * Wrapper body:
             * { "userId": "...", "locations": [ ... ] }
             */
            val body = JSONObject().apply {
                if (!userId.isNullOrEmpty()) {
                    put("userId", userId)
                }
                put("locations", jsonArray)
            }

            Log.d(
                TAG,
                """
                === API REQUEST ===
                URL: $urlStr
                Method: POST
                Payload: ${body.toString(2)}
                ===================
                """.trimIndent()
            )

            if (!postJson(urlStr, headersJson, body.toString())) {
                // Keep the rows; they are retried on the next sync.
                return false
            }

            /*
             * Server accepted the batch: remove exactly these rows,
             * then loop to send the next chunk.
             */
            db.deleteSynced(locations.map { it.id })

            batchesSent++
            pointsSent += locations.size
        }

        Log.d(
            TAG,
            "Reached $MAX_BATCHES_PER_RUN requests in one run " +
                "($pointsSent sent); remaining points go in the next sync"
        )

        return true
    }

    /**
     * POSTs [payload] as JSON. Returns true for any 2xx response.
     */
    private fun postJson(
        urlStr: String,
        headersJson: JSONObject?,
        payload: String
    ): Boolean {

        var connection: HttpURLConnection? = null

        try {

            connection = URL(urlStr).openConnection() as HttpURLConnection

            connection.apply {

                requestMethod = "POST"
                connectTimeout = CONNECT_TIMEOUT
                readTimeout = READ_TIMEOUT
                doOutput = true
                doInput = true
                useCaches = false

                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")

                headersJson?.let { json ->

                    val keys = json.keys()

                    while (keys.hasNext()) {

                        val key = keys.next()

                        // userId is body metadata, not an HTTP header.
                        if (key.equals("userId", ignoreCase = true)) {
                            continue
                        }

                        val value = json.optString(key)

                        if (value.isNotEmpty()) {
                            setRequestProperty(key, value)
                        }
                    }
                }
            }

            OutputStreamWriter(
                connection.outputStream,
                Charsets.UTF_8
            ).use { writer ->
                writer.write(payload)
                writer.flush()
            }

            val responseCode = connection.responseCode

            val responseStream =
                if (responseCode in 200..299) {
                    connection.inputStream
                } else {
                    connection.errorStream
                }

            val responseBody =
                responseStream?.let { stream ->
                    BufferedReader(
                        InputStreamReader(stream, Charsets.UTF_8)
                    ).use { reader -> reader.readText() }
                } ?: ""

            Log.d(
                TAG,
                """
                === API RESPONSE ===
                Status: $responseCode
                Body: $responseBody
                ====================
                """.trimIndent()
            )

            if (responseCode in 200..299) {
                return true
            }

            Log.e(TAG, "API call failed. HTTP $responseCode")
            return false

        } catch (e: Exception) {
            Log.e(TAG, "=== API ERROR ===\nMessage: ${e.message}", e)
            return false

        } finally {

            connection?.disconnect()
        }
    }
}