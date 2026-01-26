import SwiftUI
import Combine

struct ServerSetupView: View {
    @StateObject private var viewModel = ServerSetupViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 60))
                            .foregroundStyle(.tint)

                        Text("Connect to Suwayomi")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Enter your Suwayomi server URL to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .listRowBackground(Color.clear)

                Section("Server URL") {
                    TextField("http://192.168.1.100:4567", text: $viewModel.serverUrl)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }

                Section("Authentication") {
                    Picker("Auth Type", selection: $viewModel.authType) {
                        ForEach(ServerConfig.AuthType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    if viewModel.authType == .basic {
                        TextField("Username", text: $viewModel.username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.testConnection()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text("Test Connection")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }

                if let connectionStatus = viewModel.connectionStatus {
                    Section {
                        HStack {
                            Image(systemName: connectionStatus.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(connectionStatus.isSuccess ? .green : .red)
                            Text(connectionStatus.message)
                                .foregroundColor(connectionStatus.isSuccess ? Color.primary : .red)
                        }
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.saveConfiguration()
                            appState.completeSetup()
                        }
                    }) {
                        Text("Save & Continue")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(!viewModel.canSave || viewModel.isLoading)
                }
            }
            .navigationTitle("Server Setup")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }
}

@MainActor
final class ServerSetupViewModel: ObservableObject {
    @Published var serverUrl: String = ""
    @Published var authType: ServerConfig.AuthType = .none
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var connectionStatus: ConnectionStatus?
    @Published var showError: Bool = false
    @Published var errorMessage: String?

    struct ConnectionStatus {
        let isSuccess: Bool
        let message: String
    }

    var isValid: Bool {
        guard let url = URL(string: serverUrl),
              url.scheme != nil,
              url.host != nil else {
            return false
        }

        if authType == .basic {
            return !username.isEmpty && !password.isEmpty
        }

        return true
    }

    var canSave: Bool {
        isValid && connectionStatus?.isSuccess == true
    }

    init() {
        let authManager = AuthManager.shared
        if !authManager.serverConfig.serverUrl.isEmpty {
            serverUrl = authManager.serverConfig.serverUrl
            authType = authManager.serverConfig.authType
            username = authManager.serverConfig.username ?? ""
            password = authManager.serverConfig.password ?? ""
        }
    }

    func testConnection() async {
        isLoading = true
        connectionStatus = nil

        let config = ServerConfig(
            serverUrl: serverUrl,
            authType: authType,
            username: authType == .basic ? username : nil,
            password: authType == .basic ? password : nil
        )

        do {
            try await AuthManager.shared.configure(with: config)
            let success = try await AuthManager.shared.testConnection()

            if success {
                connectionStatus = ConnectionStatus(isSuccess: true, message: "Connection successful!")
            } else {
                connectionStatus = ConnectionStatus(isSuccess: false, message: "Connection failed")
            }
        } catch {
            connectionStatus = ConnectionStatus(isSuccess: false, message: error.localizedDescription)
        }

        isLoading = false
    }

    func saveConfiguration() async {
        isLoading = true

        let config = ServerConfig(
            serverUrl: serverUrl,
            authType: authType,
            username: authType == .basic ? username : nil,
            password: authType == .basic ? password : nil
        )

        do {
            try await AuthManager.shared.configure(with: config)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }
}

#Preview {
    ServerSetupView()
        .environmentObject(AppState.shared)
}
