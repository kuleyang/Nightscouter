//
//  SiteTableViewController.swift
//  Nightscouter
//
//  Created by Peter Ina on 6/16/15.
//  Copyright © 2015 Peter Ina. All rights reserved.
//

import UIKit
import NightscouterKit

//TODO:// Add an updating mechanism, like pull to refresh, button and or timer. Maybe consider moving a timer to the API that observers can subscribe to.

class SiteListTableViewController: UITableViewController, SitesDataSourceProvider, SegueHandlerType {
    
    @IBOutlet fileprivate weak var snoozeAlarmButton: UIBarButtonItem!
    @IBOutlet fileprivate weak var headerView: BannerMessage!
    
    struct CellIdentifier {
        static let SiteTableViewStyle = "siteCell"
    }
    
    enum SegueIdentifier: String {
        case EditExisting, ShowDetail, AddNew, AddNewWhenEmpty, ShowPageView, unwindToSiteList
    }
    
    let network = Nightscout()
    
    // MARK: Properties
    
    // Computed Property: Grabs the common set of sites from the data manager.
    var sites: [Site] {
        return SitesDataSource.sharedInstance.sites
    }
    
    var milliseconds: Double = 0 {
        didSet{
            let str = String(stringInterpolation:LocalizedString.lastUpdatedDateLabel.localized, AppConfiguration.lastUpdatedDateFormatter.string(from: date))
            self.refreshControl?.attributedTitle = NSAttributedString(string:str, attributes: [NSForegroundColorAttributeName: Color.white])
            self.refreshControl?.endRefreshing()
        }
    }
    
    /// Holds a site to display straight away. It will push the detail view controller.
    var siteToDisplay: Site?
    
    /// Holds the indexPath of an accessory that was tapped. Used for getting the right Site from the sites array before passing over to the next view.
    var accessoryIndexPath: IndexPath?
    
