//
// ExpressionRecognitionModel.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class ExpressionRecognitionModelInput : MLFeatureProvider {
    
    /// Input image; grayscale 48x48 of a face as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 48 pixels wide by 48 pixels high
    var image: CVPixelBuffer
    
    var featureNames: Set<String> {
        get {
            return ["image"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "image") {
            return MLFeatureValue(pixelBuffer: image)
        }
        return nil
    }
    
    init(image: CVPixelBuffer) {
        self.image = image
    }
}


/// Model Prediction Output Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class ExpressionRecognitionModelOutput : MLFeatureProvider {
    
    /// Probability of each expression as dictionary of strings to doubles
    let classLabelProbs: [String : Double]
    
    /// Most likely expression as string value
    let classLabel: String
    
    var featureNames: Set<String> {
        get {
            return ["classLabelProbs", "classLabel"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "classLabelProbs") {
            return try! MLFeatureValue(dictionary: classLabelProbs as [NSObject : NSNumber])
        }
        if (featureName == "classLabel") {
            return MLFeatureValue(string: classLabel)
        }
        return nil
    }
    
    init(classLabelProbs: [String : Double], classLabel: String) {
        self.classLabelProbs = classLabelProbs
        self.classLabel = classLabel
    }
}


/// Class for model loading and prediction
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class ExpressionRecognitionModel {
    var model: MLModel
    
    /**
     Construct a model with explicit path to mlmodel file
     - parameters:
     - url: the file url of the model
     - throws: an NSError object that describes the problem
     */
    init(contentsOf url: URL) throws {
        self.model = try MLModel(contentsOf: url)
    }
    
    /// Construct a model that automatically loads the model from the app's bundle
    convenience init() {
        let bundle = Bundle(for: ExpressionRecognitionModel.self)
        let assetPath = bundle.url(forResource: "ExpressionRecognitionModel", withExtension:"mlmodelc")
        try! self.init(contentsOf: assetPath!)
    }
    
    /**
     Make a prediction using the structured interface
     - parameters:
     - input: the input to the prediction as ExpressionRecognitionModelInput
     - throws: an NSError object that describes the problem
     - returns: the result of the prediction as ExpressionRecognitionModelOutput
     */
    func prediction(input: ExpressionRecognitionModelInput) throws -> ExpressionRecognitionModelOutput {
        let outFeatures = try model.prediction(from: input)
        let result = ExpressionRecognitionModelOutput(classLabelProbs: outFeatures.featureValue(for: "classLabelProbs")!.dictionaryValue as! [String : Double], classLabel: outFeatures.featureValue(for: "classLabel")!.stringValue)
        return result
    }
    
    /**
     Make a prediction using the convenience interface
     - parameters:
     - image: Input image; grayscale 48x48 of a face as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 48 pixels wide by 48 pixels high
     - throws: an NSError object that describes the problem
     - returns: the result of the prediction as ExpressionRecognitionModelOutput
     */
    func prediction(image: CVPixelBuffer) throws -> ExpressionRecognitionModelOutput {
        let input_ = ExpressionRecognitionModelInput(image: image)
        return try self.prediction(input: input_)
    }
}
