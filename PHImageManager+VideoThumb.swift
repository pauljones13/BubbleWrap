//
//  PHImageManager+VideoThumb.swift
//  BubbleWrap
//
//  Created by Paul Jones on 17/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import UIKit
import Photos


extension PHImageManager {

    func requestThumbnailImageForAsset(asset: PHAsset, targetSize: CGSize, completion: (UIImage?, [NSObject : AnyObject]?) -> Void ) -> PHImageRequestID{

        switch asset.mediaType {
            
        case .Audio:    completion(nil, nil)
                        return 0
            
        case .Unknown:  completion(nil, nil)
                        return 0
            
        case .Image: return self.requestImageForAsset(asset, targetSize: targetSize, contentMode: .AspectFit, options: nil, resultHandler: completion)
            
        case .Video: return self.requestAVAssetForVideo(asset, options: nil) {
                assetObj, _, info in
                
                guard let av_asset = assetObj as? AVURLAsset else {
                    completion(nil, info)
                    return
                }
                
                let maxSize = CGSize(width: targetSize.width, height: targetSize.width * CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth))
                av_asset.requestMidPointPreviewImage(maximumSize: maxSize) {
                    image, error in
                    
                    var rvInfo = info
                    if let error = error {
                        rvInfo?.updateValue(error, forKey: "NSError")
                    }
                    
                    completion(image, info)
                    
                }
            }
            
        }
    }
}
