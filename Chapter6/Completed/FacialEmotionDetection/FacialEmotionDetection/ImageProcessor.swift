//
//  ImageProcessor.swift
//  FacialEmotionDetection
//
//  Created by Joshua Newnham on 03/03/2018.
//  Copyright © 2018 PacktPub. All rights reserved.
//

import UIKit
import Vision
import Accelerate

protocol ImageProcessorDelegate : class{
    func onImageProcessorCompleted(status: Int, faces:[CIImage]?)
}

class ImageProcessor{
    
    weak var delegate : ImageProcessorDelegate?
    
    /*
     VNDetectFaceRectanglesRequest:
     https://developer.apple.com/documentation/vision/VNDetectFaceRectanglesRequest
     An image analysis request that finds faces within an image.
     */
    let faceDetection = VNDetectFaceRectanglesRequest()
    
    /*
     VNSequenceRequestHandler:
     https://developer.apple.com/documentation/vision/VNSequenceRequestHandler
     An object that processes image analysis requests pertaining to a
     sequence of multiple images.
     */
    let faceDetectionRequest = VNSequenceRequestHandler()
    
    init(){
        
    }
    
    public func getFaces(pixelBuffer:CVPixelBuffer){
        DispatchQueue.global(qos: .background).async {
            
            // Perform face detection
            try? self.faceDetectionRequest.perform(
                [self.faceDetection],
                on: pixelBuffer)
            
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let width = ciImage.extent.width
            let height = ciImage.extent.height
            
            // Grayscale filter
            guard let grayscaleFilter = CIFilter(name: "CIColorControls") else{
                fatalError("Unable to init CIFilter 'CIColorControls'")
            }
            grayscaleFilter.setValue(0, forKey: kCIInputSaturationKey)
            
            var faces = [CIImage]()
            
            /*
             VNFaceObservation:
             https://developer.apple.com/documentation/vision/vnfaceobservation
             Face or facial-feature information detected by an image analysis request.
             */
            if let faceDetectionResults = self.faceDetection.results as? [VNFaceObservation]{
                print("faceDetectionResults")
                for face in faceDetectionResults{
                    let bbox = face.boundingBox
                    print(bbox)
                    
                    let imageSize = CGSize(width:width,
                                           height:height)
                    
                    /*
                     The face's bounding box is normalised in respect to the
                     size of the image i.e. is in a range of 0.0 - 1.0 where
                     this is a ratio of the overall image size e.g. width = 0.5 would
                     be half of the width of the source image.
                     */
                    let w = bbox.width * imageSize.width
                    let h = bbox.height * imageSize.height
                    let x = bbox.origin.x * imageSize.width
                    let y = bbox.origin.y * imageSize.height
                    
                    let faceRect = CGRect(x: x,
                                          y: y,
                                          width: w,
                                          height: h)
                    
                    /*
                     It’s worth remembering that Vision the framework
                     is using a flipped coordinate system, which means we
                     need to invert y
                     */
                    let invertedY = imageSize.height - (faceRect.origin.y + faceRect.height)
                    let invertedFaceRect = CGRect(x: x,
                                                  y: invertedY,
                                                  width: w,
                                                  height: h)
                    
                    let croppedImage = ciImage.cropped(to: invertedFaceRect)
                    
                    grayscaleFilter.setValue(croppedImage, forKey: kCIInputImageKey)
                    
                    if let grayscaleCroppedImage = grayscaleFilter.value(forKey: kCIOutputImageKey) as? CIImage {
                        faces.append(grayscaleCroppedImage)
                    } else{
                        print("Failed to apply filter on cropped image")
                    }
                }
                
                DispatchQueue.main.async {
                    print("Found \(faces.count) faces")
                    self.delegate?.onImageProcessorCompleted(status: 1, faces: faces)
                }
            } else{
                DispatchQueue.main.async {
                    print("Found no faces")
                    self.delegate?.onImageProcessorCompleted(status: -1, faces: nil)
                }
            }
        }
    }
}


