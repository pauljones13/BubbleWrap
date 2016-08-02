//
//  BubbleWrap.swift
//  BubbleWrap
//
//  Created by Paul Jones on 16/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import Foundation
import UIKit
import Photos
import PhotosUI
import CoreImage
import QuartzCore



// iOS9 doesn't let us exclude our own activities - we need to hack this by overriding a private method
// http://stackoverflow.com/questions/31792506/how-to-exclude-notes-and-reminders-apps-from-the-uiactivityviewcontroller
class ActivityViewController: UIActivityViewController {
    func _shouldExcludeActivityType(activity: UIActivity) -> Bool {
        if let actType = activity.activityType(),
            let excl = super.excludedActivityTypes {
            return excl.contains(actType)
        }
        return false
    }
}


class BubbleWrapPreviewViewController: UIViewController {
    // MARK: Temporary testing methods
    deinit { print(#file, #function) }
    
    // MARK: IBOutlets
    @IBOutlet var sourceImage:UIImageView!
    @IBOutlet var previewImage:UIImageView!
    
    @IBOutlet var toolbar:UIToolbar!
    @IBOutlet var toolbarTop: NSLayoutConstraint!

    @IBOutlet var progress: UIProgressView!
    
    
    internal let previewFilter = BPPlanetFilter()
    internal (set) var rotation: CGFloat = 0.0
    
    internal var imageProcessingQueue = dispatch_queue_create(NSBundle.mainBundle().bundleIdentifier! + ".imageproc", DISPATCH_QUEUE_SERIAL) // DISPATCH_QUEUE_CONCURRENT
    
    internal var photoEditingContentInput: PHContentEditingInput?
    internal let context = CIContext(options: nil)
    
    internal var contextMaxSize: CGSize {
        let maxSize = CGSize(width: 4096.0, height: 4096.0)
        return CGSize(width: min(self.context.inputImageMaximumSize().width, maxSize.width),
                      height: min(self.context.inputImageMaximumSize().height, maxSize.height))
    }
    
    // MARK: source image thumbnail - only modify this on the main queue
    var sourceThumbnail: UIImage? {
        didSet {
            
            guard self.sourceThumbnail != oldValue else { return }
            
            guard let img = self.sourceThumbnail else {
                print("THUMBNAIL SET TO NIL")
                self.previewFilter.inputImage = nil
                self.sourceImage.image = nil
                self.previewImage.image = nil
                return
            }
            
            self.sourceImage.image = img
            self.refreshPreview()
            
        }
    }
    
    // MARK: IBActions
    @IBAction func rotatePreview(sender: UIRotationGestureRecognizer) {
        
        self.previewImage.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(CGFloat(M_SQRT2), CGFloat(M_SQRT2)), self.rotation + sender.rotation)
        
        if sender.state == .Ended {
            self.rotation = self.rotation + sender.rotation
        }
        
    }
    
    
    internal func showHideToolbar(show: Bool, animated: Bool) {
        if animated {
            if show {
                self.toolbar.hidden = false
                self.toolbarTop.constant = 0.0
                self.toolbar.alpha = 0.0
                UIView.animateWithDuration(1.0) {
                    self.view.layoutIfNeeded()
                    self.toolbar.alpha = 1.0
                }
            }
            else {
                self.toolbarTop.constant = -self.toolbar.frame.height
                UIView.animateWithDuration(1.0, animations: {
                    self.view.layoutIfNeeded()
                    self.toolbar.alpha = 0.0
                }) { _ in
                    self.toolbar.hidden = true
                }
            }
        }
        else {
            if show {
                self.toolbar.hidden = false
                self.toolbarTop.constant = 0.0
                self.toolbar.alpha = 1.0
            }
            else {
                self.toolbar.hidden = true
                self.toolbarTop.constant = -self.toolbar.frame.height
                self.toolbar.alpha = 0.0
            }
            self.view.layoutIfNeeded()
        }
    }
    
    
    // MARK: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configure()
    }

}

// MARK: Private synchronous image processing. Should not be run on the main queue
extension BubbleWrapPreviewViewController {
    private func filterImage(image: CIImage) -> (image: UIImage, data: PHAdjustmentData)? {
        
        let fullSizeFilter = BPPlanetFilter()
        fullSizeFilter.setDefaults()
        
        fullSizeFilter.outputImageSize = self.previewFilter.outputImageSize
        fullSizeFilter.innerR = self.previewFilter.innerR
        fullSizeFilter.outerR = self.previewFilter.outerR
        fullSizeFilter.rotation = self.rotation * -180.0 * CGFloat(M_1_PI)
        
        fullSizeFilter.inputImage = image
        guard let outputCIImage = fullSizeFilter.outputImage else { return nil }
        
        let outImg = UIImage(CGImage: self.context.createCGImage(outputCIImage, fromRect: outputCIImage.extent))
        
        return (outImg, fullSizeFilter.adjustmentData)
        
    }
    
