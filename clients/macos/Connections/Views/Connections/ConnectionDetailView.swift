import SwiftUI

struct ConnectionDetailView: View {
    let connection: Connection
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 16) {
                    if let photo = connection.photo, let url = URL(string: photo) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        HStack(spacing: 12) {
                            Label("\(connection.feedCount) feeds", systemImage: "list.bullet")
                            Label("\(connection.uriCount) URIs", systemImage: "doc.text")
                            if connection.unreadUriCount > 0 {
                                Label("\(connection.unreadUriCount) unread", systemImage: "circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Tags
                if !connection.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tags")
                            .font(.headline)
                        FlowLayout(spacing: 6) {
                            ForEach(connection.tags) { tag in
                                Text(tag.name)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Metadata
                if !connection.metadata.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Metadata")
                            .font(.headline)
                        ForEach(connection.metadata) { meta in
                            HStack {
                                Text(meta.fieldType.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, alignment: .trailing)
                                if meta.value.hasPrefix("http") {
                                    Link(meta.value, destination: URL(string: meta.value)!)
                                        .font(.caption)
                                } else {
                                    Text(meta.value)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }

                // Note
                if let note = connection.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note")
                            .font(.headline)
                        Text(note)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
