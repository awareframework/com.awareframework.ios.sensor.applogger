import Foundation
import GRDB
import com_awareframework_ios_core

public struct AppEventsData: BaseDbModelSQLite {
    public static let databaseTableName = "ios_app_events"

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    /// "foreground" | "background" | "terminate"
    public var event: String

    public init(
        event: String,
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        label: String = ""
    ) {
        self.event = event
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id        = dict["id"]        as? Int64
        self.timestamp = dict["timestamp"] as? Int64  ?? Int64(Date().timeIntervalSince1970 * 1000)
        self.deviceId  = dict["deviceId"]  as? String ?? AwareUtils.getCommonDeviceId()
        self.label     = dict["label"]     as? String ?? ""
        self.event     = dict["event"]     as? String ?? ""
    }

    public func toDictionary() -> [String: Any] {
        [
            "id":          id ?? -1,
            "timestamp":   timestamp,
            "deviceId":    deviceId,
            "label":       label,
            "event":       event,
            "os":          os,
            "timezone":    timezone,
            "jsonVersion": jsonVersion,
        ]
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp",   .integer).notNull()
                t.column("deviceId",    .text).notNull()
                t.column("label",       .text)
                t.column("event",       .text).notNull()
                t.column("os",          .text).notNull()
                t.column("timezone",    .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
            }
        }
    }
}
