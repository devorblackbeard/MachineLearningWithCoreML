//
//  PhotoSearcher.swift
//  ObjectDetection
//
//  Created by Joshua Newnham on 14/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit
import Photos

protocol PhotoSearcherDelegate : class{
    func onPhotoSearcherCompleted(status: Int, result:[SearchResult]?)
}

class PhotoSearcher{
    
    weak var delegate : PhotoSearcherDelegate?
    
    var targetSize = CGSize(width: 416, height: 416)
    
    public func search(searchCriteria : [ObjectBounds]?){
        DispatchQueue.global(qos: .background).sync {
            
            var results = [SearchResult]()
            
            let photos = getPhotos()
            
            
            for photo in photos{
                let searchResult = SearchResult(
                    image: photo,
                    detectedObjects: [],
                    score: 0.0)
                
                results.append(searchResult)
            }
            
            DispatchQueue.main.async {
                self.delegate?.onPhotoSearcherCompleted(
                    status: 1,
                    result: results)
            }
        }
    }
}

// MARK: - Photo search

extension PhotoSearcher{
    
    func getPhotos() -> [UIImage]{
        var photos = [UIImage]()
        
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        
        let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        for i in 0..<fetchResult.count{
            PHImageManager.default().requestImage(
                for: fetchResult.object(at: i) as PHAsset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestOptions,
                resultHandler: { (image, error) in
                    if let image = image{
                        photos.append(image)
                    }
                }
            )
        }
        
        return photos
    }
}

