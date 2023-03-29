//
//  VCMain.swift
//  MoneyManager
//
//  Created by Roman on 07.01.2021.
//

import UIKit
import JGProgressHUD

protocol ProtocolVCMain {
    func updateScreen() throws // full screen update
    func showOperation(_ id: UUID) throws // opens a PopUp window for a specific operation
    func hideOperation() throws // closes the PopUp window of a specific operation
    func editOperation(uuid: UUID) // transition to editing the selected operation on the second screen
    func miniGraphStarterBackground(status: Bool)

    func returnMonthOfDate(_ dateInternal: Date) -> String
    func returnIncomesExpenses() -> [String: Double]?

    func getUserRepository() -> UserRepository
    func getUserData() throws -> User
    func updateUserData(newData: User)
    func updateOperations(amount: Double, categoryUUID: UUID, note: String, date: Date, idOfObject: UUID)
    func addOperations(amount: Double, categoryUUID: UUID, note: String, date: Date)
    func deleteCategory(idOfObject: UUID)
    func updateCategory(name: String, icon: String, idOfObject: UUID)
    func returnGraphData() -> [GraphData]
    func addCategory(name: String, icon: String, date: Double)
    func deleteOperation(uuid: UUID)
    func fetchFirebase() async
    func showAlert(message: String)
}

// swiftlint:disable all
class VCMain: UIViewController {
// swiftlint:enable all
    static let shared = VCMain()

        // MARK: - outlets
    @IBOutlet var tableView: UITableView!
    @IBOutlet var buttonDaily: UIView!
    @IBOutlet var buttonWeekly: UIView!
    @IBOutlet var buttonMonthly: UIView!
    @IBOutlet var buttonYearly: UIView!
    @IBOutlet var topMenuButtonStrip: UIView!
    @IBOutlet var labelDaily: UILabel!
    @IBOutlet var labelWeekly: UILabel!
    @IBOutlet var labelMothly: UILabel!
    @IBOutlet var labelYearly: UILabel!
    @IBOutlet var bottomPopInView: UIView!
    @IBOutlet var labelAmountOfIncomes: UILabel!
    @IBOutlet var labelAmountOfExpenses: UILabel!
    @IBOutlet var constraintTopMenuBottomStrip: NSLayoutConstraint!
    @IBOutlet var viewOperation: UIView!
    @IBOutlet var constraintContainerBottomPoint: NSLayoutConstraint!
    @IBOutlet var miniGraph: RoundedGraphView!
    @IBOutlet var screen1BottomMenu: UIView!
    @IBOutlet var scrollViewFromBottomPopInView: UIScrollView!
    @IBOutlet var graphFromBottomPopInView: UIView!
    @IBOutlet var buttonNewOperation: UIButton!
    @IBOutlet var buttonShowGraph: UIButton!
    @IBOutlet var buttonShowList: UIButton!
    @IBOutlet var miniGraphStarterBackground: UIView!

        // MARK: - delegates and variables
    var income: Double = 0
    var expensive: Double = 0
    var tapShowOperation: UITapGestureRecognizer?
    var vcSettingDelegate: ProtocolVCSetting?
    var vcOperationDelegate: ProtocolVCOperation?
    var vcGraphDelegate: ProtocolVCGraph?
    var tagForEdit: UUID?
    var screen1StatusGrapjDisplay = false
    var arrayForIncrease: [Int] = [0]
    var graphDataArray: [GraphData] = []
    var datasource: MyDataSource?
    var userRepository = UserRepository.shared
    let dateFormatter = DateFormatter()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    let hud = JGProgressHUD()
    var isButtonsActive = false

