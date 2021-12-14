import { LightningElement, api } from 'lwc';
import getCampaignMembers from '@salesforce/apex/UndergradOrientationProcessingController.getCampaignMembers';
import getProcessedMemberStatus from '@salesforce/apex/UndergradOrientationProcessingController.getProcessedMemberStatus';
import assignAdvisor from '@salesforce/apex/UndergradOrientationProcessingController.assignAdvisor';
import updateStatus from '@salesforce/apex/UndergradOrientationProcessingController.updateStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// URL for CIS panel to update major/minor
const CHECK_MAJOR_URL = 'https://student.apps.utah.edu/uofu/stu/change-of-major/admin/student-search/main?query=';
// URL for peoplesoft panel to view/add Advisor Notes
const VIEW_ADVISOR_MEETINGS = 'https://www.stu.utah.edu/psp/heprod/EMPLOYEE/SA/c/UU_UNIVERSITY_COLLEGE.UU_MAND_ADV_MTG.GBL?EMPLID=';
// columns for the flattened datatable
const COLUMNS = [
  { label: 'First Name', fieldName: 'firstName', type:'text', editable: false, sortable : true },
  { label: 'Last Name', fieldName: 'lastName', type: 'text', editable: false, sortable : true },
  { label: 'uNID', fieldName: 'ContactLink', type: 'url', editable: false, sortable : true,
  
    typeAttributes:{label: { fieldName: 'uNID' },tooltip:"Open Contact record", target: "_blank" }

  },
  { label: 'Advisor', fieldName: 'advisor', type: 'text', editable: false, sortable : true }, 
  { label: 'Type', fieldName: 'type', type: 'text', editable: false, sortable : true }, 
  { label: 'Status', fieldName: 'RecordLink', type: 'url', editable: false, sortable : true,

    typeAttributes:{label: { fieldName: 'memberStatus' },tooltip:"Open Campaign Member record", target: "_blank" }

  },
  
  { label: 'CIS Link', fieldName: 'checkMajorUrl', type: 'url',   
      typeAttributes:{ label:"Change Major",tooltip:"Open Change Major/Minor page in CIS", target: "_blank" }, 
      cellAttributes: { 
        iconName: 'utility:change_request' ,
        iconPosition: 'left'
    },
      editable: false, sortable : false },
      { label: 'Peoplesoft Link', fieldName: 'viewAdvisorMeetings', type: 'url',   
      typeAttributes:{ label:"Remove Hold",tooltip:"Open Advisor Meetings - SA1094 panel in Peoplesoft", target: "_blank" }, 
      cellAttributes: { 
        iconName: 'utility:note' ,
        iconPosition: 'left'
    },
      editable: false, sortable : false },

];

export default class UasOrientationContainer extends LightningElement {

  /*
  * variables for datatable
  */
  sortBy = 'advisor';
  sortDirection = 'asc';
  rowOffset = 0;
  memberListData = [];
  preSelectedRows = [];
  selectedRows = [];
  columns = COLUMNS;

  // default campaign member status for a record that has been processed. Retrieved from controller. 
  processedMemberStatus = '';

  /*
  * variables for component visibility 
  */
  hideMemberSearch = true;
  loadSpinner = false;

  // set to true if at least one row is selected
  get hasSelectedRows(){
    if(this.countSelectedRows > 0){
      return true;
    } else {
      return false;
    }
  }

  // set to true if memberListData has at least one record
  get hasAttendees(){
    if(this.memberListData.length > 0){
      return true;
    } else {
      return false;
    }
  }

  // set to true if campaignId is not blank
  get hasCampaign(){
    if(this.campaignId == ''){
      return false;
    } else {
      return true;
    }
  }

  // set to true if there are no selected rows
  get hideMassUpdate(){
    if(this.countSelectedRows === 0){
      return true;
    } else {
      return false;
    }
  }

  // set to true if advisorId is blank
  get hideAdvisor(){
    if(this.advisorId == ''){
      return true;
    } else {
      return false;
    }
  }


