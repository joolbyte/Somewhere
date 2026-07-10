//
//  EditorialMosaicLayout.swift
//  Somewhere
//

import SwiftUI

nonisolated struct MosaicAttributes: Equatable, Sendable {
    let span: Int
    let tieBreak: UInt64
}

private nonisolated struct MosaicAttributesKey: LayoutValueKey {
    static let defaultValue = MosaicAttributes(span: 1, tieBreak: 0)
}

nonisolated extension View {
    func mosaicAttributes(_ attributes: MosaicAttributes) -> some View {
        layoutValue(key: MosaicAttributesKey.self, value: attributes)
    }
}

/// A stable, chronological skyline layout. Objects keep their input order, but
/// settle into the lowest contiguous set of tracks that can hold their span.
nonisolated struct EditorialMosaicLayout: Layout {
    let trackCount: Int
    let spacing: CGFloat

    init(trackCount: Int = 3, spacing: CGFloat = 10) {
        self.trackCount = max(1, trackCount)
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 420
        let placements = makePlacements(for: subviews, width: width)
        let height = placements.map { $0.origin.y + $0.size.height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for placement in makePlacements(for: subviews, width: bounds.width) {
            subviews[placement.index].place(
                at: CGPoint(
                    x: bounds.minX + placement.origin.x,
                    y: bounds.minY + placement.origin.y
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(
                    width: placement.size.width,
                    height: placement.size.height
                )
            )
        }
    }

    private func makePlacements(for subviews: Subviews, width: CGFloat) -> [Placement] {
        guard !subviews.isEmpty else { return [] }

        let trackWidth = max(0, (width - CGFloat(trackCount - 1) * spacing) / CGFloat(trackCount))
        var trackHeights = Array(repeating: CGFloat.zero, count: trackCount)
        var placements: [Placement] = []

        for index in subviews.indices {
            let subview = subviews[index]
            let attributes = subview[MosaicAttributesKey.self]
            let span = min(max(attributes.span, 1), trackCount)
            let candidateCount = trackCount - span + 1
            let preferredStart = Int(attributes.tieBreak % UInt64(candidateCount))

            var selectedStart = 0
            var selectedY = CGFloat.greatestFiniteMagnitude
            var selectedTieDistance = Int.max

            for start in 0..<candidateCount {
                let end = start + span
                let y = trackHeights[start..<end].max() ?? 0
                let tieDistance = (start - preferredStart + candidateCount) % candidateCount

                if y < selectedY || (y == selectedY && tieDistance < selectedTieDistance) {
                    selectedStart = start
                    selectedY = y
                    selectedTieDistance = tieDistance
                }
            }

            let itemWidth = CGFloat(span) * trackWidth + CGFloat(span - 1) * spacing
            let proposedSize = ProposedViewSize(width: itemWidth, height: nil)
            var size = subview.sizeThatFits(proposedSize)
            size.width = itemWidth

            let x = CGFloat(selectedStart) * (trackWidth + spacing)
            placements.append(
                Placement(index: index, origin: CGPoint(x: x, y: selectedY), size: size)
            )

            let nextY = selectedY + size.height + spacing
            for track in selectedStart..<(selectedStart + span) {
                trackHeights[track] = nextY
            }
        }

        return placements
    }

    private struct Placement {
        let index: Int
        let origin: CGPoint
        let size: CGSize
    }
}
