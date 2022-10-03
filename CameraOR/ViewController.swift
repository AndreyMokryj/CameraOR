//
//  ViewController.swift
//  CameraOR
//
//  Created by Andrew Mokryj on 10.08.2022.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var button: UIButton!
    @IBOutlet var cameraButton: UIButton!
    
    var foundBounds: CGRect? = nil
    var coef: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        button.backgroundColor = .systemBlue
        button.setTitle("Open camera", for: .normal)
        button.setTitleColor(.white, for: .normal)
        
        cameraButton.backgroundColor = .white
        cameraButton.setTitle("", for: .normal)
    }

    @IBAction func didTapButton(){
        setupAVCapture()
    }
    
    @IBAction func didTapCameraButton(){
        session.stopRunning()

        previewLayer.removeFromSuperlayer()
        session.removeInput(deviceInput)
        session.removeOutput(videoDataOutput)
        session.removeOutput(photoOutput)
    }
    
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    
    @IBOutlet weak private var previewView: UIView!
    var session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    let videoDataOutput = AVCaptureVideoDataOutput()
    let photoOutput = AVCapturePhotoOutput()
    let videoFileOutput = AVCaptureMovieFileOutput()

    var deviceInput: AVCaptureDeviceInput!
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // to be implemented in the subclass
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupAVCapture() {
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .vga640x480 // Model image size is smaller.
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        

//        if session.canAddOutput(videoFileOutput) {
////            session.addOutput(videoFileOutput)
//            // Add a video data output
////            videoFileOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
////            videoFileOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
//        } else {
//            print("Could not add video data output to the session")
//            session.commitConfiguration()
//            return
//        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            // Add a video data output
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        } else {
            print("Could not add photo output to the session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)
//        let captureConnection = videoFileOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
    }
    
    func startCaptureSession() {
        session.startRunning()
        
//        VideoService.instance.launchVideoRecorder(in: self, completion: nil)
//        VideoService.instance.delegate = self
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            return
        }
        imageView.image = image
    }
    
    func cropToBounds(image: UIImage, rect: CGRect?) -> UIImage
    {
        if (rect != nil) {
            let contextImage: UIImage = UIImage(cgImage: image.cgImage!)
            
            print("rect.minX = \(rect!.minX)\nrect.minY = \(rect!.minY)\nrect.width = \(rect!.width)\nrect.height = \(rect!.height)\n")
            print("rect.midX = \(rect!.midX)\nrect.midY = \(rect!.midY)\n")
            print("rect.maxX = \(rect!.maxX)\nrect.maxY = \(rect!.maxY)\n")

            let _coef = 6.5
            let _ycoef = 3.7
            let _rect = CGRect(x: rect!.minX * _coef, y: rect!.minY * _ycoef, width: rect!.width * _coef, height: rect!.height * _coef)
            let imageRef: CGImage = contextImage.cgImage!.cropping(to: _rect)!

            let _image: UIImage = UIImage(cgImage: imageRef, scale: image.imageRendererFormat.scale, orientation: image.imageOrientation)
            return _image
        }
        return image
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {

        if let error = error {
            print("Error capturing photo: \(error)")
        } else {
            if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {

                if let image = UIImage(data: dataImage) {
                    self.imageView.image = cropToBounds(image: image, rect: foundBounds)
                }
            }
        }
    }

    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image =  UIImage(data: data)  else {
                return
        }

        self.imageView.image = cropToBounds(image: image, rect: foundBounds)
    }
}

//extension ViewController : VideoServiceDelegate {
//
//    func videoDidFinishSaving(error: Error?, url: URL?) {
//        let success: Bool = error == nil
//
//        if success {
////            button.option = .playMovie
////            self.videoURL = url
//            print(url)
//        }
//
//        let title = success ? "Success" : "Error"
//        let message = success ? "Video was saved" : "Could not save video"
//        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
//        self.present(alert, animated: true, completion: nil)
//    }
//}

extension ViewController : AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        return
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
                let success: Bool = error == nil

                if success {
        //            button.option = .playMovie
        //            self.videoURL = url
                    print(outputFileURL)
                }

                let title = success ? "Success" : "Error"
                let message = success ? "Video was saved" : "Could not save video"
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
//        return
    }

    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        return
    }
}
