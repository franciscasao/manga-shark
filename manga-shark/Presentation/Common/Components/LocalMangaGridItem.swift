import SwiftUI
import SwiftData

struct LocalMangaGridItem: View {
    let manga: LocalManga
    let deviceUnreadCount: Int

    init(manga: LocalManga, deviceUnreadCount: Int = 0) {
        self.manga = manga
        self.deviceUnreadCount = deviceUnreadCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                AsyncCachedImage(url: manga.thumbnailUrl)
                    .aspectRatio(2/3, contentMode: .fill)
                    .clipped()
                    .cornerRadius(8)

                if deviceUnreadCount > 0 {
                    Text("\(deviceUnreadCount)")
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

#Preview("Single Local Item") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: LocalManga.self, LocalChapter.self, configurations: config)

    let manga = LocalManga(
        serverId: 1,
        sourceId: "preview",
        url: "/manga/1",
        title: "One Piece",
        genres: ["Action", "Adventure"],
        status: "ONGOING"
    )

    return LocalMangaGridItem(manga: manga, deviceUnreadCount: 42)
        .frame(width: 150)
        .modelContainer(container)
}
