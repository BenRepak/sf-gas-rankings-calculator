/*******************************************************************************************************
* @author Ben Repak
* @date 2021
*
* @description  a batchable class that can be scheduled. 
* Identifies Contacts who should have their Undergrad_Program_Status__c field updated based on values in their Major_Code__c field. 
* If contacts are found requiring updates, they will be added to a CSV and an email will be sent to email address in the UG_PROGRAM_UPDATER_NOTIFICATIONS custom label
*/


global with sharing class UndergradProgramStatusUpdaterBatch implements Database.Batchable<sobject>,Schedulable, Database.Stateful {
    @TestVisible
    private static final Set<String> GRAD_MAJOR_CODES = new Set<String>{'ACCTMAC','XMBAMBA','BUADMBA','OMBAMBA','BUADPHD','PMBAMBA','BUADMPL','BUANMS','BUCRMBC','FIN.MS','HADMMHA','IS..MS','REDVMRD'};
    @TestVisible
    private static final Set<String> MAJOR_CODES = new Set<String>{'ACCTBS','ACCTHBS','BUADBA','BUADBS','BUADHBS','ENTPBS','ENTPHBS','FIN.BS','FIN.HBS','IS..BS','IS..HBS','BUSIBA.I','MGT.BA','MGT.BS','MGT.HBS','MKTGBS','MKTGHBS','OM..BS','OM..HBS','QAMOBS','QAMOHBS','USBUBUS'};
    @TestVisible
    private static final Set<String> MINOR_CODES = new Set<String>{'AFA.MIN','BUSNMIN','ENTPMIN','IS..MIN','MGT.MIN','PSBDMIN'};
    @TestVisible
    private static final Set<String> PRE_MAJOR_CODES = new Set<String>{'BUSIBA.P','BUSIBS.P','QAMOBS.P'};
    @TestVisible
    private static final Set<String> USER_ASSIGNED_UG_PRG_STATUS = new Set<String>{'Leave of Absence','Pre Minor / Certificate'};
    private static final Date TODAY_DATE = system.today();
    private List<StudentProgramStatus> changedStatuses = new List<StudentProgramStatus>();

    /*******************************************************************************************************
    * @author Ben Repak
    * @date 2021
    *
    * @description  wrapper class used to build rows for CSV of changed records
    */
    private class StudentProgramStatus{
        String recordId;
        String name;
        String uNID;
        String previousStatus;
        String currentStatus;
        String majorCodes;
        String minorCodes;
        String advisorName;

        // constructor of wrapper class
        private StudentProgramStatus(Contact c, String previousStatus){
            this.recordId = c.Id;
            this.name = c.Name.escapeCSV();
            this.uNID = (c.student_id_number__c == null ? '' : c.student_id_number__c.escapeCSV());
            this.previousStatus = (previousStatus == null ? '' : previousStatus).escapeCSV();
            this.currentStatus = (c.undergrad_program_status__c == null ? '' : c.undergrad_program_status__c.escapeCSV());
            this.majorCodes = (c.major_codes__c == null ? '' : c.major_codes__c.escapeCSV());
            this.minorCodes = (c.minor_codes__c == null ? '' : c.minor_codes__c.escapeCSV());
            this.advisorname = (c.advisor_assigned__r.Name == null ? '' : c.advisor_assigned__r.Name.escapeCSV());
        }
    }

        
    /*******************************************************************************************************
    * @description batchable START method to query for contacts to review. 
    */
    global Database.Querylocator start(Database.BatchableContext bC) {
        String selectString = 'SELECT id, Student_Id_Number__c,Name, Undergrad_Program_Status__c, Major__c,Major_Codes__c,Minor_1__c,Minor_Codes__c,Advisor_Assigned__c, Advisor_Assigned__r.Name,Peoplesoft_Load_Date__c';
        String fromString = 'FROM Contact';
        String whereString = 'WHERE Peoplesoft_Load_Date__c != null OR Undergrad_Program_Status__c != null';
        String queryString = selectString + ' ' + fromString + ' ' + whereString;
       return Database.getQueryLocator(queryString);
    }
    
    /*******************************************************************************************************
    * @description batchable EXECUTE method to identify new undergrad program status for each record returned from start method
    */
    global void execute(Database.BatchableContext BC, List<sobject> scope) {
       List<Contact> contactsToUpdate = new List<Contact>();       
        for(sObject objScope: scope) {
            Contact c = (Contact)objScope;
            String initialUgPgrStatus = c.undergrad_program_status__c;
            Boolean hasPremajor = false;
            Boolean hasGrad = false;
            Boolean hasMajor = false;
            Boolean hasMinor = false;
            Boolean hasUserAssignedStatus = false;
            List<String> majorCodes; 
            List<String> minorCodes; 
                
            // check for major and premajor codes
            // set boolean flags as needed if contact contains any of the grad, major, or preminor codes
            if(c.Major_Codes__c != null){
                majorCodes = StringUtilities.splitAndTrimString(c.Major_Codes__c,',');
                for(String majorCode : majorCodes){
                    if(GRAD_MAJOR_CODES.contains(majorCode)){
                        hasGrad = true;
                    }
                    if(MAJOR_CODES.contains(majorCode)){
                        hasMajor = true;
                    }
                    if(PRE_MAJOR_CODES.contains(majorCode)){
                        hasPremajor = true;
                    }
                }
            }
            
            // check for minor codes
            // set boolean flag as needed if contact contains any of the minor codes
            if(c.Minor_codes__c != null){
                minorCodes = StringUtilities.splitAndTrimString(c.Minor_Codes__c,',');  
                for(String minorCode : minorCodes){
                    if(MINOR_CODES.contains(minorCode)){
                        hasMinor = true;
                    }
                }
            }
            
            // check for user assigned undergrad program status
            // set boolean flag as needed
            if(c.undergrad_program_status__c != null){
                if(USER_ASSIGNED_UG_PRG_STATUS.contains(c.undergrad_program_status__c)){
                    hasUserAssignedStatus = true;
                }
            }

            // set undergrad program status based on checks above
            if(hasGrad){ // grad declaration has highest prirority 
                c.undergrad_program_status__c = 'Declared Graduate Bus Major';
            }else if(hasMajor){ // major has next highest priority
                c.undergrad_program_status__c = 'Declared Undergrad Bus Major';
            } else if (hasMinor){
                c.undergrad_program_status__c = 'Declared Undergrad Bus Minor';
            } else if (hasPremajor){
                c.undergrad_program_status__c = 'Pre Business';
            } else if (hasUserAssignedStatus){ // don't change if user defined status and major or minor hasn't been set
                continue;
            } else {
            //  system.debug('nullIt');
                c.undergrad_program_status__c = null; // for non-user defined statuses where the major/minor has been removed
            }

            // only update the contact if the status has changed during this process
            if(initialUgPgrStatus != c.undergrad_program_status__c){
                StudentProgramStatus statusChange = new StudentProgramStatus(c,initialUgPgrStatus);
                changedStatuses.add(statusChange);
                contactsToUpdate.add(c); // Add records to the List
            }
       }
 
       // update contacts if there are any in the list 
        if (contactsToUpdate.size()>0) {
            Database.update(contactsToUpdate); 
       }
    }
     
        
    /*******************************************************************************************************
    * @description scheduleable EXECUTE method 
    */
    public void execute(SchedulableContext ctx){
        Database.executeBatch(this,50);
    } 
     
    /*******************************************************************************************************
    * @description batchable FINISH method
    */
    global void finish(Database.BatchableContext BC) {
        String documentationLink = 'https://sites.google.com/a/gcloud.utah.edu/salesforce-knowledge-base/program-specific/uas/undergrad-program-status';
        String senderName = 'Eccles Salesforce Automated Process';
        String replyTo = 'Salesforce@eccles.utah.edu';
        List<String> usersToEmail = System.Label.UG_PROGRAM_UPDATER_NOTIFICATIONS.split(',');
        String emailSubject = 'Batch Processing-Undergrad Program Status';
        String emailBody = '';
        Boolean hasRecordsForCSV = changedStatuses.size() > 0;
        Integer recordsToUpdate = changedStatuses.size();

        // get job ID for batch
        AsyncApexJob a = [Select a.TotalJobItems, a.Status, a.NumberOfErrors,
        a.JobType, a.JobItemsProcessed, a.ExtendedStatus, a.CreatedById,
        a.CompletedDate From AsyncApexJob a WHERE id = :BC.getJobId()];
        // get the job Id
       System.debug('$$$ Jobid is'+BC.getJobId());
        

        // create body and add job Id
        emailBody = 'The Batch Apex job (job id ' + a.id +') processed '+ a.TotalJobItems+' batches with '+a.NumberOfErrors+' failures.\n\n';
       
        // set email variables if there are records to process  
        if(hasRecordsForCSV){
            // update body if there are records to put in a CSV
            emailBody =  emailBody + 'A CSV with updated records is attached to this Email.\n\n';
        } else {
            // update body if there are no records to put in a CSV
            emailBody =  emailBody + 'No contact records have been identified for updates.\n\n';

        }

        // add link to documentation
        emailBody = emailBody + 'More information about this process can be found here: ' + documentationLink +'\n\n';
        // add info about how to get removed from email
        emailBody = emailBody + 'To report an error or to request removal from this email, please contact Salesforce@eccles.utah.edu.';


        // build an email and attach CSV if hasRecordsForCSV == true
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(usersToEmail);
        mail.setReplyTo(replyTo); //  email address
        mail.setSenderDisplayName(senderName);
        mail.setSubject(emailSubject + ': ' +a.Status);
        mail.setPlainTextBody(emailBody);
 
        if(hasRecordsForCSV){
            string header = 'Salesforce Record Id,Name,uNID,Previous Undergrad Program Status,Updated Undergrad Program Status,Student Major Codes, Student Minor Codes, Advisor Name \n';
            string finalstr = header ;
            for(StudentProgramStatus s: changedStatuses){
                string recordString = s.recordId+','+s.name+','+s.uNID+','+s.previousStatus+','+s.currentStatus+','+s.majorCodes+','+s.minorCodes+','+s.advisorName +'\n';
                finalstr = finalstr +recordString;
            }
    
            Messaging.EmailFileAttachment csvAttc = new Messaging.EmailFileAttachment();
            blob csvBlob = Blob.valueOf(finalstr);
            String stringDate = TODAY_DATE.year() + '-' + TODAY_DATE.month() + '-' + TODAY_DATE.day();
            string csvname= stringDate + ' Undergrad Program Status Changes.csv';
            csvAttc.setFileName(csvname);
            csvAttc.setBody(csvBlob);
            mail.setFileAttachments(new Messaging.EmailFileAttachment[]{csvAttc});  
        }

           
        try{
            // send the email
            Messaging.sendEmail(new Messaging.Singleemailmessage [] {mail});
        }catch(Exception e){
            system.debug('exception --> ' + e);
        }
      
    }
   
}