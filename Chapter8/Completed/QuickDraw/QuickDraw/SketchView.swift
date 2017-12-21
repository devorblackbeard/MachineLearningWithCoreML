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
    
    init(startingPoint:CGPoint, color:UIColor=UIColor.black, width:CGFloat=2.0) {
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
    var strokeWidth : CGFloat = 2.0
    
    var strokes : [Stroke] = [Stroke]()
    
    var currentStroke : Stroke?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

// MARK: - Drawing

extension SketchView{
    
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
        self.sendActions(for: UIControlEvents.valueChanged)
        
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
        self.sendActions(for: UIControlEvents.valueChanged)
    }
    
    override func cancelTracking(with event: UIEvent?) {
        guard let _ = self.currentStroke else{ return }
        
        // set currentStroke to nil
        self.currentStroke = nil
        
        // request the view to redraw itself
        self.setNeedsDisplay()
        
        // notify target of action (target-action pattern)
        self.sendActions(for: UIControlEvents.valueChanged)
    }
}
