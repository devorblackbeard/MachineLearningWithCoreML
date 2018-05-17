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
import Darwin

protocol PhotoSearcherDelegate : class{
    func onPhotoSearcherCompleted(status: Int, result:[SearchResult]?)
}

class PhotoSearcher{
    
    weak var delegate : PhotoSearcherDelegate?        
    
    let yolo = YOLOFacade()
    
    public func asyncSearch(searchCriteria : [ObjectBounds]?){
        DispatchQueue.global(qos: .background).sync {
            let photos = getPhotos()
            
            let unscoredSearchResults = self.detectObjects(photos: photos)
            
            var sortedSearchResults : [SearchResult]?
            
            if let unscoredSearchResults = unscoredSearchResults{
                sortedSearchResults = self.scoreObjects(
                    detectedObjects:unscoredSearchResults ,
                    searchCriteria: searchCriteria).sorted(by: { (a, b) -> Bool in
                        return a.cost < b.cost
                    })
            }
            
            DispatchQueue.main.async {
                self.delegate?.onPhotoSearcherCompleted(
                    status: 1,
                    result: sortedSearchResults)
            }
        }
    }
}

// MARK: - Photo DataSource

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
                targetSize: yolo.targetSize,
                contentMode: .aspectFill,
                options: requestOptions,
                resultHandler: { (image, bundle) in
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
    
    func detectObjects(photos:[UIImage]) -> [SearchResult]?{
        var results = [SearchResult]()
        
        for photo in photos{
            
            yolo.detectObjects(photo: photo) { (result) in
                if let result = result{
                    results.append(SearchResult(image: photo, detectedObjects: result, cost: 0.0))
                }
            }
        }
        
        return results
    }            
}

// MARK: Photo Ordering

extension PhotoSearcher{
    
    private func scoreObjects(detectedObjects:[SearchResult], searchCriteria:[ObjectBounds]?) -> [SearchResult]{
        guard let searchCriteria = searchCriteria else{
            return detectedObjects
        }
        
        var result = [SearchResult]()
        
        for searchResult in detectedObjects{
            let cost = self.costForObjectPresences(detectedObject: searchResult, searchCriteria: searchCriteria) +
                self.costForObjectRelativePositions(detectedObject: searchResult, searchCriteria: searchCriteria) +
                self.costForObjectSizeRelativeToImageSize(detectedObject: searchResult, searchCriteria: searchCriteria) +
                self.costForObjectSizeRelativeToOtherObjects(detectedObject: searchResult, searchCriteria: searchCriteria)
            
            result.append(SearchResult(image: searchResult.image,
                                                      detectedObjects:searchResult.detectedObjects,
                                                      cost: cost))
        }
        
        return result
    }
    
    private func costForObjectPresences(detectedObject:SearchResult, searchCriteria:[ObjectBounds], weight:Float=2.0) -> Float{
        var cost : Float = 0.0
        
        var searchObjectCounts = searchCriteria.map { (detectedObject) -> String in
            return detectedObject.object.label
            }.reduce([:]) { (counter:[String:Float] , label) -> [String:Float] in
                var counter = counter
                counter[label] = counter[label]?.advanced(by: 1) ?? 1
                return counter
        }
        
        var detectedObjectCounts = detectedObject.detectedObjects.map { (detectedObject) -> String in
            return detectedObject.object.label
            }.reduce([:]) { (counter:[String:Float] , label) -> [String:Float] in
                var counter = counter
                counter[label] = counter[label]?.advanced(by: 1) ?? 1
                return counter
        }
        
        // Iterate through all possible labels and compute the cost based on the
        // difference between the two dictionaries
        for detectableObject in DetectableObject.objects{
            let label = detectableObject.label
            
            let searchCount = searchObjectCounts[label] ?? 0
            let detectedCount = detectedObjectCounts[label] ?? 0
            
            cost += (searchCount - detectedCount)
        }
        return cost * weight
    }
    
    private func costForObjectRelativePositioning(detectedObject:SearchResult,
                                                  searchCriteria:[ObjectBounds],
                                                  weight:Float=1.5) -> Float{
        
        func findClosestObject(objects:[ObjectBounds], forObjectAtIndex i:Int) -> ObjectBounds?{
            let searchACenter = objects[i].bounds.center
            
            var closestDistance = FLT_MAX
            var closestObjectBounds : ObjectBounds?
            
            for j in i+1..<objects.count{
                // TODO
            }
            
            return closestObjectBounds
        }
        
        for si in 0..<searchCriteria.count{
            let searchACenter = searchCriteria[si].bounds.center
            
            for j in i+1
        }
        
        return 0.0
    }
    
    private func costForObjectSizeRelativeToImageSize(detectedObject:SearchResult,
                                                      searchCriteria:[ObjectBounds],
                                                      weight:Float=1.0) -> Float{
        return 0.0
    }
    
    private func costForObjectSizeRelativeToOtherObjects(detectedObject:SearchResult,
                                                         searchCriteria:[ObjectBounds],
                                                         weight:Float=0.5) -> Float{
        return 0.0
    }
}