    internal func generateFullSizedPlanetSync(sourceImage sourceImage: UIImage) -> (image: UIImage?, data: PHAdjustmentData?, error: NSError?) {
        
        guard let scaled_ci = CIImage(image: sourceImage.imageScaledToFit(self.contextMaxSize, exact: true)),
            let output = self.filterImage(scaled_ci) else {
                print("Could not create CI Image")
                return (nil, nil, nil)
        }
        
        return (output.image, output.data, nil)

    }
    
    private func shareFullSizedPlanetSync(sourceImage sourceImage: UIImage, sender: UIBarButtonItem) -> UIActivityViewController? {
        
        guard let output = generateFullSizedPlanetSync(sourceImage: sourceImage).image else {
            return nil
        }
        
        // TODO: need to check this is OK off the main queue (the VC is not being presented, only configured)
        
        let shareActivity = ActivityViewController(activityItems: [output], applicationActivities: [])
        
        shareActivity.excludedActivityTypes = [UIActivityTypePostToWeibo, UIActivityTypePostToTencentWeibo]
        
        if let bundleID = NSBundle.mainBundle().bundleIdentifier {
            print("Excluding: \(bundleID)")
            shareActivity.excludedActivityTypes?.append(bundleID)
        }
        
        shareActivity.modalPresentationStyle = .Popover
        
        // popoverPresentationController will non-nil on iPad - need to set barButtonItem
        shareActivity.popoverPresentationController?.permittedArrowDirections = .Any
        shareActivity.popoverPresentationController?.barButtonItem = sender
        
        return shareActivity
        
    }
}


// MARK: public/internal asynchronous image processing can be run on any queue, including the main queue
extension BubbleWrapPreviewViewController {
    internal func generateFullSizedPlanet(sourceURL sourceURL: NSURL, completionHandler: (image: UIImage?, data: PHAdjustmentData?, error: NSError?) -> Void) {
        dispatch_async(imageProcessingQueue) {
            guard let img = UIImage(contentsOfURL: sourceURL) else {
                dispatch_async(dispatch_get_main_queue()) {
                    // TODO: Provide an error message
                    completionHandler(image: nil, data: nil, error: nil)
                }
                return
            }
            
            let rv = self.generateFullSizedPlanetSync(sourceImage: img)
            
            dispatch_async(dispatch_get_main_queue()) {
                completionHandler(image: rv.image, data: rv.data, error: rv.error)
            }

        }
    }
    internal func generateFullSizedPlanet(sourceImage sourceImage: UIImage, completionHandler: (image: UIImage?, data: PHAdjustmentData?, error: NSError?) -> Void) {
        dispatch_async(imageProcessingQueue) {
            let rv = self.generateFullSizedPlanetSync(sourceImage: sourceImage)
            dispatch_async(dispatch_get_main_queue()) {
                completionHandler(image: rv.image, data: rv.data, error: rv.error)
            }
        }
    }
    internal func shareFullSizedPlanet(sourceURL sourceURL: NSURL, sender: UIBarButtonItem, completionHandler: (UIActivityViewController?) -> Void) {
        
        dispatch_async(imageProcessingQueue) {
            guard let sourceImage = UIImage(contentsOfURL: sourceURL) else {
                dispatch_async(dispatch_get_main_queue()) {
                    completionHandler(nil)
                }
                return
            }
            
            let rv = self.shareFullSizedPlanetSync(sourceImage: sourceImage, sender: sender)
            
            dispatch_async(dispatch_get_main_queue()) {
                completionHandler(rv)
            }
            
        }
    }
    internal func shareFullSizedPlanet(sourceImage sourceImage: UIImage, sender: UIBarButtonItem, completionHandler: (UIActivityViewController?) -> Void) {
        dispatch_async(imageProcessingQueue) {
            
            let rv = self.shareFullSizedPlanetSync(sourceImage: sourceImage, sender: sender)
            
            dispatch_async(dispatch_get_main_queue()) {
                completionHandler(rv)
            }
            
        }
    }
    
    internal func refreshPreview() {

        dispatch_async(imageProcessingQueue) {
            [weak self] in
            
            guard let sourceImage = self?.sourceImage.image,
                   let size = self?.previewImage.frame.size,
                    let context = self?.context else { return }
            
            self?.previewFilter.inputImage = CIImage(image: sourceImage)
            self?.previewFilter.outputImageSize = min(Int(ceil(size.width)), Int(ceil(size.height)))
            
            guard let planetPreview = self?.previewFilter.outputImage else { return }
            
            let inset = CGFloat(0.5 * (1.0 - M_SQRT2))
            let extendedRect = planetPreview.extent.insetBy(dx: planetPreview.extent.width * inset, dy: planetPreview.extent.height * inset)

            let compImg = UIImage(CGImage: context.createCGImage(planetPreview.imageByClampingToExtent(), fromRect: extendedRect))
            
            dispatch_async(dispatch_get_main_queue()) {
                guard let rotation = self?.rotation else { return }
                self?.previewImage.image = compImg
                self?.previewImage.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(CGFloat(M_SQRT2), CGFloat(M_SQRT2)), rotation)
            }
            
        }
        
    }

}


