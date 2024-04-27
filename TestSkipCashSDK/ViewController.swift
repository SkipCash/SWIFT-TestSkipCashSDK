//
//  ViewController.swift
//  SkipCashSDKDemo
//
//  Created by Divya Thakkar on 4/03/24.
//  Improved by Ahmed Mustafa on 25/04/24.

import UIKit
import PassKit
import SkipCashSDK


class ViewController: UIViewController, ApplePayReponseDelegate {
    
    func applePayResponseData(paymentId: String, isSuccess: Bool, token: String, returnCode: Int, errorMessage: String) {
        
        if (isSuccess) {
            self.showAlert(with: "Success", message: "Transaction was successful! To process a refund, please provide a screenshot of this alert with the payment ID '\(paymentId)' to support@skipcash.com.")
        }else{
            self.showAlert(with: "Failure", message: "Transaction Failed, \(errorMessage)  ")
        }
        
    }
    
    @IBOutlet weak var applePayView: UIView!
    var paymentController: PKPaymentAuthorizationController?
    var paymentSummaryItems = [PKPaymentSummaryItem]()
    var paymentStatus = PKPaymentAuthorizationStatus.failure
    typealias PaymentCompletionHandler = (Bool) -> Void
    var completionHandler: PaymentCompletionHandler!
    
    static let supportedNetworks: [PKPaymentNetwork] = [
        .amex,
        .discover,
        .masterCard,
        .visa
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let result = ViewController.applePayStatus()
        var button: UIButton?
        
        if result.canMakePayments {
            button = PKPaymentButton(paymentButtonType: .book, paymentButtonStyle: .black)
            button?.addTarget(self, action: #selector(ViewController.payPressed), for: .touchUpInside)
        } else if result.canSetupCards {
            button = PKPaymentButton(paymentButtonType: .setUp, paymentButtonStyle: .black)
            button?.addTarget(self, action: #selector(ViewController.setupPressed), for: .touchUpInside)
        }
        
        if let applePayButton = button {
            let constraints = [
                applePayButton.centerXAnchor.constraint(equalTo: applePayView.centerXAnchor),
                applePayButton.centerYAnchor.constraint(equalTo: applePayView.centerYAnchor)
            ]
            applePayButton.translatesAutoresizingMaskIntoConstraints = false
            applePayView.addSubview(applePayButton)
            NSLayoutConstraint.activate(constraints)
        }
    }
    
    @objc func payPressed(sender: AnyObject) {
        self.startPayment() { (success) in
            if success {
                //                print("Success")
            }
        }
    }
    
    @objc func setupPressed(sender: AnyObject) {
        let passLibrary = PKPassLibrary()
        passLibrary.openPaymentSetup()
    }
    
    class func applePayStatus() -> (canMakePayments: Bool, canSetupCards: Bool) {
        return (PKPaymentAuthorizationController.canMakePayments(),
                PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks))
    }
    
    
    
    func startPayment(completion: @escaping PaymentCompletionHandler) {
        
        completionHandler = completion
        
        let ticket = PKPaymentSummaryItem(label: "Festival Entry", amount: NSDecimalNumber(string: "0.88"), type: .final)
        let tax = PKPaymentSummaryItem(label: "Tax", amount: NSDecimalNumber(string: "0.12"), type: .final)
        let total = PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(string: "1.00"), type: .final)
        paymentSummaryItems = [ticket, tax, total]
//
        // Create a payment request.
        let paymentRequest = PKPaymentRequest()
        paymentRequest.paymentSummaryItems = paymentSummaryItems
        paymentRequest.merchantIdentifier = "merchant.com.skipcash.appay"
        paymentRequest.merchantCapabilities = .threeDSecure
        paymentRequest.countryCode = "QA"
        paymentRequest.currencyCode = "QAR"
        paymentRequest.supportedNetworks = ViewController.supportedNetworks
        
        // Display the payment request.
        paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController?.delegate = self
        paymentController?.present(completion: { (presented: Bool) in
            if presented {
                debugPrint("Presented payment controller")
            } else {
                debugPrint("Failed to present payment controller")
                self.completionHandler(false)
            }
        })
    }
    
    func showAlert(with title: String, message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        
        var viewController = window.rootViewController
        while let presentedViewController = viewController?.presentedViewController {
            viewController = presentedViewController
        }
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            // Dismiss the presented controller when "OK" is tapped
            viewController?.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(okAction)
        
        viewController?.present(alertController, animated: true, completion: nil)
    }
    
    
}

// Set up PKPaymentAuthorizationControllerDelegate conformance.

extension ViewController: PKPaymentAuthorizationControllerDelegate {
    
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        
        // Perform basic validation on the provided contact information.
        let errors = [Error]()
        let status = PKPaymentAuthorizationStatus.success
        
        var sign = ""
        
        do{
            if let jsonResponse = try JSONSerialization.jsonObject(with: payment.token.paymentData, options: []) as? [String: Any]{
                sign = String(decoding: payment.token.paymentData, as: UTF8.self)
            }else{
                print("error")
            }
            
        }catch{
            print("error converting payment token")
        }
        
        let podBundle = Bundle(for: SetupVC.self)
        let storyboard = UIStoryboard(name: "main", bundle: podBundle)
       
        /*
            Create a customer_data object and pass the necessary data (including the amount) to it,
            from where you initiate the payment, By passing it to the SetupVC
         */
        
        let customer_data = CustomerPaymentData(phone: "+97492333331", email:"example@some.com", firstName:"someone", lastName: "someone", amount: "1.00")
        
        if let vc = storyboard.instantiateViewController(withIdentifier: "SetupVC") as? SetupVC{
            vc.paymentData = customer_data
            vc.appBackendServerEndPoint = "https://paymentsimulation-4f296ff7747c.herokuapp.com/api/createPaymentLink/"
//            vc.authorizationHeader = "" // add authorization header if BE server endpoint requires
            vc.delegate = self
            vc.paymentToken = sign
            let navigationController = UINavigationController(rootViewController: vc)
            navigationController.modalPresentationStyle = .overCurrentContext
            self.present(navigationController, animated: true, completion: nil)
        }
        // Send the payment token to your server or payment provider to process here.
        // Once processed, return an appropriate status in the completion handler (success, failure, and so on).
        
        self.paymentStatus = status
        completion(PKPaymentAuthorizationResult(status: status, errors: errors))
    }
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            // The payment sheet doesn't automatically dismiss once it has finished. Dismiss the payment sheet.
            DispatchQueue.main.async {
                if self.paymentStatus == .success {
                    self.completionHandler!(true)
                } else {
                    self.completionHandler!(false)
                }
            }
        }
    }
    
    
}
