//
//  RootView.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import SwiftUI

/// Top-level view shown by `manga_sharkApp`.
///
/// TODO: This currently shows `LibraryView` directly. The previous
/// implementation routed between `ServerSetupView` and `MainTabView`
/// based on whether a server was configured — reintroduce that routing
/// (driven by `AppConfig`/a settings store) once the UI layer is rebuilt.
struct RootView: View {
    var body: some View {
        LibraryView()
    }
}

#Preview {
    RootView()
}