  /*
  * variables for records Ids. Assigned from the selections in the customSearchLookup components
  */
  campaignId = '';
  advisorId = '';
  advisorName = '';
  campaignName = '';

  

  // used for selecting multiple records
  batchSize = null;


  // dynamically build the multiple record selector
  get batchSelectOption() {
    let i = 0;
    let groupCount = 5;
    let options = [];
    let groups = parseInt(this.totalAttendees / 5);
    options.push({label:'All',value:'all'});
    options.push({label:'Unassigned',value:'allUnassigned'});
    while(i < groups){
      let tempLabel = groupCount.toString();
      let tempValue = groupCount.toString();
      options.push({label:tempLabel,value:tempValue});
      i++;
      groupCount = groupCount + 5;
      console.log('tempLabel --> ' + tempLabel);
      console.log('tempValue --> ' + tempValue);

    }
    return options;
  }


  // update the selected items when using the multiple record selector
  handleBatchSizeChange(event) {
    console.log('handle batch');
    this.batchSize = event.detail.value;
    console.log(this.batchSize);
    let i = 0;
    let tempData = this.memberListData;
    let tempList = []
    this.memberListData = [];
    for (i; i < tempData.length; i++) {
      let tempRecord = tempData[i];
      let tempRecordKey = tempRecord.memberId;
      if(this.batchSize == 'allUnassigned'){
        if(tempRecord.advisor == null){
          tempList.push(tempRecordKey);
        }
      }
      else if(this.batchSize == 'all'){
        tempList.push(tempRecordKey);
      }
      else if(i < Number(this.batchSize)){
        tempList.push(tempRecordKey);
          }
          this.memberListData.push(tempRecord);

        }
      this.preSelectedRows = tempList;
      this.selectedRows = tempList;
    }
      
  
  // count of total campaign members returned
  get totalAttendees(){
    return this.memberListData.length;
  }

  // count of campaign members with an advisor
  get countAttendeesWithAdvisor(){
    let cnt = 0;
    let i = 0;
    for (i; i < this.memberListData.length; i++) {
      let tempRecord = this.memberListData[i];
      if(tempRecord.advisor != null){
        cnt = cnt + 1;
      } 
    }
    return cnt;
  }

  // count of campaign members wihtout an advisor
  get countAttendeesWithoutAdvisor(){
    let cnt = 0;
    let i = 0;
    for (i; i < this.memberListData.length; i++) {
      let tempRecord = this.memberListData[i];
      if(tempRecord.advisor == null){
        cnt = cnt + 1;
      } 
    }
    return cnt;
  }

  // percent of campaign members with an advisor
  get percentAttendeesWithAdvisor(){
    return (this.countAttendeesWithAdvisor / this.totalAttendees) * 100;
  }

  // count of campaign members with the default processed status
  get countAttendeesProcessed(){
    let cnt = 0;
    let i = 0;
    for (i; i < this.memberListData.length; i++) {
      let tempRecord = this.memberListData[i];
      if(tempRecord.memberStatus === this.processedMemberStatus){
        cnt = cnt + 1;
      } 
    }
    return cnt;
  }

  // count of campaign members without the default processed status
  get countAttendeesToProcess(){
    let cnt = 0;
    let i = 0;
    for (i; i < this.memberListData.length; i++) {
      let tempRecord = this.memberListData[i];
      if(tempRecord.memberStatus !== this.processedMemberStatus){
        cnt = cnt + 1;
      } 
    }
    return cnt;
  }


  // percent of campaign members that have been processed with the default status
  get percentAttendeesProcessed(){
    return (this.countAttendeesProcessed / this.totalAttendees) * 100;
  }

  
  // dynamically set the name of the card baed on the campaignName
  get attendeeCardTitle(){
    if(this.campaignName === ''){
      return '';
    } else{
      return `Attendees for: ${this.campaignName}`
    }
  }

