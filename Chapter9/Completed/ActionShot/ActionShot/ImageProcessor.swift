//
//  ImageProcessor.swift
//  ActionShot
//
//  Created by Joshua Newnham on 31/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import Foundation
import Vision
import CoreML

protocol ImageProcessorDelegate : class{
    func onImageProcessorCompleted(status: Int, processedImage:CGImage?)
}

protocol ImageProcessorDatasource : class{
    var count : Int{ get }
    
    func getFrameAtIndex(index:Int) -> CIImage?
}

class ImageProcessor{
    
    weak var delegate : ImageProcessorDelegate?
    
    weak var datasource : ImageProcessorDatasource?
    
    lazy var model : VNCoreMLModel = {
        do{
            let model = try VNCoreMLModel(
                for: small_unet().model
            )
            return model
        } catch{
            fatalError("Failed to create VNCoreMLModel")
        }
    }()
    
    func getRequest() -> VNCoreMLRequest{
        let request = VNCoreMLRequest(model: self.model, completionHandler: { [weak self] request, error in
            self?.processRequest(for: request, error: error)
        })
        request.imageCropAndScaleOption = .centerCrop
        return request
    }
    
    var processingFrameIndex : Int = 0
    
    var processedFrames = [CIImage]()
    
    init(){
        
    }
    
    public func start() -> Bool{
        guard let datasource = self.datasource, datasource.count > 0 else{
            return false
        }
        
        processingFrameIndex = 0
        processedFrames.removeAll()
        
        DispatchQueue.global(qos: .background).sync {
            self.processNextFrame()
        }
        
        return true
    }
}

// MARK: - Image processing / segmentation and masking

extension ImageProcessor{
    func processNextFrame(){
        if self.datasource!.count == self.processingFrameIndex{
            self.compositeFrames()
            return
        }
        
        guard let frame = self.datasource!.getFrameAtIndex(index: processingFrameIndex) else{
            self.compositeFrames()
            return
        }
        
        let handler = VNImageRequestHandler(ciImage: frame)
        
        do {
            try handler.perform([self.getRequest()])
        } catch {
            /*
             This handler catches general image processing errors. The `classificationRequest`'s
             completion handler `processClassifications(_:error:)` catches errors specific
             to processing that request.
             */
            print("Failed to perform classification.\n\(error.localizedDescription)")
        }
    }
    
    func processRequest(for request:VNRequest, error: Error?){
        guard let results = request.results else {
            print("ImageProcess", #function, "ERROR:",
                  String(describing: error?.localizedDescription))
            self.delegate?.onImageProcessorCompleted(
                status: -1,
                stylizedImage: nil)
            return
        }
        
        let stylizedPixelBufferObservations = results as! [VNPixelBufferObservation]
        
        guard stylizedPixelBufferObservations.count > 0 else {
            print("ImageProcess", #function,"ERROR:", "No Results")
            self.delegate?.onImageProcessorCompleted(
                status: -1,
                stylizedImage: nil)
            return
        }
        
        guard let cgImage = stylizedPixelBufferObservations[0].pixelBuffer.toCGImage() else{
            print("ImageProcess", #function, "ERROR:", "Failed to convert CVPixelBuffer to CGImage")
            self.delegate?.onImageProcessorCompleted(
                status: -1,
                stylizedImage: nil)
            return
        }
    }
}

// MARK: - Composite image

extension ImageProcessor{
    
    func compositeFrames(){
        // do some work here
        
        DispatchQueue.main.async {
            self.delegate?.onImageProcessorCompleted(
                status: 1,
                stylizedImage:cgImage)
        }
    }
    
}
