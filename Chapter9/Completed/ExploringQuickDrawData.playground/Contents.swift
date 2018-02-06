/*:
 We will be using a small subset of the [ndjson]: https://github.com/maxogden/ndjson files for the airplane raw and simplified. The main dif
 */
import UIKit
import PlaygroundSupport
import CoreML

/*:
 The format of a raw sample is:
 {
 "key_id":"5891796615823360",
 "word":"nose",
 "countrycode":"AE",
 "timestamp":"2017-03-01 20:41:36.70725 UTC",
 "recognized":true,
 "drawing":[[[129,128,129,129,130,130,131,132,132,133,133,133,133,...]]]
 }
 
 Where drawing is broken into:
 [
    [  // First stroke
    [x0, x1, x2, x3, ...],
    [y0, y1, y2, y3, ...],
    [t0, t1, t2, t3, ...]
 ],
    [  // Second stroke
    [x0, x1, x2, x3, ...],
    [y0, y1, y2, y3, ...],
    [t0, t1, t2, t3, ...]
 ],
    ... // Additional strokes
 ]
 
 The simplified version includes all the meta-data with the following adjustments
 made to the drawing path(s):
 - Align the drawing to the top-left corner, to have minimum values of 0.
 - Uniformly scale the drawing, to have a maximum value of 255.
 - Resample all strokes with a 1 pixel spacing.
 - Simplify all strokes using the [https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm]: Ramer–Douglas–Peucker algorithm with an epsilon value of 2.0.
- Remove time
 */

/*:
 Let's extend our StrokeSketch class to include a method for handling
 parsing the JSON files so we can preview them
 */
extension StrokeSketch{
    
    static func createFromJSON(json:[String:Any]?) -> StrokeSketch?{
        guard let json = json else{
            return nil
        }
        
        let sketch = StrokeSketch()
        
        var countrycode : String?
        var key_id : String?
        var recognized : Bool?
        var word : String?
        
        if let tmp = json["countrycode"] as? String{
            countrycode = tmp
        }
        
        if let tmp = json["key_id"] as? String{
            key_id = tmp
        }
        
        if let tmp = json["recognized"] as? Bool{
            recognized = tmp
        }
        
        if let tmp = json["word"] as? String{
            word = tmp
        }
        
        if let points = json["drawing"] as? Array<Array<Array<Float>>>{
            for strokePoints in points{
                var stroke : Stroke?
                
                for xyPair in zip(strokePoints[0], strokePoints[1]){
                    let point = CGPoint(x:CGFloat(xyPair.0),
                                        y:CGFloat(xyPair.1))
                    
                    if let stroke = stroke{
                        stroke.points.append(point)
                    } else{
                        stroke = Stroke(startingPoint: point)
                    }
                }
                
                if let stroke = stroke, stroke.points.count > 0{
                    sketch.addStroke(stroke: stroke)
                }
            }
        }
        
        return sketch
    }
}

/*:
 Next we will load an extract of the raw airplane dataset and simplified
 airplane dataset
 */

var rawJSON : [Any]?
var simplifiedJSON : [Any]?

do{
    if let fileUrl = Bundle.main.url(
        forResource: "data/small_raw_airplane",
        withExtension: "json"){
        
        if let data = try? Data(contentsOf: fileUrl){
            rawJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [Any]
        }
    }
    
    if let fileUrl = Bundle.main.url(
        forResource: "data/small_simplified_airplane",
        withExtension: "json"){
        
        if let data = try? Data(contentsOf: fileUrl){
            simplifiedJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [Any]
        }
    }
} catch{
    fatalError(error as! String)
}

/*:
 Next we want to create a function responsible for rendering a given sketch - the task
 of this function is mainly concerned with rescaling and centering the sketch to the view.
 This function will instantiate an instance of SketchView which includes the re-scaled
 and re-centered sketch (of which we can preview)
 */
