// 앱 아이콘 원본 → App Store 규격 1024x1024, 알파 없는 PNG 로 변환
// 사용: swift scripts/make_icon.swift <원본.png> <출력.png>
// 원본의 둥근 모서리 바깥을 배경색으로 채운다 (iOS/watchOS 가 자체 마스크를 적용하므로).
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3,
      let source = NSImage(contentsOfFile: args[1]),
      let cgSource = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write("usage: make_icon.swift <input.png> <output.png>\n".data(using: .utf8)!)
    exit(1)
}

let size = 1024
let rect = CGRect(x: 0, y: 0, width: size, height: size)
guard let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(1) }

// 배경색: 원본 왼쪽 가장자리 안쪽 중간 픽셀 (아이콘 바탕색)
let sampleRep = NSBitmapImageRep(cgImage: cgSource)
let sample = sampleRep.colorAt(x: cgSource.width / 20, y: cgSource.height / 2) ?? .black
context.setFillColor(sample.usingColorSpace(.sRGB)!.cgColor)
context.fill(rect)

// 원본 모서리(흰색/투명)만 배경색으로 덮이도록, 원본보다 약간 큰 반경의 둥근 사각형으로 잘라서 그린다
context.interpolationQuality = .high
let clip = CGPath(roundedRect: rect, cornerWidth: 240, cornerHeight: 240, transform: nil)
context.addPath(clip)
context.clip()
context.draw(cgSource, in: rect)

guard let output = context.makeImage(),
      let data = NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:])
else { exit(1) }
try data.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2]) \(size)x\(size)")
