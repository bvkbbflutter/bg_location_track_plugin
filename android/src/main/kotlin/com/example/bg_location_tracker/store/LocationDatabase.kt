package com.example.bg_location_tracker.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.example.bg_location_tracker.models.LocationData

class LocationDatabase private constructor(context: Context) : SQLiteOpenHelper(context.applicationContext, "bg_location.db", null, 1) {
    
    companion object {
        @Volatile
        private var instance: LocationDatabase? = null

        fun getInstance(context: Context): LocationDatabase {
            return instance ?: synchronized(this) {
                instance ?: LocationDatabase(context).also { instance = it }
            }
        }
    }
    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE locations (id INTEGER PRIMARY KEY AUTOINCREMENT, lat REAL, lng REAL, acc REAL, alt REAL, spd REAL, brg REAL, time INTEGER, mock INTEGER)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS locations")
        onCreate(db)
    }

    fun insert(loc: LocationData): Long {
        val cv = ContentValues().apply {
            put("lat", loc.latitude)
            put("lng", loc.longitude)
            put("acc", loc.accuracy)
            put("alt", loc.altitude)
            put("spd", loc.speed)
            put("brg", loc.bearing)
            put("time", loc.time)
            put("mock", if (loc.isMock) 1 else 0)
        }
        return writableDatabase.insert("locations", null, cv)
    }

    fun getUnsynced(limit: Int): List<LocationData> {
        val list = mutableListOf<LocationData>()
        val cursor = readableDatabase.query("locations", null, null, null, null, null, "time ASC", limit.toString())
        cursor.use {
            while (it.moveToNext()) {
                list.add(LocationData(
                    id = it.getLong(0),
                    latitude = it.getDouble(1),
                    longitude = it.getDouble(2),
                    accuracy = it.getFloat(3),
                    altitude = it.getDouble(4),
                    speed = it.getFloat(5),
                    bearing = it.getFloat(6),
                    time = it.getLong(7),
                    isMock = it.getInt(8) == 1
                ))
            }
        }
        return list
    }

    fun deleteSynced(ids: List<Long>) {
        if (ids.isEmpty()) return
        val idList = ids.joinToString(",")
        writableDatabase.delete("locations", "id IN ($idList)", null)
    }

    fun clearAll() {
        writableDatabase.delete("locations", null, null)
    }
}
