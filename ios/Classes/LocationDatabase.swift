import Foundation
import SQLite3
import CoreLocation

struct LocationRecord {
    let id: Int64
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let altitude: Double
    let speed: Double
    let bearing: Double
    let time: Int64
    let isMock: Bool
}

class LocationDatabase {
    static let shared = LocationDatabase()
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.bg_location_tracker.db")

    private init() {
        openDB()
        createTable()
    }
    
    private func openDB() {
        let fileManager = FileManager.default
        guard let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dbUrl = docDir.appendingPathComponent("locations.sqlite")
        
        if sqlite3_open_v2(dbUrl.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK {
            var errMsg: UnsafeMutablePointer<Int8>?
            sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, &errMsg)
        } else {
            print("Unable to open database")
        }
    }
    
    private func createTable() {
        let createSql = """
        CREATE TABLE IF NOT EXISTS locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            acc REAL NOT NULL,
            alt REAL NOT NULL,
            spd REAL NOT NULL,
            brg REAL NOT NULL,
            time INTEGER NOT NULL,
            mock INTEGER NOT NULL
        );
        """
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, createSql, nil, nil, &errMsg) != SQLITE_OK {
            let errStr = String(cString: errMsg!)
            print("Error creating table: \(errStr)")
            sqlite3_free(errMsg)
        }
    }
    
    @discardableResult
    func insert(location: CLLocation, isMock: Bool = false) -> Int64 {
        var insertedId: Int64 = 0
        dbQueue.sync {
            let insertSql = "INSERT INTO locations (lat, lng, acc, alt, spd, brg, time, mock) VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, insertSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, location.coordinate.latitude)
                sqlite3_bind_double(stmt, 2, location.coordinate.longitude)
                sqlite3_bind_double(stmt, 3, location.horizontalAccuracy)
                sqlite3_bind_double(stmt, 4, location.altitude)
                sqlite3_bind_double(stmt, 5, max(0.0, location.speed))
                sqlite3_bind_double(stmt, 6, max(0.0, location.course))
                let timeMs = Int64(location.timestamp.timeIntervalSince1970 * 1000)
                sqlite3_bind_int64(stmt, 7, timeMs)
                sqlite3_bind_int(stmt, 8, isMock ? 1 : 0)
                
                if sqlite3_step(stmt) == SQLITE_DONE {
                    insertedId = sqlite3_last_insert_rowid(self.db)
                } else {
                    print("Could not insert row into locations.")
                }
            }
            sqlite3_finalize(stmt)
        }
        return insertedId
    }
    
    func getUnsynced(limit: Int) -> [LocationRecord] {
        var results = [LocationRecord]()
        dbQueue.sync {
            let querySql = "SELECT id, lat, lng, acc, alt, spd, brg, time, mock FROM locations ORDER BY time ASC LIMIT ?;"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, querySql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(limit))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = sqlite3_column_int64(stmt, 0)
                    let lat = sqlite3_column_double(stmt, 1)
                    let lng = sqlite3_column_double(stmt, 2)
                    let acc = sqlite3_column_double(stmt, 3)
                    let alt = sqlite3_column_double(stmt, 4)
                    let spd = sqlite3_column_double(stmt, 5)
                    let brg = sqlite3_column_double(stmt, 6)
                    let time = sqlite3_column_int64(stmt, 7)
                    let mock = sqlite3_column_int(stmt, 8) == 1
                    
                    results.append(LocationRecord(
                        id: id,
                        latitude: lat,
                        longitude: lng,
                        accuracy: acc,
                        altitude: alt,
                        speed: spd,
                        bearing: brg,
                        time: time,
                        isMock: mock
                    ))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
    
    func deleteSynced(ids: [Int64]) {
        guard !ids.isEmpty else { return }
        dbQueue.sync {
            let idList = ids.map { String($0) }.joined(separator: ",")
            let deleteSql = "DELETE FROM locations WHERE id IN (\(idList));"
            var errMsg: UnsafeMutablePointer<Int8>?
            if sqlite3_exec(self.db, deleteSql, nil, nil, &errMsg) != SQLITE_OK {
                let errStr = errMsg != nil ? String(cString: errMsg!) : "Unknown error"
                print("Could not delete synced locations: \(errStr)")
                sqlite3_free(errMsg)
            }
        }
    }
    
    func getUnsyncedCount() -> Int {
        var count = 0
        dbQueue.sync {
            let querySql = "SELECT COUNT(*) FROM locations;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(self.db, querySql, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(stmt, 0))
                }
            }
            sqlite3_finalize(stmt)
        }
        return count
    }
    
    func getAllLocations() -> [[String: Any]] {
        var results = [[String: Any]]()
        dbQueue.sync {
            let querySql = "SELECT id, lat, lng, acc, alt, spd, brg, time, mock FROM locations ORDER BY time ASC;"
            var stmt: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, querySql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = sqlite3_column_int64(stmt, 0)
                    let lat = sqlite3_column_double(stmt, 1)
                    let lng = sqlite3_column_double(stmt, 2)
                    let acc = sqlite3_column_double(stmt, 3)
                    let alt = sqlite3_column_double(stmt, 4)
                    let spd = sqlite3_column_double(stmt, 5)
                    let brg = sqlite3_column_double(stmt, 6)
                    let time = sqlite3_column_int64(stmt, 7)
                    let mock = sqlite3_column_int(stmt, 8) == 1
                    
                    results.append([
                        "id": id,
                        "latitude": lat,
                        "longitude": lng,
                        "accuracy": acc,
                        "altitude": alt,
                        "speed": spd,
                        "bearing": brg,
                        "timestamp": time,
                        "time": time,
                        "isMock": mock
                    ])
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
    
    func clearAll() {
        dbQueue.sync {
            var errMsg: UnsafeMutablePointer<Int8>?
            if sqlite3_exec(self.db, "DELETE FROM locations;", nil, nil, &errMsg) != SQLITE_OK {
                print("Could not clear locations")
                sqlite3_free(errMsg)
            }
        }
    }
}
