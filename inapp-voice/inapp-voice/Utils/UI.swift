//
//  utils.swift
//  inapp-voice
//
//  Created by iujie on 19/04/2023.
//

import UIKit

extension UIViewController {

func showToast(message : String, font: UIFont) {

    let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 100, y: self.view.frame.size.height-100, width: 200, height: 35))
    toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    toastLabel.textColor = UIColor.white
    toastLabel.font = font
    toastLabel.textAlignment = .center;
    toastLabel.text = message
    toastLabel.alpha = 1.0
    toastLabel.layer.cornerRadius = 10;
    toastLabel.clipsToBounds  =  true
    self.view.addSubview(toastLabel)
    UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
         toastLabel.alpha = 0.0
    }, completion: {(isCompleted) in
        toastLabel.removeFromSuperview()
    })
} }

func createAlert(message : String, completion: ((_ isActionSubmitted: Bool) -> ())? = nil) -> UIAlertController{
    let alert = UIAlertController(title: message, message: nil , preferredStyle: .alert)
    let alertAction = UIAlertAction(title: "OK", style: .default) { action in
        if let completion = completion {
            completion(true)
        }
    }
    alert.addAction(alertAction)
    
    return alert
}

func createLoadingActivityIndicator() -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView()
        
        indicator.style = .large
        indicator.color = .darkGray
            
        // The indicator should be animating when
        // the view appears.
        indicator.startAnimating()
            
        // Setting the autoresizing mask to flexible for all
        // directions will keep the indicator in the center
        // of the view and properly handle rotation.
        indicator.autoresizingMask = [
            .flexibleLeftMargin, .flexibleRightMargin,
            .flexibleTopMargin, .flexibleBottomMargin
        ]
            
        return indicator
}

extension UIViewController {
    var appDelegate: AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
   }
}
