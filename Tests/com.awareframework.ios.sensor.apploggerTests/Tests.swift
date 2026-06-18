import XCTest
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applogger

final class Tests: XCTestCase {

    func testConfigDefaultsAndApply() {
        let config = AppLoggerSensor.Config().apply { config in
            config.debug = true
            config.label = "session-a"
            config.heartbeatInterval = 15
            config.dbType = .none
            config.serverType = .none
        }

        XCTAssertTrue(config.debug)
        XCTAssertEqual(config.label, "session-a")
        XCTAssertEqual(config.heartbeatInterval, 15)
        XCTAssertEqual(config.dbPath, "aware_applogger")
        XCTAssertEqual(config.dbType, .none)
        XCTAssertEqual(config.serverType, .none)
    }

    func testAppEventsDataDictionaryRoundTrip() {
        let input: [String: Any] = [
            "id": Int64(12),
            "timestamp": Int64(1_700_000_001_000),
            "deviceId": "device-1",
            "label": "daily",
            "event": "foreground",
        ]

        let data = AppEventsData(input)
        let dict = data.toDictionary()

        XCTAssertEqual(dict["id"] as? Int64, 12)
        XCTAssertEqual(dict["timestamp"] as? Int64, 1_700_000_001_000)
        XCTAssertEqual(dict["deviceId"] as? String, "device-1")
        XCTAssertEqual(dict["label"] as? String, "daily")
        XCTAssertEqual(dict["event"] as? String, "foreground")
        XCTAssertEqual(dict["os"] as? String, "iOS")
        XCTAssertEqual(dict["jsonVersion"] as? Int, 1)
    }

    func testAppHeartbeatDataDictionaryRoundTrip() {
        let input: [String: Any] = [
            "id": Int64(34),
            "timestamp": Int64(1_700_000_002_000),
            "deviceId": "device-2",
            "label": "night",
        ]

        let data = AppHeartbeatData(input)
        let dict = data.toDictionary()

        XCTAssertEqual(dict["id"] as? Int64, 34)
        XCTAssertEqual(dict["timestamp"] as? Int64, 1_700_000_002_000)
        XCTAssertEqual(dict["deviceId"] as? String, "device-2")
        XCTAssertEqual(dict["label"] as? String, "night")
        XCTAssertEqual(dict["os"] as? String, "iOS")
        XCTAssertEqual(dict["jsonVersion"] as? Int, 1)
    }

    func testAppLogDataDictionaryRoundTrip() {
        let input: [String: Any] = [
            "id": Int64(56),
            "timestamp": Int64(1_700_000_003_000),
            "deviceId": "device-3",
            "label": "debugging",
            "level": "warn",
            "message": "buffer almost full",
        ]

        let data = AppLogData(input)
        let dict = data.toDictionary()

        XCTAssertEqual(dict["id"] as? Int64, 56)
        XCTAssertEqual(dict["timestamp"] as? Int64, 1_700_000_003_000)
        XCTAssertEqual(dict["deviceId"] as? String, "device-3")
        XCTAssertEqual(dict["label"] as? String, "debugging")
        XCTAssertEqual(dict["level"] as? String, "warn")
        XCTAssertEqual(dict["message"] as? String, "buffer almost full")
        XCTAssertEqual(dict["os"] as? String, "iOS")
        XCTAssertEqual(dict["jsonVersion"] as? Int, 1)
    }

    func testSensorLabelAndLogControllers() {
        final class Observer: AppLoggerObserver {
            var loggedData: AppLogData?

            func onLog(data: AppLogData) {
                loggedData = data
            }
        }

        let observer = Observer()
        let sensor = AppLoggerSensor(AppLoggerSensor.Config().apply { config in
            config.dbType = .none
            config.serverType = .none
            config.sensorObserver = observer
        })

        let setLabelExpectation = expectation(description: "set label notification")
        let logExpectation = expectation(description: "log notification")

        let setLabelObserver = NotificationCenter.default.addObserver(
            forName: .actionAwareAppLoggerSetLabel,
            object: sensor,
            queue: nil
        ) { notification in
            XCTAssertEqual(
                notification.userInfo?[AppLoggerSensor.EXTRA_LABEL] as? String,
                "field-test"
            )
            setLabelExpectation.fulfill()
        }

        let logNotificationObserver = NotificationCenter.default.addObserver(
            forName: .actionAwareAppLoggerLog,
            object: sensor,
            queue: nil
        ) { _ in
            logExpectation.fulfill()
        }

        sensor.set(label: "field-test")
        sensor.log("calibration completed", level: "info")

        wait(for: [setLabelExpectation, logExpectation], timeout: 1)
        NotificationCenter.default.removeObserver(setLabelObserver)
        NotificationCenter.default.removeObserver(logNotificationObserver)

        XCTAssertEqual(observer.loggedData?.label, "field-test")
        XCTAssertEqual(observer.loggedData?.level, "info")
        XCTAssertEqual(observer.loggedData?.message, "calibration completed")
    }
}
