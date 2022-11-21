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
    var sampleBufferGlobal : CMSampleBuffer?
    let writerFileName = "tempVideoAsset.mov"
    var outputSettings   = [String: Any]()
    var videoWriterInput: AVAssetWriterInput!
    var assetWriter: AVAssetWriter!
    
    var isRecording: Bool = false
    
    private var detectionOverlay: CALayer! = nil
    
    // Vision parts
    private var requests = [VNRequest]()
    
//    @discardableResult
//    func setupVision() -> NSError? {
//        // Setup Vision parts
//        let error: NSError! = nil
//
////        guard let modelURL = Bundle.main.url(forResource: "ObjectDetector", withExtension: "mlmodelc") else {
////            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
////        }
//        do {
////            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
//            let objectRecognition = VNRequest(completionHandler: { (request, error) in
//                print("Some text")
//                DispatchQueue.main.async(execute: {
//                    // perform all the UI updates on the main queue
//                    if let results = request.results {
//                        self.drawVisionRequestResults(results)
//                    }
//                })
//            })
//            self.requests = [objectRecognition]
////            self.detectionRequest = VNCoreMLRequest(model: visionModel)
//        } catch let error as NSError {
//            print("Model loading went wrong: \(error)")
//        }
//
//        return error
//    }
    
//    func drawVisionRequestResults(_ results: [Any]) {
//        CATransaction.begin()
//        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
//        foundBounds = nil
//        detectionOverlay.sublayers = nil // remove all the old recognized objects
//        for observation in results where observation is VNRecognizedObjectObservation {
//            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
//                continue
//            }
//            // Select only the label with the highest confidence.
//            let topLabelObservation = objectObservation.labels[0]
//            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
//
//            let dotsLayer = self.createDotsLayerWithBounds(objectBounds)
//            detectionOverlay.addSublayer(dotsLayer)
//
//            foundBounds = CGRect(
//                x: dotsLayer.frame.minX,
//                y: detectionOverlay.frame.maxY - dotsLayer.frame.maxY * 1.7, // Move
//                width: dotsLayer.frame.width,
//                height: dotsLayer.frame.height
//            )
//        }
//        self.updateLayerGeometry()
//        CATransaction.commit()
//    }
    
    func drawNyckelResult(_ result: CGRect) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        foundBounds = nil
        detectionOverlay.sublayers = nil // remove all the old recognized objects
//        for observation in results where observation is VNRecognizedObjectObservation {
//            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
//                continue
//            }
//            // Select only the label with the highest confidence.
//            let topLabelObservation = objectObservation.labels[0]
//            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
//
//            let dotsLayer = self.createDotsLayerWithBounds(objectBounds)
//            detectionOverlay.addSublayer(dotsLayer)
//
//            foundBounds = CGRect(
//                x: dotsLayer.frame.minX,
//                y: detectionOverlay.frame.maxY - dotsLayer.frame.maxY * 1.7, // Move
//                width: dotsLayer.frame.width,
//                height: dotsLayer.frame.height
//            )
//        }
        
        let dotsLayer = self.createDotsLayerWithBounds(result)
        detectionOverlay.addSublayer(dotsLayer)

//        foundBounds = CGRect(
//            x: dotsLayer.frame.minX,
//            y: detectionOverlay.frame.maxY - dotsLayer.frame.maxY * 1.7, // Move
//            width: dotsLayer.frame.width,
//            height: dotsLayer.frame.height
//        )
        
        self.updateLayerGeometry()
        CATransaction.commit()
        print("CATransaction commited")
    }

    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        sampleBufferGlobal = sampleBuffer
        writeVideoFromData()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
//        let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer)
//        let uiImage = UIImage(data: pixelBuffer as! Data)
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let ciImageDepth            = CIImage(cvPixelBuffer: pixelBuffer)
        let contextDepth:CIContext  = CIContext.init(options: nil)
        let cgImageDepth:CGImage    = contextDepth.createCGImage(ciImageDepth, from: ciImageDepth.extent)!
        let uiImageDepth:UIImage    = UIImage(cgImage: cgImageDepth, scale: 1, orientation: UIImage.Orientation.up)

        
//        let image = UIImage(ciImage: ciimage, scale: 1.0, orientation: exifOrientation)
//        let result = detectBounds(uiImage: image)
        let result = detectBounds(uiImage: uiImageDepth)
        if (result != nil) {
//            print("Nyckel Result")
//            print("minX = \(result!.minX)")
//            print("minY = \(result!.minY)")
//            print("width = \(result!.width)")
//            print("height = \(result!.height)")
            drawNyckelResult(result!)
        }
        
//        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
//        do {
//            try imageRequestHandler.perform(self.requests)
//        } catch {
//            print(error)
//        }
        
        
    }
    
    override func setupAVCapture() {
        super.setupAVCapture()
        
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
//        setupVision()
        
        // start the capture
        startCaptureSession()
        
        view.addSubview(cameraButton)
        view.bringSubviewToFront(cameraButton)
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
        
    override func didTapCameraButton(){
        if (!isRecording) {
            setupAssetWriter()
            cameraButton.backgroundColor = .red
        } else {
            cameraButton.backgroundColor = .white
            cameraButton.removeFromSuperview()
            detectionOverlay.removeFromSuperlayer()
            stopAssetWriter()
            super.didTapCameraButton()
        }
        isRecording = !isRecording
    }

    func setupAssetWriter () {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsURL.appendingPathComponent(writerFileName)
        self.videoUrl = filePath
        let filePathStr = filePath.path
        print("filePath.path = \(filePath.path)")
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: (filePathStr)) {
            // Delete file
            try? fileManager.removeItem(atPath: filePathStr)
        } else {
            print("File does not exist")
        }

        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBufferGlobal!);
        let _width = CVPixelBufferGetWidth(imageBuffer!);
        let _height = CVPixelBufferGetHeight(imageBuffer!);

        outputSettings = [AVVideoCodecKey   : AVVideoCodecType.h264,
                             AVVideoWidthKey: _width,
                            AVVideoHeightKey: _height]

        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        videoWriterInput.expectsMediaDataInRealTime = true
        videoWriterInput.transform = CGAffineTransform(rotationAngle: .pi/2)

        assetWriter = try! AVAssetWriter(outputURL: filePath, fileType: AVFileType.mov)
        assetWriter!.add(videoWriterInput)
    }
    
    func writeVideoFromData() {
        guard isRecording else {
            return
        }
        
        if assetWriter?.status == AVAssetWriter.Status.unknown {
            if (( assetWriter?.startWriting ) != nil) {
                assetWriter?.startWriting()
                assetWriter?.startSession(atSourceTime:  CMSampleBufferGetPresentationTimeStamp(sampleBufferGlobal!))
            }
        }
        if assetWriter?.status == AVAssetWriter.Status.writing {
            if (videoWriterInput.isReadyForMoreMediaData == true) {
                if  videoWriterInput.append(sampleBufferGlobal!) == false {
                    print("There is a problem with writing video")
                }
            }
        }
    }
    
    func stopAssetWriter() {
        videoWriterInput.markAsFinished()
        assetWriter?.finishWriting(completionHandler: {
            print(self.assetWriter!.status)
            if (self.assetWriter?.status == AVAssetWriter.Status.failed) {
                print("Creating movie file has failed")
            } else {
                print("Creating movie file was successful")
                DispatchQueue.main.async(execute: { () -> Void in

                })
            }
        })
    }
}
