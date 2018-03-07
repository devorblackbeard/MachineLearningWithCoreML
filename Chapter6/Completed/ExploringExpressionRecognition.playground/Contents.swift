//: Playground - noun: a place where people can play

import UIKit
import Vision
import CoreML
import PlaygroundSupport

// Required to run tasks in the background
PlaygroundPage.current.needsIndefiniteExecution = true

/** Load test images **/
// Arrays to hold the images and extracted features
var images = [UIImage]()
for i in 1...3{
    guard let image = UIImage(named:"images/joshua_newnham_\(i).jpg")
        else{ fatalError("Failed to extract features") }
    
    images.append(image)
}

if let happyImage = UIImage(named:"images/happy.png"){
    images.append(happyImage)
}

if let angryImage = UIImage(named:"images/angry.png"){
    images.append(angryImage)
}

let faceIdx = 4 // image index of our images array
let imageView = UIImageView(image: images[faceIdx])
imageView.contentMode = .scaleAspectFit

// Get the orientation of the image which we will feed into the request handler
let imageOrientation = CGImagePropertyOrientation(images[faceIdx].imageOrientation)

/*
 VNDetectFaceRectanglesRequest:
 https://developer.apple.com/documentation/vision/VNDetectFaceRectanglesRequest
 An image analysis request that finds faces within an image.
 */
let faceDetection = VNDetectFaceRectanglesRequest()

/*
 VNSequenceRequestHandler:
 https://developer.apple.com/documentation/vision/VNSequenceRequestHandler
 An object that processes image analysis requests pertaining to a
 sequence of multiple images.
 */
let faceDetectionRequest = VNSequenceRequestHandler()

// Perform face detection
try? faceDetectionRequest.perform(
    [faceDetection],
    on: images[faceIdx].cgImage!,
    orientation: imageOrientation)

/*
 VNFaceObservation:
 https://developer.apple.com/documentation/vision/vnfaceobservation
 Face or facial-feature information detected by an image analysis request.
 */
if let faceDetectionResults = faceDetection.results as? [VNFaceObservation]{
    for face in faceDetectionResults{
        if let currentImage = imageView.image{
            let bbox = face.boundingBox
            
            let imageSize = CGSize(width:currentImage.size.width,
                                   height: currentImage.size.height)
  
            /*
             The face's bounding box is normalised in respect to the
             size of the image i.e. is in a range of 0.0 - 1.0 where
             this is a ratio of the overall image size e.g. width = 0.5 would
             be half of the width of the source image.
            */
            let w = bbox.width * imageSize.width
            let h = bbox.height * imageSize.height
            let x = bbox.origin.x * imageSize.width
            let y = bbox.origin.y * imageSize.height
            
            let faceRect = CGRect(x: x,
                                  y: y,
                                  width: w,
                                  height: h)
            
            /*
             It’s worth remembering that Vision the framework
             is using a flipped coordinate system, which means we
             need to invert y
             */
            let invertedY = imageSize.height - (faceRect.origin.y + faceRect.height)
            let invertedFaceRect = CGRect(x: x,
                                          y: invertedY,
                                          width: w,
                                          height: h)
            
            /*
             // An alternative to inverting the face rectangle would be to use an
             // AfflineTransform; such as follows
             var transform = CGAffineTransform(scaleX: 1, y: -1)
             transform = transform.translatedBy(x: 0, y: -imageSize.height)
             let invertedFaceRect = faceRect.apply(transform)
            */
            
            imageView.drawRect(rect: invertedFaceRect)
        }
    }
}

/*
 VNDetectFaceLandmarksRequest:
 https://developer.apple.com/documentation/vision/vndetectfacelandmarksrequest
 An image analysis request that finds facial features
 (such as the eyes and mouth) in an image.
 
 By default, a face landmarks request first locates all faces
 in the input image, then analyzes each to detect facial features.
 
 If you've already located all the faces in an image, or want to
 detect landmarks in only a subset of the faces in the image, set
 the inputFaceObservations property to an array of VNFaceObservation
 objects representing the faces you want to analyze.
 */
let faceLandmarks = VNDetectFaceLandmarksRequest()

// Perform facial landmarks detection
try? faceDetectionRequest.perform(
    [faceLandmarks],
    on: images[faceIdx].cgImage!,
    orientation: imageOrientation)