        // MARK: - transitions
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vewController = segue.destination as? VCSetting,
           segue.identifier == PerformSegueIdentifiers.segueToVCSetting.rawValue {
            vcSettingDelegate = vewController
            vewController.vcMainDelegate = self
        }
        if let viewController = segue.destination as? VCOperation,
           segue.identifier == PerformSegueIdentifiers.segueToVCOperation.rawValue {
            vcOperationDelegate = viewController
            viewController.vcMainDelegate = self
        }
        if let viewController = segue.destination as? VCGraph,
           segue.identifier == PerformSegueIdentifiers.segueToVCGraph.rawValue {
            vcGraphDelegate = viewController
            viewController.vcMainDelegate = self
        }
        if let viewController = segue.destination as? VCSetting,
           segue.identifier == PerformSegueIdentifiers.segueToVCSettingForEdit.rawValue {
            if let userRepositoryUser = userRepository.user {
                viewController.vcSettingStatusEditing = true
                viewController.vcMainDelegate = self
                vcSettingDelegate = viewController
                if let specialOperation = userRepositoryUser.operations.filter({$0.value.id == tagForEdit}).first?.value {
                    if let vcSettingDelegate = vcSettingDelegate {
                        if let specialOperationCategory = specialOperation.category {
                            vcSettingDelegate.setVCSetting(
                                amount: specialOperation.amount,
                                categoryUUID: specialOperationCategory,
                                date: specialOperation.date,
                                note: specialOperation.note,
                                id: specialOperation.id
                            )
                        } else {
                            showAlert(message: "Error specialOperationCategory")
                        }
                    } else {
                        showAlert(message: "Error vcSettingDelegate == nil")
                    }
                } else {
                    showAlert(message: "Error specialOperation")
                }
            } else {
                showAlert(message: "Error VCSetting destination: userRepository.user")
            }
        }
    }

        // MARK: - clicks

    @IBAction func settingPage(_ sender: Any) {
        performSegue(withIdentifier: PerformSegueIdentifiers.segueToVCAccount.rawValue, sender: nil)
    }

    @IBAction func buttonActionScreen1NewOperation(_ sender: Any) {
        performSegue(withIdentifier: PerformSegueIdentifiers.segueToVCSetting.rawValue, sender: nil)
    }

    @IBAction func buttonActionScreen1ShowGraph(_ sender: Any) {
        if isButtonsActive == true {
            print("screen1StatusGrapjDisplay= \(screen1StatusGrapjDisplay)")
            if screen1StatusGrapjDisplay == false {
                    // userRepository.updateDaysForSorting(daysForSorting: 30)
                // vcGraphDelegate?.dataUpdate()
                DispatchQueue.main.async {
                    self.buttonMonthlyGesture(self)
                }
                buttonDaily.isUserInteractionEnabled = false
                buttonDaily.alpha = 0.3
                buttonWeekly.isUserInteractionEnabled = false
                buttonWeekly.alpha = 0.3
                buttonYearly.isUserInteractionEnabled = false
                buttonYearly.alpha = 0.3
                countingIncomesAndExpensive()
                do {
                    try vcGraphDelegate?.dataUpdate()
                    miniGraph.setNeedsDisplay()
                    try applySnapshot()
                    borderLineForMenu(days: 30)
                } catch {
                    showAlert(message: "Error updating VCGraph")
                }
                UIView.transition(
                    from: scrollViewFromBottomPopInView,
                    to: graphFromBottomPopInView,
                    duration: 1.0,
                    options: [.transitionFlipFromLeft, .showHideTransitionViews],
                    completion: nil
                )
                screen1StatusGrapjDisplay = true
                buttonShowGraph.setImage(UIImage.init(named: "Left-On"), for: .normal)
                buttonShowList.setImage(UIImage.init(named: "Right-Off"), for: .normal)
            }
        }
    }

    @IBAction func buttonActionScreen1ShowList(_ sender: Any) {
        isButtonsActive = true
        if screen1StatusGrapjDisplay == true {
            UIView.transition(
                from: graphFromBottomPopInView,
                to: scrollViewFromBottomPopInView,
                duration: 1.0,
                options: [.transitionFlipFromRight, .showHideTransitionViews],
                completion: nil
            )
            buttonDaily.isUserInteractionEnabled = true
            buttonDaily.alpha = 1
            buttonWeekly.isUserInteractionEnabled = true
            buttonWeekly.alpha = 1
            buttonYearly.isUserInteractionEnabled = true
            buttonYearly.alpha = 1

            screen1StatusGrapjDisplay = false
            buttonShowGraph.setImage(UIImage.init(named: "Left-Off"), for: .normal)
            buttonShowList.setImage(UIImage.init(named: "Right-On"), for: .normal)
            buttonDaily.isUserInteractionEnabled = true
            buttonDaily.alpha = 1
        }
            // configureDataSource()
            // applySnapshot()
        do {
            try updateScreen()
        } catch {
            showAlert(message: "Screen update error")
        }
    }

    @IBAction func buttonDailyGesture(_ sender: Any) {
        if isButtonsActive == true {
            do {
                try userRepository.updateDaysForSorting(daysForSorting: 1)
                print("updateDaysForSorting 1= \(userRepository.user?.daysForSorting)")
                try updateScreen()
            } catch ThrowError.mainViewUpdateScreen {
                showAlert(message: "Screen update error")
            } catch {
                showAlert(message: "Database connection error, missing userReference")
            }
        }
    }

    @IBAction func buttonWeeklyGesture(_ sender: Any) {
        if isButtonsActive == true {
            do {
                try userRepository.updateDaysForSorting(daysForSorting: 7)
                print("updateDaysForSorting 7= \(userRepository.user?.daysForSorting)")
                try updateScreen()
            } catch ThrowError.mainViewUpdateScreen {
                showAlert(message: "Screen update error")
            } catch {
                showAlert(message: "Database connection error, missing userReference")
            }
        }
    }

    @IBAction func buttonMonthlyGesture(_ sender: Any) {
        if isButtonsActive == true {
            do {
                try userRepository.updateDaysForSorting(daysForSorting: 30)
                print("updateDaysForSorting 30= \(userRepository.user?.daysForSorting)")
                try updateScreen()
            } catch ThrowError.mainViewUpdateScreen {
                showAlert(message: "Screen update error")
            } catch {
                showAlert(message: "Database connection error, missing userReference")
            }
        }
    }

    @IBAction func buttonYearlyGesture(_ sender: Any) {
        if isButtonsActive == true {
            do {
                try userRepository.updateDaysForSorting(daysForSorting: 365)
                print("updateDaysForSorting 365= \(userRepository.user?.daysForSorting)")
                try updateScreen()
            } catch ThrowError.mainViewUpdateScreen {
                showAlert(message: "Screen update error")
            } catch {
                showAlert(message: "Database connection error, missing userReference")
            }
        }
    }

    @objc func switchScreen1GraphContainer(tap: UITapGestureRecognizer) {
        if tap.state == UIGestureRecognizer.State.ended {
            print("Tap Graph ended")
        }
    }

    @objc func handlerToHideContainerScreen1(tap: UITapGestureRecognizer) {
        if tap.state == UIGestureRecognizer.State.ended {
            print("Tap ended")
            let pointOfTap = tap.location(in: self.view)
            if viewOperation.frame.contains(pointOfTap) {
                print("Tap inside Container")
            } else {
                print("Tap outside Container")
                do {
                    try hideOperation()
                } catch {
                    showAlert(message: "hideOperation error")
                }
            }
        }
    }

    // MARK: - top Menu
    private func topMenuHighliter(specifyLabel: UILabel) {
        specifyLabel.font = UIFont.systemFont(ofSize: specifyLabel.font.pointSize, weight: .bold)
        switch specifyLabel {
        case labelDaily:
            labelWeekly.font = UIFont.systemFont(ofSize: labelWeekly.font.pointSize, weight: .medium)
            labelMothly.font = UIFont.systemFont(ofSize: labelMothly.font.pointSize, weight: .medium)
            labelYearly.font = UIFont.systemFont(ofSize: labelYearly.font.pointSize, weight: .medium)
            print("111")
        case labelWeekly:
            labelDaily.font = UIFont.systemFont(ofSize: labelDaily.font.pointSize, weight: .medium)
            labelMothly.font = UIFont.systemFont(ofSize: labelMothly.font.pointSize, weight: .medium)
            labelYearly.font = UIFont.systemFont(ofSize: labelYearly.font.pointSize, weight: .medium)
            print("222")
        case labelMothly:
            labelDaily.font = UIFont.systemFont(ofSize: labelDaily.font.pointSize, weight: .medium)
            labelWeekly.font = UIFont.systemFont(ofSize: labelWeekly.font.pointSize, weight: .medium)
            labelYearly.font = UIFont.systemFont(ofSize: labelYearly.font.pointSize, weight: .medium)
            print("333")
        case labelYearly:
            labelDaily.font = UIFont.systemFont(ofSize: labelDaily.font.pointSize, weight: .medium)
            labelWeekly.font = UIFont.systemFont(ofSize: labelWeekly.font.pointSize, weight: .medium)
            labelMothly.font = UIFont.systemFont(ofSize: labelMothly.font.pointSize, weight: .medium)
            print("444")
        default:
            print("Error with higlightLabel")
        }
    }

    func borderLineForMenu(days: Int) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: UIView.AnimationOptions(),
            animations: {
                switch days {
                case 1:
                    self.constraintTopMenuBottomStrip.constant = self.buttonDaily.frame.origin.x + 10
                    self.topMenuHighliter(specifyLabel: self.labelDaily)
                    print("borderForMenuBottom 1")
                case 7:
                    self.constraintTopMenuBottomStrip.constant = self.buttonWeekly.frame.origin.x + 10
                    print("borderForMenuBottom 7")
                    self.topMenuHighliter(specifyLabel: self.labelWeekly)
                case 30:
                    self.constraintTopMenuBottomStrip.constant = self.buttonMonthly.frame.origin.x + 10
                    self.topMenuHighliter(specifyLabel: self.labelMothly)
                    print("borderForMenuBottom 30")
                case 365:
                    self.constraintTopMenuBottomStrip.constant = self.buttonYearly.frame.origin.x + 10
                    self.topMenuHighliter(specifyLabel: self.labelYearly)
                    print("borderForMenuBottom 365")
                default:
                    print("Error with borderForMenuBotton")
                }
            }, completion: { _ in })
    }

    func countingIncomesAndExpensive() {
        if let operations = userRepository.user?.operations,
        let userRepositoryUser = userRepository.user {
            let freshHold = Date().timeIntervalSince1970 - Double(86400 * userRepositoryUser.daysForSorting)

            income = 0
            expensive = 0
            for data in operations.filter({ $0.value.amount > 0 && $0.value.date > freshHold }) {
                income += data.value.amount
            }
            for data in operations.filter({ $0.value.amount < 0 && $0.value.date > freshHold }) {
                expensive += data.value.amount
            }

            if income.truncatingRemainder(dividingBy: 1) == 0 {
                labelAmountOfIncomes.text = "$\(String(format: "%.0f", income))"
            } else {
                labelAmountOfIncomes.text = "$\(String(format: "%.2f", income))"
            }

            if expensive.truncatingRemainder(dividingBy: 1) == 0 {
                labelAmountOfExpenses.text = "$\(String(format: "%.0f", expensive))"
            } else {
                labelAmountOfExpenses.text = "$\(String(format: "%.2f", expensive))"
            }
        } else {
            showAlert(message: "Error countingIncomesAndExpensive")
        }
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad")
        Task {
            do {
                // hudAppear()
                try await userRepository.fetchGetUserData { user in
                    self.hudAppear()
                    self.userRepository.user = user
                    print("NewData= \(String(describing: self.userRepository.user))")
                    do {
                        try self.updateScreen()
                    } catch {
                        self.showAlert(message: "Screen update error")
                    }
                    self.hudDisapper()
                    // self.showAlert(message: "Database connection success")
                }
            } catch ThrowError.getUserDataError {
                showAlert(message: "Database connection error, missing userReference")
            }
        }
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        configureDataSource()
        do {
            try applySnapshot()
        } catch {
            showAlert(message: "Error updating VCGraph")
        }

        miniGraph.setDelegateScreen1RoundedGraph(delegate: self)
        // 
        // bottomPopInView.textContainer.lineBreakMode = .byTruncatingTail
        // bottomPopInView.layer.borderColor = UIColor.gray.cgColor
        // bottomPopInView.layer.borderWidth = 2
        bottomPopInView.layer.cornerRadius = 20
        bottomPopInView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomPopInView.clipsToBounds = true

            // adding a blur effect
        self.view.insertSubview(self.blurView, belowSubview: self.viewOperation)
        self.blurView.backgroundColor = .clear
        self.blurView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.blurView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.blurView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.blurView.heightAnchor.constraint(equalTo: self.view.heightAnchor),
            self.blurView.widthAnchor.constraint(equalTo: self.view.widthAnchor)
        ])
        self.blurView.isHidden = true
    }

    func showAlert(message: String) {
        let alert = UIAlertController(
          title: message,
          message: nil,
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil ))
        self.present(alert, animated: true, completion: nil)
    }
}
