/*:
Here we are using the Swedish Auto Insurance Dataset; a regression problem that involves predicting the total payment for all claims in thousands of Swedish Kronor, given the total number of claims.

It is comprised of 63 observations with 1 input variable and 1 output variable. The variable names are as follows:
- Number of claims.
- Total payment for all claims in thousands of Swedish Kronor.

Further details can be found [here.](http://college.cengage.com/mathematics/brase/understandable_statistics/7e/students/datasets/slr/frames/slr06.html)
The original dataset can be found [here.](https://www.math.muni.cz/~kolacek/docs/frvs/M7222/data/AutoInsurSweden.txt)
 
*/

import UIKit
import PlaygroundSupport

// create view to render scatter plot
let view = PlotView(frame: CGRect(x: 20, y: 20, width: 500, height: 400))

// add style for our predictions
view.styles["prediction"] = DataPointStyle(size: 5, color: UIColor.red.cgColor)
// add a style for the best fit line
view.styles["prediction_line"] = DataPointStyle(size: 2, color: UIColor.red.cgColor)


func squaredError(y:[CGFloat], y_:[CGFloat]) -> CGFloat{
    if y.count != y_.count{
        return 0
    }
    
    let sumSqErr = Array(zip(y, y_)).map({ (a, b) -> CGFloat in
        return (a-b) * (a-b)
    }).reduce(0, { (res, a) -> CGFloat in
        return res + a
    })
    
    return sumSqErr
}

func meanSquaredError(y:[CGFloat], y_:[CGFloat]) -> CGFloat{
    if y.count != y_.count{
        return 0
    }
    
    print("sqerr \(squaredError(y: y, y_: y_))")
    
    return squaredError(y: y, y_: y_) / CGFloat(y.count)
}

/**
 Train model using Gradient Descent 
 
 - returns:
 The model from training (bias and weight) 
 
 - parameters:
    - x: training x 
    - y: training y
    - b: pre-initilised b value
    - w: pre-initilised w value 
    - learningRate: determines how quickly we adjust the coefficients based on the error 
    - epochs: numbers of training iterations
 */
func train(x:[CGFloat], y:[CGFloat], b:CGFloat=0.0, w:CGFloat=0.0, learningRate:CGFloat=0.001, epochs:Int=100) -> (b:CGFloat, w:CGFloat){
    
    var B = b
    var W = w
    
    for _ in 0...epochs{
        var sumError : CGFloat = 0.0
        for i in 0..<x.count{
            // predict y using our existing coefficients
            let yHat = B + W * x[i]
            // calculate the absolute error
            let error = yHat - y[i]
            // track the squared error (can preview these via the playground 'Quick Look' feature)
            sumError += error * error
            // update bias using the error
            B = B - learningRate * error
            // update weight using the error relative to the existing weight
            W = W - learningRate * error * W
        }
        
    }
    
    return (b:B, w:W)
}

// load dataset
let csvData = parseCSV(contents:loadCSV(file:"SwedishAutoInsurance"))

// create structure for our plot
let dataPoints = extractDataPoints(data: csvData, xKey: "claims", yKey: "payments")

// add data points from our dataset
view.scatter(dataPoints)

// set some random variables for a bias and weight
let b = CGFloat(arc4random()) / CGFloat(UINT32_MAX)
let w = CGFloat(arc4random()) / CGFloat(UINT32_MAX)

// search for our coefficents for linear regression (which represent our model) using gradient descent
let model = train(x:csvData["claims"]!,
                   y:csvData["payments"]!,
                   b:b, w:w)

print("model = \(model.b) + \(model.w)  * x")

// create datapoints of predictions (line best fit)
var predDataPoints = dataPoints.map({ (dp) -> DataPoint in
    let y = model.b + dp.x * model.w
    return DataPoint(tag: "prediction", x: dp.x, y: y)
});

// add our predicted data points using our model
view.scatter(predDataPoints)

// create a line using our model, from minX to maxX
// (this is our best fit line)
let minX = dataPoints.map({ (dp) -> CGFloat in
    return dp.x
}).min()!

let maxX = dataPoints.map({ (dp) -> CGFloat in
    return dp.x
}).max()!

view.line(pointA: DataPoint(tag: "prediction_line",
                            x: minX,
                            y: model.b + minX * model.w),
          pointB: DataPoint(tag: "prediction_line",
                            x: maxX,
                            y: model.b + maxX * model.w))

// Present the view controller in the Live View window
PlaygroundPage.current.liveView = view

// calculate mean squared error 
let y = dataPoints.map { (dp) -> CGFloat in
    return dp.y
}

let yHat = predDataPoints.map { (dp) -> CGFloat in
    return dp.y
}

let mse = meanSquaredError(y: y, y_: yHat)

print("mean squared error \(mse)")
