//
//  SketchView.swift
//  QuickDraw
//
//  Created by Joshua Newnham on 21/12/2017.
//  Copyright © 2017 Method. All rights reserved.
//

import UIKit

class Stroke{
    // Points that make up the stroke
    var points : [CGPoint] = [CGPoint]()
    // Color of this stroke
    var color : UIColor!
    // Width of this stroke
    var width : CGFloat!
    
    /**
     Return the min point (min x, min y) that contains the users stroke
     */
    var minPoint : CGPoint{
        get{
            guard points.count > 0 else{
                return CGPoint(x: 0, y: 0)
            }
            
            let minX : CGFloat = points.map { (cp) -> CGFloat in
                return cp.x
                }.min() ?? 0
            
            let minY : CGFloat = points.map { (cp) -> CGFloat in
                return cp.y
                }.min() ?? 0
            
            return CGPoint(x: minX, y: minY)
        }
    }
    
    /**
     Return the max point (max x, max y) that contains the users stroke
     */
    var maxPoint : CGPoint{
        get{
            guard points.count > 0 else{
                return CGPoint(x: 0, y: 0)
            }
            
            let maxX : CGFloat = points.map { (cp) -> CGFloat in
                return cp.x
                }.max() ?? 0
            
            let maxY : CGFloat = points.map { (cp) -> CGFloat in
                return cp.y
                }.max() ?? 0
            
            return CGPoint(x: maxX, y: maxY)
        }
    }
    
    var path : CGPath{
        get{
            let path = CGMutablePath.init()
            if points.count > 0{
                for (idx, point) in self.points.enumerated(){
                    if idx == 0{
                        path.move(to: point)
                    } else{
                        path.addLine(to: point)
                    }
                }
            }
            
            return path
        }
    }
    
    init(startingPoint:CGPoint, color:UIColor=UIColor.black, width:CGFloat=10.0) {
        self.points.append(startingPoint)
        self.color = color
        self.width = width
    }
}

class SketchView: UIControl {
    
    // Color used to fill (clear) the canvas
    var clearColor : UIColor = UIColor.white
    
    // The color assigned to the stroke
    var strokeColor : UIColor = UIColor.black
    
    // The width assigned to the stroke
    var strokeWidth : CGFloat = 10.0
    
    // All strokes that make up this sketch
    var strokes : [Stroke] = [Stroke]()
    
    var currentStroke : Stroke?
    
    /**
     Return the min point (min x, min y) that contains the users stroke
     */
    var minPoint : CGPoint{
        get{
            guard strokes.count > 0 else{
                return CGPoint(x: 0, y: 0)
            }
            
            let minPoints = strokes.map { (stroke) -> CGPoint in
                return stroke.minPoint
            }
            
            let minX : CGFloat = minPoints.map { (cp) -> CGFloat in
                return cp.x
                }.min() ?? 0
            
            let minY : CGFloat = minPoints.map { (cp) -> CGFloat in
                return cp.y
                }.min() ?? 0
            
            return CGPoint(x: minX, y: minY)
        }
    }
    
    /**
     Return the max point (max x, max y) that contains the users stroke
     */
    var maxPoint : CGPoint{
        get{
            guard strokes.count > 0 else{
                return CGPoint(x: 0, y: 0)
            }
            
            let maxPoints = strokes.map { (stroke) -> CGPoint in
                return stroke.maxPoint
            }
            
            let maxX : CGFloat = maxPoints.map { (cp) -> CGFloat in
                return cp.x
                }.max() ?? 0
            
            let maxY : CGFloat = maxPoints.map { (cp) -> CGFloat in
                return cp.y
                }.max() ?? 0
            
            return CGPoint(x: maxX, y: maxY)
        }
    }
    
