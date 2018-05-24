//
//  YOLOFacade.swift
//  ObjectDetection
//
//  Created by Joshua Newnham on 17/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit
import Photos
import CoreML
import Vision

class YOLOFacade{
    
    // The size the input will be cropped and resized to
    var targetSize = CGSize(width: 416, height: 416)
    // Search grid size
    let gridSize = CGSize(width: 13, height: 13)
    // Classes
    let numberOfClasses = 20
    // Number of boxes for each cell
    let numberOfAnchorBoxes = 5
    // Box shapes
    let anchors : [Float] = [1.08, 1.19, 3.42, 4.41, 6.63, 11.38, 9.42, 5.11, 16.62, 10.52]
    
    lazy var model : VNCoreMLModel? = {
        do{
            let model = try VNCoreMLModel(
                for: tinyyolo_voc2007().model)
            return model
        } catch{
            fatalError("Failed to obtain tinyyolo_voc2007")
        }
    }()
    
    func asyncDetectObjects(
        photo:UIImage,
        completionHandler:@escaping (_ result:[ObjectBounds]?) -> Void){
        
        DispatchQueue.global(qos: .background).sync {
            
            self.detectObjects(photo: photo, completionHandler: { (result) -> Void in
                DispatchQueue.main.async {
                    completionHandler(result)
                }
            })
        }
    }
    
}

// MARK: - Core ML

extension YOLOFacade{
    
    func detectObjects(photo:UIImage, completionHandler:(_ result:[ObjectBounds]?) -> Void){
        guard let cgImage = photo.cgImage else{
            completionHandler(nil)
            return
        }
        
        // TODO preprocess image and pass to model
        let request = VNCoreMLRequest(model: self.model)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform classification.\n\(error.localizedDescription)")
            completionHandler(nil)
            return
        }
        
        // TODO pass models results to detectObjectsBounds(::)
        
        completionHandler(nil)
    }
    
    func detectObjectsBounds(array:MLMultiArray, objectThreshold:Float = 0.3) -> [ObjectBounds]?{
        
        let gridStride = array.strides[0].intValue
        let rowStride = array.strides[1].intValue
        let colStride = array.strides[2].intValue

        let arrayPointer = UnsafeMutablePointer<Double>(OpaquePointer(array.dataPointer))

        var objectsBounds = [ObjectBounds]()
        var objectConfidences = [Float]()
        
        for row in 0..<Int(gridSize.height) {
            for col in 0..<Int(gridSize.width) {
                for b in 0..<numberOfAnchorBoxes {
                    
                    let gridOffset = row * rowStride + col * colStride
                    let anchorBoxOffset = b * (numberOfClasses + numberOfAnchorBoxes)
                    
                    // The 4th element is the confidence of a object being present
                    let confidence = sigmoid(x: Float(arrayPointer[(anchorBoxOffset + 4) * gridStride + gridOffset]))

                    // From 5th element onwards are the classes
                    var classes = Array<Float>(repeating: 0.0, count: numberOfClasses)
                    for c in 0..<numberOfClasses{
                        classes[c] = Float(arrayPointer[(anchorBoxOffset + 5 + c) * gridStride + gridOffset])
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
                    let tx = CGFloat(arrayPointer[anchorBoxOffset * gridStride + gridOffset])
                    let ty = CGFloat(arrayPointer[(anchorBoxOffset+1) * gridStride + gridOffset])
                    let tw = CGFloat(arrayPointer[(anchorBoxOffset+2) * gridStride + gridOffset])
                    let th = CGFloat(arrayPointer[(anchorBoxOffset+3) * gridStride + gridOffset])

                    let cx = (CGFloat(col) + sigmoid(x: tx)) / gridSize.width // center position, unit: image width
                    let cy = (CGFloat(row) + sigmoid(x: ty)) / gridSize.height // center position, unit: image height
                    let w = CGFloat(anchors[2 * b + 0]) * exp(tw) / gridSize.width // unit: image width
                    let h = CGFloat(anchors[2 * b + 1]) * exp(th) / gridSize.height // unit: image height
                    
                    guard let detectableObject = DetectableObject.objects.filter(
                        {$0.classIndex == classIdx}).first else{
                        continue
                    }
                    
                    let objectBounds = ObjectBounds(
                        object: detectableObject,
                        origin: CGPoint(x: cx - w/2, y: cy - h/2),
                        size: CGSize(width: w, height: h))

                    objectsBounds.append(objectBounds)
                    objectConfidences.append(classConfidence)
                }
            }
        }
        
        return self.filterDetectedObjects(
            objectsBounds: objectsBounds,
            objectsConfidence: objectConfidences)
    }
}

// MARK: - Non-Max Suppression

extension YOLOFacade{
    
    func filterDetectedObjects(
        objectsBounds:[ObjectBounds],
        objectsConfidence:[Float],
        nmsThreshold : Float = 0.3) -> [ObjectBounds]?{
        
        // If there are no bounding boxes do nothing
        guard objectsBounds.count > 0 else{
            return []
        }
        
        // Create a list of confidences to keep track of the detection confidence
        // of each predicted bounding box
        var detectionConfidence = objectsConfidence.map{
            (confidence) -> Float in
            return confidence
        }

        // Sort the indices of the bounding boxes by detection confidence value in descending order.
        // Do an argsort on the confidence scores, from high to low.
        let sortedIndices = detectionConfidence.indices.sorted {
            detectionConfidence[$0] > detectionConfidence[$1]
        }

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
                guard detectionConfidence[sortedIndices[j]] > 0 else {
                    continue
                }
                let otherObjectBounds = objectsBounds[sortedIndices[j]]
                
                // If the IOU of objectBounds and otherObjectBounds is higher than the given IOU threshold set
                // otherObjectBounds's detection confidence to zero.
                if Float(objectBounds.bounds.computeIOU(
                    other: otherObjectBounds.bounds)) > nmsThreshold{
                    detectionConfidence[sortedIndices[j]] = 0.0
                }
            }
        }
        
        return bestObjectsBounds
    }
}
