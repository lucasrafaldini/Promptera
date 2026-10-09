import Foundation

public enum SystemInfo {
    /// Marketing name of the CPU, e.g. "Apple M4 Pro".
    public static let chipName: String = {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return "Apple Silicon"
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else {
            return "Apple Silicon"
        }
        return String(cString: buffer)
    }()

    /// Installed unified memory, e.g. "24 GB".
    public static let memoryDescription: String = {
        let gigabytes = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return "\(Int(gigabytes.rounded())) GB"
    }()

    /// CFBundleShortVersionString when running from the .app bundle.
    public static let appVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0"
    }()
}