  get attendeeCardTitleLink(){
    if(this.campaignId === ''){
      return '';
    } else{
      return "/lightning/r/Campaign/" +  this.campaignId + "/view";
    }
  }

  // dynamically display help text for the Status Update button
  get massUpdateHelpText() {
    if(this.countAttendeesToProcess === 0){
      return `There are no attendees needing a status update.`;
    } else if (this.countAttendeesToProcess === 1){
      return `Update the ${this.countAttendeesToProcess} attendee status to ${this.processedMemberStatus}. This will not change advisor assignments.`;
    } else {
      return `Update the ${this.countAttendeesToProcess} attendees' statuses to ${this.processedMemberStatus}. This will not change advisor assignments.`;
    }
  }

  // dynamically display help text for the Assign Advisor button
  get advisorAssignmentHelpText() {
    if(this.advisorName === ''){
      return `Please choose an advisor before selecting students to assign.`
    } else {
      if(this.countSelectedRows === 0) {
        return `Please select at least 1 attendee in order to make advisor assignments for ${this.advisorName}.`;
      } else if (this.countSelectedRows === 1){
        return `Assign the ${this.countSelectedRows} selected attendee to ${this.advisorName}. This will not change the attendee Status.`;
      } else {
        return `Assign the ${this.countSelectedRows} selected attendees to ${this.advisorName}. This will not change the attendee Status.`;
      }
    }
  }

  
  // dynamically get the count of selected rows
  get countSelectedRows(){
    return this.selectedRows.length;
  }
  
  // dynmically build the text for pill
  get selectedPillText(){
    return `${this.countSelectedRows} selected`
  }
    


    
  // enable spinner when performing work
  enableSpinner(){
    this.loadSpinner = true;
  }

  // disable spinner when work is complete
  disableSpinner(){
    this.loadSpinner = false;
  }

  // remove the advisor pill when removing the campaignId
  removePill(className){
      let element = this.template.querySelector('[class="' + className + '"]');
      element.removeItem();
  }

  // when a campaign is selected, query for related campaign members and update the data table
  handleCampaignIdChange(event){
    this.enableSpinner();
    this.clearSelectedRows()
    this.memberListData = [];
    this.hideMemberSearch = true;
    let tempId = event.detail.Id;
    let tempName = event.detail.Name;
    if(tempId.length === 15 || tempId.length === 18){
      this.campaignId = tempId;
      this.campaignName = tempName;
      this.hideMemberSearch = false;
      this.getProcessedMemberStatus();
      this.getRelatedMembers();
    } else {
      this.campaignId = '';
      this.hideMemberSearch = true;
      this.memberListData = [];
      // this.hideAdvisor = true;
      this.advisorId = '';
      this.removePill('advisor-search');
    }
    this.disableSpinner();

  }

  // when an advisir is selected, query for a user and update variables
  handleAdvisorIdChange(event){
    this.enableSpinner();
    // this.hideAdvisor = true;
    let tempId = event.detail.Id;
    let tempName = event.detail.Name;
    if(tempId.length === 15 || tempId.length === 18){
      this.advisorId = tempId;
      this.advisorName = tempName;
    } else {
      this.advisorId = '';
      this.advisorName = '';
    }
    this.disableSpinner();
  }

  // get or create the default campaign member status
  getProcessedMemberStatus(){
    getProcessedMemberStatus({inCampaignId : this.campaignId})
    .then((result)=> {
      console.log('result --> ' + result);
      this.processedMemberStatus = result;
    })
    .catch((error)=>{
      console.log('error --> ' + error);
      this.processedMemberStatus = undefined;

    });
  }


    
  // get related campaign members
  getRelatedMembers(){
  this.enableSpinner();
  getCampaignMembers({ inCampaignId: this.campaignId })  
    .then((result) => { 
      console.log('memberlist result ' + JSON.stringify(result));
      if (result.length === 0) {  
            this.memberListData = [];
        } else {  
            this.memberListData = this.flattenRecords(result);
            console.log('memberlist result ' + JSON.stringify(result));
            //this.countAttendees();
        }  
        this.error = undefined;  
        this.batchSize = null;
        this.disableSpinner();
  })  
    .catch((error) => {  
      console.log('error --> ' + error);
    this.memberListData = undefined;
    this.disableSpinner();
  });  

  }