    /** Returning the bounding box that encapsulates the users sketch **/
    var boundingBox : CGRect{
        get{
            let minPoint = self.minPoint
            let maxPoint = self.maxPoint
            
            let size = CGSize(width: maxPoint.x - minPoint.x, height: maxPoint.y - minPoint.y)
            
            return CGRect(x: minPoint.x, y: minPoint.y, width: size.width, height: size.height)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

// MARK: - Drawing

extension SketchView{
    
    func exportSketch(size:CGSize) -> CIImage?{
        let boundingBox = self.boundingBox
        var scale : CGFloat = 1.0
        
        if boundingBox.width > boundingBox.height{
            scale = size.width / (boundingBox.width)
        } else{
            scale = size.height / (boundingBox.height)
        }
        
        guard boundingBox.width > 0, boundingBox.height > 0 else{
            return nil
        }
        
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        
        guard let context = UIGraphicsGetCurrentContext() else{
            return nil
        }
        
        UIGraphicsPushContext(context)
        
        context.scaleBy(x: scale, y: scale)
        
        let scaledSize = CGSize(width: boundingBox.width * scale, height: boundingBox.height * scale)
        
        context.translateBy(x: -boundingBox.origin.x + (size.width - scaledSize.width)/2,
                            y: -boundingBox.origin.y + (size.height - scaledSize.height)/2)
        
        self.clearView(context: context)
        self.drawStrokes(context: context)
        
        UIGraphicsPopContext()
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else{
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()
        
        return image.ciImage != nil ? image.ciImage : CIImage(cgImage: image.cgImage!)
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else{ return }
        
        self.clearView(context: context)
        self.drawStrokes(context: context)
    }
    
    private func clearView(context:CGContext){
        self.clearColor.setFill()
        UIRectFill(self.bounds)
    }
    
    private func drawStrokes(context:CGContext){
        for stroke in self.strokes{
            self.drawStroke(context: context, stroke: stroke)
        }
    }
    
    private func drawStroke(context:CGContext, stroke:Stroke){
        stroke.color.setStroke()
        context.setStrokeColor(stroke.color.cgColor)
        context.setLineWidth(stroke.width)
        context.addPath(stroke.path)
        context.drawPath(using: .stroke)
    }
}

// MARK: - Touch methods

extension SketchView{
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool{
        // obtain the point of touch relative to this view
        let point = touch.location(in: self)
        // create a new stroke
        self.currentStroke = Stroke(startingPoint: point,
                                    color:self.strokeColor,
                                    width:self.strokeWidth)
        
        // add currentStroke to strokes
        self.strokes.append(self.currentStroke!)
        
        // request the view to redraw itself
        self.setNeedsDisplay()
        
        // notify target of action (target-action pattern)
        self.sendActions(for: UIControlEvents.valueChanged)
        
        // return true to indicate we want to continue tracking
        return true
    }
    
    override func continueTracking(_ touch: UITouch?, with event: UIEvent?) -> Bool {
        guard let currentStroke = self.currentStroke, let touch = touch else{ return false }
        
        // obtain the point of touch relative to this view
        let point = touch.location(in: self)
        
        // add point to the current stroke
        currentStroke.points.append(point)
        
        // request the view to redraw itself
        self.setNeedsDisplay()
        
        // notify target of action (target-action pattern)
        self.sendActions(for: UIControlEvents.editingDidBegin)
        
        // return true to indicate we want to continue tracking
        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        guard let currentStroke = self.currentStroke, let touch = touch else{ return }
        
        // obtain the point of touch relative to this view
        let point = touch.location(in: self)
        
        // add point to the current stroke
        currentStroke.points.append(point)
        
        // set currentStroke to nil
        self.currentStroke = nil
        
        // request the view to redraw itself
        self.setNeedsDisplay()
        
        // notify target of action (target-action pattern)
        self.sendActions(for: UIControlEvents.editingChanged)
    }
    
    override func cancelTracking(with event: UIEvent?) {
        guard let _ = self.currentStroke else{ return }
        
        // set currentStroke to nil
        self.currentStroke = nil
        
        // request the view to redraw itself
        self.setNeedsDisplay()
        
        // notify target of action (target-action pattern)
        self.sendActions(for: UIControlEvents.editingDidEnd)
    }
}
