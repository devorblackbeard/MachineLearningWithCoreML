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
let view = ScatterPlotView(frame: CGRect(x: 20, y: 20, width: 300, height: 300))

// add style for our predictions
view.styles["prediction"] = DataPointStyle(size: 5, color: UIColor(red:217, green:94, blue:89).cgColor)

// add a style for the best fit line
view.styles["prediction_line"] = DataPointStyle(size: 2, color: UIColor(red:217, green:94, blue:89).cgColor)


/**
 Takes in 2 arrays and calcualtes the squared error between the two. Used by meanSquaredError.
 */
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

/*:
 In many cases; calculating the mean squared error provides us with a better gauge than absolute error for the reasons:
 - Avoid having the sign cancel out errors i.e. errors for 2 data points of-100 and 100 will result in an asbolute error of 0.
 - Prioritises large errors over small errors.
 */
func meanSquaredError(y:[CGFloat], y_:[CGFloat]) -> CGFloat{
    if y.count != y_.count{
        return 0
    }
    
    return squaredError(y: y, y_: y_) / CGFloat(y.count)
}

/*:
 Train model using Gradient Descent;
 
 Gradient descent is essentially an algorithm that minimizes functions. Given a function defined by a set of parameters, gradient descent starts with an initial set of parameter values and iteratively moves toward a set of parameter values that minimize the function. This iterative minimization is achieved by calculating the partial derivate with respect to the error for each of our coefficents (in our case b and w); because we're descenting we take the negative of this which is used to steer the search in the direction to minimize the error. [gradient](https://en.wikipedia.org/wiki/Gradient).
 We control the descent with a learing rate, this is used to avoid our step 'overshooting' the minimum.
 
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
func train(x:[CGFloat], y:[CGFloat], b:CGFloat=0.0, w:CGFloat=0.0, learningRate:CGFloat=0.0001, epochs:Int=100) -> (b:CGFloat, w:CGFloat){
    
    var B = b
    var W = w
    
    let N = CGFloat(x.count) // number of data points
    
    for _ in 0...epochs{
        var sumError : CGFloat = 0.0
        var bGradient : CGFloat = 0.0
        var wGradient : CGFloat = 0.0
        
        for i in 0..<x.count{
            // predict y using our existing coefficients
            let yHat = W * x[i] + B
            // calculate the absolute error
            let error = y[i] - yHat
            // track the squared error (can preview these via the playground 'Quick Look' feature)
            sumError += error * error
            
            // calculate the graidents for the bias and coefficent (weight)
            bGradient += -(2.0/N) * error
            wGradient += -(2.0/N) * x[i] * error
        }
        
        // update bias using the accumulated gradient
        B = B - (learningRate * bGradient)
        // update weight using the accumulated gradient
        W = W - (learningRate * wGradient)
    }
    
    return (b:B, w:W)
}

// load dataset
let csvData = parseCSV(contents:loadCSV(file:"SwedishAutoInsurance"))

// create structure for our plot
let dataPoints = extractDataPoints(data: csvData, xKey: "claims", yKey: "payments")

// add/view data points from our dataset
view.scatter(dataPoints)

/*:
 By visualising the datapoints, we intuitively see signs of a correlation between the number of claims and amount of claims. To
 We will use a simple linear equation to model this relationship and use it to make predictions. 
 */

// set some random variables for a bias and weight
let b = CGFloat(arc4random()) / CGFloat(UINT32_MAX)
let w = CGFloat(arc4random()) / CGFloat(UINT32_MAX)

// search for our coefficents for linear regression (which represent our model) using gradient descent (introduced above)
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
