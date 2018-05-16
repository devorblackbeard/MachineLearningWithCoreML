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
        // Calculate the area of the each bounding box
        let area1 = self.area
        let area2 = other.area
        
        if area1 <= 0 || area2 <= 0{
            return 0
        }
        
        // Find the x-coordinates of the intersection rectangle
        let intersectionMinX = max(self.minX, other.minX)
        let intersectionMaxX = min(self.maxX, other.maxX)

        // Find the y-coordinates of the intersection rectangle
        let intersectionMinY = max(self.minY, other.minY)
        let intersectionMaxY = min(self.maxY, other.maxY)

        // Calculate the area of intersection of the two bounding boxes
        let intersectionArea = max(intersectionMaxY - intersectionMinY, 0) *
            max(intersectionMaxX - intersectionMinX, 0)

        // Calculate the area of the union of the two bounding boxes
        let unionArea = area1 + area2 - intersectionArea

        //let iou = intersectionArea / unionArea
        let iou = self.intersection(other).area / self.union(other).area
        
        return iou
    }
    
}
