// Cuts the foreground subject out of an image using the system Vision model and
// writes a transparent PNG. Usage: cutout <input> <output.png>
import AppKit
import CoreImage
import CoreVideo
import Vision

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { fail("usage: cutout <input> <output.png>") }

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

guard let image = NSImage(contentsOf: inputURL),
      let tiff = image.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let cgImage = representation.cgImage else {
    fail("could not decode \(inputURL.path)")
}

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
let request = VNGenerateForegroundInstanceMaskRequest()
do {
    try handler.perform([request])
} catch {
    fail("foreground mask failed: \(error.localizedDescription)")
}

guard let observation = request.results?.first else {
    fail("no subject found in \(inputURL.lastPathComponent)")
}

let buffer: CVPixelBuffer
do {
    buffer = try observation.generateMaskedImage(
        ofInstances: observation.allInstances,
        from: handler,
        croppedToInstancesExtent: false
    )
} catch {
    fail("could not apply mask: \(error.localizedDescription)")
}

let context = CIContext(options: [.useSoftwareRenderer: false])
let source = CIImage(cvPixelBuffer: buffer)
guard let masked = context.createCGImage(source, from: source.extent) else {
    fail("could not rasterize the masked image")
}

let bitmap = NSBitmapImageRep(cgImage: masked)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fail("could not encode PNG")
}
do {
    try png.write(to: outputURL)
} catch {
    fail("could not write \(outputURL.path): \(error.localizedDescription)")
}

print("wrote \(outputURL.path) \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
