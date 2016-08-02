//
//  PhotoLibraryPanoramaCell.swift
//  BubbleWrap
//
//  Created by Paul Jones on 18/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import UIKit
import Photos

class PhotoLibraryPanoramaCell: UITableViewCell {
    
    @IBOutlet var thumbnailImageView: UIImageView!
    
    var imageRequest:PHImageRequestID = PHInvalidImageRequestID {
        willSet {
            if self.imageRequest != PHInvalidImageRequestID {
                // Cancel the existing request before updating a new one
                PHImageManager.defaultManager().cancelImageRequest(self.imageRequest)
            }
        }
    }
    
    override func prepareForReuse() {
        self.thumbnailImageView.image = nil
        self.phAsset = nil
        
        imageRequest = PHInvalidImageRequestID  // willSet will cancel the existing request
        
        self.tag = self.tag + 1
    }
    
    var phAsset:PHAsset? {
        didSet {
            guard let asset = self.phAsset else {
                self.thumbnailImageView.image = nil
                return
            }
            
            let id = self.tag
            
            self.imageRequest = PHImageManager.defaultManager().requestThumbnailImageForAsset(asset, targetSize: self.thumbnailImageView.frame.size) {
                imageObj, info in
                
                guard info?[PHImageCancelledKey] == nil else { return } // Make sure the request has not been cancelled
                
                guard id == self.tag else { // This makes sure the cell has not been reused since the image was requested
                    if let key = info?[PHImageResultRequestIDKey]?.intValue {
                        PHImageManager.defaultManager().cancelImageRequest(key)
                    }
                    return
                }
                
                
                guard let image = imageObj else {
                    self.thumbnailImageView.image = nil
                    print("Request failed: \(info)")
                    return
                }
                
                UIView.transitionWithView(self.thumbnailImageView,
                                          duration: (self.thumbnailImageView.image == nil) ? 0.10 : 0.50,
                                          options: .TransitionCrossDissolve,
                                          animations: { self.thumbnailImageView.image = image },
                                          completion: nil)
            }
            
        }
        
    }
    
}


