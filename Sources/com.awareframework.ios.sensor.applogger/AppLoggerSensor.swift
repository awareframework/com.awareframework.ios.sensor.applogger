import UIKit
import com_awareframework_ios_core

extension Notification.Name {
    public static let actionAwareAppLogger          = Notification.Name(AppLoggerSensor.ACTION_AWARE_APPLOGGER)
    public static let actionAwareAppLoggerStart     = Notification.Name(AppLoggerSensor.ACTION_AWARE_APPLOGGER_START)
    public static let actionAwareAppLoggerStop      = Notification.Name(AppLoggerSensor.ACTION_AWARE_APPLOGGER_STOP)
    public static let actionAwareAppLoggerSync      = Notification.Name(AppLoggerSensor.ACTION_AWARE_APPLOGGER_SYNC)
    public static let actionAwareAppLoggerSetLabel  = Notification.Name(AppLoggerSensor.ACTION_AWARE_APPLOGGER_SET_LABEL)
    public static let actionAwareAppLoggerSyncCompletion = Notification.Name(AppLoggerSensor.ACTION_AWARE_APPLOGGER_SYNC_COMPLETION)

    public static let actionAwareAppLoggerForeground = Notification.Name("com.awareframework.ios.sensor.applogger.APP_FOREGROUND")
    public static let actionAwareAppLoggerBackground = Notification.Name("com.awareframework.ios.sensor.applogger.APP_BACKGROUND")
    public static let actionAwareAppLoggerTerminate  = Notification.Name("com.awareframework.ios.sensor.applogger.APP_TERMINATE")
    public static let actionAwareAppLoggerHeartbeat  = Notification.Name("com.awareframework.ios.sensor.applogger.HEARTBEAT")
    public static let actionAwareAppLoggerLog        = Notification.Name("com.awareframework.ios.sensor.applogger.LOG")
}

public protocol AppLoggerObserver {
    func onAppForeground(data: AppEventsData)
    func onAppBackground(data: AppEventsData)
    func onAppTerminate(data: AppEventsData)
    func onHeartbeat(data: AppHeartbeatData)
    func onLog(data: AppLogData)
}

public extension AppLoggerObserver {
    func onAppForeground(data: AppEventsData) {}
    func onAppBackground(data: AppEventsData) {}
    func onAppTerminate(data: AppEventsData) {}
    func onHeartbeat(data: AppHeartbeatData) {}
    func onLog(data: AppLogData) {}
}

public class AppLoggerSensor: AwareSensor {

    public static let TAG = "AWARE::AppLogger"

    public static let ACTION_AWARE_APPLOGGER           = "com.awareframework.ios.sensor.applogger"
    public static let ACTION_AWARE_APPLOGGER_START     = "com.awareframework.ios.sensor.applogger.SENSOR_START"
    public static let ACTION_AWARE_APPLOGGER_STOP      = "com.awareframework.ios.sensor.applogger.SENSOR_STOP"
    public static let ACTION_AWARE_APPLOGGER_SET_LABEL = "com.awareframework.ios.sensor.applogger.SET_LABEL"
    public static let ACTION_AWARE_APPLOGGER_SYNC      = "com.awareframework.ios.sensor.applogger.SENSOR_SYNC"
    public static let ACTION_AWARE_APPLOGGER_SYNC_COMPLETION = "com.awareframework.ios.sensor.applogger.SENSOR_SYNC_COMPLETION"
    public static let EXTRA_LABEL = "label"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
    public static let EXTRA_OBJECT_TYPE = "objectType"
    public static let EXTRA_TABLE_NAME = "tableName"

    public var CONFIG = Config()

    private var lifecycleObservers: [NSObjectProtocol] = []
    private var heartbeatTimer: Timer?

    /// Shared instance for use with the static `log()` API.
    public static weak var shared: AppLoggerSensor?

    public class Config: SensorConfig {
        public var sensorObserver: AppLoggerObserver?
        /// Heartbeat interval in seconds (default: 60).
        public var heartbeatInterval: TimeInterval = 60

        public override init() {
            super.init()
            dbPath = "aware_applogger"
        }

