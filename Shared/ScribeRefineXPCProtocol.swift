import Foundation

let scribeRefineXPCServiceName = "com.prakashjoshipax.Scribe.RefineXPC"
let scribeRefineXPCErrorDomain = "com.prakashjoshipax.Scribe.RefineXPC"

struct ScribeRefinePrepareRequest: Codable, Sendable {
    let requestID: UUID
    let modelDirectoryPath: String
    let systemPrompt: String
}

struct ScribeRefineEnhanceRequest: Codable, Sendable {
    let requestID: UUID
    let modelDirectoryPath: String
    let systemPrompt: String
    let transcript: String
}

struct ScribeRefineEnhanceResponse: Codable, Sendable {
    let requestID: UUID
    let output: String
}

enum ScribeRefineXPCErrorCode: Int {
    case invalidRequest = 1
    case inferenceFailed = 2
    case invalidResponse = 3
    case connectionFailed = 4
}

@objc protocol ScribeRefineXPCProtocol {
    func prepare(
        _ requestData: NSData,
        withReply reply: @escaping (NSError?) -> Void
    )

    func enhance(
        _ requestData: NSData,
        withReply reply: @escaping (NSData?, NSError?) -> Void
    )

    func shutdown(withReply reply: @escaping () -> Void)
}

func makeScribeRefineXPCError(
    _ code: ScribeRefineXPCErrorCode,
    description: String
) -> NSError {
    NSError(
        domain: scribeRefineXPCErrorDomain,
        code: code.rawValue,
        userInfo: [NSLocalizedDescriptionKey: description]
    )
}
