import SwiftUI

/// Stroked circle with an arc starting at 12 o'clock. All rings are decorative —
/// callers hide them from accessibility and carry the value in adjacent text.
struct ProgressRing: View {
    let fraction: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let track: Color
    let arc: Color
    var dashedTrack = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    track,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        dash: dashedTrack ? [0.5, lineWidth * 1.8] : []
                    )
                )
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(arc, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
