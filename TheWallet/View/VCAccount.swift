//
//  VCAccount.swift
//  MoneyManager
//
//  Created by Roman on 22.11.2022.
//

import UIKit
import FirebaseAuth
import GoogleSignIn

class VCAccount: UIViewController {

  @IBAction func logOut(_ sender: Any) {
    GIDSignIn.sharedInstance.signOut()
    try? Auth.auth().signOut()
    UserRepository.shared.user = nil
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: "email")
    defaults.removeObject(forKey: "password")
    performSegue(withIdentifier: "segueToVCSignIn", sender: nil)
  }
  
  @IBAction func closeView(_ sender: Any) {
    dismiss(animated: true)
  }

    override func viewDidLoad() {
        super.viewDidLoad()

    }

}
