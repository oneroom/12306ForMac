//
//  LoginWindowController.swift
//  Train12306
//
//  Created by fancymax on 15/8/10.
//  Copyright (c) 2015年 fancy. All rights reserved.
//

import Cocoa

class LoginWindowController: NSWindowController{

    @IBOutlet weak var passWord: NSSecureTextField!
    @IBOutlet weak var userName: AutoCompleteTextField!
    @IBOutlet weak var loginImage: RandCodeImageView2!
    
    let service = Service()
    var users = [UserX]()
    var isAutoLogin = false
    var isLogin = false
    
    override var windowNibName: String{
        return "LoginWindowController"
    }
    
    override func windowDidLoad() {
        if let lastName = QueryDefaultManager.sharedInstance.lastUserName,
        let lastPassword = QueryDefaultManager.sharedInstance.lastUserPassword{
            userName.stringValue = lastName
            passWord.stringValue = lastPassword
        }
        
        userName.tableViewDelegate = self

        users = DataManger.sharedInstance.queryAllUsers()
        
        loadImage()
    }
    
    @IBAction func clickNextImage(_ sender: NSButton)
    {
        loadImage()
    }
    
    @IBAction func clickOK(_ sender:AnyObject?){
        if userName.stringValue == "" || passWord.stringValue == "" {
            self.showTip("请先输入用户名和密码")
            return
        }
        if loginImage.randCodeStr == nil {
            self.showTip("请先选择验证码")
            return
        }
        
        if isLogin {
            return
        }
        
        isLogin = true
        self.startLoadingTip("正在登录...")
        
        let failureHandler = {(error:NSError) -> () in
            self.isLogin = false
            self.stopLoadingTip()
            self.showTip(translate(error))
            Timer.scheduledTimer(timeInterval: 1, target: self, selector:#selector(LoginWindowController.handlerAfterFailure), userInfo: nil, repeats: false)
        }
        
        let successHandler = {
            self.stopLoadingTip()
            self.handlerAfterSuccess()
        }
        
        service.loginFlow(user: userName.stringValue, passWord: passWord.stringValue, randCodeStr: loginImage.randCodeStr!, success: successHandler, failure: failureHandler)
    }
    
    @IBAction func clickCancel(_ button:NSButton){
        dismissWithModalResponse(NSModalResponseCancel)
    }
    
    
    func showTip(_ tip:String)  {
        DJTipHUD.showStatus(tip, from: self.window?.contentView)
    }
    
    func startLoadingTip(_ tip:String)
    {
        DJLayerView.showStatus(tip, from: self.window?.contentView)
    }
    
    func stopLoadingTip(){
        DJLayerView.dismiss()
    }
    
    
    func handlerAfterFailure(){
        self.loadImage()
    }
   
    func handlerAfterSuccess(){
        QueryDefaultManager.sharedInstance.lastUserName = userName.stringValue
        QueryDefaultManager.sharedInstance.lastUserPassword = passWord.stringValue
        
        //save user
        let updateUser = users.filter({$0.name == userName.stringValue})
        if updateUser.count > 0 {
            for user in updateUser where user.password != passWord.stringValue {
                user.password = passWord.stringValue
                DataManger.sharedInstance.updateUser(user)
            }
        }
        else {
            let user = UserX()
            user.name = userName.stringValue
            user.password = passWord.stringValue
            DataManger.sharedInstance.inserUser(user)
        }
        
        self.dismissWithModalResponse(NSModalResponseOK)
    }
    
    func loadImage(){
        self.loginImage.clearRandCodes()
        self.startLoadingTip("正在加载...")
        
        let autoLoginHandler = {(image:NSImage)->() in
            self.startLoadingTip("自动打码...")
            
            Dama.sharedInstance.dama(AdvancedPreferenceManager.sharedInstance.damaUser,
                password: AdvancedPreferenceManager.sharedInstance.damaPassword,
                ofImage: image,
                success: {imageCode in
                        self.stopLoadingTip()
                        self.loginImage.drawDamaCodes(imageCode)
                        self.clickOK(nil)
                },
                failure: {error in
                        self.stopLoadingTip()
                        self.showTip(translate(error))
                })
        }
        
        let successHandler = {(image:NSImage) -> () in
            self.loginImage.image = image
            self.stopLoadingTip()
            
            if ((self.isAutoLogin)&&(AdvancedPreferenceManager.sharedInstance.isUseDama)) {
                autoLoginHandler(image)
            }
        }
        let failureHandler = {(error:NSError) -> () in
            self.stopLoadingTip()
            self.showTip(translate(error))
        }
        service.preLoginFlow(success: successHandler,failure: failureHandler)
    }
    
    func dismissWithModalResponse(_ response:NSModalResponse)
    {
        if window != nil {
            if window!.sheetParent != nil {
                window!.sheetParent!.endSheet(window!,returnCode: response)
            }
        }
    }
}

// MARK: - AutoCompleteTableViewDelegate
extension LoginWindowController: AutoCompleteTableViewDelegate{
    func textField(_ textField: NSTextField, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: Int) -> [String] {
        var matches = [String]()
        for  user in self.users {
            if let _ = user.name.range(of: textField.stringValue, options: NSString.CompareOptions.anchored)
            {
                matches.append(user.name)
            }
        }
        return matches
    }
    
    func didSelectItem(_ selectedItem: String) {
        for  user in self.users where user.name == selectedItem {
            self.passWord.stringValue = user.password
        }
    }
}
