public with sharing class GasRankingsCalculator {

    public class Ranking{
        // number of applicants
        @AuraEnabled
        public Integer countApplicants = 0;

        // number of offers of admission
        @AuraEnabled
        public Integer countOffers = 0;

        // number of new entrants
        @AuraEnabled
        public Integer countNewEntrants = 0;

        // average gpa for new entrants
        @AuraEnabled
        public Integer countNewEntrantsWithGPA = 0;
        @AuraEnabled
        public Decimal sumGpaNewEntrants = 0;
        @AuraEnabled
        public Decimal avgGpaNewEntrants = 0;

        // average gmat for new entrants
        @AuraEnabled
        public Integer countNewEntrantsWithGmat = 0;
        @AuraEnabled
        public Decimal avgGmatNewEntrants = 0;
        @AuraEnabled
        public Decimal sumGmatNewEntrants = 0;

        @AuraEnabled
        public List<String> desiredPrograms;

        @AuraEnabled
        public List<String> desiredRecordTypes;

        @AuraEnabled
        public String desiredAcademicYear;

        @AuraEnabled
        public List<String> desiredTerms;

        @AuraEnabled
        public String rankingType;

        @AuraEnabled
        public List<Graduate_Application_Summary__c> recordsToProcess = new List<Graduate_Application_Summary__c>();
    }


    public GasRankingsCalculator() {
        


    }


    // TFE calculations

    @AuraEnabled
    public static Ranking processRankings(String programs, String academicYear, String rankingType) {

        Ranking ranking = new Ranking();
        ranking.desiredPrograms = programs.split(',');

        ranking.rankingType = rankingType;
        
        // need to including pending to account for the deferals 
        ranking.desiredRecordTypes = new List<String>{'Final Review Complete','Pending Final Review'};

        // build set of desired terms based on academic year
        ranking.desiredAcademicYear = academicYear;
        ranking.desiredTerms = new List<String>();
        ranking.desiredTerms.add('Spring ' + ranking.desiredAcademicYear);
        ranking.desiredTerms.add('Summer ' + ranking.desiredAcademicYear);
        ranking.desiredTerms.add('Fall ' + ranking.desiredAcademicYear);


        List<Graduate_Application_Summary__c> recordsToProcess = new List<Graduate_Application_Summary__c>();
        // execute query and loop results 

        Set<String> toSkip = new Set<String>();

        List<Graduate_Application_Summary__c> records = getGasRecords(ranking.desiredTerms,ranking.desiredPrograms,ranking.desiredRecordTypes);
        for(Graduate_Application_Summary__c g :records){ 
            
            // skip orphaned records
            if(g.applications_graduate__r.size() == 0){
                toSkip.add(g.id);
                continue;
            }
            
            /*
            * count of applicants
            */
            // counting anyone who has a term completed within the desired academic year
            if(ranking.desiredTerms.contains(g.Term_Application_Completed__c)){
                ranking.countApplicants ++;
                ranking.recordsToProcess.add(g);
            }
            
            /*
            * count of offers
            */
            Boolean isOffered = isOffered(ranking.rankingType,ranking.desiredTerms,g);
            if(isOffered == true){
                ranking.countOffers ++;
            }
            
            /*
            * count of matriculants
            */
            // counting anyone who has a term matriculated within the desired academic year
            if(ranking.desiredTerms.contains(g.Term_Matriculated__c)){
                ranking.countNewEntrants ++;
                // for calculating gpa
                if(g.Undergraduate_GPA__c != null && g.Undergraduate_GPA__c > 0){
                    ranking.sumGpaNewEntrants += g.Undergraduate_GPA__c;
                    ranking.countNewEntrantsWithGPA ++;
                }
                // for calculating gmat
                if((g.Standardized_Test_Type__c == 'GMAT' || g.Standardized_Test_Type__c == 'GRE-GMAT Converted') && g.Standardized_Test_Score__c != null && g.Standardized_Test_Score__c > 0){
                    ranking.sumGmatNewEntrants += g.Standardized_Test_Score__c;
                    ranking.countNewEntrantsWithGMAT ++;
                }

            }
            
            
        }

        system.debug('');
        system.debug('<<<<<<<<<< Program(s) >>>>>>>>>>');
        system.debug(ranking.desiredPrograms);

        system.debug('');
        system.debug('<<<<<<<<<< Term(s) >>>>>>>>>>');
        system.debug(ranking.desiredTerms);

        system.debug('');
        system.debug('<<<<<<<<<< Orphaned GAS Records >>>>>>>>>>');
        system.debug(toSkip);
        system.debug('');
        system.debug('<<<<<<<<<< COUNTS >>>>>>>>>>');
        system.debug('Number of Applicants --> ' + ranking.countApplicants);
        system.debug('Number of Offers of Admission --> ' + ranking.countOffers);
        system.debug('Number of New Entrants --> ' + ranking.countNewEntrants);


        // TODO how should this be rounded? 
        if(ranking.sumGpaNewEntrants != 00 && ranking.countNewEntrantsWithGPA != 0){
            ranking.avgGpaNewEntrants = (ranking.sumGpaNewEntrants / ranking.countNewEntrantsWithGPA).setScale(3);
        }
        system.debug('');
        system.debug('<<<<<<<<<< GPA Calculations >>>>>>>>>>');
        system.debug('# New Entrants with GPA --> ' + ranking.countNewEntrantsWithGPA);
        system.debug('Summed GPA for New Entrants --> ' + ranking.sumGpaNewEntrants);
        system.debug('AVG GPA of New Entrants --> ' + ranking.avgGpaNewEntrants);   



        // TODO how should this be rounded? 
        if(ranking.sumGmatNewEntrants != 00 && ranking.countNewEntrantsWithGMAT != 0){
            ranking.avgGmatNewEntrants = (ranking.sumGmatNewEntrants / ranking.countNewEntrantsWithGMAT).setScale(3);
        }
        system.debug('');
        system.debug('<<<<<<<<<< GMAT Calculations >>>>>>>>>>');
        system.debug('# New Entrants with GMAT --> ' + ranking.countNewEntrantsWithGMAT);
        system.debug('Summed GMAT for New Entrants --> ' + ranking.sumGmatNewEntrants);
        system.debug('AVG GMAT of New Entrants --> ' + ranking.avgGmatNewEntrants);

        return ranking;
    }


    private static List<Graduate_Application_Summary__c> getGasRecords(List<String> terms, List<String> programs, List<String> recordTypes){
        // build query
        String selectString = 'SELECT Id,Application_Program__c,Applicant_uNID__c, Name, (SELECT Id FROM Applications_Graduate__r), Standardized_Test_Type__c, Standardized_Test_Score__c, Term_Application_Completed__c, Term_Offered_Admission__c, Term_Deferred_Admission__c,Term_Matriculated__c, Undergraduate_GPA__c';
        String fromString = 'FROM Graduate_Application_Summary__c';
        String whereString = 'WHERE Excluded_from_Reports_Flag__c = False AND RecordType.Name IN :recordTypes AND Application_Program__c IN :programs AND (Term_Application_Completed__c IN :terms OR Term_Offered_Admission__c IN :terms OR Term_Deferred_Admission__c IN :terms OR Term_Matriculated__c IN :terms)';
        String queryString = selectString + ' ' + fromString + ' ' + whereString;
        return Database.query(queryString);
    }


    private static boolean isOffered(String rankingType, List<String> desiredTerms, Graduate_Application_Summary__c g) {
        Boolean isOffered = false;

        if(rankingType == 'TFE'){
            isOffered = isOfferedTfe(desiredTerms, g);
        } else if(rankingType == 'AACSB'){
            isOffered = isOfferedAacsb(desiredTerms, g);
        }
        return isOffered;
    }


    private static boolean isOfferedTfe(List<String> desiredTerms, Graduate_Application_Summary__c g){
        Boolean isOffered = false;
        if(desiredTerms.contains(g.Term_Offered_Admission__c) && string.isBlank(g.Term_Deferred_Admission__c)){
            isOffered = true;
        } else if(desiredTerms.contains(g.Term_Offered_Admission__c) && desiredTerms.contains(g.Term_Deferred_Admission__c)){
            isOffered = true;
        } else if (desiredTerms.contains(g.Term_Deferred_Admission__c)){
            isOffered = true;
        }

        return isOffered;
    }

    private static boolean isOfferedAacsb(List<String> desiredTerms, Graduate_Application_Summary__c g){
        Boolean isOffered = false;
        if(desiredTerms.contains(g.Term_Offered_Admission__c)){
            isOffered = true;
        } else if(string.isBlank(g.Term_Offered_Admission__c) && desiredTerms.contains(g.Term_Deferred_Admission__c)){
            isOffered = true;
        } 
        return isOffered;
    }






/*

        String senderName = 'Eccles Salesforce Automated Process';
        String replyTo = 'Salesforce@eccles.utah.edu';
		List<String> usersToEmail = new List<String>{'ben.repak@eccles.utah.edu'};
        String emailSubject = 'GAS Resulsts';
        String emailBody = '';
        Boolean hasRecordsForCSV = recordsToProcess.size() > 0;
        Integer recordsToUpdate = recordsToProcess.size();
		Date TODAY_DATE = System.Today();
        

        // create body and add job Id
        emailBody = 'Here is the data';
       
        // build an email and attach CSV if hasRecordsForCSV == true
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(usersToEmail);
        mail.setReplyTo(replyTo); //  email address
        mail.setSenderDisplayName(senderName);
        mail.setSubject(emailSubject);
        mail.setPlainTextBody(emailBody);
 
        if(hasRecordsForCSV){
            string header = 'Salesforce Record Id,Record Name,Program,Term Application Completed,uNID \n';
            string finalstr = header ;
            for(Graduate_Application_Summary__c g: recordsToProcess){
                string recordString = g.Id+','+g.Name+','+g.Application_Program__c + ','+g.Term_Application_Completed__c + ','+g.Applicant_uNID__c +'\n';
                finalstr = finalstr +recordString;
            }
    
            Messaging.EmailFileAttachment csvAttc = new Messaging.EmailFileAttachment();
            blob csvBlob = Blob.valueOf(finalstr);
            String stringDate = TODAY_DATE.year() + '-' + TODAY_DATE.month() + '-' + TODAY_DATE.day();
            string csvname= stringDate + ' GAS Data.csv';
            csvAttc.setFileName(csvname);
            csvAttc.setBody(csvBlob);
            mail.setFileAttachments(new Messaging.EmailFileAttachment[]{csvAttc});  
        }

           
        try{
            // send the email
            system.debug('try sending...');
            Messaging.sendEmail(new Messaging.Singleemailmessage [] {mail});
        }catch(Exception e){
            system.debug('exception --> ' + e);
        }

*/
}
