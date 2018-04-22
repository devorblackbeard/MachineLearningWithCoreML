//
//  RescaleOutputLambda.swift
//  StyleTransfer
//
//  Created by Joshua Newnham on 19/04/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import Foundation
import CoreML
import Accelerate

/**
  ((x+1)*127.5.
 */
@objc(RescaleOutputLambda) class RescaleOutputLambda: NSObject, MLCustomLayer {
    
    required init(parameters: [String : Any]) throws {
        super.init()
    }
    
    func setWeightData(_ weights: [Data]) throws {
        print(#function, weights)
    }
    
    func outputShapes(forInputShapes inputShapes: [[NSNumber]]) throws
        -> [[NSNumber]] {
            print("RescaleOutputLambda", #function, inputShapes)
            return inputShapes
    }
    
    /**

    */
    func evaluate(inputs: [MLMultiArray], outputs: [MLMultiArray]) throws {
        print("ResCropBlockLambda", #function, inputs.count, outputs.count)
        
        let rescaleAddition = 1.0
        let rescaleMulitplier = 127.5
        
        for (i, input) in inputs.enumerated(){
            
            let shape = input.shape // expecting [1, 1, Channels, Kernel Width, Kernel Height]
            for c in 0..<shape[2].intValue{
                for w in 0..<shape[3].intValue{
                    for h in 0..<shape[4].intValue{
                        let index = [NSNumber(value: 0),
                                     NSNumber(value: 0),
                                     NSNumber(value: c),
                                     NSNumber(value: w),
                                     NSNumber(value: h)]
                        let outputValue = NSNumber(value:(input[index].doubleValue + rescaleAddition) * rescaleMulitplier)
                        
                        outputs[i][index] = outputValue
                    }
                }
            }
        }
    }
}
