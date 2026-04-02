import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .feed

    enum Tab: String {
        case feed, map, report, activity
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "newspaper.fill")
                }
                .tag(Tab.feed)

            MapExploreView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.map)

            SubmitReportView()
                .tabItem {
                    Label("Report", systemImage: "plus.circle.fill")
                }
                .tag(Tab.report)

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }
                .tag(Tab.activity)
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
}
