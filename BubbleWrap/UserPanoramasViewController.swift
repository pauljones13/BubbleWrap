//
//  UserPanoramasViewController.swift
//  BubbleWrap
//
//  Created by Paul Jones on 16/05/2016.
//  Copyright © 2016 Fluid Pixel Limited. All rights reserved.
//

import UIKit
import Photos

class UserPanoramasViewController: UITableViewController {

    weak var previewEdit: BubbleWrapPreviewViewController? = nil
    var previewEditAsset: PHAsset?
    
    var photoPanoramas:PHFetchResult?

    override func viewWillAppear(animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
        super.viewWillAppear(animated)
        
        PHPhotoLibrary.requestAuthorization {
            status in
            
            guard status == .Authorized else {
                // TODO: handle no permissions
                return
            }
            
            guard let iosPanosCollection = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumPanoramas, options: nil).firstObject as? PHAssetCollection else {
                // TODO: handle no panos album
                return
            }
            
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            self.photoPanoramas = PHAsset.fetchAssetsInAssetCollection(iosPanosCollection, options: options)
            
            PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
            
            dispatch_async(dispatch_get_main_queue()) {
                self.tableView.reloadData()
            }
            
        }
        
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
        
    }

    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        
        if segue.identifier == "showDetail",
            let nav = segue.destinationViewController as? UINavigationController,
            let previewView = nav.topViewController as? BubbleWrapPreviewViewController,
            let senderCell = sender as? PhotoLibraryPanoramaCell,
            let phAsset = senderCell.phAsset {
            
            
            self.previewEdit = previewView
            self.previewEditAsset = nil
            
            previewView.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
            previewView.navigationItem.leftItemsSupplementBackButton = true
            
            // even though this is on the main queue, the previewView is not fully configured so we need to dispatch a block
            // which will run after it is configured
            dispatch_async(dispatch_get_main_queue()) {
                previewView.showHideToolbar(false, animated: false)
                
                if phAsset.mediaType == .Video {
                    previewView.previewFilter.innerR = -0.25
                    previewView.previewFilter.outerR = -0.21
                }
                
                previewView.sourceThumbnail = senderCell.thumbnailImageView.image
                
                PHImageManager.defaultManager().requestThumbnailImageForAsset(phAsset, targetSize: previewView.previewImage.frame.size) {
                    imageObj, info in
                    
                    guard let image = imageObj else {
                        print(info)
                        return
                    }
                    

                    previewView.sourceThumbnail = image

                    self.previewEditAsset = phAsset
                    
                    previewView.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self,
                                                                                    action: #selector(UserPanoramasViewController.previewEdit_Action(_:)))
                    
                }
                
            }
            
        }
        
    }
    
    
    func previewEdit_Action(sender: UIBarButtonItem) {
        sender.enabled = false
        
        guard let controller = self.previewEdit else { return }
        guard let phAsset = self.previewEditAsset else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .HighQualityFormat
        
        PHImageManager.defaultManager().requestImageForAsset(phAsset, targetSize: controller.context.inputImageMaximumSize(), contentMode: .AspectFit, options: options) {
            imageObj, info in
            
            guard let image = imageObj else {
                print(info)
                return
            }
            
            controller.shareFullSizedPlanet(sourceImage: image, sender: sender) {
                viewController in
                guard let vc = viewController else { return }
                
                self.presentViewController(vc, animated: true) {
                    sender.enabled = true
                }
            }
            
        }
        
    }
    
    
}

// MARK: - Table View
extension UserPanoramasViewController {
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.photoPanoramas?.count ?? 0
    }
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PhotoLibraryPanoramaCell", forIndexPath: indexPath) as! PhotoLibraryPanoramaCell
        cell.phAsset = self.photoPanoramas?.objectAtIndex(indexPath.row) as? PHAsset
        return cell
    }
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        guard let asset = self.photoPanoramas?.objectAtIndex(indexPath.row) as? PHAsset where asset.mediaType == .Image else {
            return self.tableView.frame.width * 0.5 + 8.0
        }
        return self.tableView.frame.width * CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth) + 8.0
    }
}

// MARK: - PHPhotoLibraryChangeObserver
extension UserPanoramasViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(changeInstance: PHChange) {
        // TODO: Make this look good
        self.tableView.reloadData()
    }
}



