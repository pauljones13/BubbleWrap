//
//  BubbleWrapPreviewViewController+Action.swift
//  BubbleWrap Action Extension
//
//  Created by Paul Jones on 16/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import UIKit
import MobileCoreServices
import Photos


let noVideoSupport = NSError(domain: NSBundle.mainBundle().bundleIdentifier!, code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "Video is not supported at present"])

extension BubbleWrapPreviewViewController {
    
    var itemProvider: NSItemProvider? {
        for inputItem in (self.extensionContext?.inputItems as? [NSExtensionItem]) ?? [] {
            for itemProvider in (inputItem.attachments as? [NSItemProvider]) ?? []
                where itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) ||
                itemProvider.hasItemConformingToTypeIdentifier(kUTTypeMPEG4 as String) {
                    return itemProvider
            }
        }
        return nil
    }

    func configure() {

        self.showHideToolbar(true, animated: false)
        
        let barItem0 = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Cancel, target: self,
                                    action: #selector(BubbleWrapPreviewViewController.toolbarCancel(_:)))
        let barItem1 = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil,
                                    action: nil)
        let barItem2 = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self,
                                    action: #selector(BubbleWrapPreviewViewController.toolbarSave(_:)))
        barItem2.enabled = false
        self.toolbar.setItems([barItem0, barItem1, barItem2], animated: true)
        
        
        guard let item = self.itemProvider else {
            // TODO: Error handling
            self.cancel(nil)
            return
        }
        
        self.previewFilter.setDefaults()

        if item.hasItemConformingToTypeIdentifier(kUTTypeMPEG4 as String) {
            
            item.loadItemForTypeIdentifier(kUTTypeMPEG4 as String, options: nil) {
                item, error in
                
                guard let videoURL = item as? NSURL else {
                    // TODO: Error handling
                    dispatch_async(dispatch_get_main_queue()) {
                        self.cancel(nil)
                    }
                    return
                }
                
                AVURLAsset(URL: videoURL, options: nil).requestMidPointPreviewImage {
                    imageObj, error in
                    guard let image = imageObj else {
                        // TODO: Error handling
                        self.cancel(error)
                        return
                    }
                    self.sourceThumbnail = image
                }

            }
            
        }
        else {
            item.loadItemForTypeIdentifier(kUTTypeImage as String, options: nil) {
                item, error in
                
                let img:UIImage?
                
                if let image = item as? UIImage {
                    img = image.imageScaledToFit(CGSize(width: 1024, height: 1024), exact: false)
                }
                else if let imageURL = item as? NSURL {
                    img = UIImage(contentsOfURL: imageURL, scaleToSize: CGSize(width: 1024, height: 1024), exactly: false)
                }
                else {
                    img = nil
                }
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.sourceThumbnail = img
                    if img == nil  {
                        // TODO: Error handling
                        self.cancel(nil)
                    }
                    else {
                        barItem2.enabled = true
                    }
                }
 
            }
        }

    }
    
    func cancel(error:NSError?) {
        if let error = error {
            print("ERROR", error, error.localizedDescription)
            self.extensionContext?.cancelRequestWithError(error)
        }
        else {
            print("CANCEL")
            self.extensionContext?.completeRequestReturningItems([], completionHandler: nil)
        }
    }
    
    
    
    @IBAction func toolbarSave(sender: UIBarButtonItem) {
        
        sender.enabled = false
        
        guard let item = self.itemProvider else {
            // TODO: Error handling
            self.cancel(nil)
            return
        }
        
        // !!!: try weak self here
        item.loadItemForTypeIdentifier(kUTTypeImage as String, options: nil) {
            item, error in
            
            
            let completionHandler: (UIImage?, PHAdjustmentData?, NSError?) -> Void = {
                imageObj, _, error in
                
                guard let image = imageObj else {
                    // TODO: Error handling
                    self.cancel(error)
                    sender.enabled = true
                    return
                }

                let shareActivity = ActivityViewController(activityItems: [image], applicationActivities: [])
                
                shareActivity.excludedActivityTypes = [UIActivityTypePostToWeibo, UIActivityTypePostToTencentWeibo]
                
                if let bundleID = NSBundle.mainBundle().bundleIdentifier {
                    shareActivity.excludedActivityTypes?.append(bundleID)
                }
                
                shareActivity.modalPresentationStyle = .Popover
                
                // popoverPresentationController will non-nil on iPad - need to set barButtonItem
                shareActivity.popoverPresentationController?.permittedArrowDirections = .Any
                shareActivity.popoverPresentationController?.barButtonItem = sender
                
                shareActivity.completionWithItemsHandler = {
                    activityType, completed, returnedItems, activityError in
                    
                    // Don't finish with action if share was not completed or image was only copied to pasteboard
                    if completed && activityType != UIActivityTypeCopyToPasteboard && activityError == nil {
                        self.extensionContext?.completeRequestReturningItems(returnedItems, completionHandler: nil)
                    }

                }
                
                self.presentViewController(shareActivity, animated: true) {
                    sender.enabled = true
                }
                
            }
            
            if let image = item as? UIImage {
                self.generateFullSizedPlanet(sourceImage: image, completionHandler: completionHandler)
            }
            else if let imageURL = item as? NSURL {
                self.generateFullSizedPlanet(sourceURL: imageURL, completionHandler: completionHandler)
            }
            else {
                // TODO: Support making moving planets
                self.cancel(noVideoSupport)
            }
            
        }
        
    }
    
    @IBAction func toolbarCancel(sender: UIBarButtonItem) {
        self.cancel(nil)
    }
    

}


