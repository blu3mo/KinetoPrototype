//
//  ViewController.swift
//  KinetoPrototype
//
//  Created by Shutaro Aoyama on 2020/03/26.
//  Copyright © 2020 Shutaro Aoyama. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    var captureSession = AVCaptureSession()
    var mainCamera: AVCaptureDevice?
    var innerCamera: AVCaptureDevice?
    var currentDevice: AVCaptureDevice?
    var videoOutput : AVCaptureVideoDataOutput?
    var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    
    var timer = Timer()

    @IBOutlet weak var fpsSlider: UISlider!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var currentFpsLabel: UILabel!
    
    var pastImages: [UIImage] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        captureSession.startRunning()
        
        runTimer(fps: 30.0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func fpsValueChanged(_ sender: UISlider) {
        runTimer(fps: sender.value)
    }
    
    func runTimer(fps: Float) {
        currentFpsLabel.text = String(format: "x%.3f", fps/30)
        timer.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval((1/fps)), repeats: true, block: { (timer) in
            if self.pastImages.count > 0 {
                do {
                    try self.previewImageView.image = self.pastImages.first //FIX: EXC_BAD_ACCESS起こる
                    self.pastImages.remove(at: 0)
                } catch {
                    print("frame update error")
                }
            }
        })
    }
    
    @IBAction func backToTheFuture(_ sender: Any) {
        pastImages = []
        runTimer(fps: 30)
    }
}


extension ViewController{
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.medium
    }

    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        let devices = deviceDiscoverySession.devices

        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                mainCamera = device
            } else if device.position == AVCaptureDevice.Position.front {
                innerCamera = device
            }
        }
        currentDevice = mainCamera
    }


    func setupInputOutput() {
        do {

            let captureDeviceInput = try AVCaptureDeviceInput(device: currentDevice!)
            captureSession.addInput(captureDeviceInput)

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA] as [String : Any]
            videoOutput!.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            videoOutput!.alwaysDiscardsLateVideoFrames = true
            
            captureSession.addOutput(videoOutput!)
            
            if currentDevice == innerCamera {
                captureSession.connections.first?.videoOrientation = .portrait
            } else {
                captureSession.connections.first?.videoOrientation = .portraitUpsideDown
            }
        
        } catch {
            print(error)
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer)
        self.pastImages.append(image)
    }
    
    func imageFromSampleBuffer(sampleBuffer :CMSampleBuffer) -> UIImage {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!

        // イメージバッファのロック
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

        // 画像情報を取得
        let base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        let bytesPerRow = UInt(CVPixelBufferGetBytesPerRow(imageBuffer))
        let width = UInt(CVPixelBufferGetWidth(imageBuffer))
        let height = UInt(CVPixelBufferGetHeight(imageBuffer))

        // ビットマップコンテキスト作成
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerCompornent = 8
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
        let newContext = CGContext(data: base, width: Int(width), height: Int(height), bitsPerComponent: Int(bitsPerCompornent), bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: bitmapInfo.rawValue)! as CGContext

        // 画像作成
        let imageRef = newContext.makeImage()!
        let image = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImage.Orientation.right)

        // イメージバッファのアンロック
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return image
    }
}
