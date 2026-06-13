# AWARE: AppLogger

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

This sensor module tracks iOS app lifecycle events (foreground, background, terminate), emits periodic heartbeat records, and provides a structured logging API. All data is stored in a local SQLite database and can be synced to a remote AWARE server.

## Requirements
iOS 13 or later

## Installation

1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...`

2. Find the package using the manager
    * Select `Search Package URL` and type `https://github.com/awareframework/com.awareframework.ios.sensor.applogger.git`

3. Import the package into your target.

## Public functions

### AppLoggerSensor

+ `init(_ config: AppLoggerSensor.Config)`: Initializes the sensor with the given configuration.
+ `start()`: Registers lifecycle observers and starts the heartbeat timer.
+ `stop()`: Removes lifecycle observers and stops the heartbeat timer.
+ `sync(force:)`: Syncs all three tables (AppEventsData, AppHeartbeatData, AppLogData) sequentially to the configured host.
+ `set(label:)`: Sets a custom label applied to all subsequent data points.
+ `log(_ message: String, level: String)`: Saves an arbitrary log entry. Can be called via the shared instance (`AppLoggerSensor.shared?.log(...)`). `level` defaults to `"info"`.

### AppLoggerSensor.Config

Class to hold the configuration of the sensor.

#### Fields

+ `sensorObserver: AppLoggerObserver?`: Callback for live data updates.
+ `heartbeatInterval: TimeInterval`: Interval in seconds between heartbeat records. (default = `60`)
+ `enabled: Bool`: Sensor is enabled or not. (default = `false`)
+ `debug: Bool`: Enable/disable logging. (default = `false`)
+ `label: String`: Label for the data. (default = "")
+ `deviceId: String`: Id of the device associated with the events. (default = "")
+ `dbEncryptionKey`: Encryption key for the database. (default = `nil`)
+ `dbType: Engine`: Which db engine to use for saving data. (default = `Engine.DatabaseType.NONE`)
+ `dbPath: String`: Path of the database. (default = "aware_applogger")
+ `dbHost: String`: Host for syncing the database. (default = `nil`)

## Broadcasts

### Fired Broadcasts

+ `AppLoggerSensor.ACTION_AWARE_APPLOGGER`: fired on any lifecycle event, heartbeat, or log entry.
+ `actionAwareAppLoggerForeground`: fired when the app enters the foreground.
+ `actionAwareAppLoggerBackground`: fired when the app enters the background.
+ `actionAwareAppLoggerTerminate`: fired when the app is about to terminate.
+ `actionAwareAppLoggerHeartbeat`: fired on each heartbeat tick.
+ `actionAwareAppLoggerLog`: fired when a log entry is saved.

### Received Broadcasts

+ `AppLoggerSensor.ACTION_AWARE_APPLOGGER_START`: received broadcast to start the sensor.
+ `AppLoggerSensor.ACTION_AWARE_APPLOGGER_STOP`: received broadcast to stop the sensor.
+ `AppLoggerSensor.ACTION_AWARE_APPLOGGER_SYNC`: received broadcast to send sync attempt to the host.
+ `AppLoggerSensor.ACTION_AWARE_APPLOGGER_SET_LABEL`: received broadcast to set the data label.

## Data Representations

### AppEventsData (table: `ios_app_events`)

Contains app lifecycle transition events.

| Field       | Type   | Description                                                             |
| ----------- | ------ | ----------------------------------------------------------------------- |
| event       | String | Lifecycle event: `"foreground"`, `"background"`, or `"terminate"`       |
| label       | String | Customizable label. Useful for data calibration or traceability         |
| deviceId    | String | AWARE device UUID                                                       |
| timestamp   | Int64  | Unixtime milliseconds since 1970                                        |
| timezone    | Int    | Timezone of the device                                                  |
| os          | String | Operating system of the device (iOS)                                    |
| jsonVersion | Int    | JSON schema version                                                     |

### AppHeartbeatData (table: `ios_app_heartbeat`)

Contains periodic heartbeat records emitted while the sensor is running.

| Field       | Type   | Description                                      |
| ----------- | ------ | ------------------------------------------------ |
| label       | String | Customizable label                               |
| deviceId    | String | AWARE device UUID                                |
| timestamp   | Int64  | Unixtime milliseconds since 1970                 |
| timezone    | Int    | Timezone of the device                           |
| os          | String | Operating system of the device (iOS)             |
| jsonVersion | Int    | JSON schema version                              |

### AppLogData (table: `ios_app_log`)

Contains structured log entries written via `log(_:level:)`.

| Field       | Type   | Description                                                        |
| ----------- | ------ | ------------------------------------------------------------------ |
| level       | String | Log severity: `"debug"`, `"info"`, `"warn"`, or `"error"`         |
| message     | String | Log message text                                                   |
| label       | String | Customizable label                                                 |
| deviceId    | String | AWARE device UUID                                                  |
| timestamp   | Int64  | Unixtime milliseconds since 1970                                   |
| timezone    | Int    | Timezone of the device                                             |
| os          | String | Operating system of the device (iOS)                               |
| jsonVersion | Int    | JSON schema version                                                |

## Example usage

```swift
import com_awareframework_ios_sensor_applogger
```

```swift
let sensor = AppLoggerSensor(AppLoggerSensor.Config().apply { config in
    config.sensorObserver = Observer()
    config.heartbeatInterval = 60
    config.debug = true
})

sensor.start()

// Write a log entry from anywhere
AppLoggerSensor.shared?.log("Study session started", level: "info")

// Later...
sensor.stop()
```

```swift
class Observer: AppLoggerObserver {
    func onAppForeground(data: AppEventsData) {
        print("App foregrounded at:", data.timestamp)
    }

    func onAppBackground(data: AppEventsData) {
        print("App backgrounded at:", data.timestamp)
    }

    func onAppTerminate(data: AppEventsData) {
        print("App terminating at:", data.timestamp)
    }

    func onHeartbeat(data: AppHeartbeatData) {
        print("Heartbeat at:", data.timestamp)
    }

    func onLog(data: AppLogData) {
        print("[\(data.level)] \(data.message)")
    }
}
```

## Author
Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## Related Links
* [Apple | UIApplication Lifecycle](https://developer.apple.com/documentation/uikit/uiapplication)

## License
Copyright (c) 2018 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
