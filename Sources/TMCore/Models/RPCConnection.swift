import Foundation

public struct RPCConnection: Hashable {
    public var host: String
    public var port: Int
    public var rpcPath: String
    public var username: String
    public var password: String

    public init(
        host: String = "localhost",
        port: Int = 9091,
        rpcPath: String = "/transmission/rpc",
        username: String = "",
        password: String = ""
    ) {
        self.host = host
        self.port = port
        self.rpcPath = rpcPath
        self.username = username
        self.password = password
    }

    public var baseURLString: String {
        "http://\(host):\(port)\(rpcPath)"
    }
}
