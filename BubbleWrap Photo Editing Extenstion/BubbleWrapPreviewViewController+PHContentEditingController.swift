//
//  BubbleWrapPreviewViewController+PHContentEditingController.swift
//  BubbleWrap Photo Editing Extenstion
//
//  Created by Paul Jones on 16/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import UIKit
import Photos
import PhotosUI


extension BubbleWrapPreviewViewController: PHContentEditingController {
    
    func configure() {
        self.showHideToolbar(false, animated: false)
    }
    
    func canHandleAdjustmentData(adjustmentData: PHAdjustmentData!) -> Bool {
        return false
    }

    var shouldShowCancelConfirmation: Bool { return false }
    
    func cancelContentEditing() {
        // Clean up temporary files, etc.
        // May be called after finishContentEditingWithCompletionHandler: while you prepare output.
    }
    
    func startContentEditingWithInput(contentEditingInput: PHContentEditingInput!, placeholderImage: UIImage!) {
        self.photoEditingContentInput = contentEditingInput
        
        self.previewFilter.setDefaults()
        
        self.sourceThumbnail = placeholderImage
        
    }
    
    func finishContentEditingWithCompletionHandler(completionHandler: ((PHContentEditingOutput!) -> Void)!) {
        
        guard let phInput = self.photoEditingContentInput else {
            print("No Content Input")
            return
        }
        
        // Update UI to reflect that editing has finished and output is being rendered.
        
        let output = PHContentEditingOutput(contentEditingInput: phInput)
        
        dispatch_async(imageProcessingQueue) {
            
            guard let img = UIImage(contentsOfURL: phInput.fullSizeImageURL!) else {
                // TODO: handle errors
                return
            }
            
            let rv = self.generateFullSizedPlanetSync(sourceImage: img)
            guard let adjData = rv.data,
                let image = rv.image,
                let renderedJPEGData = UIImageJPEGRepresentation(image, 1.0) else {
                // TODO: handle errors
                return
            }
            
            output.adjustmentData = adjData
            
            renderedJPEGData.writeToURL(output.renderedContentURL, atomically: true)
            
            completionHandler?(output)
            
        }
        
    }
    
}

