public with sharing class GasRankingsCalculator {

    private static List<Decimal> gmatScores = new List<Decimal>();
    private static List<Decimal> greScores = new List<Decimal>();
    private static List<Decimal> empMonths = new List<Decimal>();
    private static List<Decimal> gpaScores = new List<Decimal>();


    public class Ranking{
        // number of applicants
        @AuraEnabled
        public Integer countApplicants;
        @AuraEnabled
        public Integer countOffers;
        @AuraEnabled
        public Integer countNewEntrants;
        @AuraEnabled
        public Integer countNewEntrantsWithGPA;
        @AuraEnabled
        public Decimal sumGpaNewEntrants;
        @AuraEnabled
        public Decimal avgGpaNewEntrants;
        @AuraEnabled
        public Decimal medianGpaNewEntrants;
        @AuraEnabled
        public Integer countNewEntrantsWithGmat;
        @AuraEnabled
        public Decimal avgGmatNewEntrants;
        @AuraEnabled
        public Decimal sumGmatNewEntrants;
        @AuraEnabled
        public Decimal medianGmatNewEntrants;
        @AuraEnabled
        public Integer countNewEntrantsWithGre;
        @AuraEnabled
        public Decimal avgGreNewEntrants;
        @AuraEnabled
        public Decimal sumGreNewEntrants;
        @AuraEnabled
        public Decimal medianGreNewEntrants;
        @AuraEnabled
        public Integer countNewEntrantsWithEmp;
        @AuraEnabled
        public Decimal avgMonthsEmpNewEntrants;
        @AuraEnabled
        public Decimal sumMonthsEmpNewEntrants;
        @AuraEnabled
        public Decimal medianMonthsEmpNewEntrants;
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
        public List<Graduate_Application_Summary__c> recordsToProcess;

        public Ranking(){
            countApplicants = 0;
            countOffers = 0;
            countNewEntrants = 0;
            countNewEntrantsWithGPA = 0;
            sumGpaNewEntrants = 0;
            avgGpaNewEntrants = 0;
            medianGpaNewEntrants = 0;
            countNewEntrantsWithGmat = 0;
            avgGmatNewEntrants = 0;
            sumGmatNewEntrants = 0;
            medianGmatNewEntrants = 0;
            countNewEntrantsWithGre = 0;
            avgGreNewEntrants = 0;
            sumGreNewEntrants = 0;
            medianGreNewEntrants = 0;
            countNewEntrantsWithEmp = 0;
            avgMonthsEmpNewEntrants = 0;
            sumMonthsEmpNewEntrants = 0;
            medianMonthsEmpNewEntrants = 0;
            recordsToProcess = new List<Graduate_Application_Summary__c>();
        }
    }

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
                    gpaScores.add(g.Undergraduate_GPA__c);
                }
                // for calculating gmat
                if((g.Standardized_Test_Type__c == 'GMAT' || g.Standardized_Test_Type__c == 'GRE-GMAT Converted') && g.Standardized_Test_Score__c != null && g.Standardized_Test_Score__c > 0){
                    ranking.sumGmatNewEntrants += g.Standardized_Test_Score__c;
                    ranking.countNewEntrantsWithGMAT ++;
                    gmatScores.add(g.Standardized_Test_Score__c);
                }
                // for calculating gre
                if((g.Standardized_Test_Type__c == 'GRE') && g.Standardized_Test_Score__c != null && g.Standardized_Test_Score__c > 0){
                    ranking.sumGreNewEntrants += g.Standardized_Test_Score__c;
                    ranking.countNewEntrantsWithGre ++;
                    greScores.add(g.Standardized_Test_Score__c);
                }

                // for calculating employment
                if((g.Months_of_Professional_Experience__c != null && g.Months_of_Professional_Experience__c > 0)){
                    ranking.sumMonthsEmpNewEntrants += g.Months_of_Professional_Experience__c;
                    ranking.countNewEntrantsWithEmp ++;
                    empMonths.add(g.Months_of_Professional_Experience__c);
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

        ranking.avgGpaNewEntrants = calculateAverage(ranking.sumGpaNewEntrants, ranking.countNewEntrantsWithGPA);
        ranking.medianGpaNewEntrants = calculateMedian(gpaScores);
        system.debug('');
        system.debug('<<<<<<<<<< GPA Calculations >>>>>>>>>>');
        system.debug('# New Entrants with GPA --> ' + ranking.countNewEntrantsWithGPA);
        system.debug('Summed GPA for New Entrants --> ' + ranking.sumGpaNewEntrants);
        system.debug('AVG GPA of New Entrants --> ' + ranking.avgGpaNewEntrants);   


        // avg
        ranking.avgGmatNewEntrants = calculateAverage(ranking.sumGmatNewEntrants, ranking.countNewEntrantsWithGMAT);
        // median
        ranking.medianGmatNewEntrants = calculateMedian(gmatScores);
        system.debug('');
        system.debug('<<<<<<<<<< GMAT Calculations >>>>>>>>>>');
        system.debug('# New Entrants with GMAT --> ' + ranking.countNewEntrantsWithGMAT);
        system.debug('Summed GMAT for New Entrants --> ' + ranking.sumGmatNewEntrants);
        system.debug('AVG GMAT of New Entrants --> ' + ranking.avgGmatNewEntrants);
        system.debug('Median GMAT of New Entrants --> ' + ranking.medianGmatNewEntrants);


        // avg
        ranking.avgGreNewEntrants = calculateAverage(ranking.sumGreNewEntrants, ranking.countNewEntrantsWithGre);
        // median
        ranking.medianGreNewEntrants = calculateMedian(greScores);
        system.debug('');
        system.debug('<<<<<<<<<< GRE Calculations >>>>>>>>>>');
        system.debug('# New Entrants with GRE --> ' + ranking.countNewEntrantsWithGre);
        system.debug('Summed GRE for New Entrants --> ' + ranking.sumGreNewEntrants);
        system.debug('AVG GRE of New Entrants --> ' + ranking.avgGreNewEntrants);
        system.debug('Median GRE of New Entrants --> ' + ranking.medianGreNewEntrants);


        // avg
        ranking.avgMonthsEmpNewEntrants = calculateAverage(ranking.sumMonthsEmpNewEntrants, ranking.countNewEntrantsWithEmp);
        // median
        ranking.medianMonthsEmpNewEntrants = calculateMedian(empMonths);
        system.debug('');
        system.debug('<<<<<<<<<< EMP Calculations >>>>>>>>>>');
        system.debug('# New Entrants with EMP --> ' + ranking.countNewEntrantsWithEmp);
        system.debug('Summed EMP for New Entrants --> ' + ranking.sumMonthsEmpNewEntrants);
        system.debug('AVG EMP of New Entrants --> ' + ranking.avgMonthsEmpNewEntrants);
        system.debug('Median EMP of New Entrants --> ' + ranking.medianMonthsEmpNewEntrants);

        return ranking;
    }

    private static List<Graduate_Application_Summary__c> getGasRecords(List<String> terms, List<String> programs, List<String> recordTypes){
        // build query
        String selectString = 'SELECT Id,Application_Program__c,Applicant_uNID__c, Name, Months_of_Professional_Experience__c, (SELECT Id FROM Applications_Graduate__r), Standardized_Test_Type__c, Standardized_Test_Score__c, Term_Application_Completed__c, Term_Offered_Admission__c, Term_Deferred_Admission__c,Term_Matriculated__c, Undergraduate_GPA__c';
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

    private static Decimal calculateAverage(Decimal inputSum, Integer inputCount){
        Decimal calculatedAverage = 0;
        if(inputSum != 00 && inputCount != 0){
            calculatedAverage = (inputSum / inputCount).setScale(3,System.RoundingMode.HALF_UP);
        }
        return calculatedAverage;
    }

    private static Decimal calculateMedian(List<Decimal> inputValues){
        if(inputValues.size() == 0){
            return null;
        }
    
        Integer sizeOfList = inputValues.size();
        system.debug('size of list is '+ sizeOfList);
        Integer index = sizeOfList - 1;
        system.debug('the index is '+index);
        Decimal median = 0.0;

        // sort the list first
        inputValues.sort();

        //Calculate median
        if (Math.mod(sizeOfList, 2) == 0) {
            median = (inputValues[(index-1)/2] + inputValues[(index/2)+1])/2;
        }else{
            median = inputValues[(index+1)/2];
        }

        system.debug('the median is: '+median);
        return median;
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
