//
//  BingServiceAPI.swift
//  QuickDraw
//
//  Created by Joshua Newnham on 27/12/2017.
//  Copyright © 2017 Method. All rights reserved.
//

import UIKit

/**
 Basic data object encapsulating the results of a Bing
 image search
 */
class BingServiceResult{
    var name : String
    var url : String    
    
    init(name:String, url:String) {
        self.name = name
        self.url = url
    }
}

class BingService{
    
    static let sharedInstance: BingService = BingService()
    
    // Replace the subscriptionKey string value with your valid subscription key.
    let subscriptionKey = "6d4144f607cb4e82ace8ebc7a2a5b357"
    
    // Verify the endpoint URI.  At this writing, only one endpoint is used for Bing
    // search APIs.  In the future, regional endpoints may be available.  If you
    // encounter unexpected authorization errors, double-check this host against
    // the endpoint for your Bing Web search instance in your Azure dashboard.
    let endpoint = "https://api.cognitive.microsoft.com/bing/v7.0/images/search"
    
    private init() {
        
    }
}

// MARK: - Bing service handling methods

extension BingService{
    
    func syncSearch(searchTerm:String, count:Int=4) -> [BingServiceResult]{
        print("syncSearch \(searchTerm)")
        
        var results = [BingServiceResult]()
        
        guard let escapedSearchTerm = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else{
            return results
        }
        
        // build request
        guard let url = NSURL(string: "\(endpoint)?q=\(escapedSearchTerm)%20drawing&imageType=Line&count=\(count)") else {
            return results
        }
        
        let request = NSMutableURLRequest(url: url as URL)
        request.setValue("application/json; charset=utf-8",
                         forHTTPHeaderField: "Content-Type")
        request.setValue(subscriptionKey,
                         forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.httpMethod = "GET"
        
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            if error == nil, data != nil {
                let _ = self.parseBingResults(data: data!, results: &results)
            }
            semaphore.signal()
        }
        
        task.resume()
        
        _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(5))
        
        return results
    }
    
    func asyncSearch(searchTerm:String, count:Int=4,
                     callback: @escaping (_ status:Int, _ results:[BingServiceResult]?) -> Void) -> Void{
        
        guard let url = NSURL(string: "\(endpoint)?q=\(searchTerm)&imageType=Line&count=\(count)") else {
            callback(-1, nil)
            return
        }
        
        let request = NSMutableURLRequest(url: url as URL)
        request.setValue("application/json; charset=utf-8",
                         forHTTPHeaderField: "Content-Type")
        request.setValue(subscriptionKey,
                         forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.httpMethod = "GET"
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: {(data, response, error) -> Void in
            
            if let error = error{
                print(error.localizedDescription)
                
                DispatchQueue.main.async {
                    callback(-2, nil)
                }
            }
            else{
                
                guard let data = data else{
                    DispatchQueue.main.async {
                        callback(-3, nil)
                    }
                    return
                }
                
                var results = [BingServiceResult]()
                
                if !self.parseBingResults(data: data, results: &results){
                    DispatchQueue.main.async {
                        callback(-4, nil)
                    }
                }
                
                DispatchQueue.main.async {
                    callback(1, results)
                }
            }
        })
        
        task.resume()
    }
}

// MARK: - Image handling methods

extension BingService{
    
    func syncDownloadImage(bingResult:BingServiceResult) -> CIImage?{
        print("syncDownloadImage \(bingResult.url)")
        
        guard let url = URL(string: bingResult.url) else{
            return nil
        }
        
        var result : CIImage?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            
            if error == nil, data != nil{
                let filename = response?.suggestedFilename ?? url.lastPathComponent
                print("Downloaded \(filename)")
                
                result = CIImage(data: data!)
            }
            
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(5))
        
        return result
    }
    
    func asyncDownloadImage(bingResult:BingServiceResult,
                       callback:@escaping (_ status:Int, _ filename:String?, _ image: CIImage?)->Void){
        
        guard let url = URL(string: bingResult.url) else{
            callback(-1, nil, nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else{
                DispatchQueue.main.async {
                    callback(-2, nil, nil)
                }
                return
            }
            
            if let error = error{
                print(error.localizedDescription)
                
                DispatchQueue.main.async {
                    callback(-3, nil, nil)
                }
            }
            else{
                let filename = response?.suggestedFilename ?? url.lastPathComponent
                
                guard let image = CIImage(data: data) else{
                    DispatchQueue.main.async {
                        callback(-4, nil, nil)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    callback(1, filename, image)
                }
            }
            }.resume()
    }
    
}

// MARK: - Bing results parsing

extension BingService{
    fileprivate func parseBingResults(data:Data, results:inout [BingServiceResult]) -> Bool{
        do{
            let parsed = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)
            
            //let responseAsString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            
            if let root = parsed as? NSDictionary{
                if let searchResults = root["value"] as? NSArray{
                    for searchResult in searchResults{
                        if let searchResult = searchResult as? NSDictionary{
                            if let name = searchResult["name"] as? NSString,
                                //let contentUrl = searchResult["contentUrl"] as? NSString{
                                let contentUrl = searchResult["thumbnailUrl"] as? NSString{
                                results.append(
                                    BingServiceResult(name: name as String,
                                                      url: contentUrl as String))
                            }
                        }
                    }
                }
            }
            
        } catch {
            return false
        }
        
        return true
    }
}
