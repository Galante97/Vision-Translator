//
//  ViewController.swift
//  vision Translator
//
//  Created by James Galante on 4/11/18.
//  Copyright © 2018 James Galante. All rights reserved.
//

import AVFoundation
import UIKit
import Vision

class ViewController: UIViewController {

    @IBOutlet weak var cameraView: UIView!
    
    


override func viewDidLoad() {
    super.viewDidLoad()
    
    
    let k = DrawRect(frame: CGRect(
        origin: CGPoint(x: 50, y: 50),
        size: CGSize(width: 100, height: 100)))
    self.view.addSubview(k)
    k.backgroundColor = UIColor.clear
    k.bringSubview(toFront: view);
    
    //tesseract OCR
    tesseract?.pageSegmentationMode = .sparseText
    tesseract?.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890()-+*!/?.,@#$%&"
    
    if isAuthorized() {
        configureTextDetection()
        configureCamera()
    }
    
}

override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
}
    
    
// MARK: - Text Requests and setup
    
private func configureTextDetection() {
    textDetectionRequest = VNDetectTextRectanglesRequest(completionHandler: handleDetection)
    textDetectionRequest!.reportCharacterBoxes = true
}
private func configureCamera() {
    preview.session = session
    
    let cameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
    var cameraDevice: AVCaptureDevice?
    for device in cameraDevices.devices {
        if device.position == .back {
            cameraDevice = device
            break
        }
    }
    do {
        let captureDeviceInput = try AVCaptureDeviceInput(device: cameraDevice!)
        if session.canAddInput(captureDeviceInput) {
            session.addInput(captureDeviceInput)
        }
    }
    catch {
        print("Error occured \(error)")
        return
    }
    session.sessionPreset = .high
    let videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "Buffer Queue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil))
    if session.canAddOutput(videoDataOutput) {
        session.addOutput(videoDataOutput)
    }
    preview.videoPreviewLayer.videoGravity = .resize
    session.startRunning()
}
private func handleDetection(request: VNRequest, error: Error?) {
    
    guard let detectionResults = request.results else {
        print("No detection results")
        return
    }
    let textResults = detectionResults.map() {
        return $0 as? VNTextObservation
    }
    if textResults.isEmpty {
        return
    }
    textObservations = textResults as! [VNTextObservation]
    DispatchQueue.main.async {
        
        guard let sublayers = self.cameraView.layer.sublayers else {
            return
        }
        for layer in sublayers[1...] {
            if (layer as? CATextLayer) == nil {
                layer.removeFromSuperlayer()
            }
        }
        let viewWidth = self.cameraView.frame.size.width
        let viewHeight = self.cameraView.frame.size.height
        for result in textResults {

            if let textResult = result {
                
                let layer = CALayer()
                var rect = textResult.boundingBox
                rect.origin.x *= viewWidth
                rect.size.height *= viewHeight
                rect.origin.y = ((1 - rect.origin.y) * viewHeight) - rect.size.height
                rect.size.width *= viewWidth

                layer.frame = rect
                layer.borderWidth = 2
                layer.borderColor = UIColor.red.cgColor
                self.cameraView.layer.addSublayer(layer)
            }
        }
    }
}
private var preview: PreviewView {
    return cameraView as! PreviewView
}
private func isAuthorized() -> Bool {
    let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    switch authorizationStatus {
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: AVMediaType.video,
                                      completionHandler: { (granted:Bool) -> Void in
                                        if granted {
                                            DispatchQueue.main.async {
                                                self.configureTextDetection()
                                                self.configureCamera()
                                            }
                                        }
        })
        return true
    case .authorized:
        return true
    case .denied, .restricted: return false
    }
}
private var textDetectionRequest: VNDetectTextRectanglesRequest?
private let session = AVCaptureSession()
private var textObservations = [VNTextObservation]()
private var tesseract = G8Tesseract(language: "eng", engineMode: .tesseractOnly)
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
// MARK: - Camera Delegate and Setup
func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        return
    }
    var imageRequestOptions = [VNImageOption: Any]()
    if let cameraData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
        imageRequestOptions[.cameraIntrinsics] = cameraData
    }
    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: imageRequestOptions)
    do {
        try imageRequestHandler.perform([textDetectionRequest!])
    }
    catch {
        print("Error occured \(error)")
    }
    var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let transform = ciImage.orientationTransform(for: CGImagePropertyOrientation(rawValue: 6)!)
    ciImage = ciImage.transformed(by: transform)
    let size = ciImage.extent.size
    var recognizedTextPositionTuples = [(rect: CGRect, text: String)]()
    for textObservation in textObservations {
        guard let rects = textObservation.characterBoxes else {
            continue
        }
        var xMin = CGFloat.greatestFiniteMagnitude
        var xMax: CGFloat = 0
        var yMin = CGFloat.greatestFiniteMagnitude
        var yMax: CGFloat = 0
        for rect in rects {
            
            xMin = min(xMin, rect.bottomLeft.x)
            xMax = max(xMax, rect.bottomRight.x)
            yMin = min(yMin, rect.bottomRight.y)
            yMax = max(yMax, rect.topRight.y)
        }
        let imageRect = CGRect(x: xMin * size.width, y: yMin * size.height, width: (xMax - xMin) * size.width, height: (yMax - yMin) * size.height)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: imageRect) else {
            continue
        }
        let uiImage = UIImage(cgImage: cgImage)
        tesseract?.image = uiImage
        tesseract?.recognize()
        guard var text = tesseract?.recognizedText else {
            continue
        }
        text = text.trimmingCharacters(in: CharacterSet.newlines)
        if !text.isEmpty {
            let x = xMin
            let y = 1 - yMax
            let width = xMax - xMin
            let height = yMax - yMin
            recognizedTextPositionTuples.append((rect: CGRect(x: x, y: y, width: width, height: height), text: text))
        }
    }
    textObservations.removeAll()
    DispatchQueue.main.async {
        let viewWidth = self.cameraView.frame.size.width
        let viewHeight = self.cameraView.frame.size.height
        guard let sublayers = self.cameraView.layer.sublayers else {
            return
        }
        for layer in sublayers[1...] {
            
            if let _ = layer as? CATextLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        //WHERE TEXT IS MADE INTO A STRING
        for tuple in recognizedTextPositionTuples {
            let textLayer = CATextLayer()
            textLayer.backgroundColor = UIColor.clear.cgColor
            var rect = tuple.rect

            rect.origin.x *= viewWidth
            rect.size.width *= viewWidth
            rect.origin.y *= viewHeight
            rect.size.height *= viewHeight

            textLayer.frame = rect
            textLayer.string = tuple.text
            textLayer.foregroundColor = UIColor.blue.cgColor
            self.cameraView.layer.addSublayer(textLayer)
        }
    }
}
}
