//
//  MovieMaker.swift
//  movie
//
//  Created by takuyasudo on 2022/06/19.
//

import Foundation
import AVFoundation
import AVKit

class MovieMaker {
    
    enum MovieMakderError: Error {
        case AVAssetReader
        case AVAssetWriter
    }
    
    let videoUrl = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!).appendingPathComponent("movie_maker_temp.mp4") //output
    
    var asset: AVAsset
    
    static func duration(url: URL) -> Double {
        let asset = AVAsset(url: url)
        
        return Double(asset.duration.value) / Double(asset.duration.timescale)
    }
    
    static func size(url: URL) -> CGSize? {
        let asset = AVAsset(url: url)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return nil }
        return videoTrack.naturalSize
    }
    
    init (asset: AVAsset) {
        self.asset = asset
    }
    
    func trim(
        outputUrl: URL,
        startTime: CMTime? = nil,
        endTime: CMTime? = nil,
        completion: @escaping () -> Void = { () in }
    ) {
        DispatchQueue(label: "movie_maker_trim").async {
            /* Track */
            guard let videoTrack = self.asset.tracks(withMediaType: .video).first else { return }
            let audioTrack = self.asset.tracks(withMediaType: .audio).first
            
            let composition = AVMutableComposition()
            let range = CMTimeRangeMake(start: CMTime.zero, duration: self.asset.duration)
            
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
            if FileManager.default.fileExists(atPath: outputUrl.path) {
                try? FileManager.default.removeItem(at: outputUrl)
            }
            
            // export
            guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return }
            session.outputURL = outputUrl
            session.outputFileType = .mp4
            session.timeRange = CMTimeRange(
                start: startTime ?? CMTime.zero,
                end: endTime ?? self.asset.duration
            )
            
            session.exportAsynchronously {
                if session.status == .completed {
                    print("finished")
                } else {
                    print("error")
                }
                DispatchQueue.main.sync {
                    completion()
                }
            }
        }
    }
    
    func composeMovie(
        view: UIView,
        outputUrl: URL,
        onProgress: @escaping (_ progress: Float) -> Void = { (v) in print(v) }, //0.0 ~ 1.0
        completion: @escaping () -> Void = { () in },
        onError: @escaping (_ error: Error?) -> Void = { (e) in print(e as Any) }
    ) {
        DispatchQueue(label: "queue").async {
        
            /* Track */
            guard let videoTrack = self.asset.tracks(withMediaType: .video).first else { return }
            let audioTrack = self.asset.tracks(withMediaType: .audio).first
            let size = videoTrack.naturalSize
            
            /* Reader */
            guard let videoReader = try? AVAssetReader(asset: self.asset) else {
                onError(MovieMakderError.AVAssetReader)
                return
            }
            let readerOutput = AVAssetReaderTrackOutput(
                track: videoTrack,
                outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                ]
            )
            
            /* Writer */
            guard let videoWriter = try? AVAssetWriter(outputURL: self.videoUrl, fileType: .mp4) else {
                onError(MovieMakderError.AVAssetWriter)
                return
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
            
            let trackDuration = Double(self.asset.duration.value) / Double(self.asset.duration.timescale)
            
            videoReader.add(readerOutput)
            videoReader.startReading()
            videoWriter.startWriting()
            videoWriter.startSession(atSourceTime: CMTime.zero)
            
            // 読んだものをそのまま書くなら以下の処理
//            while true {
//                if writerInput.isReadyForMoreMediaData {
//                    guard let buffer = readerOutput.copyNextSampleBuffer() else { break }
//
//                    let cmTime = CMSampleBufferGetPresentationTimeStamp(buffer)
//                    print("progress: \(Float(cmTime.value) / Float(cmTime.timescale)) sec")
//
//                    writerInput.append(buffer)
//                } else {
//                    Thread.sleep(forTimeInterval: 1.0 / 60.0)
//                }
//            }
            
            let layerImage = view.convertCIImage()
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
                    onProgress(Float(cmTime.value) / Float(cmTime.timescale))
                    
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
                let asset = AVAsset(url: self.videoUrl)
                guard let edittedVideoTrack = asset.tracks(withMediaType: .video).first else { return }
                
                composeMovie(
                    videoTrack: edittedVideoTrack,
                    audioTrack: audioTrack,
                    duration: asset.duration,
                    startTime: CMTime(seconds: 1.0, preferredTimescale: asset.duration.timescale),
                    endTime: CMTime(seconds: trackDuration - 1.0, preferredTimescale: asset.duration.timescale)
                )
            }
            
            // movie composition
            func composeMovie(
                videoTrack: AVAssetTrack,
                audioTrack: AVAssetTrack?,
                duration: CMTime,
                startTime: CMTime? = nil,
                endTime: CMTime? = nil
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
                if FileManager.default.fileExists(atPath: outputUrl.path) {
                    try? FileManager.default.removeItem(at: outputUrl)
                }
                
                // export
                guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return }
                session.outputURL = outputUrl
                session.outputFileType = .mp4
                session.timeRange = CMTimeRange(
                    start: startTime ?? CMTime.zero,
                    end: endTime ?? duration
                )
                session.exportAsynchronously {
                    if session.status == .completed {
                        print("MovieMaker finished")
                        DispatchQueue.main.async {
                            completion()
                        }
                    } else {
                        print("MovieMaker error")
                        onError(session.error)
                    }
                }
            }
        }
    }
}
