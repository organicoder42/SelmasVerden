import SwiftUI
import CoreGraphics

#if canImport(UIKit)
import UIKit

/// Kameraet, pakket ind så det kan bruges fra SwiftUI. Giver et CGImage der vender rigtigt.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (CGImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (CGImage?) -> Void
        init(onImage: @escaping (CGImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let ui = info[.originalImage] as? UIImage
            // Gå via JPEG-data så EXIF-orienteringen bliver bagt ind i pixels.
            if let data = ui?.jpegData(compressionQuality: 0.95) {
                onImage(ImageIO.loadOrientedCGImage(from: data))
            } else {
                onImage(nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
        }
    }

    static var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
}
#else
/// På Mac (kun til typetjek/forhåndsvisning) er der ikke noget kamera.
struct CameraPicker: View {
    let onImage: (CGImage?) -> Void
    var body: some View { Text("Kameraet er kun på iPad/iPhone.").onAppear { onImage(nil) } }
    static var isCameraAvailable: Bool { false }
}
#endif