func drawSketch(sketch:Sketch) -> SketchView{
    let viewDimensions : CGFloat = 600
    // get bounding box
    let bbox = sketch.boundingBox
    
    // scale to fit into view
    if max(bbox.size.width,bbox.size.height) > viewDimensions{
        sketch.scale = viewDimensions / max(bbox.size.width,bbox.size.height)
    }
    
    // Center sketch in view (we take into account that the bounds have been scaled
    // therefore must inverse this by 'scaling up' i.e. 1.0 - sketch.scale;
    // the reason for this is that the points are transformed relative to their current
    // position (using the 'bounds' which is affected by the scale we set above)
    sketch.center = CGPoint(x:(viewDimensions - bbox.size.width * (1.0-sketch.scale)) / 2.0,
                            y:(viewDimensions - bbox.size.height * (1.0-sketch.scale)) / 2.0)
    
    // Instantiate the SketchView
    let sketchView = SketchView(frame: CGRect(
        x: 0, y: 0, width: viewDimensions, height: viewDimensions))
    
    // Now add our sketch to the sketches and nudge the view to update itself
    sketchView.sketches.append(sketch)
    sketchView.setNeedsDisplay()
    
    return sketchView
}

/*:
 Let's peek at some of the sketches we have; we will first preview the sketches from the
 raw dataset and then the simplified
 */

if let json = rawJSON{
    if let sketch = StrokeSketch.createFromJSON(json: json[0] as? [String:Any]){
        drawSketch(sketch: sketch)
    }
    
    if let sketch = StrokeSketch.createFromJSON(json: json[1] as? [String:Any]){
        drawSketch(sketch: sketch)
    }
    
    if let sketch = StrokeSketch.createFromJSON(json: json[2] as? [String:Any]){
        drawSketch(sketch: sketch)
        drawSketch(sketch: sketch.simplify())
    }
}

if let json = simplifiedJSON{
    if let sketch = StrokeSketch.createFromJSON(json: json[0] as? [String:Any]){
        drawSketch(sketch: sketch)
    }
    
    if let sketch = StrokeSketch.createFromJSON(json: json[1] as? [String:Any]){
        drawSketch(sketch: sketch)
    }
    
    if let sketch = StrokeSketch.createFromJSON(json: json[2] as? [String:Any]){
        drawSketch(sketch: sketch)
    }
}

/*:
 The model has been based on the tutorial https://www.tensorflow.org/tutorials/recurrent_quickdraw which speculates (and dictates) how the data needs to be prepared.
 The first is that the training samples were taken from the simplified dataset; therefore
 we must apply the same pre-processing steps on the user input as was performed on the raw training data (as listed above).
 Secondly; the tutorial (and therefore model) introduced a further step before feeding the data into the model; this included:
 - Introduce another dimension to indicate if a point is the end of not
 - Size normalization i.e. such that the minimum stroke point is 0 (on both axis) and maximum point is 1.0.
 - Compute deltas; the model was trained on deltas rather than absolutes positions
 */

/*:
 We will tackle each of these in turn; starting with the simplification pre-process; our litmus test will be to take a sample from the raw dataset and re-created the simplified equivalent.
 */

public extension StrokeSketch{
    
    /**
     - Align the drawing to the top-left corner, to have minimum values of 0.
     - Uniformly scale the drawing, to have a maximum value of 255.
     - Resample all strokes with a 1 pixel spacing.
     - Simplify all strokes using the [https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm]: Ramer–Douglas–Peucker algorithm with an epsilon value of 2.0.
    */
    public func simplify() -> StrokeSketch{
        var copy = self.copy() as! StrokeSketch
        copy.scale = 1.0
        
        let minPoint = copy.minPoint
        let maxPoint = copy.maxPoint
        let diffPoint = CGPoint(x: maxPoint.x-minPoint.x, y:maxPoint.y-minPoint.y)
        
        var width : CGFloat = 255.0
        var height : CGFloat = 255.0
        
        // adjust aspect ratio
        if diffPoint.x > diffPoint.y{
            height *= diffPoint.y/diffPoint.x
        } else{
            width *= diffPoint.y/diffPoint.x
        }
        
        // for each point, subtract the min and divide by the max
        for i in 0..<copy.strokes.count{
            copy.strokes[i].points = copy.strokes[i].points.map({ (pt) -> CGPoint in
                // Normalise point and then scale based on adjusted dimension above
                // (also casting to an Int then back to a CGFloat to get 1 pixel precision)
                let x : CGFloat = CGFloat(Int(((pt.x - minPoint.x)/diffPoint.x) * width))
                let y : CGFloat = CGFloat(Int (((pt.y - minPoint.y)/diffPoint.y) * height))
                
                return CGPoint(x:x, y:y)
            })
        }
        
        // perform line simplification
        copy.strokes = copy.strokes.map({ (stroke) -> Stroke in
            return stroke.simplify()
        })
        
        return copy
    }
}

