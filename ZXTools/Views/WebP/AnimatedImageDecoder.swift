import Foundation
import ImageIO
import AppKit

struct AnimatedImageFrame: Identifiable {
    let id: Int
    let image: NSImage
    let duration: TimeInterval
    let pixelBytes: UInt64
}

struct AnimatedImageAnalysis {
    let fileURL: URL
    let fileSize: UInt64
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: TimeInterval
    let frames: [AnimatedImageFrame]

    var decodedBytes: UInt64 {
        frames.reduce(0) { $0 + $1.pixelBytes }
    }

    var averageFrameRate: Double {
        guard duration > 0 else { return 0 }
        return Double(frames.count) / duration
    }
}

enum AnimatedImageDecoderError: LocalizedError {
    case unsupportedFile
    case noFrames
    case decodeFailed(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "无法读取该文件，请选择 GIF 或 WebP 动图。"
        case .noFrames:
            return "文件中没有可解码的图像帧。"
        case .decodeFailed(let index):
            return "第 \(index + 1) 帧解码失败。"
        }
    }
}

enum AnimatedImageDecoder {
    static func decode(url: URL) throws -> AnimatedImageAnalysis {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw AnimatedImageDecoderError.unsupportedFile
        }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw AnimatedImageDecoderError.noFrames }

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (fileAttributes[.size] as? NSNumber)?.uint64Value ?? 0
        var frames: [AnimatedImageFrame] = []
        frames.reserveCapacity(count)

        var width = 0
        var height = 0
        var totalDuration: TimeInterval = 0

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, [
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary) else {
                throw AnimatedImageDecoderError.decodeFailed(index)
            }

            width = max(width, cgImage.width)
            height = max(height, cgImage.height)
            let duration = frameDuration(source: source, index: index)
            totalDuration += duration
            let bytes = UInt64(cgImage.bytesPerRow) * UInt64(cgImage.height)
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            frames.append(AnimatedImageFrame(id: index, image: image, duration: duration, pixelBytes: bytes))
        }

        return AnimatedImageAnalysis(
            fileURL: url,
            fileSize: fileSize,
            pixelWidth: width,
            pixelHeight: height,
            duration: totalDuration,
            frames: frames
        )
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return 0.1
        }

        let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let webPKey = "{WebP}" as CFString
        let webP = properties[webPKey] as? [CFString: Any]

        let candidates: [Any?] = [
            gif?[kCGImagePropertyGIFUnclampedDelayTime],
            gif?[kCGImagePropertyGIFDelayTime],
            webP?["UnclampedDelayTime" as CFString],
            webP?["DelayTime" as CFString]
        ]

        for candidate in candidates {
            if let number = candidate as? NSNumber {
                return max(number.doubleValue, 0.02)
            }
        }
        return 0.1
    }
}