        public func apply(closure: (_ config: AppLoggerSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }

    public override convenience init() {
        self.init(AppLoggerSensor.Config())
    }

    public init(_ config: AppLoggerSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        super.syncConfig = DbSyncConfig().apply { syncConfig in
            syncConfig.serverType = config.serverType
            syncConfig.debug = config.debug
            syncConfig.batchSize = 1000
            syncConfig.dispatchQueue = DispatchQueue(
                label: "com.awareframework.ios.sensor.applogger.sync.queue")
            syncConfig.completionHandler = { status, error in
                var userInfo: [String: Any] = [AppLoggerSensor.EXTRA_STATUS: status]
                if let error = error { userInfo[AppLoggerSensor.EXTRA_ERROR] = error }
                self.notificationCenter.post(
                    name: .actionAwareAppLoggerSyncCompletion, object: self, userInfo: userInfo)
            }
        }
        initializeTables()
        AppLoggerSensor.shared = self
    }

    public override func start() {
        setLifecycleObservers()
        startHeartbeatTimer()
        notificationCenter.post(name: .actionAwareAppLoggerStart, object: self)
    }

    public override func stop() {
        removeLifecycleObservers()
        stopHeartbeatTimer()
        notificationCenter.post(name: .actionAwareAppLoggerStop, object: self)
    }

    public override func sync(force: Bool = false) {
        guard let syncConfig = super.syncConfig else { return }
        notificationCenter.post(name: .actionAwareAppLoggerSync, object: self)
        let tables = [
            AppEventsData.databaseTableName,
            AppHeartbeatData.databaseTableName,
            AppLogData.databaseTableName,
        ]
        startSequentialSync(for: tables, syncConfig: syncConfig, currentIndex: 0, hasFailure: false, lastError: nil)
    }

    public override func set(label: String) {
        CONFIG.label = label
        notificationCenter.post(
            name: .actionAwareAppLoggerSetLabel, object: self,
            userInfo: [AppLoggerSensor.EXTRA_LABEL: label])
    }

    // MARK: - Public log API

    /// Save an arbitrary log entry. Can be called from anywhere via `AppLoggerSensor.shared?.log(...)`.
    public func log(_ message: String, level: String = "info") {
        var data = AppLogData(message: message, level: level, label: CONFIG.label)
        data.deviceId = AwareUtils.getCommonDeviceId()
        saveModels([data])
        CONFIG.sensorObserver?.onLog(data: data)
        notificationCenter.post(name: .actionAwareAppLoggerLog, object: self)
    }

    // MARK: - Lifecycle observers

    private func setLifecycleObservers() {
        let center = NotificationCenter.default
        let pairs: [(NSNotification.Name, String, Notification.Name)] = [
            (UIApplication.didBecomeActiveNotification,    "foreground", .actionAwareAppLoggerForeground),
            (UIApplication.didEnterBackgroundNotification, "background", .actionAwareAppLoggerBackground),
            (UIApplication.willTerminateNotification,      "terminate",  .actionAwareAppLoggerTerminate),
        ]
        lifecycleObservers = pairs.map { (uiName, event, awareName) in
            center.addObserver(forName: uiName, object: nil, queue: .main) { [weak self] _ in
                self?.saveLifecycleEvent(event, notificationName: awareName)
            }
        }
    }

    private func removeLifecycleObservers() {
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        lifecycleObservers.removeAll()
    }

    private func saveLifecycleEvent(_ event: String, notificationName: Notification.Name) {
        var data = AppEventsData(event: event, label: CONFIG.label)
        data.deviceId = AwareUtils.getCommonDeviceId()
        saveModels([data])
        switch event {
        case "foreground": CONFIG.sensorObserver?.onAppForeground(data: data)
        case "background": CONFIG.sensorObserver?.onAppBackground(data: data)
        case "terminate":  CONFIG.sensorObserver?.onAppTerminate(data: data)
        default: break
        }
        notificationCenter.post(name: notificationName, object: self)
        notificationCenter.post(name: .actionAwareAppLogger, object: self)
    }

    // MARK: - Heartbeat timer

    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(
            withTimeInterval: CONFIG.heartbeatInterval,
            repeats: true
        ) { [weak self] _ in
            self?.saveHeartbeat()
        }
    }