    var timer: Timer?
    
    
    // MARK: View controller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let site = siteToDisplay {
            performSegue(withIdentifier: .ShowPageView, sender: site)
        }
        
        // Common setup.
        configureView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check if we should display a form.
        shouldIShowNewSiteForm()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    deinit {
        // Remove this class from the observer list. Was listening for a global update timer.
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return sites.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = CellIdentifier.SiteTableViewStyle
        
        // Configure the cell...
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! SiteTableViewCell
        
        configureCell(cell, indexPath: indexPath)
        
        return cell
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            let site = sites[indexPath.row]
            SitesDataSource.sharedInstance.deleteSite(site)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            shouldIShowNewSiteForm()
        }
    }
    
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
        // update the item in my data source by first removing at the from index, then inserting at the to index.
        SitesDataSource.sharedInstance.moveSite(fromIndex: fromIndexPath.row, toIndex: toIndexPath.row)
    }
    
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        if sites.count == 1 {
            return false
        }
        return true
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        accessoryIndexPath = indexPath
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let action = UITableViewRowAction(style: .destructive, title: LocalizedString.tableViewCellRemove.localized) { (action, aIndexPath) in
            self.tableView(tableView, commit: .delete, forRowAt: aIndexPath)
        }
        action.backgroundColor = NSAssetKit.predefinedAlertColor
        
        return [action]
    }
    
    override func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return LocalizedString.tableViewCellRemove.localized
    }
    
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        print(">>> Entering \(#function) <<<")
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        switch segueIdentifierForSegue(segue: segue) {
        case .EditExisting:
            #if DEBUG
                print("Editing existing site")
            #endif
            isEditing = false
            let siteDetailViewController = segue.destination as! SiteFormViewController
            // Get the cell that generated this segue.
            if let selectedSiteCell = sender as? UITableViewCell {
                let indexPath = tableView.indexPath(for: selectedSiteCell)!
                let selectedSite = sites[indexPath.row]
                siteDetailViewController.site = selectedSite
            }
            
        case .AddNew:
            #if DEBUG
                print("Adding new site")
            #endif
            self.setEditing(false, animated: true)
            
        case .AddNewWhenEmpty:
            #if DEBUG
                print("Adding new site when empty")
            #endif
            self.setEditing(false, animated: true)
            
        case .ShowDetail:
            #if DEBUG
                print("Show detail view")
            #endif
            
            let siteDetailViewController = segue.destination as! SiteDetailViewController
            // Get the cell that generated this segue.
            if let selectedSiteCell = sender as? UITableViewCell {
                let indexPath = tableView.indexPath(for: selectedSiteCell)!
                let selectedSite = sites[indexPath.row]
                siteDetailViewController.site = selectedSite
            }
            
        case .ShowPageView:
            #if DEBUG
                print("Show page view.")
            #endif
            
            // Get the cell that generated this segue.
            if let selectedSiteCell = sender as? UITableViewCell {
                let indexPath = tableView.indexPath(for: selectedSiteCell)!
                SitesDataSource.sharedInstance.lastViewedSiteIndex = indexPath.row
            }
            
            if let incomingSite = sender as? Site{
                if let indexOfSite = sites.index(of: incomingSite) {
                    SitesDataSource.sharedInstance.lastViewedSiteIndex = indexOfSite
                }
            }
        default:
            return
        }
    }
    
    @IBAction func unwindToSiteList(_ sender: UIStoryboardSegue) {
        
        if let sourceViewController = sender.source as? SiteFormViewController, let site = sourceViewController.site {
            
            // This segue is triggered when we "save" or "next" out of the url form.
            if let selectedIndexPath = accessoryIndexPath {
                // Update an existing site.
                SitesDataSource.sharedInstance.updateSite(site)
                self.refreshDataFor(site, index: selectedIndexPath.row)
                //tableView.reloadRows(at: [selectedIndexPath], with: .none)
                accessoryIndexPath = nil
            } else {
                // Add a new site.
                isEditing = false
                let newIndexPath = IndexPath(row: 0, section: 0)
                SitesDataSource.sharedInstance.createSite(site, atIndex: newIndexPath.row)
                
                accessoryIndexPath = nil
                guard let _ = tableView.cellForRow(at: newIndexPath) else {
                    
                    tableView.reloadData()
                    return
                }
                
                tableView.insertRows(at: [newIndexPath], with: .automatic)
                
            }
        }
        
        if let pageViewController = sender.source as? SiteListPageViewController {
            tableView.reloadRows(at: [IndexPath(row: pageViewController.currentIndex, section: 0)], with: .none)
        }
        
        shouldIShowNewSiteForm()
    }
    
    
    // MARK: Actions
    @IBAction func refreshTable() {
        updateData()
    }
    
    @IBAction func manageAlarm(_ sender: UIBarButtonItem?) {
        print(">>> Entering \(#function) <<<")
        FIXME()
        // AlarmManager.sharedManager.presentSnoozePopup(forViewController: self)
    }
    
    @IBAction func goToSettings(_ sender: AnyObject?) {
        print(">>> Entering \(#function) <<<")
        let settingsUrl = URL(string: UIApplicationOpenSettingsURLString)
        UIApplication.shared.openURL(settingsUrl!)
    }
    
    
    // MARK: Private Methods
    
    func configureView() {
        // The following line displys an Edit button in the navigation bar for this view controller.
        navigationItem.leftBarButtonItem = self.editButtonItem
        
        // Only allow the edit button to be enabled if there are items in the sites array.
        clearsSelectionOnViewWillAppear = true
        
        // Configure table view properties.
        tableView.tableHeaderView = nil
        tableView.estimatedRowHeight = 180
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.backgroundView = BackgroundView() // TODO: Move this out to a theme manager.
        tableView.separatorColor = NSAssetKit.darkNavColor
        
        // Position refresh control above background view
        refreshControl?.tintColor = UIColor.white
        refreshControl?.layer.zPosition = tableView.backgroundView!.layer.zPosition + 1
        
        self.setupNotifications()
        
        if #available(iOS 10.0, *) {
            self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval.OneMinute, repeats: true, block: { (timer) in
                self.updateUI(timer: timer)
            })
        } else {
            self.timer = Timer.scheduledTimer(timeInterval: TimeInterval.OneMinute, target: self, selector: #selector(SiteListTableViewController.updateUI(timer:)), userInfo: nil, repeats: true)
        }
        
        // Make sure the idle screen timer is turned back to normal. Screen will time out.
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    func updateUI(timer: Timer?) {
        print(">>> Entering \(#function) <<<")
        print("Updating user interface at: \(Date())")
        self.tableView.reloadData()
    }
    
    func setupNotifications() {
        // Listen for global update timer.
        NotificationCenter.default.addObserver(self, selector: #selector(SiteListTableViewController.updateData), name: .NightscoutDataStaleNotification, object: nil)
        //NotificationCenter.default.addObserver(self, selector: #selector(SiteListTableViewController.updateData), name: .NightscoutDataUpdatedNotification, object: nil)
    }
    
    // For a given cell and index path get the appropriate site object and assign various properties.
    func configureCell(_ cell: SiteTableViewCell, indexPath: IndexPath) -> Void {
        let site = sites[indexPath.row]
        let model = site.summaryViewModel
        
        cell.configure(withDataSource: model, delegate: model)
        // FIXME:// this prevents a loop, but needs to be fixed and errors need to be reported.
        FIXME()
        if (site.updateNow || site.configuration == nil) {
            refreshDataFor(site, index: indexPath.row)
        }
    }
    
    func shouldIShowNewSiteForm() {
        // If the sites array is empty show a vesion of the form that does not allow escape.
        if sites.isEmpty{
            let vc = storyboard?.instantiateViewController(withIdentifier: StoryboardIdentifier.formViewController.rawValue) as! SiteFormViewController
            self.parent!.present(vc, animated: true, completion: { () -> Void in
                // println("Finished presenting SiteFormViewController.")
            })
        } else {
            dismiss(animated: true, completion: { () -> Void in
                self.updateData()
            })
        }
    }
    
    
    // MARK: Fetch data via REST API
    
    func updateData(){
        // Do not allow refreshing to happen if there is no data in the sites array.
        if sites.isEmpty == false {
            if refreshControl?.isRefreshing == false {
                refreshControl?.beginRefreshing()
                // tableView.setContentOffset(CGPoint(x: 0, y: tableView.contentOffset.y-refreshControl!.frame.size.height), animated: true)
            }
            for (index, site) in sites.enumerated() {
                refreshDataFor(site, index: index)
            }
            
        } else {
            // No data in the sites array. Cancel the refreshing!
            refreshControl?.endRefreshing()
        }
    }
    
    func refreshDataFor(_ site: Site, index: Int){
        /// Tie into networking code.
        FIXME()
        var siteToUpdate = site
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        siteToUpdate.fetchDataFromNetwrok(userInitiated: false) { (success, updatedsite, err) in
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            
            if let error = err {
                self.presentAlertDialog(site.url, index: index, error: error.kind.description)
            }
            
            if let upSite = updatedsite {
                SitesDataSource.sharedInstance.updateSite(upSite)
            }
            
            if (self.refreshControl?.isRefreshing != nil) {
                self.refreshControl?.endRefreshing()
            }
            
            OperationQueue.main.addOperation {
                if let _ = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) , self.tableView.numberOfRows(inSection: 0)<0 {
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                } else {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    // Attempt to handle an error.
    func presentAlertDialog(_ siteURL:URL, index: Int, error: String) {
        
        let alertController = UIAlertController(title: LocalizedString.uiAlertBadSiteTitle.localized, message: String(format: LocalizedString.uiAlertBadSiteMessage.localized, siteURL as CVarArg, error), preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: LocalizedString.generalCancelLabel.localized, style: .cancel) { (action) in
            // ...
        }
        alertController.addAction(cancelAction)
        
        let retryAction = UIAlertAction(title: LocalizedString.generalRetryLabel.localized, style: .default) { (action) in
            let indexPath = IndexPath(row: index, section: 0)
            var site = SitesDataSource.sharedInstance.sites[indexPath.row]
            site.disabled = false
            SitesDataSource.sharedInstance.updateSite(site)
            
            self.refreshDataFor(site, index: indexPath.row)
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        alertController.addAction(retryAction)
        
        let editAction = UIAlertAction(title: LocalizedString.generalEditLabel.localized, style: .default) { (action) in
            let indexPath = IndexPath(row: index, section: 0)
            let tableViewCell = self.tableView.cellForRow(at: indexPath)
            self.accessoryIndexPath = indexPath
            self.performSegue(withIdentifier: SegueIdentifier.EditExisting.rawValue, sender:tableViewCell)
        }
        alertController.addAction(editAction)
        
        let removeAction = UIAlertAction(title: LocalizedString.tableViewCellRemove.localized, style: .destructive) { (action) in
            self.tableView.beginUpdates()
            
            let site = SitesDataSource.sharedInstance.sites[index]
            SitesDataSource.sharedInstance.deleteSite(site)
            self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            self.tableView.endUpdates()
        }
        alertController.addAction(removeAction)
        
        alertController.view.tintColor = NSAssetKit.darkNavColor
        
        self.view.window?.tintColor = nil
        
        let _ = self.navigationController?.popToRootViewController(animated: true)
        
        self.present(alertController, animated: true) {
            // remove nsnotification observer?
            // ...
        }
    }
}



//    func alarmManagerHasChangedAlarmingState(isActive alarm: Bool, urgent: Bool, snoozed: Bool) {
//
//        if alarm == true || snoozed {
//            let activeColor = urgent ? NSAssetKit.predefinedAlertColor : NSAssetKit.predefinedWarningColor
//
//            snoozeAlarmButton.isEnabled = true
//            snoozeAlarmButton.tintColor = activeColor
//
//            tableView.tableHeaderView = headerView
//            tableView.reloadData()
//
//            if let headerView = tableView.tableHeaderView as? BannerMessage {
//                headerView.isHidden = false
//                headerView.tintColor = activeColor
////                headerView.message = snoozed ? AlarmManager.sharedManager.snoozeText : "One or more of your sites are sounding an alarm."
//            }
//
//        } else if alarm == false && !snoozed {
//            snoozeAlarmButton.isEnabled = false
//            snoozeAlarmButton.tintColor = nil
//            tableView.tableHeaderView = nil
//
//        } else {
//            snoozeAlarmButton.image = UIImage(named: "alarmIcon")
//            tableView.tableHeaderView = nil
//        }
//    }

/*
 extension SiteListTableViewController: UpdatableUserInterfaceType {
 override func viewWillAppear(_ animated: Bool) {
 super.viewWillAppear(animated)
 startUpdateUITimer()
 }
 
 func updateUI(_ notif: Timer) {
 print("updating ui for: \(notif)")
 self.tableView.reloadData()
 }
 
 override func viewWillDisappear(_ animated: Bool) {
 super.viewWillDisappear(animated)
 updateUITimer.invalidate()
 }
 }
 */