/*:
 Line simplification using Ramer–Douglas–Peucker algorithm;
 https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm
 https://commons.wikimedia.org/wiki/File%3ADouglas-Peucker_animated.gif
 */

public extension Stroke{
    
    /**
     Perform line simplification using Ramer-Douglas-Peucker algorithm
    */
    public func simplify(epsilon:CGFloat=2.0) -> Stroke{
        
        var simplified: [CGPoint] = [self.points.first!]
        
        self.simplifyDPStep(points: self.points,
                            first: 0, last: self.points.count-1,
                            tolerance: epsilon * epsilon,
                            simplified: &simplified)
        
        simplified.append(self.points.last!)
        
        var copy = self.copy() as! Stroke
        copy.points = simplified
        
        return copy
    }
    
    func simplifyDPStep(points:[CGPoint], first:Int, last:Int,
                        tolerance:CGFloat, simplified: inout [CGPoint]){
        
        var maxSqDistance = tolerance
        var index = 0
        
        for i in first + 1..<last{
            let sqDist = CGPoint.getSquareSegmentDistance(
                p0: points[i], p1: points[first], p2: points[last])
            
            if sqDist > maxSqDistance {
                maxSqDistance = sqDist
                index = i
            }
        }
        
        if maxSqDistance > tolerance{
            if index - first > 1 {
                simplifyDPStep(points: points,
                               first: first,
                               last: index,
                               tolerance: tolerance,
                               simplified: &simplified)
            }
            
            simplified.append(points[index])
            
            if last - index > 1{
                simplifyDPStep(points: points,
                               first: index,
                               last: last,
                               tolerance: tolerance,
                               simplified: &simplified)
            }
        }
    }
    
}

public extension CGPoint{
    
    public static func getSquareDistance(p0:CGPoint, p1:CGPoint) -> CGFloat{
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y

        return dx * dx + dy * dy
    }
    
    public static func getSquareSegmentDistance(p0:CGPoint, p1:CGPoint, p2:CGPoint) -> CGFloat{
        var x0 = p0.x, y0 = p0.y
        var x1 = p1.x, y1 = p1.y
        var x2 = p2.x, y2 = p2.y
        var dx = x2 - x1
        var dy = y2 - y1
        
        if dx != 0.0 && dy != 0.0{
            let numerator = (x0 - x1) * dx + (y0 - y1) * dy
            let denom = dx * dx + dy * dy
            let t =  numerator / denom
            
            if t > 1.0{
                x1 = x2
                y1 = y2
            } else{
                x1 += dx * t
                y1 += dy * t
            }
        }
        
        dx = x0 - x1
        dy = y0 - y1
        
        return dx * dx + dy * dy
    }
}

/*:
 Let's now handle the final piece of pre-processing, as used in training, which requires the following steps:
 - Introduce another dimension to indicate if a point is the end of not
 - Size normalization i.e. such that the minimum stroke point is 0 (on both axis) and maximum point is 1.0.
 - Compute deltas; the model was trained on deltas rather than absolutes positions
 */

/*
 
 def pad_stroke_sequence(x, max_len=MAX_SEQ_LEN):
    padded_x = np.zeros((x.shape[0], max_len, 3), dtype=np.float32)
    for i in range(x.shape[0]):
        X = x[i]
        if X.shape[0] > max_len:
            X = X[:max_len, :]
    elif X.shape[0] < max_len:
        padding = np.array([[0,0,0]] * (max_len-X.shape[0]), dtype=np.float32)
        X = np.vstack((padding, X))
 
    padded_x[i] = X
 
    return padded_x
 
 */
extension StrokeSketch{
    
    public static func preprocess(sketch:StrokeSketch) -> MLMultiArray?{
        let maxSeqLen = NSNumber(value:75)
        
        let simplifiedSketch = sketch.simplify()
       
        guard var array = try? MLMultiArray(shape: [
            NSNumber(value:simplifiedSketch.strokes.count),
            maxSeqLen,
            NSNumber(value:3)], dataType: .double) else{
                return nil
        }
        
        for i in 0..<simplifiedSketch.strokes.count-1{
            let stroke = simplifiedSketch.strokes[i]
            let strokePoints = simplifiedSketch.strokes.map({ (point) -> CGPoint in
                return CGPoint.zero
            })
            //let x =
        }
        
        return array
    }
}