    private func stopHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func saveHeartbeat() {
        var data = AppHeartbeatData(label: CONFIG.label)
        data.deviceId = AwareUtils.getCommonDeviceId()
        saveModels([data])
        CONFIG.sensorObserver?.onHeartbeat(data: data)
        notificationCenter.post(name: .actionAwareAppLoggerHeartbeat, object: self)
        notificationCenter.post(name: .actionAwareAppLogger, object: self)
    }

    // MARK: - DB helpers

    private func initializeTables() {
        guard let queue = (self.dbEngine as? SQLiteEngine)?.getSQLiteInstance() else { return }
        do {
            try AppEventsData.createTable(queue: queue)
            try AppHeartbeatData.createTable(queue: queue)
            try AppLogData.createTable(queue: queue)
        } catch {
            if CONFIG.debug { print(error) }
        }
    }

    private func saveModels<T: BaseDbModelSQLite>(_ models: [T]) {
        guard let engine = self.dbEngine as? SQLiteEngine else { return }
        engine.save(models)
    }

    private func makeSyncConfig(from base: DbSyncConfig, completionHandler: DbSyncCompletionHandler?) -> DbSyncConfig {
        let c = DbSyncConfig()
        c.removeAfterSync = base.removeAfterSync
        c.batchSize = base.batchSize
        c.markAsSynced = base.markAsSynced
        c.skipSyncedData = base.skipSyncedData
        c.keepLastData = base.keepLastData
        c.deviceId = base.deviceId
        c.debug = base.debug
        c.debugLevel = base.debugLevel
        c.progressHandler = base.progressHandler
        c.dispatchQueue = base.dispatchQueue
        c.backgroundSession = base.backgroundSession
        c.compactDataFormat = base.compactDataFormat
        c.serverType = base.serverType
        c.test = base.test
        c.completionHandler = completionHandler
        return c
    }

    private func makeSyncEngine(for tableName: String) -> Engine {
        Engine.Builder()
            .setPath(CONFIG.dbPath)
            .setType(CONFIG.dbType)
            .setHost(CONFIG.dbHost)
            .setEncryptionKey(CONFIG.dbEncryptionKey)
            .setTableName(tableName)
            .build()
    }

    private func startSequentialSync(
        for tables: [String],
        syncConfig: DbSyncConfig,
        currentIndex: Int,
        hasFailure: Bool,
        lastError: Error?
    ) {
        guard currentIndex < tables.count else {
            syncConfig.completionHandler?(!hasFailure, lastError)
            return
        }
        let tableName = tables[currentIndex]
        let engine = makeSyncEngine(for: tableName)
        let perConfig = makeSyncConfig(from: syncConfig) { [weak self] status, error in
            guard let self else { return }
            var userInfo: [String: Any] = [
                AppLoggerSensor.EXTRA_STATUS: status,
                AppLoggerSensor.EXTRA_TABLE_NAME: tableName,
            ]
            switch tableName {
            case AppEventsData.databaseTableName:
                userInfo[AppLoggerSensor.EXTRA_OBJECT_TYPE] = AppEventsData.self
            case AppHeartbeatData.databaseTableName:
                userInfo[AppLoggerSensor.EXTRA_OBJECT_TYPE] = AppHeartbeatData.self
            default:
                userInfo[AppLoggerSensor.EXTRA_OBJECT_TYPE] = AppLogData.self
            }
            if let error = error { userInfo[AppLoggerSensor.EXTRA_ERROR] = error }
            self.notificationCenter.post(
                name: .actionAwareAppLoggerSyncCompletion, object: self, userInfo: userInfo)
            self.startSequentialSync(
                for: tables,
                syncConfig: syncConfig,
                currentIndex: currentIndex + 1,
                hasFailure: hasFailure || status == false,
                lastError: error ?? lastError)
        }
        engine.startSync(perConfig)
    }
}
