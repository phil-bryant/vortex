import Foundation
import Piston

@_silgen_name("FountainConfigure")
private func FountainConfigureC(_ databasePath: UnsafePointer<CChar>) -> Bool

@_silgen_name("FountainSetInstallID")
private func FountainSetInstallIDC(_ installID: UnsafePointer<CChar>)

@_silgen_name("FountainSetSessionID")
private func FountainSetSessionIDC(_ sessionID: UnsafePointer<CChar>)

@_silgen_name("FountainSetAppMetadata")
private func FountainSetAppMetadataC(
    _ bundleID: UnsafePointer<CChar>,
    _ appVersion: UnsafePointer<CChar>,
    _ build: UnsafePointer<CChar>,
    _ osName: UnsafePointer<CChar>,
    _ osVersion: UnsafePointer<CChar>,
    _ arch: UnsafePointer<CChar>
)

@_silgen_name("FountainLogEvent")
private func FountainLogEventC(
    _ level: Int32,
    _ eventName: UnsafePointer<CChar>,
    _ component: UnsafePointer<CChar>,
    _ fields: UnsafeRawPointer?,
    _ fieldCount: Int
)

struct AlwaysOnConsentProvider: DiagnosticsConsentProvider {
    var diagnosticsUploadEnabled: Bool { true }
}

enum HarnessError: Error {
    case invalidEndpoint
    case fountainConfigureFailed(String)
}

@main
struct VortexHarness {
    static func main() async throws {
        let endpointRaw = ProcessInfo.processInfo.environment["VORTEX_MANIFOLD_URL"] ?? "http://127.0.0.1:18080/v1/events/batch"
        let dbPath = ProcessInfo.processInfo.environment["VORTEX_FOUNTAIN_DB_PATH"] ?? "/tmp/vortex-fountain.sqlite3"
        let eventName = ProcessInfo.processInfo.environment["VORTEX_E2E_EVENT_NAME"] ?? "vortex.e2e.smoketest"

        guard let endpointURL = URL(string: endpointRaw) else {
            throw HarnessError.invalidEndpoint
        }

        FileManager.default.createFile(atPath: dbPath, contents: nil)
        let configured = dbPath.withCString { FountainConfigureC($0) }
        guard configured else {
            throw HarnessError.fountainConfigureFailed(dbPath)
        }

        "vortex-e2e-install".withCString(FountainSetInstallIDC)
        "vortex-e2e-session".withCString(FountainSetSessionIDC)
        "dev.vortex.harness".withCString { bundleID in
            "0.1.0".withCString { appVersion in
                "1".withCString { build in
                    "macOS".withCString { osName in
                        "13+".withCString { osVersion in
                            "arm64".withCString { arch in
                                FountainSetAppMetadataC(bundleID, appVersion, build, osName, osVersion, arch)
                            }
                        }
                    }
                }
            }
        }

        eventName.withCString { eventNamePtr in
            "vortex.harness".withCString { componentPtr in
                FountainLogEventC(1, eventNamePtr, componentPtr, nil, 0)
            }
        }

        let uploader = PistonUploader(
            endpointURL: endpointURL,
            configuration: .init(
                maxEventsPerBatch: 20,
                maxBatchBytes: 256 * 1024,
                uploadTimeoutSeconds: 30,
                minimumUploadIntervalSeconds: 300,
                allowsCellularOrExpensiveNetwork: true,
                userAgent: "VortexHarness/0.1.0"
            ),
            consentProvider: AlwaysOnConsentProvider()
        )

        await uploader.flushNow()
        uploader.stop()
        print("Uploaded one Fountain batch through Piston.")
    }
}
