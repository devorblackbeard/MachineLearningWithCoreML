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
            let photos = getPhotos()
            
            let unscoredSearchResults = self.detectObjects(photos: photos)
            
            DispatchQueue.main.async {
                self.delegate?.onPhotoSearcherCompleted(
                    status: 1,
                    result: unscoredSearchResults)
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
        
        var detectedObjects = [ObjectBounds]()
        
        for observation in observations{
            guard let multiArray = observation.featureValue.multiArrayValue else{
                continue
            }
            
            if let observationDetectedObjects = self.detectObjectsBounds(array: multiArray){
                for detectedObject in observationDetectedObjects.map(
                    {$0.transformFromCenteredCropping(from: photo.size, to: self.targetSize)}){
                    detectedObjects.append(detectedObject)
                }
            }
        }
        
        return SearchResult(image: photo, detectedObjects: detectedObjects, score: 0.0)
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
                    
                    let cx = CGFloat((Float(col) + sigmoid(x: tx)) / Float(gridSize.width)) // center position, unit: image width
                    let cy = CGFloat((Float(row) + sigmoid(x: ty)) / Float(gridSize.height)) // center position, unit: image height
                    let w = CGFloat(anchors[2 * b + 0] * exp(tw) / Float(gridSize.width)) // unit: image width
                    let h = CGFloat(anchors[2 * b + 1] * exp(th) / Float(gridSize.height)) // unit: image height
                    
                    guard let detectableObject = DetectableObject.objects.filter({$0.classIndex == classIdx}).first else{
                        continue
                    }
                    
                    let objectBounds = ObjectBounds(object: detectableObject,
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
     Non-Max Supression; Filter out 'significantly' overlapping objects which have a lower
     confidence (than the object overlapping it) 
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
        let sortedIndices = detectionConfidence.indices.sorted { detectionConfidence[$0] > detectionConfidence[$1] }

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
                
                // If the IOU of objectBounds and otherObjectBounds is higher than the given IOU threshold set
                // otherObjectBounds's detection confidence to zero.
                if Float(objectBounds.bounds.computeIOU(other: otherObjectBounds.bounds)) > nmsThreshold{
                    detectionConfidence[sortedIndices[j]] = 0.0
                }
            }
        }
        
        return bestObjectsBounds
    }    
}

