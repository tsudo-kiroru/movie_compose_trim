//
//  UtilExt.swift
//  movie
//
//  Created by takuyasudo on 2022/06/19.
//

import UIKit
import AVFoundation
import AVKit

extension CMSampleBuffer {
    func convertUIView() -> UIView {
        let pixelBuffer = CMSampleBufferGetImageBuffer(self)!
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let imageRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
            height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        )
        let ciContext = CIContext.init()
        let cgImage = ciContext.createCGImage(ciImage, from: imageRect)!
        
        let image = UIImage(cgImage: cgImage)
        
        return UIImageView.init(image: image)
    }
    
    func convertUIImage() -> UIImage {
        let pixelBuffer = CMSampleBufferGetImageBuffer(self)!
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let imageRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
            height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        )
        let ciContext = CIContext.init()
        let cgImage = ciContext.createCGImage(ciImage, from: imageRect)!
        
        return UIImage(cgImage: cgImage)
    }
    
    func convertCGImage() -> CGImage {
        let pixelBuffer = CMSampleBufferGetImageBuffer(self)!
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let imageRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
            height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        )
        let ciContext = CIContext.init()
        let cgImage = ciContext.createCGImage(ciImage, from: imageRect)!
        
        return cgImage
    }
    
    func convertCIImage() -> CIImage {
        let pixelBuffer = CMSampleBufferGetImageBuffer(self)!
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let imageRect = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
            height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        )
        let ciContext = CIContext.init()
        let cgImage = ciContext.createCGImage(ciImage, from: imageRect)!
        
        return CIImage(cgImage: cgImage)
    }
    
    func convertRect() -> CGRect {
        let pixelBuffer = CMSampleBufferGetImageBuffer(self)!
        
        return CGRect(
            x: 0,
            y: 0,
            width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
            height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        )
    }
}

extension UIView {
    func convertCGImage() -> CGImage {
        // キャプチャする範囲を取得する
        let rect = self.bounds
        
        // ビットマップ画像のcontextを作成する
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        let context : CGContext = UIGraphicsGetCurrentContext()!
        
        // view内の描画をcontextに複写する
        self.layer.render(in: context)
        
        // contextのビットマップをUIImageとして取得する
        let image : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        // contextを閉じる
        UIGraphicsEndImageContext()
        
        return image.cgImage!
    }
    
    func convertCIImage() -> CIImage {
        return CIImage(cgImage: self.convertCGImage())
    }
    
    func convertUIImage() -> UIImage {
        return UIImage(cgImage: self.convertCGImage())
    }
}

extension UIImage {
    func convertToBuffer() -> CVPixelBuffer? {
        
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, Int(self.size.width),
            Int(self.size.height),
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer)
        
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(
            data: pixelData,
            width: Int(self.size.width),
            height: Int(self.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

extension CGImage {
    func convertCVPixelBuffer() -> CVPixelBuffer {
        let options = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pxBuffer: CVPixelBuffer? = nil
        
        let width = self.width
        let height = self.height
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32ARGB,
                            options as CFDictionary?,
                            &pxBuffer)
        CVPixelBufferLockBaseAddress(pxBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pxdata = CVPixelBufferGetBaseAddress(pxBuffer!)
        
        let bitsPerComponent: size_t = 8
        let bytesPerRow: size_t = 4 * width
        
        let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pxdata,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.draw(self, in: CGRect(x:0, y:0, width:CGFloat(width),height:CGFloat(height)))
        
        CVPixelBufferUnlockBaseAddress(pxBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pxBuffer!
    }
}

extension CIImage {
    func toPixelBuffer(cgSize size:CGSize) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let width:Int = Int(size.width)
        let height:Int = Int(size.height)

        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32BGRA,
                            attrs,
                            &pixelBuffer)

        // put bytes into pixelBuffer
        let context = CIContext()
        context.render(self, to: pixelBuffer!)
        return pixelBuffer!
    }
}
