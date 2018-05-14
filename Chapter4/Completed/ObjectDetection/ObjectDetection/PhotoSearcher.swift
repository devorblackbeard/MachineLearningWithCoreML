//
//  PhotoSearcher.swift
//  ObjectDetection
//
//  Created by Joshua Newnham on 14/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit
import Photos
import CoreML
import Vision

protocol PhotoSearcherDelegate : class{
    func onPhotoSearcherCompleted(status: Int, result:[SearchResult]?)
}

class PhotoSearcher{
    
    weak var delegate : PhotoSearcherDelegate?
    
    var targetSize = CGSize(width: 416, height: 416)
    
    lazy var model : VNCoreMLModel = {
        do{
            let model = try VNCoreMLModel(
                for: tinyyolo_voc2007().model)
            return model
        } catch{
            fatalError("Failed to obtain tinyyolo_voc2007")
        }
    }()
    
    
    
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

// MARK: - CoreML

extension PhotoSearcher{
    
    func objectDetection(photos:[UIImage]) -> [SearchResult]?{
        var results = [SearchResult]()
        
        for photo in photos{
            if let searchResult = objectDetection(photo: photo){
                results.append(searchResult)
            }
        }
        
        return results
    }
    
    func objectDetection(photo:UIImage) -> SearchResult?{
        guard let cgImage = photo.cgImage else{
            return nil
        }
        
        let request = VNCoreMLRequest(model: self.model)
        request.imageCropAndScaleOption = .centerCrop
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform classification.\n\(error.localizedDescription)")
            return nil
        }
        
        guard let observations = request.results as? [VNCoreMLFeatureValueObservation] else{
            return nil
        }
        
        for observation in observations{
            guard let multiArray = observation.featureValue.multiArrayValue else{
                continue
            }
        }
        
        return nil
    }
}

