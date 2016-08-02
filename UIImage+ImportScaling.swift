//
//  UIImage+ImportScaling.swift
//  BubbleWrap
//
//  Created by Paul Jones on 16/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import UIKit


public extension UIImage {
    
    public convenience init?(contentsOfURL url: NSURL) {
        guard let data = NSData(contentsOfURL: url) else { return nil }
        self.init(data: data)
    }
    
    public convenience init?(contentsOfURL url: NSURL, scaleToSize: CGSize, exactly: Bool) {
        guard let image = UIImage(contentsOfURL: url) else { return nil }
        guard let scaledToCG = image.imageScaledToFit(scaleToSize, exact: exactly).CGImage else { return nil }
        self.init(CGImage: scaledToCG)
    }
    
    public func imageScaledToFit(targetSize: CGSize, exact: Bool) -> UIImage {
        
        guard self.size.width > targetSize.width || self.size.height > targetSize.height else { return self }
        
        let newRect:CGRect
        if exact {
            let scale = min(1.0, targetSize.width / self.size.width, targetSize.height / self.size.height)
            newRect = CGRect(x: 0.0, y: 0.0, width: self.size.width * scale, height: self.size.height * scale).integral.intersect(CGRect(origin: CGPointZero, size: targetSize))
        }
        else {
            var zRect = CGRect(origin: CGPointZero, size: self.size)
            while zRect.size.width > targetSize.width || zRect.size.height > targetSize.height {
                zRect.size.width /= 2
                zRect.size.height /= 2
                zRect.makeIntegralInPlace()
            }
            newRect = zRect
        }
        
        UIGraphicsBeginImageContext(newRect.size)
        self.drawInRect(newRect)
        let rv = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return rv
        
    }
    
}