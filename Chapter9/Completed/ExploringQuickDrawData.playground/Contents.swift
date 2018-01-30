/*:
 We will be using a small subset of the [ndjson]: https://github.com/maxogden/ndjson files for the airplane raw and simplified. The main dif
 */
import UIKit
import PlaygroundSupport

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

if let json = rawJSON{
    if let sketch = StrokeSketch.createFromJSON(json: json[2] as? [String:Any]){
        sketch.scale = 1.0
        
        print(sketch.boundingBox)
        
        let sketchView = SketchView(frame: CGRect(
            x: 0, y: 0, width: 600, height: 600))
        
        sketchView.sketches.append(sketch)
        sketchView.setNeedsDisplay()
    }
}

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
