import SwiftUI

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 120, 60, 180)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UIColor Brightness Helper
extension UIColor {
    /// Returns a new color with the brightness adjusted to the given value (0–1).
    /// Optionally scale saturation (e.g. 0.5 = half the original saturation).
    func adjusted(brightness target: CGFloat, saturationScale: CGFloat = 1.0) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: min(s * saturationScale, 1), brightness: min(max(target, 0), 1), alpha: a)
    }
}

// MARK: - Curated Folders Grid Destination
struct CuratedFoldersDestination: Hashable {}

// MARK: - Individual Folder Detail Destination
struct FolderDetailDestination: Hashable {
    let folderId: String
}

// MARK: - You Might Like Grid Destination
struct YouMightLikeDestination: Hashable {}

// MARK: - Section card → detail pager (full section list so user can swipe between podcasts)
struct PodcastNavDestination: Hashable {
    let podcasts: [PodcastSummary]
    let startIndex: Int
    let zoomSourceID: String
}

// MARK: - Category section header → grid page navigation
struct CategorySectionDestination: Hashable {
    let categoryId: String
    let title: String
}

// MARK: - Curated Folder (genre-based, populated from iTunes charts API)
struct CuratedFolder: Identifiable {
    let id: String
    let name: String
    let genreId: Int
    var podcasts: [TopPodcast] = []
    var isLoading: Bool = true
}

extension CuratedFolder {
    static let all: [CuratedFolder] = [
        .init(id: "tech",          name: "Tech",          genreId: 1318),
        .init(id: "news",          name: "News",          genreId: 1489),
        .init(id: "science",       name: "Science",       genreId: 1533),
        .init(id: "culture",       name: "Culture",       genreId: 1302),
        .init(id: "education",     name: "Education",     genreId: 1304),
        .init(id: "business",      name: "Business",      genreId: 1321),
        .init(id: "design",        name: "Design",        genreId: 1301),
        .init(id: "product",       name: "Product",       genreId: 1318),
        .init(id: "health",        name: "Health",        genreId: 1512),
        .init(id: "truecrime",     name: "True Crime",    genreId: 1488),
        .init(id: "entertainment", name: "Entertainment", genreId: 1309),
    ]
}

// MARK: - Mood Model

struct PodcastMood: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let genreIds: [Int]
    let minSeconds: Int?   // nil = no lower bound
    let maxSeconds: Int?   // nil = no upper bound

    static let all: [PodcastMood] = [
        .init(id: "commute",   name: "Commute",    icon: "car.fill",             color: Color(hex: "#E8820C"), genreIds: [1489, 1321], minSeconds: 900,  maxSeconds: 2700),
        .init(id: "walking",   name: "Walking",    icon: "figure.walk",          color: Color(hex: "#2A6B5E"), genreIds: [1468, 1512], minSeconds: 600,  maxSeconds: 1800),
        .init(id: "focus",     name: "Focus",      icon: "target",               color: Color(hex: "#1E3A6E"), genreIds: [1318, 1477, 1304], minSeconds: 2700, maxSeconds: nil),
        .init(id: "latenight", name: "Late Night", icon: "moon.zzz.fill",        color: Color(hex: "#2D1B4E"), genreIds: [1488, 1309], minSeconds: nil,  maxSeconds: nil),
        .init(id: "journey",   name: "Journey",    icon: "airplane",             color: Color(hex: "#1A4A6B"), genreIds: [1260, 1487], minSeconds: 3600, maxSeconds: nil),
        .init(id: "bored",     name: "Bored",      icon: "sparkles.tv.fill",      color: Color(hex: "#6B1A4A"), genreIds: [1303, 1309], minSeconds: nil,  maxSeconds: nil),
    ]
}

// MARK: - Podcast Category (genre-based sections on Home)

struct PodcastCategory: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let genreId: Int
    var curatedIds: [String]? = nil   // if set, batch-lookup overrides genre fetch

    static let all: [PodcastCategory] = [
        .init(id: "tech",          title: "Tech",          subtitle: "Product, AI and startup conversations",              genreId: 1318),
        .init(id: "news",          title: "News",          subtitle: "Breaking stories, explainers, and daily headlines",  genreId: 1489),
        .init(id: "business",      title: "Business",      subtitle: "Markets, operators and company strategy",            genreId: 1321),
        .init(id: "design",        title: "Design",        subtitle: "Product design, UX, and the craft of making",        genreId: 1402),
        .init(
            id: "product",
            title: "Product",
            subtitle: "Product thinking, growth and building what matters",
            genreId: 1321,   // fallback only
            curatedIds: [
                "1447537524", // Lenny's Podcast: Product | Growth | Career
                "1227971746", // Masters of Scale — Reid Hoffman
                "1150510297", // How I Built This — Guy Raz
                "1050462261", // Acquired
                "842818711",  // a16z Podcast
                "1028908750", // 20VC: The Twenty Minute VC
                "863897795",  // The Tim Ferriss Show
                "990149481",  // The Knowledge Project — Shane Parrish
                "1236907421", // Y Combinator Podcast
                "1177526500", // Indie Hackers
                "315114957",  // This Week in Startups
                "1152000936", // Invest Like the Best
                "1527315836", // The Bootstrapped Founder
                "862714883",  // Product Hunt Radio
                "1615369263", // Hardcore Software — Steven Sinofsky
            ]
        ),
        .init(id: "health",        title: "Health",        subtitle: "Wellness, medicine and everyday health guidance",    genreId: 1512),
        .init(id: "science",       title: "Science",       subtitle: "Research-backed stories from science and space",     genreId: 1477),
        .init(id: "culture",       title: "Culture",       subtitle: "Ideas, arts and culture commentary",                 genreId: 1324),
        .init(id: "education",     title: "Education",     subtitle: "Learning-first shows for practical growth",          genreId: 1304),
        .init(id: "truecrime",     title: "True Crime",    subtitle: "Investigative crime stories and case breakdowns",    genreId: 1488),
        .init(id: "entertainment", title: "Entertainment", subtitle: "Film, TV, and pop-culture conversations",            genreId: 1309),
    ]
}

// MARK: - Safe Array Subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
