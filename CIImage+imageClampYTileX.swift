//
//  CIImage+imageClampYTileX.swift
//  BubblePix
//
//  Created by Paul Jones on 13/06/2016.
//  Copyright © 2016 Fluid Pixel. All rights reserved.
//

import Foundation
import CoreImage

public extension CIImage {
    
    // Applies the custom kernel to clamp the image vertically and tile it horizontally
    public func imageClampYTileX() -> CIImage {
        
        let sourceROI = self.extent
        func roiCallback(image:Int32, dest:CGRect) -> CGRect {
            return sourceROI
        }
        let arguments = [self.extent.minX, self.extent.minY, self.extent.width, self.extent.maxY]
        let rv = BubblePixKernels.clampYTileX().applyWithExtent(CGRectInfinite, roiCallback: roiCallback, inputImage: self, arguments: arguments)!
        return rv
        
    }
}

