//
//  ObjectRecognitionViewController.swift
//  CameraOR
//
//  Created by Andrew Mokryj on 11.08.2022.
//

import UIKit
import AVFoundation
import Vision

class ObjectRecognitionViewController: ViewController {
    var isRecording: Bool = false
    
    private var detectionOverlay: CALayer! = nil
    
    
    // Vision parts
    private var requests = [VNRequest]()
    
    @discardableResult
    func setupVision() -> NSError? {
        // Setup Vision parts
        let error: NSError! = nil
        
        guard let modelURL = Bundle.main.url(forResource: "ObjectDetector", withExtension: "mlmodelc") else {
            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        self.drawVisionRequestResults(results)
                    }
                })
            })
            self.requests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
        
        return error
    }
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        foundBounds = nil
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            let dotsLayer = self.createDotsLayerWithBounds(objectBounds)
            detectionOverlay.addSublayer(dotsLayer)
            
            foundBounds = CGRect(
                x: dotsLayer.frame.minX,
                y: detectionOverlay.frame.maxY - dotsLayer.frame.maxY * 1.7, // Move
                width: dotsLayer.frame.width,
                height: dotsLayer.frame.height
            )
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    override func setupAVCapture() {
        super.setupAVCapture()
        
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        setupVision()
        
        // start the capture
        startCaptureSession()
        
        view.addSubview(cameraButton)
        view.bringSubviewToFront(cameraButton)
        
        session.addOutput(videoFileOutput)
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
    }
    
    func createDotsLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        
        var _dotPath = UIBezierPath(ovalIn: CGRect(x: bounds.minX, y: bounds.minY, width: 10, height: 10))
        var _layer = CAShapeLayer()
        _layer.path = _dotPath.cgPath
        _layer.fillColor = UIColor.blue.cgColor
        shapeLayer.addSublayer(_layer)
        
        _dotPath = UIBezierPath(ovalIn: CGRect(x: bounds.minX, y: bounds.maxY, width: 10, height: 10))
        _layer = CAShapeLayer()
        _layer.path = _dotPath.cgPath
        _layer.fillColor = UIColor.blue.cgColor
        shapeLayer.addSublayer(_layer)
        
        _dotPath = UIBezierPath(ovalIn: CGRect(x: bounds.maxX, y: bounds.minY, width: 10, height: 10))
        _layer = CAShapeLayer()
        _layer.path = _dotPath.cgPath
        _layer.fillColor = UIColor.blue.cgColor
        shapeLayer.addSublayer(_layer)
        
        _dotPath = UIBezierPath(ovalIn: CGRect(x: bounds.maxX, y: bounds.maxY, width: 10, height: 10))
        _layer = CAShapeLayer()
        _layer.path = _dotPath.cgPath
        _layer.fillColor = UIColor.blue.cgColor
        shapeLayer.addSublayer(_layer)

        return shapeLayer
    }
    
    var videoFileOutput = AVCaptureMovieFileOutput()
    
    override func didTapCameraButton(){        
//        let photoSettings = AVCapturePhotoSettings()
//        photoSettings.isHighResolutionPhotoEnabled = true
//        if self.deviceInput.device.isFlashAvailable {
//            photoSettings.flashMode = .auto
//        }
//
//        if let firstAvailablePreviewPhotoPixelFormatTypes = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
//            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: firstAvailablePreviewPhotoPixelFormatTypes]
//        }
//
//        photoOutput.capturePhoto(with: photoSettings, delegate: self)
//
//        var recordingDelegate:AVCaptureFileOutputRecordingDelegate? = self
//
////        var videoFileOutput = AVCaptureMovieFileOutput()
////        self.captureSession.addOutput(videoFileOutput)
//
//        var videoFileOutput = AVCaptureMovieFileOutput()
//        session.addOutput(videoFileOutput)
//        session.addOutput(videoDataOutput)

//        let filePath = NSURL(fileURLWithPath: "filePath")
//
//        videoFileOutput.startRecordingToOutputFileURL(filePath, recordingDelegate: recordingDelegate)
        
        if (!isRecording) {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filePath = documentsURL.appendingPathExtension("temp")
            
            // Do recording and save the output to the `filePath`
            var recordingDelegate:AVCaptureFileOutputRecordingDelegate? = self
            videoFileOutput.startRecording(to: filePath, recordingDelegate: recordingDelegate!)
            cameraButton.backgroundColor = .red
        } else {
            videoFileOutput.stopRecording()
            cameraButton.backgroundColor = .white

            cameraButton.removeFromSuperview()
            detectionOverlay.removeFromSuperlayer()
    
            session.removeOutput(videoFileOutput)
            super.didTapCameraButton()
        }
        isRecording = !isRecording
        
    }
}
