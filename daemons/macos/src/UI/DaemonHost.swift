import Darwin
import Foundation

enum DaemonHost {
    static var computerName: String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }

    static var localIPv4: String? {
        var best: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let first = ifaddr {
            for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
                let interface = ptr.pointee
                let flags = Int32(interface.ifa_flags)
                if (flags & IFF_UP) == IFF_UP,
                    (flags & IFF_RUNNING) == IFF_RUNNING,
                    (flags & IFF_LOOPBACK) == 0,
                    interface.ifa_addr.pointee.sa_family == UInt8(AF_INET)
                {
                    let name = String(cString: interface.ifa_name)
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST
                    )
                    let ip = String(cString: hostname)
                    if name.hasPrefix("en") {
                        freeifaddrs(ifaddr)
                        return ip
                    }
                    if best == nil {
                        best = ip
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return best
    }
}
