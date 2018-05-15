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
            
            let detectedObjects = self.detectObjects(photos: photos)
            
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
    
    func detectObjects(photos:[UIImage]) -> [SearchResult]?{
        var results = [SearchResult]()
        
        for photo in photos{
            if let searchResult = detectObjects(photo: photo){
                results.append(searchResult)
            }
        }
        
        return results
    }
    
    func detectObjects(photo:UIImage) -> SearchResult?{
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
            
            if let detectedObjectBounds = self.detectObjectsBounds(array: multiArray){
                
            }
        }
        
        return nil
    }
    
    /**
     Process the result of the model and return an instance of the search results
     @param array Output from the TinyYOLO model; expecting the shape 125x13x13
     @param objectThreshold object threshold (based on the sigmod of the <object present confidence> and <probability class n>
     @return SearchResult search results
    **/
    func detectObjectsBounds(array:MLMultiArray, objectThreshold:Float = 0.3) -> [ObjectBounds]?{
        /*
         Expecting an array with the shape 125x13x13, where:
         - 13x13 is the search grid
         - 125 is 5 (anchor) boxes each containing the features
            <object present confidence>, <cx>, <cy>, <width>, <height>, <probability class 1>, ..., <probability class 2>
         
         We iterate through each of the cells and, for each cell, determine the most probable class before filtering
         out those that don't meet the threshold (based on the probability an object exists and class probability).
         After extracting the most probable objects, we further filter them using Non-Max Suppression (which determines
         the likely hood of an object based on it's intersection with others in close proximity)
        */
        
        // Search grid size
        let gridSize = CGSize(width: 13, height: 13)
        // Classes
        let numberOfClasses = 20
        // Number of boxes for each cell
        let numberOfAnchorBoxes = 5
        // Box shapes
        let anchors : [Float] = [1.08, 1.19, 3.42, 4.41, 6.63, 11.38, 9.42, 5.11, 16.62, 10.52]
        
        let arrayPointer = UnsafeMutablePointer<Double>(OpaquePointer(array.dataPointer))
        let boxStride = array.strides[0].intValue
        let rowStride = array.strides[1].intValue
        let colStride = array.strides[2].intValue
        
        var objectsBounds = [ObjectBounds]()
        var objectConfidences = [Float]()
        
        for row in 0..<Int(gridSize.height) {
            for col in 0..<Int(gridSize.width) {
                for b in 0..<numberOfAnchorBoxes {
                    
                    let boxOffset = b * (numberOfClasses + numberOfAnchorBoxes)
                    let gridOffset = row * rowStride + col * colStride
                    
                    // The 4th element is the confidence of a object being present
                    let confidence = sigmoid(x: Float(arrayPointer[(boxOffset + 4) * boxStride + gridOffset]))
                    
                    // From 5th element onwards are the classes
                    var classes = Array<Float>(repeating: 0.0, count: numberOfClasses)
                    for c in 0..<numberOfClasses{
                        classes[c] = Float(arrayPointer[(boxOffset + 5 + c) * boxStride + gridOffset])
                    }
                    classes = softmax(z: classes)
                    
                    // Select the class with the largest confidence
                    let classIdx = classes.argmax
                    let classScore = classes[classIdx]
                    let classConfidence = classScore * confidence
                    
                    // Threshold confidence levels < obj_threshold
                    if classConfidence < objectThreshold{
                        continue
                    }
                    
                    // Get the first 4 elements; which are x, y, w, and h (bounds of the detected object)
                    let tx = Float(arrayPointer[boxOffset * boxStride + gridOffset])
                    let ty = Float(arrayPointer[(boxOffset + 1) * boxStride + gridOffset])
                    let tw = Float(arrayPointer[(boxOffset + 2) * boxStride + gridOffset])
                    let th = Float(arrayPointer[(boxOffset + 3) * boxStride + gridOffset])
                    
                    let cx = Int(Float(col) + sigmoid(x: tx)) / Int(gridSize.width) // center position, unit: image width
                    let cy = Int(Float(row) + sigmoid(x: ty)) / Int(gridSize.height) // center position, unit: image height
                    let w = Int(anchors[2 * b + 0] * exp(tw) / Float(gridSize.width)) // unit: image width
                    let h = Int(anchors[2 * b + 1] * exp(th) / Float(gridSize.height)) // unit: image height
                    
                    let objectBounds = ObjectBounds(object: DetectableObject.objects[classIdx],
                                                    origin: CGPoint(x: cx - w/2, y: cy - h/2),
                                                    size: CGSize(width: w, height: h))
                    
                    objectsBounds.append(objectBounds)
                    objectConfidences.append(classConfidence)
                }
            }
        }
        
        return self.filteredDetectedObjects(objectsBounds: objectsBounds,
                                            objectsConfidence: objectConfidences)
    }
    
    /**
     Non-Max Supression
     @param objectsBounds: detected object bounds
     @param objectsConfidence: objectsBounds associated confidence score
     @param nmsThreshold: Non-Max Supression threshold (threshold based on the intersection / union ratio between two boxes)
    **/
    func filteredDetectedObjects(objectsBounds:[ObjectBounds],
                                 objectsConfidence:[Float],
                                 nmsThreshold : Float = 0.3) -> [ObjectBounds]?{
        // If there are no bounding boxes do nothing
        guard objectsBounds.count > 0 else{
            return []
        }
        
        // Create a list of confidences to keep track of the detection confidence
        // of each predicted bounding box
        var detectionConfidence = objectsConfidence.map { (confidence) -> Float in
            return confidence
        }
        
        // Sort the indices of the bounding boxes by detection confidence value in descending order.
        // Do an argsort on the confidence scores, from high to low.
        let sortedIndices = detectionConfidence.indices.sorted { $0 > $1 }

        // Create an empty list to hold the best bounding boxes after
        // Non-Maximal Suppression (NMS) is performed
        var bestObjectsBounds = [ObjectBounds]()
        
        // Perform Non-Maximal Suppression
        for i in 0..<sortedIndices.count{
            // Get the bounding box with the highest detection confidence first
            let objectBounds = objectsBounds[sortedIndices[i]]
            
            // Check that the detection confidence is not zero
            guard detectionConfidence[sortedIndices[i]] > 0 else{
                continue
            }
            
            // Save the bounding box
            bestObjectsBounds.append(objectBounds)
            
            // Go through the rest of the bounding boxes in the list and calculate their IOU with
            // respect to the previous selected objectBounds
            for j in (i+1)..<sortedIndices.count{
                let otherObjectBounds = objectsBounds[sortedIndices[j]]
                
                // If the IOU of box_i and box_j is higher than the given IOU threshold set
                // box_j's detection confidence to zero.
                if computeIOU(objectBounds, otherBounds:otherObjectBounds) > nmsThreshold{
                    detectionConfidence[sortedIndices[j]] = 0.0
                }
            }
        }
        
        return bestObjectsBounds
    }
    
    func computeIOU(_ bounds:ObjectBounds, otherBounds:ObjectBounds) -> Float{
        // Get the Width and Height of each bounding box
        let bb1Width = bounds.size.width
        let bb1Height = bounds.size.height
        let bb2Width = otherBounds.size.width
        let bb2Height = otherBounds.size.height
        
        // Calculate the area of the each bounding box
        let area1 = bb1Width * bb1Height
        let area2 = bb2Width * bb2Height
        
        // Find the vertical edges of the union of the two bounding boxes
        let minX = min(bounds.origin.x, otherBounds.origin.x)
        let maxX = max(bounds.origin.x, otherBounds.origin.x)
        
        // Calculate the width of the union of the two bounding boxes
        let unionWidth = maxX - minX
        
        // Find the horizontal edges of the union of the two bounding boxes
        let minY = min(bounds.origin.y, otherBounds.origin.y)
        let maxY = max(bounds.origin.y, otherBounds.origin.y)
        
        // Calculate the height of the union of the two bounding boxes
        let unionHeight = maxY - minY
        
        // Calculate the width and height of the area of intersection of the two bounding boxes
        let intersectionWidth = bb1Width + bb2Width - unionWidth
        let intersectionHeight = bb1Height + bb2Height - unionHeight
        
        // If the the boxes don't overlap then their IOU is zero
        if intersectionWidth <= 0 || intersectionHeight <= 0{
            return 0.0
        }
        
        // Calculate the area of intersection of the two bounding boxes
        let intersectionArea = intersectionWidth * intersectionHeight
        
        // Calculate the area of the union of the two bounding boxes
        let unionArea = area1 + area2 - intersectionArea
        
        // Calculate the IOU
        let iou = intersectionArea/unionArea
        
        return Float(iou)
        
    }
}

