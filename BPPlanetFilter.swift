//
//  BPPlanetFilter.swift
//  BubblePix
//
//  Created by Paul Jones on 12/05/2016.
//  Copyright © 2016 Fluid Pixel. All rights reserved.
//

import Foundation
import CoreImage
import UIKit

import PhotosUI
import Photos




public class BPPlanetFilter: CIFilter {
    
    public var inputImage: CIImage?
    public var inputOutputImageSize: NSNumber = 512.0
    public var inputInnerRadius: NSNumber = 0.25
    public var inputOuterRadius: NSNumber = 0.25
    public var inputRotation: NSNumber = 0.0
    
    override public func setDefaults() {
        self.inputImage = nil
        self.inputOutputImageSize = 512.0
        self.inputInnerRadius = 0.25
        self.inputOuterRadius = 0.25
        self.inputRotation = 0.0
    }
    
    override public var outputImage: CIImage? {
        guard let image = inputImage else { return nil }
        
        return BPPlanetFilter.applyPlanetWrap(image,
                                              outputImageSize: inputOutputImageSize.CGFloatValue,
                                              innerR: inputInnerRadius.CGFloatValue,
                                              outerR: inputOuterRadius.CGFloatValue,
                                              rotation: inputRotation.CGFloatValue)
        
    }
    
}


// Convenience functions to apply the kernel directly without creating a CIFilter object and scale a supplied UI Image to a size
// which CoreImage can use
extension BPPlanetFilter {

    public class func applyPlanetWrap(baseImage: CIImage, outputImageSize:CGFloat, innerR: CGFloat, outerR: CGFloat, rotation: CGFloat) -> CIImage {
        
        let bottomLine = CGRect(x: baseImage.extent.minX, y: baseImage.extent.minY, width: baseImage.extent.width, height: 2)
        
        let bottomAverageColour = baseImage.averageColour(rect: bottomLine, context: CIContext(options: nil))

        let baseExtent = baseImage.extent
        
        let image = baseImage.imageByClampingToExtent()
        
        let outputImageExtent = CGRect(x: -outputImageSize * 0.5, y: -outputImageSize * 0.5, width: outputImageSize, height: outputImageSize)
        
        let roiForCallback = CGRect(x: baseExtent.minX,
                                    y: baseExtent.minY - innerR * baseExtent.height,
                                    width: baseExtent.width,
                                    height: baseExtent.height * (1.0 + innerR + outerR * CGFloat(M_SQRT2) ) )
        
        let sX = 0.5 * baseExtent.width * CGFloat(M_1_PI)
        let sY = 2.0 * (1.0 + innerR + outerR) * baseExtent.height / outputImageSize
        let tY = innerR * baseExtent.height
        let rot = (rotation % 360.0 + 360.0) * CGFloat(M_PI) / 180.0
        
        var imageProc = BubblePixKernels.planetCore().applyWithExtent(outputImageExtent,
                                                                        roiCallback: { _,_ in roiForCallback },
                                                                        inputImage: image,
                                                                        arguments: [tY, sX, sY, rot])!
        
        let maxBlur = 200.0
        let b0 = outputImageSize * innerR * 0.5 / ( 1.0 + innerR + outerR)
        let b1 = outputImageSize * ( 1.0 + innerR) * 0.5 / ( 1.0 + innerR + outerR)
        let b2 = outputImageSize * 0.5 * CGFloat(M_SQRT2)
        let blurMask = BubblePixKernels.blurAmount().applyWithExtent(imageProc.extent, arguments: [b0 * 1.2, b1, b2])
        
        imageProc = BubblePixKernels.blendToColourRadial().applyWithExtent(imageProc.extent, arguments: [imageProc, bottomAverageColour, b0 * 0.4, b0 * 1.1])!
        
        
        let filter = CIFilter(name: "CIMaskedVariableBlur")!
        filter.setValue(imageProc, forKey: kCIInputImageKey)
        filter.setValue(blurMask, forKey: "inputMask")
        filter.setValue(maxBlur, forKey: kCIInputRadiusKey)
        imageProc = filter.outputImage!.imageByCroppingToRect(imageProc.extent)
        
