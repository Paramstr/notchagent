import SwiftUI

struct CapySettingsView: View {
    @Bindable var monitor: CapyMonitor
    @State private var key = ""
    @State private var error: String?
    @AppStorage("capyThreadLinks") private var threadLinks = ""

    var body: some View {
        Section("Capy") {
            Text(monitor.message).font(.caption).foregroundStyle(.secondary)
            SecureField("Capy API key", text: $key)
            TextField("Additional thread links (optional)", text: $threadLinks)
            Text("Use a key acting as you for your requests and private chats. Project chats are discovered automatically. Add links for chats outside projects. The key is stored in macOS Keychain; only read requests are made. Replies and approvals stay in Capy.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Connect Capy") {
                    let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard value.hasPrefix("capy_"), !value.contains(where: { $0.isWhitespace }) else {
                        error = "Enter an API key from Capy Settings → API."; return
                    }
                    do {
                        try CapyCredentialStore.save(value)
                        key = ""; error = nil; monitor.reconnect()
                    } catch { self.error = "Could not save the key in macOS Keychain." }
                }.disabled(key.isEmpty)
                Button("Refresh connection") { monitor.reconnect() }
                Button("Disconnect") {
                    do { try monitor.disconnect(); error = nil }
                    catch { self.error = "Could not remove the saved key from Keychain." }
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
    }
}
