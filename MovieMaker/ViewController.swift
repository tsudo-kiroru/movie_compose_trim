//
//  ViewController.swift
//  movie
//
//  Created by takuyasudo on 2022/06/18.
//

import UIKit
import AVFoundation
import AVKit
import Photos

class ViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    let imagePicker = UIImagePickerController()
    let videoUrl = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!).appendingPathComponent("video.mp4") //output
    let movieUrl = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!).appendingPathComponent("movie.mp4")
    
    let dispatchQueue = DispatchQueue(label: "queue")
    
    let playerController = AVPlayerViewController()
    let player = AVPlayer()
    
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    var layeredView = { (size: CGSize) -> UIView in
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        label.text = "Title"
        label.textColor = .red
        label.font = UIFont.systemFont(ofSize: 64.0)
        label.sizeToFit()
        // ラベルを真ん中に配置する
        label.frame = CGRect(
            x: size.width * 0.5 - label.frame.width * 0.5,
            y: size.height * 0.5 - label.frame.height * 0.5,
            width: label.frame.width,
            height: label.frame.height
        )
        
        let uiview = UIView(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        uiview.addSubview(label)
        return uiview
    }
    var resizedView: UIView? = nil // メインスレッドでの実行を保証するためのオブジェクト

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func onTapLibrary(_ sender: Any) {
        if FileManager.default.fileExists(atPath: videoUrl.path) {
            try? FileManager.default.removeItem(at: videoUrl)
        }

        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = ["public.movie"]
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func onTapPlay(_ sender: Any) {
        if FileManager.default.fileExists(atPath: movieUrl.path) {
            
            let playerItem = AVPlayerItem(url: movieUrl)
            player.replaceCurrentItem(with: playerItem)
            playerController.player = player
            present(playerController, animated: true) {
                self.player.play()
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true)
        
        let mediaUrl = info[.mediaURL] as! URL?
        let referenceUrl = info[.referenceURL] as! URL?
        
        switch (mediaUrl, referenceUrl) {
        case (nil, nil): break
        case (_, nil) where mediaUrl != nil:
            self.writeMovie(asset: AVAsset(url: mediaUrl!), destUrl: videoUrl)
        default:
            let assets = PHAsset.fetchAssets(withALAssetURLs: [referenceUrl!], options: nil)
            assets.enumerateObjects({ pHAsset, index, _ in
                if pHAsset.mediaType == .video {
                    let options: PHVideoRequestOptions = PHVideoRequestOptions()
                    options.deliveryMode = .highQualityFormat
                    options.version = .original
                    PHImageManager.default().requestAVAsset(forVideo: pHAsset, options: options, resultHandler: { (asset, audioMix, info) in
                        self.writeMovie(asset: asset!, destUrl: self.videoUrl)
                    })
                }
            })
        }
    }
    
    func writeMovie(asset: AVAsset, destUrl: URL) {
        DispatchQueue.global(qos: .default).async {
        
            /* Track */
            guard let videoTrack = asset.tracks(withMediaType: .video).first else { return }
            let audioTrack = asset.tracks(withMediaType: .audio).first
            let size = videoTrack.naturalSize
            
            /* Reader */
            guard let videoReader = try? AVAssetReader(asset: asset) else {
                fatalError("AVAssetReader error")
            }
            let readerOutput = AVAssetReaderTrackOutput(
                track: videoTrack,
                outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                ]
            )
            
            /* Writer */
            guard let videoWriter = try? AVAssetWriter(outputURL: destUrl, fileType: .mp4) else {
                fatalError("AVAssetWriter error")
            }
            let writerInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: size.width,
                    AVVideoHeightKey: size.height
                ]
            )
            writerInput.expectsMediaDataInRealTime = false
            videoWriter.add(writerInput)
            
            // buffer
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
                    kCVPixelBufferWidthKey as String: size.width,
                    kCVPixelBufferHeightKey as String: size.height,
                ]
            )
        
            /* Start Reading & Writing Video Track */
            DispatchQueue.main.async {
                self.indicator.startAnimating()
            }
            
            let trackDuration = Double(asset.duration.value) / Double(asset.duration.timescale)
            
            videoReader.add(readerOutput)
            videoReader.startReading()
            videoWriter.startWriting()
            videoWriter.startSession(atSourceTime: CMTime.zero)
            
            DispatchQueue.main.sync {
                self.resizedView = self.layeredView(size)
            }
            
            let layerImage = self.resizedView!.convertCIImage()
            let transformed = layerImage.transformed(by: CGAffineTransform(
                scaleX: size.width / layerImage.extent.width,
                y: size.height / layerImage.extent.height)
            )
            let ciContext = CIContext()
            
            while true {
                if adaptor.assetWriterInput.isReadyForMoreMediaData  {
                    guard let buffer = readerOutput.copyNextSampleBuffer() else { break }

                    let cmTime = CMSampleBufferGetPresentationTimeStamp(buffer)
                    print("progress: \(Double(cmTime.value) / Double(cmTime.timescale) / trackDuration * 100.0) %")
                    
                    let pixelBuffer = CMSampleBufferGetImageBuffer(buffer)!
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    let composed = transformed.composited(over: ciImage)
                    ciContext.render(
                        composed,
                        to: pixelBuffer
                    )
                    adaptor.append(pixelBuffer, withPresentationTime: cmTime)
                } else {
                    Thread.sleep(forTimeInterval: 1.0 / 60.0)
                }
            }
            
            /* End Reading & Writing Video Track */
            writerInput.markAsFinished()
            videoReader.cancelReading()
            videoWriter.finishWriting {
                let videoAsset = AVAsset(url: self.videoUrl)
                guard let edittedVideoTrack = videoAsset.tracks(withMediaType: .video).first else { return }
                
                composeMovie(
                    videoTrack: edittedVideoTrack,
                    audioTrack: audioTrack,
                    duration: asset.duration
                )
            }
            
            // movie composition
            func composeMovie(
                videoTrack: AVAssetTrack,
                audioTrack: AVAssetTrack?,
                duration: CMTime
            ) {
                let composition = AVMutableComposition()
                let range = CMTimeRangeMake(start: CMTime.zero, duration: duration)
                
                // video
                guard let videoComposeTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else { return }
                try? videoComposeTrack.insertTimeRange(range, of: videoTrack, at: CMTime.zero)
                
                // audio
                if let audioTrack = audioTrack {
                    guard let audioComposeTrack = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    ) else { return }
                    try? audioComposeTrack.insertTimeRange(range, of: audioTrack, at: CMTime.zero)
                }
                
                // file remove if exsist
                if FileManager.default.fileExists(atPath: self.movieUrl.path) {
                    try? FileManager.default.removeItem(at: self.movieUrl)
                }
                
                // export
                guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return }
                session.outputURL = self.movieUrl
                session.outputFileType = .mov
                session.timeRange = range
                session.exportAsynchronously {
                    if session.status == .completed {
                        print("finished")
                    } else {
                        print("error")
                    }
                    DispatchQueue.main.async {
                        self.indicator.stopAnimating()
                    }
                }
                
                DispatchQueue.main.async {
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer: Timer) in
                        print("\(session.progress * 100.0)%")
                        if session.progress >= 0.999999 {
                            timer.invalidate()
                        }
                    })
                }
                
            }
        }
    }
}

