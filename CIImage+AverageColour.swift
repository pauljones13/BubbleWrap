//
//  CIImage+AverageColour.swift
//  BubbleWrap
//
//  Created by Paul Jones on 02/08/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import CoreImage

extension CIImage {
    
    // Use the CIAreaAverage filter to calculate the average colour of a region of a CIImage and return as a CIColor
    func averageColour(rect rect: CGRect, context: CIContext) -> CIColor {
        let ciPixel = self.imageByApplyingFilter("CIAreaAverage", withInputParameters: [kCIInputExtentKey: CIVector(CGRect: rect)])
        
        var colourData = [UInt8](count: 4, repeatedValue: 0)
        
        context.render(ciPixel, toBitmap: UnsafeMutablePointer<Void>(colourData), rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height:1), format: kCIFormatRGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        let red = CGFloat(colourData[0]) / CGFloat(colourData[3])
        let green = CGFloat(colourData[1]) / CGFloat(colourData[3])
        let blue = CGFloat(colourData[2]) / CGFloat(colourData[3])
        
        return CIColor(red: red, green: green, blue: blue)
        
    }
}


