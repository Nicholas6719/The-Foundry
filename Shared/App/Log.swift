import os

nonisolated enum Log {
    static let app = Logger(subsystem: "com.nicholas6719.foundry", category: "app")
    static let data = Logger(subsystem: "com.nicholas6719.foundry", category: "data")
    static let health = Logger(subsystem: "com.nicholas6719.foundry", category: "health")
    static let focus = Logger(subsystem: "com.nicholas6719.foundry", category: "focus")
}
