import Foundation
import CoreGraphics
import CoreImage
import Vision

/// Finder papirarket på fotoet og retter perspektivet, så tegningen bliver set lige på.
/// Fejler stille: hvis der ikke findes et tydeligt ark, returneres billedet uændret.
enum PaperDetector {

    static func straightened(_ image: CGImage) -> CGImage {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.35
        request.minimumConfidence = 0.7
        request.maximumObservations = 1
        request.quadratureTolerance = 20

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return image
        }
        guard let rect = request.results?.first else { return image }

        let w = CGFloat(image.width), h = CGFloat(image.height)
        // Vision og Core Image har begge origo nederst til venstre, så vi kan gange direkte op.
        let ci = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return image }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: CGPoint(x: rect.topLeft.x * w, y: rect.topLeft.y * h)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: CGPoint(x: rect.topRight.x * w, y: rect.topRight.y * h)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: CGPoint(x: rect.bottomLeft.x * w, y: rect.bottomLeft.y * h)), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: CGPoint(x: rect.bottomRight.x * w, y: rect.bottomRight.y * h)), forKey: "inputBottomRight")
        guard let output = filter.outputImage else { return image }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let result = context.createCGImage(output, from: output.extent) else { return image }
        // Hvis arket fylder næsten hele billedet er rettelsen ligegyldig - og kan forvrænge. Spring over.
        let areaRatio = (output.extent.width * output.extent.height) / (w * h)
        if areaRatio > 0.97 { return image }
        return result
    }

    /// Valgfri ekstra oprydning: Apples motiv-udskæring. Bruges til fotos hvor tegningen ikke ligger på hvidt papir.
    static func subjectMask(_ image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let obs = request.results?.first else { return nil }
            let buffer = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
            let ci = CIImage(cvPixelBuffer: buffer)
            return CIContext().createCGImage(ci, from: ci.extent)
        } catch {
            return nil
        }
    }
}