        return imageProc
        
        
        // For output image x = 0: points on
        //  Input Image Y                               Output Image Y
        //  -innerR * baseExtent.height             :   0.0
        //  0.0                                     :   outputImageSize * innerR * 0.5 / ( 1.0 + innerR + outerR)
        //  baseExtent.height                       :   outputImageSize * ( 1.0 + innerR) * 0.5 / ( 1.0 + innerR + outerR)
        //  (1.0 + outerR) * baseExtent.height      :   outputImageSize * 0.5 * CGFloat(M_SQRT2)
        
    }


    class func createPlanetBubbleFromImage(fullSizedImage: UIImage, outputImageSize: CGFloat, innerR: CGFloat, outerR: CGFloat, rotation: CGFloat, context: CIContext, completion: (UIImage?, NSError?) -> Void ) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            
            let maxSize = CGSize(width: 4096.0, height: 1024.0)
            let inputSize = CGSize(width: min(context.inputImageMaximumSize().width, maxSize.width), height: min(context.inputImageMaximumSize().height, maxSize.height))
            
            guard let scaled_ci = fullSizedImage.CIImage ?? CIImage(image: fullSizedImage.imageScaledToFit(inputSize, exact: true)) else {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(nil, nil)
                    }
                    return
            }
            
            let outputSize = max(512.0, min(ceil(scaled_ci.extent.width * 0.5 * CGFloat(M_1_PI) / innerR), outputImageSize, 2048.0))
            
            let output = applyPlanetWrap(scaled_ci, outputImageSize: outputSize, innerR: innerR, outerR: outerR, rotation: rotation)
            
            let output_cg = context.createCGImage(output, fromRect: output.extent)
            
            let output_ui = UIImage(CGImage: output_cg)
            
            dispatch_async(dispatch_get_main_queue()) {
                completion(output_ui, nil)
            }
        }
    }
    
}


extension BPPlanetFilter {
    
    private static var FORMAT_IDENTIFIER = "com.bubblepix.BPPlanetFilter"
    
    // Version 1.00
    private static var FORMAT_VERSION = BPPlanetFilterVersion.V100
    private enum BPPlanetFilterVersion: String {
        case V100 = "000100"
    }
    private var parameterDictionaryV100:[String: AnyObject] {
        get {
            return ["inputOutputImageSize": inputOutputImageSize, "inputInnerRadius": inputInnerRadius, "inputOuterRadius": inputOuterRadius, "inputRotation": inputRotation]
        }
        set {
            self.inputOutputImageSize = newValue["inputOutputImageSize"] as! NSNumber
            self.inputInnerRadius = newValue["inputInnerRadius"] as! NSNumber
            self.inputOuterRadius = newValue["inputOuterRadius"] as! NSNumber
            self.inputRotation = newValue["inputRotation"] as! NSNumber
        }
    }
    
    
    public var adjustmentData: PHAdjustmentData {
        get {
            let data = NSKeyedArchiver.archivedDataWithRootObject(self.parameterDictionaryV100)
            return PHAdjustmentData(formatIdentifier: BPPlanetFilter.FORMAT_IDENTIFIER, formatVersion: BPPlanetFilter.FORMAT_VERSION.rawValue, data: data)
        }
        set {
            assert(newValue.formatIdentifier == BPPlanetFilter.FORMAT_IDENTIFIER)
            switch BPPlanetFilterVersion(rawValue: newValue.formatVersion)! {
            case .V100: self.parameterDictionaryV100 = NSKeyedUnarchiver.unarchiveObjectWithData(newValue.data) as! [String: AnyObject]
            }
        }
    }
    
}

// MARK: Native type getters and setters
extension BPPlanetFilter {
    public var outputImageSize: Int {
        get {
            return self.inputOutputImageSize.integerValue
        }
        set {
            self.inputOutputImageSize = NSNumber(integer: newValue)
        }
    }
    public var innerR: CGFloat {
        get {
            return self.inputInnerRadius.CGFloatValue
        }
        set {
            self.inputInnerRadius = NSNumber(CGFloatValue: newValue)
        }
    }
    public var outerR: CGFloat {
        get {
            return self.inputOuterRadius.CGFloatValue
        }
        set {
            self.inputOuterRadius = NSNumber(CGFloatValue: newValue)
        }
    }
    public var rotation: CGFloat {
        get {
            return self.inputRotation.CGFloatValue
        }
        set {
            self.inputRotation = NSNumber(CGFloatValue: newValue)
        }
    }
}






