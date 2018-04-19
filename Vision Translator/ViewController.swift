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
    
    var textAreaView: DrawRect!
    
    private var preview: PreviewView {
        return cameraView as! PreviewView
    } //preview

    public var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    } //screenWidth
    
    public var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    } //screenHeight
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        intializeTesseract()
        createViewingArea()
        
        if isAuthorized() { //Camera setup
            configureTextDetection()
            configureCamera()
        } //if
    } //viewDidLoad
    
    func intializeTesseract() {
        tesseract?.pageSegmentationMode = .sparseText
        tesseract?.charWhitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890()-+*!/?.,@#$%&"
    } //intializeTesseract
    
    func createViewingArea() {
        textAreaView = DrawRect(frame: CGRect(
            origin: CGPoint(x: screenWidth / 2 - 350, y: screenHeight / 2 - 200),
            size: CGSize(width: 700, height: 400)))
        
        textAreaView.backgroundColor = UIColor.clear
        textAreaView.bringSubview(toFront: view);
        
        self.view.addSubview(textAreaView)
    } //createViewArea
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            print("TOUCH")
            
        } //if
        super.touchesBegan(touches, with: event)
    } //touchesBegan
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    } //didReceiveMemoryWarning
    
    
    // MARK: - Text Requests and setup
    
    private func configureTextDetection() {
        textDetectionRequest = VNDetectTextRectanglesRequest(completionHandler: handleDetection)
        textDetectionRequest!.reportCharacterBoxes = true
    } //configureTextDetection
    private func configureCamera() {
        preview.session = session
        
        let cameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        var cameraDevice: AVCaptureDevice?
        for device in cameraDevices.devices {
            if device.position == .back {
                cameraDevice = device
                break
            } //if
        } //for
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: cameraDevice!)
            if session.canAddInput(captureDeviceInput) {
                session.addInput(captureDeviceInput)
            } //if
        } //do
        catch {
            print("Error occured \(error)")
            return
        } //catch
        session.sessionPreset = .high
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "Buffer Queue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil))
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        } //if
        preview.videoPreviewLayer.videoGravity = .resize
        session.startRunning()
    } //configureCamera
    
    
    private func handleDetection(request: VNRequest, error: Error?) {
        
        guard let detectionResults = request.results else {
            print("No detection results")
            return
        } //detectionResults
        let textResults = detectionResults.map() {
            return $0 as? VNTextObservation
        } //textResults
        if textResults.isEmpty {
            return
        } //if
        textObservations = textResults as! [VNTextObservation]
        DispatchQueue.main.async {
            
            guard let sublayers = self.cameraView.layer.sublayers else {
                return
            } //guard
            for layer in sublayers[1...] {
                if (layer as? CATextLayer) == nil {
                    layer.removeFromSuperlayer()
                }
            } //for
            
            //creation of boxes
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
                    
                    //limit view space
                    print("self.textAreaView.frame.origin.y: ",self.textAreaView.frame.origin.y)
                    print("rect.origin.y: ",rect.origin.y)
                    
                    //more then the top
                    if (rect.origin.y > self.textAreaView.frame.origin.y) {
                        //more then the bottom
                        if (rect.origin.y  < (self.textAreaView.frame.origin.y + (self.textAreaView.h * 0.5))) {
                            layer.frame = rect
                            layer.borderWidth = 2
                            layer.borderColor = UIColor.red.cgColor
                            self.cameraView.layer.addSublayer(layer)
                        } //if
                    } else {
                        print("outside desired view region")
                    } //if-else
                    
                } //if
            } //for
        } //dispatchQueue
    } //handleDetection
   
    
    
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
                                                } //DispatchQueue
                                            } //if
            })
            return true
        case .authorized:
            return true
        case .denied, .restricted: return false
        } //authorizationStatus
    } //isAuthorized
    private var textDetectionRequest: VNDetectTextRectanglesRequest?
    private let session = AVCaptureSession()
    private var textObservations = [VNTextObservation]()
    private var tesseract = G8Tesseract(language: "eng", engineMode: .tesseractOnly)
} //ViewController

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - Camera Delegate and Setup
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        } //guard
        var imageRequestOptions = [VNImageOption: Any]()
        if let cameraData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            imageRequestOptions[.cameraIntrinsics] = cameraData
        } //if
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: imageRequestOptions)
        do {
            try imageRequestHandler.perform([textDetectionRequest!])
        } //do
        catch {
            print("Error occured \(error)")
        } //catch
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let transform = ciImage.orientationTransform(for: CGImagePropertyOrientation(rawValue: 6)!)
        ciImage = ciImage.transformed(by: transform)
        let size = ciImage.extent.size
        var recognizedTextPositionTuples = [(rect: CGRect, text: String)]()
        for textObservation in textObservations {
            guard let rects = textObservation.characterBoxes else {
                continue
            } //guard
            var xMin = CGFloat.greatestFiniteMagnitude
            var xMax: CGFloat = 0
            var yMin = CGFloat.greatestFiniteMagnitude
            var yMax: CGFloat = 0
            for rect in rects {
                
                xMin = min(xMin, rect.bottomLeft.x)
                xMax = max(xMax, rect.bottomRight.x)
                yMin = min(yMin, rect.bottomRight.y)
                yMax = max(yMax, rect.topRight.y)
            } //for
            let imageRect = CGRect(x: xMin * size.width, y: yMin * size.height, width: (xMax - xMin) * size.width, height: (yMax - yMin) * size.height)
            let context = CIContext(options: nil)
            guard let cgImage = context.createCGImage(ciImage, from: imageRect) else {
                continue
            } //guard
            let uiImage = UIImage(cgImage: cgImage)
            tesseract?.image = uiImage
            tesseract?.recognize()
            guard var text = tesseract?.recognizedText else {
                continue
            } //guard
            text = text.trimmingCharacters(in: CharacterSet.newlines)
            if !text.isEmpty {
                let x = xMin
                let y = 1 - yMax
                let width = xMax - xMin
                let height = yMax - yMin
                recognizedTextPositionTuples.append((rect: CGRect(x: x, y: y, width: width, height: height), text: text))
            }
        } //for
        textObservations.removeAll()
        DispatchQueue.main.async {
            let viewWidth = self.cameraView.frame.size.width
            let viewHeight = self.cameraView.frame.size.height
            guard let sublayers = self.cameraView.layer.sublayers else {
                return
            } //guard
            for layer in sublayers[1...] {
                
                if let _ = layer as? CATextLayer {
                    layer.removeFromSuperlayer()
                } //if
            } //for
            
            //WHERE TEXT IS MADE INTO A STRING
            for tuple in recognizedTextPositionTuples {
                let textLayer = CATextLayer()
                textLayer.backgroundColor = UIColor.clear.cgColor
                var rect = tuple.rect
                
                rect.origin.x *= viewWidth
                rect.size.width *= viewWidth
                rect.origin.y *= viewHeight
                rect.size.height *= viewHeight
                
                //less then the top
                if (rect.origin.y > self.textAreaView.frame.origin.y) {
                    //more then the bottom
                    if (rect.origin.y  < (self.textAreaView.frame.origin.y + (self.textAreaView.h * 0.5))) {
                        textLayer.frame = rect
                        textLayer.string = tuple.text
                        textLayer.foregroundColor = UIColor.blue.cgColor
                        self.cameraView.layer.addSublayer(textLayer)
                    } //if
                } //if
                
                
            } //for
        } //DispatchQueue
    } //captureOutput
} //AVCaptureVideoDataOutputSampleBufferDelegate
