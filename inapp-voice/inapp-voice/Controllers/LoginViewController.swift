//
//  LoginViewController.swift
//  inapp-voice
//
//  Created by iujie on 19/04/2023.
//

import UIKit

class LoginViewController: UIViewController {
    
    // Form
    @IBOutlet weak var formStackView: UIStackView!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var regionTextField: UITextField!
    @IBOutlet weak var pinTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    
    // Table
    @IBOutlet weak var regionTableView: UITableView!
    var regionSearchResult = Constants.countries
    
    var user: UserModel?
    var userManager = UserManager()
    
    let inputTag: [String: Int] = [
        "username": 1,
        "region": 2,
        "pin": 3
    ]
    
    let loadingActivityIndicator = createLoadingActivityIndicator()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initial View
        submitButton.layer.cornerRadius = Constants.borderRadius
        
        // Delegate
        userManager.delegate = self
        
        usernameTextField.tag = inputTag["username"]!
        usernameTextField.delegate = self
        
        regionTextField.tag = inputTag["region"]!
        regionTextField.delegate = self
        
        pinTextField.tag = inputTag["pin"]!
        pinTextField.delegate = self
        
        regionTableView.dataSource = self
        regionTableView.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(connectionStatusReceived(_:)), name: .clientStatus, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(networkStatusChangedReceived(_:)), name: .networkConnectionStatusChanged, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        autoLogin()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        formStackView.isHidden = false
        loadingActivityIndicator.removeFromSuperview()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func autoLogin() {
        DispatchQueue.main.async { [weak self] in
            // Check if view controller visible and has network connected
            if (self != nil && Reachability.isConnectedToNetwork() && self!.isViewLoaded && self!.view.window != nil) {
                if let data = UserDefaults.standard.data(forKey: Constants.userKey) {
                    do {
                        let decoder = JSONDecoder()
                        let user = try decoder.decode(UserModel.self, from: data)
                        
                        // Refresh token
                        self!.userManager.fetchCredential(username: user.username, region: user.region, pin: nil, token: user.token)
                        
                        self!.formStackView.isHidden = true
                        
                        // Add loading spinner
                        self!.loadingActivityIndicator.center = CGPoint(
                            x: self!.view.bounds.midX,
                            y: self!.view.bounds.midY
                        )
                        self!.view.addSubview(self!.loadingActivityIndicator)
                        
                    } catch {
                        self!.present(createAlert(message: "Unable to Decode user: \(error)", completion: { isActionSubmitted in
                            self!.formStackView.isHidden = false
                        }), animated: true)
                    }
                }
            }
        }
    }
    
    @IBAction func submitButtonClicked(_ sender: Any) {
        if ((usernameTextField.text == "") || (regionTextField.text == "") || (pinTextField.text == "")) {
            self.showToast(message: "Missing Sign-In information", font: .systemFont(ofSize: 12.0))
            return
        }
        if !Constants.countries.contains(regionTextField.text!) {
            self.showToast(message: "Invalid region", font: .systemFont(ofSize: 12.0))
            return
        }
        
        usernameTextField.endEditing(true)
        regionTextField.endEditing(true)
        pinTextField.endEditing(true)
        
        formStackView.isHidden = true
        submitButton.isEnabled = false
        // Add loading spinner
        loadingActivityIndicator.center = CGPoint(
            x: self.view.bounds.midX,
            y: self.view.bounds.midY
        )
        view.addSubview(self.loadingActivityIndicator)
        userManager.fetchCredential(username: usernameTextField.text!, region: regionTextField.text!, pin: pinTextField.text!, token: nil)
    }
}

//MARK: Notification
extension LoginViewController {
    @objc func keyboardWillHide() {
        self.view.frame.origin.y = 0
    }
    
    @objc func keyboardWillChange(notification: NSNotification) {
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if (pinTextField.isFirstResponder || regionTextField.isFirstResponder) {
                self.view.frame.origin.y = (-keyboardSize.height + 50)
            }
            else {
                self.view.frame.origin.y = 0
            }
        }
    }
    
    @objc func connectionStatusReceived(_ notification: NSNotification) {
        if let clientStatus = notification.object as? VonageClientStatusModel {
            DispatchQueue.main.async { [weak self] in
                if (self == nil) {return}
                
                if (clientStatus.state == .connected) {
                    self!.showToast(message: "Connected", font: .systemFont(ofSize: 12.0))
                    if (self!.user == nil) {return}
                    self!.performSegue(withIdentifier: "goToCallVC", sender: self)
                }
                else if (clientStatus.state == .disconnected) {
                    self!.formStackView.isHidden = false
                    self!.loadingActivityIndicator.removeFromSuperview()
                }
            }
        }
    }
    
    @objc func networkStatusChangedReceived(_ notification: NSNotification) {
        autoLogin()
    }

}

//MARK: UITextFieldDelegate
extension LoginViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if (textField.tag == inputTag["region"]) {
            regionTableView.isHidden = false
        }
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        if (textField.tag == inputTag["region"]) {
            regionTableView.isHidden = true
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (textField.tag == inputTag["region"]) {
            regionSearchResult = filterCountries(input: regionTextField.text!)
            regionTableView.reloadData()
        }
        textField.endEditing(true)
        return true
    }
    func textFieldDidChangeSelection(_ textField: UITextField) {
        if (textField.tag == inputTag["region"]) {
            regionSearchResult = filterCountries(input: regionTextField.text!)
            regionTableView.reloadData()
        }
    }
    
    func filterCountries(input: String) -> Array<String> {
        if input != "" && !Constants.countries.contains(input){
            return Constants.countries.filter({ country in
                country.lowercased().contains(input.lowercased())
            })
        }
        else {
            return Constants.countries
        }
    }
}

//MARK: UITableViewDataSource
extension LoginViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "regionTableCell")
        
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "regionTableCell")
        }
        
        if #available(iOS 14.0, *) {
            var config = UIListContentConfiguration.cell()
            config.text = regionSearchResult[indexPath.row]
            cell?.contentConfiguration = config
        } else {
            cell?.textLabel?.text = regionSearchResult[indexPath.row]
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return regionSearchResult.count
    }
}

//MARK: UITableViewDelegate
extension LoginViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        regionTextField.text = regionSearchResult[indexPath.row]
        regionTextField.endEditing(true)
    }
}

//MARK: UserManagerDelegate
extension LoginViewController: UserManagerDelegate {
    func didUpdateUser(user: UserModel) {
        self.user = user
        DispatchQueue.main.async { [weak self] in
            if (self == nil) {return}
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self!.appDelegate.vgclient.login(user: user)
                self!.submitButton.isEnabled = true
            }
        }
    }
    func handleUserManagerError(message: String) {
        DispatchQueue.main.async { [weak self] in
            if (self == nil) {return}
            
            self!.formStackView.isHidden = false
            self!.loadingActivityIndicator.removeFromSuperview()
            self!.submitButton.isEnabled = true
            self!.appDelegate.vgclient.logout()
            self!.present(createAlert(message: message, completion: nil), animated: true, completion: nil)
        }
    }
}
