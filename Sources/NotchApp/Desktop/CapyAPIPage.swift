import Foundation

struct CapyAPIPage<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let cursor: String?
}
