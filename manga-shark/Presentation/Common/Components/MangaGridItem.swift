import SwiftUI

struct MangaGridItem: View {
    let manga: Manga

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                AsyncCachedImage(url: manga.thumbnailUrl)
                    .aspectRatio(2/3, contentMode: .fill)
                    .clipped()
                    .cornerRadius(8)

                if manga.unreadCount > 0 {
                    Text("\(manga.unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                        .padding(4)
                }
            }

            Text(manga.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

struct AsyncCachedImage: View {
    let url: String?
    @State private var imageData: Data?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                        }
                    }
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url, !url.isEmpty else { return }
        guard imageData == nil else { return }

        isLoading = true
        do {
            imageData = try await NetworkClient.shared.fetchImage(from: url)
        } catch {
            // Image failed to load, will show placeholder
        }
        isLoading = false
    }
}

// iOS 16 compatible replacement for ContentUnavailableView
struct EmptyStateView<Label: View, Description: View>: View {
    let label: Label
    let description: Description

    init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description) {
        self.label = label()
        self.description = description()
    }

    var body: some View {
        VStack(spacing: 12) {
            label
                .font(.title2)
                .foregroundStyle(.secondary)
            description
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct SearchEmptyView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
            Text("No results for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    MangaGridItem(manga: Manga(
        id: 1,
        sourceId: "test",
        url: "/manga/1",
        title: "One Piece",
        thumbnailUrl: nil,
        unreadCount: 42
    ))
    .frame(width: 150)
}