if let faceLandmarkDetectionResults = faceLandmarks.results as? [VNFaceObservation]{
    for face in faceLandmarkDetectionResults{
        if let currentImage = imageView.image{
            // As we had before; we have access to the boundingbox
            // of the face(s)
            let bbox = face.boundingBox
            
            let imageSize = CGSize(width:currentImage.size.width,
                                   height: currentImage.size.height)
            
            let w = bbox.width * imageSize.width
            let h = bbox.height * imageSize.height
            let x = bbox.origin.x * imageSize.width
            let y = bbox.origin.y * imageSize.height
            
            let faceRect = CGRect(x: x,
                                  y: y,
                                  width: w,
                                  height: h)
            
            /*
             We also have access to facial landmarks include:
             left and right eye, mouth, nose, nose crest, face contour,
             left and right eyebrow, inner and outer lips,
             median line (center of face), left and right pupil
             https://developer.apple.com/documentation/vision/vnfacelandmarks2d
            */
            
            /*
             Lets create a utility function to return a transformed
             set of points for a given landmark (the points are
             normalised i.e. 0.0 - 1.0 with respect to the image dimensions
            */
            func getTransformedPoints(
                landmark:VNFaceLandmarkRegion2D,
                faceRect:CGRect,
                imageSize:CGSize) -> [CGPoint]{
                
                // last point is 0.0
                return landmark.normalizedPoints.map({ (np) -> CGPoint in
                    return CGPoint(
                        x: faceRect.origin.x + np.x * faceRect.size.width,
                        y: imageSize.height - (np.y * faceRect.size.height + faceRect.origin.y))
                })
            }
            
            if let landmarks = face.landmarks?.leftEye {
                let transformedPoints = getTransformedPoints(
                    landmark: landmarks,
                    faceRect: faceRect,
                    imageSize: imageSize)
                
                imageView.drawPath(pathPoints: transformedPoints,
                                   closePath: true,
                                   color: UIColor.blue,
                                   lineWidth: 1.0,
                                   vFlip: false)
                
                // Find the center of the eyes
                var center = transformedPoints.reduce(CGPoint.zero, { (result, point) -> CGPoint in
                    return CGPoint(
                        x:result.x + point.x,
                        y:result.y + point.y)
                })
                
                center.x /= CGFloat(transformedPoints.count)
                center.y /= CGFloat(transformedPoints.count)
                imageView.drawCircle(center: center,
                                     radius: 2,
                                     color: UIColor.blue,
                                     lineWidth: 1.0,
                                     vFlip: false)
            }
            
            if let landmarks = face.landmarks?.rightEye {
                let transformedPoints = getTransformedPoints(
                    landmark: landmarks,
                    faceRect: faceRect,
                    imageSize: imageSize)
                
                imageView.drawPath(pathPoints: transformedPoints,
                                   closePath: true,
                                   color: UIColor.blue,
                                   lineWidth: 1.0,
                                   vFlip: false)
                
                // Find the center of the eyes
                var center = transformedPoints.reduce(CGPoint.zero, { (result, point) -> CGPoint in
                    return CGPoint(
                        x:result.x + point.x,
                        y:result.y + point.y)
                })
                
                center.x /= CGFloat(transformedPoints.count)
                center.y /= CGFloat(transformedPoints.count)
                imageView.drawCircle(center: center,
                                     radius: 2,
                                     color: UIColor.blue,
                                     lineWidth: 1.0,
                                     vFlip: false)
            }
            
            if let landmarks = face.landmarks?.faceContour {
                let transformedPoints = getTransformedPoints(
                    landmark: landmarks,
                    faceRect: faceRect,
                    imageSize: imageSize)
                
                imageView.drawPath(pathPoints: transformedPoints,
                                   closePath: false,
                                   color: UIColor.blue,
                                   lineWidth: 1.0,
                                   vFlip: false)
            }
            
            if let landmarks = face.landmarks?.nose {
                let transformedPoints = getTransformedPoints(
                    landmark: landmarks,
                    faceRect: faceRect,
                    imageSize: imageSize)
                
                imageView.drawPath(pathPoints: transformedPoints,
                                   closePath: false,
                                   color: UIColor.blue,
                                   lineWidth: 1.0,
                                   vFlip: false)
            }
            
            if let landmarks = face.landmarks?.noseCrest {
                let transformedPoints = getTransformedPoints(
                    landmark: landmarks,
                    faceRect: faceRect,
                    imageSize: imageSize)
                
                imageView.drawPath(pathPoints: transformedPoints,
                                   closePath: false,
                                   color: UIColor.blue,
                                   lineWidth: 1.0,
                                   vFlip: false)
            }
            
            if let landmarks = face.landmarks?.innerLips {
                let transformedPoints = getTransformedPoints(
                    landmark: landmarks,
                    faceRect: faceRect,
                    imageSize: imageSize)
                
                imageView.drawPath(pathPoints: transformedPoints,
                                   closePath: false,
                                   color: UIColor.blue,
                                   lineWidth: 1.0,
                                   vFlip: false)
            }
            
            if let landmarks = face.landmarks?.outerLips {
                let transformedPoints = getTransformedPoints(
                    landmark: landmarks,
                    faceRect: faceRect,
                    imageSize: imageSize)
                
                imageView.drawPath(pathPoints: transformedPoints,
                                   closePath: false,
                                   color: UIColor.blue,
                                   lineWidth: 1.0,
                                   vFlip: false)
            }
        }
    }
}

