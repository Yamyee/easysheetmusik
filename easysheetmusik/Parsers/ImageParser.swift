import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

final class ImageParser: ScoreParserProtocol {
    private static let ciContext = CIContext()

    func parse(data: Data, fileName: String?) throws -> MusicScore {
        guard let image = UIImage(data: data) else {
            throw ParserError.invalidFormat
        }

        let title = fileName.map { ($0 as NSString).deletingPathExtension } ?? T("图片乐谱", "Image Score")
        let enhancedImage = enhanceImage(image)
        return MusicScore(
            id: UUID(),
            title: title,
            artist: nil,
            pages: [ScorePage(number: 1, content: .image(enhancedImage))],
            sourceFormat: .image,
            importedAt: Date(),
            sourceText: nil,
            folder: nil,
            tags: [],
            playbackEvents: nil
        )
    }

    private func enhanceImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.55
        request.minimumAspectRatio = 0.35
        request.quadratureTolerance = 30

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
        try? handler.perform([request])

        let cropped = request.results?.first.flatMap {
            perspectiveCorrect(image, rectangle: $0)
        } ?? image
        return increaseContrast(cropped)
    }

    private func perspectiveCorrect(_ image: UIImage, rectangle: VNRectangleObservation) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = rectangle.topLeft.scaled(to: extent)
        filter.topRight = rectangle.topRight.scaled(to: extent)
        filter.bottomLeft = rectangle.bottomLeft.scaled(to: extent)
        filter.bottomRight = rectangle.bottomRight.scaled(to: extent)
        guard let output = filter.outputImage,
              let cgImage = Self.ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private func increaseContrast(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.contrast = 1.18
        filter.brightness = 0.02
        guard let output = filter.outputImage,
              let cgImage = Self.ciContext.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }
}

private extension CGPoint {
    func scaled(to extent: CGRect) -> CGPoint {
        CGPoint(x: x * extent.width + extent.minX, y: y * extent.height + extent.minY)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
