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
    var squareBounds: CGRect? = nil
    var coef: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        hideSpinner()
        button.backgroundColor = .systemBlue
        button.setTitle("Open camera", for: .normal)
        button.setTitleColor(.white, for: .normal)
        
        cameraButton.backgroundColor = .white
        cameraButton.setTitle("", for: .normal)
        cameraButton.removeFromSuperview()
    }

    @IBAction func didTapButton(){
        AppUtility.lockOrientation(.portrait, andRotateTo: .portrait)
        setupAVCapture()
    }
    
    @IBAction func didTapCameraButton(){
        session.stopRunning()

        previewLayer.removeFromSuperlayer()
        session.removeInput(deviceInput)
        session.removeOutput(videoDataOutput)
        session.removeOutput(photoOutput)
                
        AppUtility.lockOrientation(.all)
        imageView.image = nil
        showSpinner()
        let _frames = getAllFrames()
        var _framesNotNil:[UIImage] = []
        for el in _frames {
            if el != nil {
                _framesNotNil.append(el!)
            }
        }
        
        print("After get frames")
        Task {
            let _stitched = await stitch(images: _framesNotNil)
            hideSpinner()
            self.imageView.image = _stitched
            
        }
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
    
    
    /// Get  frames from video
    var videoUrl:URL?
    
    private var generator:AVAssetImageGenerator!

    func getAllFrames() -> [UIImage?] {
        let asset:AVAsset = AVAsset(url:self.videoUrl!)
        let duration:Float64 = CMTimeGetSeconds(asset.duration)
        self.generator = AVAssetImageGenerator(asset:asset)
        generator.requestedTimeToleranceBefore = .zero //Optional
        generator.requestedTimeToleranceAfter = .zero //Optional
        self.generator.appliesPreferredTrackTransform = true
        var frames:[UIImage?] = []
        
        var _coef:Float64 = 5.0
        if (duration < 3) {
            _coef = 15.0 / duration
        }
        
        for index:Int in 0 ..< Int(duration * _coef) {
            let _frame = self.getFrame(fromTime:Float64(Double(index) / _coef))
//            frames.append(_frame)
            if (_frame != nil) {
                frames.append(cropToBoundsSquare(image: _frame!, rect: squareBounds))
            }
        }
        self.generator = nil
        return frames
    }

    private func getFrame(fromTime:Float64) -> UIImage? {
        let time:CMTime = CMTimeMakeWithSeconds(fromTime, preferredTimescale:600)
        let image:CGImage
        do {
            try image = self.generator.copyCGImage(at:time, actualTime:nil)
        } catch {
            return nil
        }
        return UIImage(cgImage:image)
    }
    
    /// Stitch frames
    func stitch(images:[UIImage?]) -> UIImage? {
        var _images:[UIImage] = []
        for el in images {
            if el != nil {
                _images.append(el!)
            }
        }
        
        let _count = _images.count
        let N = 12
        
        /// 7 evenly-taken images
        let _coef = (Double(_count) - 1) / Double(N)
        var _newImages:[UIImage] = []
        for i in 0...N {
            _newImages.append(_images[Int(round(Double(i) * _coef))])
        }
        _newImages[0] = _images[1]
        _newImages[N] = _images[_count - 2]
        
        do {
            print ("Before try stitch")
//            let stitchedImage:UIImage? = try CVWrapper.process(with: _newImages)
            let stitchedImage:UIImage? = try CVWrapper.process(with: _images)
            print ("After try stitch")
            return stitchedImage
        } catch let error as NSError {
            let alert = UIAlertController(title: "Stitching Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
           self.show(alert, sender: nil)
        }
        return nil
    }
    
    /// Spinner
    @IBOutlet weak var loadingView: UIView! {
      didSet {
        loadingView.layer.cornerRadius = 6
      }
    }
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var loadingLabel: UILabel!
    
    private func showSpinner() {
        activityIndicator.startAnimating()
        loadingView.isHidden = false
    }

    private func hideSpinner() {
        activityIndicator.stopAnimating()
        loadingView.isHidden = true
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
    
    func cropToBoundsSquare(image: UIImage, rect: CGRect?) -> UIImage
    {
        if (rect != nil) {
            let contextImage: UIImage = UIImage(cgImage: image.cgImage!)
            
            print("rect.minX = \(rect!.minX)\nrect.minY = \(rect!.minY)\nrect.width = \(rect!.width)\nrect.height = \(rect!.height)\n")
            print("rect.midX = \(rect!.midX)\nrect.midY = \(rect!.midY)\n")
            print("rect.maxX = \(rect!.maxX)\nrect.maxY = \(rect!.maxY)\n")

            let screenRect = UIScreen.main.bounds
            let screenWidth = screenRect.size.width
            let screenHeight = screenRect.size.height
            
            let _coef = 720.0 / screenWidth
            let _ycoef = 720 * 65.0 / 37.0 / screenHeight
            let _rect = CGRect(x: rect!.minX * _coef, y: rect!.minY * _ycoef, width: rect!.width * _coef, height: rect!.height * _ycoef)
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
