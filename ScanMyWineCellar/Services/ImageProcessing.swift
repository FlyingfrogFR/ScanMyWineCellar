import UIKit

/// Image helpers shared by the scan flows. Photos are downscaled the moment
/// they enter the app: modern iPhone photos decode to ~200 MB each at full
/// resolution, and holding several kills the app with a memory termination.
enum ImageProcessing {
    /// Long-edge target used for both display and API upload. Claude reads
    /// labels fine at this size.
    static let maxDimension: CGFloat = 2048

    /// Returns the image scaled down so its long edge is at most
    /// `maxDimension`; returns the original if it's already small enough.
    static func downscaled(_ image: UIImage, maxDimension: CGFloat = maxDimension) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxDimension else { return image }
        let scale = maxDimension / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// JPEG for API upload, downscaling first if needed.
    static func uploadJPEG(_ image: UIImage) -> Data? {
        downscaled(image).jpegData(compressionQuality: 0.75)
    }
}
