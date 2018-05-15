//
//  CGRect+Extension.swift
//  ObjectDetection
//
//  Created by Joshua Newnham on 15/05/2018.
//  Copyright © 2018 Joshua Newnham. All rights reserved.
//

import UIKit

extension CGRect{
    
    var area : CGFloat{
        get{
            return self.size.width * self.size.height
        }
    }
    
    /**
     Calcualte Intersection-over-Union of this rectangle and the other
    **/
    func computeIOU(other:CGRect) -> CGFloat{
        
        // Get the Width and Height of each bounding box
        let bb1Width = self.size.width
        let bb1Height = self.size.height
        let bb2Width = other.size.width
        let bb2Height = other.size.height
        
        // Calculate the area of the each bounding box
        let area1 = self.area
        let area2 = other.area
        
        // Find the vertical edges of the union of the two bounding boxes
        let minX = min(self.origin.x, other.origin.x)
        let maxX = max(self.origin.x, other.origin.x)
        
        // Calculate the width of the union of the two bounding boxes
        let unionWidth = maxX - minX
        
        // Find the horizontal edges of the union of the two bounding boxes
        let minY = min(self.origin.y, other.origin.y)
        let maxY = max(self.origin.y, other.origin.y)
        
        // Calculate the height of the union of the two bounding boxes
        let unionHeight = maxY - minY
        
        // Calculate the width and height of the area of intersection of the two bounding boxes
        let intersectionWidth = bb1Width + bb2Width - unionWidth
        let intersectionHeight = bb1Height + bb2Height - unionHeight
        
        // If the the boxes don't overlap then their IOU is zero
        if intersectionWidth <= 0 || intersectionHeight <= 0{
            return 0.0
        }
        
        // Calculate the area of intersection of the two bounding boxes
        let intersectionArea = intersectionWidth * intersectionHeight
        
        // Calculate the area of the union of the two bounding boxes
        let unionArea = area1 + area2 - intersectionArea
        
        // Calculate the IOU
        let iou = intersectionArea/unionArea
        
        return iou
    }
    
}
