//
//  QueryFacade.swift
//  QuickDraw
//
//  Created by Joshua Newnham on 04/01/2018.
//  Copyright © 2018 Method. All rights reserved.
//

import UIKit

protocol QueryDelegate : class{
    func onQueryCompleted(status: Int, result:QueryResult?)
}

struct QueryResult{
    var predictions = [(key:String, value:Double)]()
    var images = [CIImage]()
}

class QueryFacade{
    
    // Used for rendering image processing results and performing image analysis. Here we use
    // it for rendering out scaled and cropped captured frames in preparation for our model.
    let context = CIContext()
    
    let model = cnnsketchclassifier()
    
    let queryQueue = DispatchQueue(label: "query_queue")
    
    var targetSize = CGSize(width: 256, height: 256)
    
    weak var delegate : QueryDelegate?
    
    var currentSketch : StrokeSketch?{
        didSet{
            self.newQueryWaiting = true
        }
    }
    
    fileprivate var newQueryWaiting : Bool = false
    
    fileprivate var processingQuery : Bool = false
    
    var isProcessingQuery : Bool{
        get{
            return self.processingQuery
        }
    }
    
    init() {
        
    }
    
    func asyncQuery(sketch:StrokeSketch){
        self.currentSketch = sketch
        
        if !self.processingQuery{
            self.queryCurrentSketch()
        }
    }
    
    fileprivate func processNextQuery(){
        if self.newQueryWaiting && !self.processingQuery{
            self.queryCurrentSketch()
        }
    }
    
    fileprivate func queryCurrentSketch(){
        guard let sketch = self.currentSketch else{
            self.processingQuery = false
            self.newQueryWaiting = false
            
            return
        }
        
        self.processingQuery = true
        self.newQueryWaiting = false
        
        queryQueue.async {
            
            guard let predictions = self.classifySketch(sketch: sketch) else{
                DispatchQueue.main.async{
                    self.processingQuery = false
                    self.delegate?.onQueryCompleted(status:-1, result:nil)
                    self.processNextQuery()
                }
                return
            }
            
            let searchTerms = predictions.map({ (key, value) -> String in
                return key
            })
            
            guard let images = self.downloadImages(searchTerms: searchTerms, searchTermsCount: 4) else{
                DispatchQueue.main.async{
                    self.processingQuery = false
                    self.delegate?.onQueryCompleted(status:-1, result:nil)
                    self.processNextQuery()
                }
                return
            }
            
            DispatchQueue.main.async{
                self.processingQuery = false
                self.delegate?.onQueryCompleted(status:1,
                                                result:QueryResult(
                                                    predictions: predictions,
                                                    images: images))
                self.processNextQuery()
            }
        }
    }
}

// MARK: - Classification

extension QueryFacade{
    
    func classifySketch(sketch:Sketch) -> [(key:String,value:Double)]?{
        // rasterize image, resize and then rescale pixels (multiplying them by 1.0/255.0 as per training)
        if let img = sketch.exportSketch(size: nil)?.resize(size: self.targetSize).rescalePixels(){
            return self.classifySketch(image: img)
        }
        
        return nil
    }
    
    func classifySketch(image:CIImage) -> [(key:String,value:Double)]?{
        // obtain the CVPixelBuffer from the image
        if let pixelBuffer = image.toPixelBuffer(context: self.context, gray: true){
            // Try to make a prediction
            let prediction = try? self.model.prediction(image: pixelBuffer)
            
            if let classPredictions = prediction?.classLabelProbs{
                let sortedClassPredictions = classPredictions.sorted(by: { (kvp1, kvp2) -> Bool in
                    kvp1.value > kvp2.value
                })
                
                return sortedClassPredictions
            }
        }
        
        return nil
    }
}

// MARK: - Bing Search

extension QueryFacade{
    
    func downloadImages(searchTerms:[String], searchTermsCount:Int=4, searchResultsCount:Int=2) -> [CIImage]?{
        var bingResults = [BingServiceResult]()
        
        for i in 0..<min(searchTermsCount, searchTerms.count){
            let results = BingService.sharedInstance.syncSearch(searchTerm: searchTerms[i], count:searchResultsCount)
            results.forEach({ (bingResult) in
                bingResults.append(bingResult)
            })
        }
        
        var images = [CIImage]()
        
        for bingResult in bingResults{
            if let image = BingService.sharedInstance.syncDownloadImage(bingResult: bingResult){
                images.append(image)
            }
        }
        
        return images
    }
    
}
