import SwiftUI

struct ConfettiView: View {
    @State private var progress = 0.0

    private let palette: [Color] = [
        .pink,
        .orange,
        .yellow,
        .green,
        .blue,
        .mint,
    ]

    var body: some View {
        Canvas { canvas, size in
            for index in 0 ..< 36 {
                let baseX = CGFloat((index * 31) % 100) / 100
                let baseDelay = Double((index * 17) % 20) / 20
                let fall = (progress + baseDelay).truncatingRemainder(dividingBy: 1)
                let x = size.width * baseX
                let y = size.height * fall
                let rotation = Angle.degrees((progress * 1080) + Double(index * 19))
                let pieceSize = CGSize(
                    width: 7 + CGFloat(index % 5),
                    height: 10 + CGFloat((index + 2) % 6)
                )

                var context = canvas
                context.translateBy(x: x, y: y)
                context.rotate(by: rotation)
                context.fill(
                    Path(CGRect(
                        x: -pieceSize.width / 2,
                        y: -pieceSize.height / 2,
                        width: pieceSize.width,
                        height: pieceSize.height
                    )),
                    with: .color(palette[index % palette.count].opacity(0.9))
                )
            }
        }
        .onAppear {
            progress = 0
            withAnimation(.linear(duration: 3.8).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
        .allowsHitTesting(false)
    }
}