  // display durrent date
  get currentTime(){
    let currentDate = new Date();
    let hours = currentDate.getHours();
    let minutes = currentDate.getMinutes();
    let ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12;
    hours = hours ? hours : 12; // the hour '0' should be '12'
    minutes = minutes < 10 ? '0'+minutes : minutes;
    var strTime = hours + ':' + minutes + ' ' + ampm;
    console.log('strTime ==> ' + strTime);

    let currentTimeMessage = 'As of Today at ' + strTime;
    return currentTimeMessage
  }

  // flatten parent/child objects for use with data table
  // datatable cannot display nested objects
  // https://developer.salesforce.com/forums/?id=9060G0000005sRWQAY
  // https://salesforce.stackexchange.com/questions/287262/flatten-data-to-display-it-using-lightning-datatable-in-lwc
  flattenRecords(records) {
    let tempRecords = [];
    let i = 0;
    for (i; i < records.length; i++) {
      let tempRecord = {};
      let record = records[i];
      Object.keys(record).forEach(key => {
        tempRecord[key] = record[key];
      });
      let checkMajorUrl = CHECK_MAJOR_URL;
      let viewAdvisorMeetings = VIEW_ADVISOR_MEETINGS;
      let uNID = record.con.Student_ID_Number__c !== undefined? this.buildLeadingZeroUnid(record.con.Student_ID_Number__c):null;
      tempRecord["firstName"] = record.con.FirstName !== undefined?record.con.FirstName:null;
      tempRecord["lastName"] = record.con.LastName !== undefined?record.con.LastName:null;
      tempRecord["uNID"] = uNID;
      tempRecord["advisor"] = record.con.Advisor_Assigned__c !== undefined?record.con.Advisor_Assigned__r.Name:null;
      tempRecord["type"] = record.con.Orientation__c !== undefined?record.con.Orientation__c.split(' - ')[0]:null;
      tempRecord["memberStatus"] = record.member.Status !== undefined?record.member.Status:null;
      tempRecord["memberId"] = record.member.Id !== undefined?record.member.Id:null;
      // replace leading u with 0
      tempRecord["checkMajorUrl"] = uNID !== null ? checkMajorUrl +  uNID : checkMajorUrl;
      // tempRecord["RecordLink"] = this.checkAccess();
      tempRecord["viewAdvisorMeetings"] = uNID !== null ? viewAdvisorMeetings + uNID:viewAdvisorMeetings + '%20';
      tempRecord["RecordLink"] = "/lightning/r/CampaignMember/" + record.member.Id + "/view";
      tempRecord["ContactLink"] = "/lightning/r/Contact/" + record.con.Id + "/view";
      tempRecords.push(tempRecord);
    }
    return tempRecords;
  }

  // replace leading U with leading 0 in uNID
  buildLeadingZeroUnid(inUnid){
    let outUnid = '';
    if(inUnid !== undefined && inUnid !== '' && inUnid.length  === 8){
      inUnid = inUnid.toLowerCase();
      outUnid =  inUnid.replace('u','0');
    }
    return outUnid;
  }



  // call apex controller to update campaign member statuses for selected records
  updateCampaignMemberStatus(){
    this.enableSpinner();
    this.updateSelectedRows();
    let campaignMemberIds = [];
    if(this.countSelectedRows === 0){
      let title = 'Warning!';
      let message = 'You have not selected any rows to process.';
      let variant = 'warning';
      this.disableSpinner();
      this.showNotification(title,message,variant);
      return;
    }
    for (let i = 0; i < this.countSelectedRows; i++) {
      campaignMemberIds.push(this.selectedRows[i].member.Id);
    }
      updateStatus({inCampaignMemberIds : campaignMemberIds})
      .then(result => {
        let title = 'Success!';
        let message = '';
        let variant = 'success';
        let count = this.countSelectedRows;
        if(count > 1){
          message = count + ' records have been updated.';
        } else {
          message = count + ' record has been updated.'
        }
        this.getRelatedMembers()
        this.disableSpinner();
        this.showNotification(title,message,variant);
        })
      .catch(error => {
        console.error(JSON.stringify(error));
        this.error = error;
        let title = 'Error!';
        let message = 'An error occured. No records were processed. Error: ' + JSON.stringify(error);
        let variant = 'error';
        this.disableSpinner();
        this.showNotification(title,message,variant);
        });
  }

