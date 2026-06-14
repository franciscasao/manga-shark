//
//  ContentView.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import SwiftUI

/// Placeholder content shown while the UI layer is being built out.
///
/// Confirms the app launches and the data/service layer
/// (`SuwayomiService`, `DownloadManager`, `Manga`/`Chapter`/`Source`
/// models) compiles and links correctly.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Manga Shark")
                .font(.title)
                .bold()
            Text("Project scaffolding in progress")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
