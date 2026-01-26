import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            List {
                serverSection
                readerSection
                librarySection
                deviceSection
                aboutSection
                dangerZoneSection
            }
            .navigationTitle("Settings")
            .task {
                await viewModel.loadServerInfo()
            }
            .alert("Reset Server Configuration", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    Task {
                        await viewModel.resetConfiguration()
                        appState.resetSetup()
                    }
                }
            } message: {
                Text("This will disconnect from the current server. You'll need to set up a new connection.")
            }
        }
    }

    private var serverSection: some View {
        Section("Server") {
            if let serverInfo = viewModel.serverInfo {
                LabeledContent("Server", value: serverInfo.name)
                LabeledContent("Version", value: serverInfo.version)
                LabeledContent("Build Type", value: serverInfo.buildType)
            }

            LabeledContent("URL", value: viewModel.serverUrl)

            NavigationLink {
                ServerSetupView()
                    .environmentObject(appState)
            } label: {
                Text("Edit Server Settings")
            }

            Button(action: {
                Task { await viewModel.testConnection() }
            }) {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    if viewModel.isTestingConnection {
                        ProgressView()
                    } else if let success = viewModel.connectionTestResult {
                        Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(success ? .green : .red)
                    }
                }
            }
        }
    }

    private var readerSection: some View {
        Section("Reader") {
            Picker("Default Mode", selection: $viewModel.readerMode) {
                ForEach(ReaderMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Picker("Reading Direction", selection: $viewModel.readingDirection) {
                ForEach(ReadingDirection.allCases, id: \.self) { direction in
                    Text(direction.displayName).tag(direction)
                }
            }
        }
    }

    private var librarySection: some View {
        Section("Library") {
            Picker("Display Mode", selection: $viewModel.libraryDisplayMode) {
                Text("Grid").tag(LibraryDisplayMode.grid)
                Text("List").tag(LibraryDisplayMode.list)
            }

            Toggle("Show NSFW Sources", isOn: $viewModel.showNsfwSources)
        }
    }

    private var deviceSection: some View {
        Section {
            HStack {
                Text("Device ID")
                Spacer()
                Text(DeviceIdentifierManager.shared.deviceId.prefix(8) + "...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Device")
        } footer: {
            Text("Each device tracks reading progress independently. This ID uniquely identifies your device.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")

            if let serverInfo = viewModel.serverInfo {
                Link(destination: URL(string: serverInfo.github)!) {
                    HStack {
                        Text("Suwayomi GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: serverInfo.discord)!) {
                    HStack {
                        Text("Suwayomi Discord")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive, action: {
                showingResetAlert = true
            }) {
                HStack {
                    Image(systemName: "server.rack")
                    Text("Reset Server Configuration")
                }
            }

            Button(role: .destructive, action: {
                Task { await viewModel.clearAllCaches() }
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Caches")
                }
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Clearing caches will remove all locally stored images and data.")
        }
    }
}

enum LibraryDisplayMode: String {
    case grid
    case list
}

struct ServerInfo {
    let name: String
    let version: String
    let buildType: String
    let buildTime: String
    let github: String
    let discord: String
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var serverInfo: ServerInfo?
    @Published var serverUrl: String = ""
    @Published var isTestingConnection = false
    @Published var connectionTestResult: Bool?

    @Published var readerMode: ReaderMode {
        didSet {
            UserDefaults.standard.set(readerMode.rawValue, forKey: UserDefaultsKeys.readerMode)
        }
    }

    @Published var readingDirection: ReadingDirection {
        didSet {
            UserDefaults.standard.set(readingDirection.rawValue, forKey: UserDefaultsKeys.readerDirection)
        }
    }

    @Published var libraryDisplayMode: LibraryDisplayMode {
        didSet {
            UserDefaults.standard.set(libraryDisplayMode.rawValue, forKey: UserDefaultsKeys.libraryDisplayMode)
        }
    }

    @Published var showNsfwSources: Bool {
        didSet {
            UserDefaults.standard.set(showNsfwSources, forKey: UserDefaultsKeys.showNsfwSources)
        }
    }

    init() {
        serverUrl = AuthManager.shared.serverConfig.serverUrl

        if let savedMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.readerMode),
           let mode = ReaderMode(rawValue: savedMode) {
            self.readerMode = mode
        } else {
            self.readerMode = .paged
        }

        if let savedDirection = UserDefaults.standard.string(forKey: UserDefaultsKeys.readerDirection),
           let direction = ReadingDirection(rawValue: savedDirection) {
            self.readingDirection = direction
        } else {
            self.readingDirection = .rightToLeft
        }

        if let savedDisplayMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.libraryDisplayMode),
           let displayMode = LibraryDisplayMode(rawValue: savedDisplayMode) {
            self.libraryDisplayMode = displayMode
        } else {
            self.libraryDisplayMode = .grid
        }

        self.showNsfwSources = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showNsfwSources)
    }

    func loadServerInfo() async {
        do {
            let response: GraphQLResponse<ServerInfoResponse> = try await NetworkClient.shared.executeGraphQL(
                query: GraphQLQueries.getServerInfo,
                responseType: GraphQLResponse<ServerInfoResponse>.self
            )

            if let data = response.data {
                serverInfo = ServerInfo(
                    name: data.aboutServer.name,
                    version: data.aboutServer.version,
                    buildType: data.aboutServer.buildType,
                    buildTime: data.aboutServer.buildTime,
                    github: data.aboutServer.github,
                    discord: data.aboutServer.discord
                )
            }
        } catch {
            // Silently fail for server info
        }
    }

    func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil

        do {
            connectionTestResult = try await AuthManager.shared.testConnection()
        } catch {
            connectionTestResult = false
        }

        isTestingConnection = false
    }

    func resetConfiguration() async {
        await AuthManager.shared.clearConfiguration()
        await clearAllCaches()
    }

    func clearAllCaches() async {
        await SourceRepository.shared.clearCache()
        await MangaRepository.shared.clearCache()
        await LibraryRepository.shared.clearCache()

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
