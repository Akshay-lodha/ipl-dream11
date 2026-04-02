import SwiftUI

struct DiscussionView: View {
    let discussion: Discussion
    @State private var newMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            LazyVStack(spacing: 12) {
                ForEach(discussion.messages) { message in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: message.author.avatarSystemName)
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(message.author.displayName)
                                    .font(.caption.weight(.semibold))
                                Text(message.timestamp.formatted(.relative(presentation: .named)))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text(message.text)
                                .font(.subheadline)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }

            Spacer(minLength: 16)

            // Compose bar
            HStack(spacing: 10) {
                TextField("Add to the discussion...", text: $newMessage)
                    .textFieldStyle(.roundedBorder)

                Button {
                    newMessage = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(.bar)
        }
    }
}

#Preview {
    DiscussionView(discussion: MockData.nexusEvents[0].discussions[0])
}