  // call apex controler to update advisor assignment for selected records
  assignAdvisor(){
    this.enableSpinner();
    this.updateSelectedRows();
    let contactIds = [];
    if(this.countSelectedRows === 0){
      let title = 'Warning!';
      let message = 'You have not selected any rows to process.';
      let variant = 'warning';
      this.disableSpinner();
      this.showNotification(title,message,variant);
      return;
    }
    for (let i = 0; i < this.countSelectedRows; i++) {
      contactIds.push(this.selectedRows[i].con.Id);
    }
      assignAdvisor({inAdvisorId : this.advisorId, inContactIds : contactIds})
      .then(result => {
        let title = 'Success!';
        let message = '';
        let variant = 'success';
        let count = this.countSelectedRows;
        if(count > 1){
          message = count + ' records have been assigned to ' + this.advisorName + '.';
        } else {
          message = count + ' record has been assigned to ' + this.advisorName + '.';
        }
        this.getRelatedMembers()
        this.disableSpinner();
        this.showNotification(title,message,variant);
        })
      .catch(error => {
        console.error(JSON.stringify(error));
        this.error = error;
        let title = 'Error!';
        let message = 'An error occured. No records were processed. Error: ' + JSON.stringify(error);
        let variant = 'error';
        this.disableSpinner();
        this.showNotification(title,message,variant);
        });

  }

  // refresh data table
  refreshList(){
    this.clearSelectedRows();
    this.getRelatedMembers();
  }

  // clear the selected rows 
  clearSelectedRows(){
    if(this.template.querySelector('lightning-datatable') !== null){
      console.log('enter clear');
      this.template.querySelector('lightning-datatable').selectedRows = [];
    }
    this.selectedRows = [];
    }

  // refresh selected rows
  updateSelectedRows(){
    if(this.template.querySelector('lightning-datatable') !== null){
      this.selectedRows = this.template.querySelector('lightning-datatable').getSelectedRows();
      console.log('this.selectedRows --> ' + this.selectedRows);
    } else {
      this.clearSelectedRows();
    }
  }

  // sort data table based on specific field
  updateColumnSorting(event){
    //https://jungleeforce.com/2019/08/17/lwc-lightning-datatable-sorting/        
    let fieldName = event.detail.fieldName;
    let sortDirection = event.detail.sortDirection;
    //assign the values
    this.sortBy = fieldName;
    this.sortDirection = sortDirection;
    //call the custom sort method.
    this.sortData(fieldName, sortDirection);
  }
  
  //This sorting logic here is very simple. This will be useful only for text or number field.
  // You will need to implement custom logic for handling different types of field.
  sortData(fieldName, sortDirection) {
    //https://jungleeforce.com/2019/08/17/lwc-lightning-datatable-sorting/
    let sortResult = Object.assign([], this.memberListData);
    this.memberListData = sortResult.sort(function(a,b){
      if(a[fieldName] < b[fieldName]){
        return sortDirection === 'asc' ? -1 : 1;
      }
      else if(a[fieldName] > b[fieldName]){
        return sortDirection === 'asc' ? 1 : -1;
      } else {
        return 0;
      }
    })
  }


  // display toast
  showNotification(title,message,variant) {
    const evt = new ShowToastEvent({
        title: title,
        message: message,
        variant: variant,
    });
    this.dispatchEvent(evt);
  }


}