/*
 Now we have had a play with the Vision framework; let's return to our
 task of classification the facial expression (and therefore mood)
 from a given photo
 */

// Restore the image of our ImageView
imageView.image = images[faceIdx]

if let faceDetectionResults = faceDetection.results as? [VNFaceObservation]{
    for face in faceDetectionResults{
        if let currentImage = imageView.image{
            let bbox = face.boundingBox
            
            let imageSize = CGSize(width:currentImage.size.width,
                                   height: currentImage.size.height)
            
            let w = bbox.width * imageSize.width
            let h = bbox.height * imageSize.height
            let x = bbox.origin.x * imageSize.width
            let y = bbox.origin.y * imageSize.height
            
            let faceRect = CGRect(x: x,
                                  y: y,
                                  width: w,
                                  height: h)
            
            /*
             Along with inverting the face bounds we want to pad it out
             (to include the top of the head and some surplus padding around
             the face/head).
             */
            let paddingTop = faceRect.height * 0.57
            let paddingBottom = faceRect.height * 0.15
            let paddingWidth = faceRect.width * 0.15
            
            let invertedY = imageSize.height - (faceRect.origin.y + faceRect.height)
            
            let croppingRect = CGRect(x: max(x - paddingWidth, 0),
                                          y: max(invertedY - paddingTop, 0),
                                          width: min(w + paddingWidth*2, imageSize.width),
                                          height: min(h + paddingTop + paddingBottom, imageSize.height))
            
            // visualisation of the face
            imageView.drawRect(rect: croppingRect)
            
            // Crop out the face
            if let croppedCGImage = images[faceIdx].cgImage?.cropping(to: croppingRect){
                imageView.image = UIImage(cgImage:croppedCGImage)
            }
            
            // Let's now grayscale the image
            let model = try VNCoreMLModel(for: ExpressionRecognitionModel().model)
            
            let request = VNCoreMLRequest(
                model: model,
                completionHandler: { (request, error) in
                    /*
                     A request can be given a hander which is called once
                     the inference has been performed; the resutls is of type VNRequest
                     and includes a results variable including ... the results of the
                     inference - if no error has occured.
                     
                     The results, in our case, are observations (array of VNClassificationObservation); this datatype is returned by VNCoreMLRequests that are using a model performing
                     classification (like our expression recognition model).
                     */
                    guard let observations = request.results as? [VNClassificationObservation] else{ return }
                    
                    /*
                     Each observation consists of a label and confidence level;
                     observations are sorted by confidence - let's have a look.
                    */
                    for observation in observations{
                        print("\(observation.identifier) \(observation.confidence)")
                    }
                    
                    DispatchQueue.main.sync{
                        print("Classification finished")
                    }
            })
            request.imageCropAndScaleOption = .centerCrop
            
            DispatchQueue.global(qos: .background).async {
                if let pixelBuffer = images[faceIdx].toPixelBuffer(){
                    let imageOrientation = images[faceIdx].imageOrientation
                    
                    let handler = VNImageRequestHandler(
                        cvPixelBuffer: pixelBuffer,
                        orientation: CGImagePropertyOrientation(imageOrientation),
                        options: [:])
                    
                    try? handler.perform([request])
                    
                } else{
                    fatalError("Unable to get the pixel buffer from the image")
                }
            }
        }
    }
}


