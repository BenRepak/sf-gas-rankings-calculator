    public static List<Decimal> gmatScores = new List<Decimal>();
    public static List<Decimal> greScores = new List<Decimal>();
    public static List<Decimal> empMonthsIncluding0 = new List<Decimal>();
    public static List<Decimal> empMonthsExcluding0 = new List<Decimal>();
    public static List<Decimal> gpaScores = new List<Decimal>();

    String program = 'MSF';
    String year = '2021';
    String type = 'tfe';

    processRankings(program,year,type);


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

            for(Application_Graduate__c ag : g.applications_graduate__r){
                if(ag.Excluded_from_Reports_Flag__c == true){
                    toSkip.add(g.id);
                    continue;
                }
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
                // TODO - ask bethany if shoulds 0s be counted for avg, count, and median?
                // if((g.Months_of_Professional_Experience__c != null && g.Months_of_Professional_Experience__c > 0)){
                if((g.Months_of_Professional_Experience__c != null )){
                    ranking.sumMonthsEmpNewEntrants += g.Months_of_Professional_Experience__c;
                    ranking.countNewEntrantsWithEmp ++;
                    if(g.Months_of_Professional_Experience__c >= 0 ){
                        empMonthsIncluding0.add(g.Months_of_Professional_Experience__c);
                    } 
                    if(g.Months_of_Professional_Experience__c > 0 ){
                        empMonthsExcluding0.add(g.Months_of_Professional_Experience__c);
                    } 
                }
            }
        }

        system.debug('<<<<<<<<<< Program >>>>>>>>>>');
        system.debug(ranking.desiredPrograms);

        system.debug('');
        system.debug('<<<<<<<<<< Ranking Type >>>>>>>>>>');
        system.debug(ranking.rankingType);



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

        ranking.avgGpaNewEntrants = calculateAverage(gpaScores);
        ranking.medianGpaNewEntrants = calculateMedian(gpaScores);
        system.debug('');
        system.debug('<<<<<<<<<< GPA Calculations >>>>>>>>>>');
        system.debug('# New Entrants with GPA --> ' + ranking.countNewEntrantsWithGPA);
        // system.debug('Summed GPA for New Entrants --> ' + ranking.sumGpaNewEntrants);
        system.debug('AVG GPA of New Entrants --> ' + ranking.avgGpaNewEntrants);   
        system.debug('Median GPA of New Entrants --> ' + ranking.medianGpaNewEntrants);


        // avg
        ranking.avgGmatNewEntrants = calculateAverage(gmatScores);
        // median
        ranking.medianGmatNewEntrants = calculateMedian(gmatScores);
        system.debug('');
        system.debug('<<<<<<<<<< GMAT Calculations >>>>>>>>>>');
        system.debug('# New Entrants with GMAT --> ' + ranking.countNewEntrantsWithGMAT);
        // system.debug('Summed GMAT for New Entrants --> ' + ranking.sumGmatNewEntrants);
        system.debug('AVG GMAT of New Entrants --> ' + ranking.avgGmatNewEntrants);
        system.debug('Median GMAT of New Entrants --> ' + ranking.medianGmatNewEntrants);


        // avg
        ranking.avgGreNewEntrants = calculateAverage(greScores);
        // median
        ranking.medianGreNewEntrants = calculateMedian(greScores);
        system.debug('');
        system.debug('<<<<<<<<<< GRE Calculations >>>>>>>>>>');
        system.debug('# New Entrants with GRE --> ' + ranking.countNewEntrantsWithGre);
        // system.debug('Summed GRE for New Entrants --> ' + ranking.sumGreNewEntrants);
        system.debug('AVG GRE of New Entrants --> ' + ranking.avgGreNewEntrants);
        system.debug('Median GRE of New Entrants --> ' + ranking.medianGreNewEntrants);


        // avg
        // ranking.avgMonthsEmpNewEntrants = calculateAverage(ranking.sumMonthsEmpNewEntrants, ranking.countNewEntrantsWithEmp);
        // median
        //ranking.medianMonthsEmpNewEntrants = calculateMedian(empMonths);
        system.debug('');
        system.debug('<<<<<<<<<< EMP Calculations (Including 0 reported months) >>>>>>>>>>');
        system.debug('# New Entrants with EMP (Including 0 reported months) --> ' + empMonthsIncluding0.size());
        system.debug('AVG EMP of New Entrants (Including 0 reported months) --> ' + calculateAverage(empMonthsIncluding0));
        system.debug('Median EMP of New Entrants (Including 0 reported months) --> ' + calculateMedian(empMonthsIncluding0));
    
        system.debug('');
        system.debug('<<<<<<<<<< EMP Calculations (Excluding 0 reported months) >>>>>>>>>>');
        system.debug('# New Entrants with EMP (Excluding 0 reported months) --> ' + empMonthsExcluding0.size());
        system.debug('AVG EMP of New Entrants (Excluding 0 reported months) --> ' + calculateAverage(empMonthsExcluding0));
        system.debug('Median EMP of New Entrants (Excluding 0 reported months) --> ' + calculateMedian(empMonthsExcluding0));

        String csvString = buildCsv(ranking.recordsToProcess);
        String emailBody = '';

        emailBody += '<<<<<<<<<< Program >>>>>>>>>>\n';
        emailBody += program;

        emailBody += '\n\n';
        emailBody += '<<<<<<<<<< Term(s) >>>>>>>>>>\n';
        emailBody += ranking.desiredTerms;

        emailBody += '\n\n';
        emailBody += '<<<<<<<<<< Application Counts >>>>>>>>>>\n';
        emailBody += 'Number of Applicants: ' + ranking.countApplicants + '\n';
        emailBody += 'Number of Offers of Admission: ' + ranking.countOffers + '\n';
        emailBody += 'Number of New Entrants: ' + ranking.countNewEntrants + '\n';

        emailBody += '\n\n';
        emailBody += '<<<<<<<<<< GPA Calculations >>>>>>>>>>\n';
        emailBody += '# New Entrants with GPA: ' + ranking.countNewEntrantsWithGPA+ '\n';
        emailBody += 'AVG GPA of New Entrants: ' + ranking.avgGpaNewEntrants+ '\n';
        emailBody += 'Median GPA of New Entrants: ' + ranking.medianGpaNewEntrants+ '\n';

        emailBody += '\n\n';
        emailBody += '<<<<<<<<<< GMAT Calculations >>>>>>>>>>\n';
        emailBody += '# New Entrants with GMAT: ' + ranking.countNewEntrantsWithGMAT+ '\n';
        emailBody += 'AVG GMAT of New Entrants: ' + ranking.avgGmatNewEntrants+ '\n';
        emailBody += 'Median GMAT of New Entrants: ' + ranking.medianGmatNewEntrants+ '\n';

        emailBody += '\n\n';
        emailBody += '<<<<<<<<<< GRE Calculations >>>>>>>>>>\n';
        emailBody += '# New Entrants with GRE: ' + ranking.countNewEntrantsWithGre+ '\n';
        emailBody += 'AVG GRE of New Entrants: ' + ranking.avgGreNewEntrants+ '\n';
        emailBody += 'Median GRE of New Entrants: ' + ranking.medianGreNewEntrants+ '\n';

        emailBody += '\n\n';
        emailBody += '<<<<<<<<<< Employment Calculations (Including 0 reported months) >>>>>>>>>>\n';
        emailBody += '# New Entrants with EMP: ' + empMonthsIncluding0.size()+ '\n';
        emailBody += 'AVG EMP of New Entrants: ' + calculateAverage(empMonthsIncluding0)+ '\n';
        emailBody += 'Median EMP of New Entrants: ' + calculateMedian(empMonthsIncluding0)+ '\n';

        emailBody += '\n\n';
        emailBody += '<<<<<<<<<< Employment Calculations (Excluding 0 reported months) >>>>>>>>>>\n';
        emailBody += '# New Entrants with EMP: ' + empMonthsExcluding0.size()+ '\n';
        emailBody += 'AVG EMP of New Entrants: ' + calculateAverage(empMonthsExcluding0)+ '\n';
        emailBody += 'Median EMP of New Entrants: ' + calculateMedian(empMonthsExcluding0)+ '\n';
    

        Messaging.SingleEmailMessage mail = buildEmail(csvString,emailBody,program, ranking.rankingType);

         try{
            // send the email
            system.debug('sending....');
            Messaging.sendEmail(new Messaging.Singleemailmessage [] {mail});
        }catch(Exception e){
            system.debug('exception --> ' + e);
        }


        return ranking;
    }

    public static List<Graduate_Application_Summary__c> getGasRecords(List<String> terms, List<String> programs, List<String> recordTypes){
        // build query
        String selectString = 'SELECT Id,Application_Program__c,Applicant_uNID__c, Name, Months_of_Professional_Experience__c, (SELECT Id, Excluded_from_Reports_Flag__c FROM Applications_Graduate__r), Standardized_Test_Type__c, Standardized_Test_Score__c, Term_Application_Completed__c, Term_Offered_Admission__c, Term_Deferred_Admission__c,Term_Matriculated__c, Undergraduate_GPA__c';
        String fromString = 'FROM Graduate_Application_Summary__c';
        String whereString = 'WHERE Excluded_from_Reports_Flag__c = False AND RecordType.Name IN :recordTypes AND Application_Program__c IN :programs AND (Term_Application_Completed__c IN :terms OR Term_Offered_Admission__c IN :terms OR Term_Deferred_Admission__c IN :terms OR Term_Matriculated__c IN :terms)';
        String queryString = selectString + ' ' + fromString + ' ' + whereString;
        return Database.query(queryString);
    }


    public static boolean isOffered(String rankingType, List<String> desiredTerms, Graduate_Application_Summary__c g) {
        Boolean isOffered = false;

        if(rankingType == 'TFE'){
            isOffered = isOfferedTfe(desiredTerms, g);
        } else if(rankingType == 'AACSB'){
            isOffered = isOfferedAacsb(desiredTerms, g);
        }
        return isOffered;
    }


    public static boolean isOfferedTfe(List<String> desiredTerms, Graduate_Application_Summary__c g){
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

    public static boolean isOfferedAacsb(List<String> desiredTerms, Graduate_Application_Summary__c g){
        Boolean isOffered = false;
        if(desiredTerms.contains(g.Term_Offered_Admission__c)){
            isOffered = true;
        } else if(string.isBlank(g.Term_Offered_Admission__c) && desiredTerms.contains(g.Term_Deferred_Admission__c)){
            isOffered = true;
        } 
        return isOffered;
    }

    public static Decimal calculateAverage(List<Decimal> numbersToAverage){
        Decimal calculatedAverage = 0;
        Integer size = 0;
        Decimal sum = 0;
        if(numbersToAverage.size() > 0){
            for(Decimal d : numbersToAverage){
                size ++;
                sum += d;
            }
        }

        if(size != 0 && sum != 0){
            calculatedAverage = (sum / size).setScale(3,System.RoundingMode.HALF_UP);
        }
        return calculatedAverage;
    }

    public static Decimal calculateMedian(List<Decimal> inputValues){
        if(inputValues.size() == 0){
            return null;
        }
    
        Integer sizeOfList = inputValues.size();
        // system.debug('size of list is '+ sizeOfList);
        Integer index = sizeOfList - 1;
        // system.debug('the index is '+index);
        Decimal median = 0.0;

        // sort the list first
        inputValues.sort();

        //Calculate median
        if (Math.mod(sizeOfList, 2) == 0) {
            median = (inputValues[(index-1)/2] + inputValues[(index/2)+1])/2;
        }else{
            median = inputValues[(index+1)/2];
        }

        return median.setScale(3,System.RoundingMode.HALF_UP);
    }


    public static String buildCsv(List<sObject> records){

        
        
        List<Map<String, Object>> csvValues = new List<Map<String, Object>>();
        Set<String> fieldNames = new Set<String>();
        for(sObject record: records) {
            //Map<String, Object> fieldValues = record.getPopulatedFieldsAsMap();
            Map<String, Object> fieldValues = new Map<String, Object>();

            // check for parent relationships 
            Map<String, Object> fieldsToValue = record.getPopulatedFieldsAsMap();
            for (String fieldName : fieldsToValue.keySet()){
                Object fieldValue = fieldsToValue.get(fieldName);
                // System.debug('field name is ' + fieldName + ', value is ' + fieldValue);
                String fieldValueType = getType(fieldValue);
                // system.debug('fieldType --> ' + fieldValueType);
                if(fieldValueType == 'SObject'){
                    // system.debug('object type --> '+ (SObject)fieldValue+'');

                   // for(String parentFieldName : )
                } else {
                    fieldValues.put(fieldName,fieldValue);
                }
            }

            csvValues.add(fieldValues);
            fieldNames.addAll(fieldValues.keySet());
        }
        String[] allData = new String[0];
        // Build header
        String[] tempRow = new String[0];
        for(String fieldName: fieldNames) {
            tempRow.add(fieldName.escapeCSV());
        }
        allData.add(String.join(tempRow,','));
        for(Map<String, Object> valuesFromRecord: csvValues) {
            tempRow.clear();
            for(String fieldName: fieldNames) {
                Object value = valuesFromRecord.get(fieldName);
                if(value == null) {
                    value = '';
                }
                tempRow.add((''+value).escapeCSV());
            }
            allData.add(String.join(tempRow,','));
        }
        String finalCsv = String.join(allData,'\n');
        allData.clear(); // free heap //
        return finalCsv;
        
    }

    // https://trailblazer.salesforce.com/ideaView?id=08730000000l9wHAAQ
    private static string getType(Object o) {
        if(o==null) return '';              // we can't say much about null with our current techniques
        if(o instanceof SObject)            return 'SObject'; 
        if(o instanceof Boolean)            return 'Boolean';
        if(o instanceof Id)                 return 'Id';
        if(o instanceof String)             return 'String';
        if(o instanceof Blob)               return 'Blob';
        if(o instanceof Date)               return 'Date';
        if(o instanceof Datetime)           return 'Datetime';
        if(o instanceof Time)               return 'Time';
        if(o instanceof String)             return 'String';
        if(o instanceof Integer)            return 'Integer';
        if(o instanceof Long)               return 'Long';
        if(o instanceof Decimal)            return 'Decimal';  // we can't distinguish between decimal and double
        if(o instanceof Double)             return 'Double';   // we can't distinguish between decimal and double
        if(o instanceof List<object>)       return 'List';
        return 'Object';                    // actually we can't detect maps and sets and maps
    }


    private static Messaging.SingleEmailMessage buildEmail(String csvString, String bodyString, String program, String rankingType){
        Date TODAY_DATE = system.today();
        String senderName = 'Eccles Salesforce Automated Process';
        String replyTo = 'Salesforce@eccles.utah.edu';
        List<String> usersToEmail = new String[]{'ben.repak@eccles.utah.edu','bethany.crowell@eccles.utah.edu'};
        String emailSubject = program + ' - ' + rankingType + ' -- GAS Ranking Summary' ;
        String emailBody = bodyString;


        // build an email and attach CSV if hasRecordsForCSV == true
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(usersToEmail);
        mail.setReplyTo(replyTo); //  email address
        mail.setSenderDisplayName(senderName);
        mail.setSubject(emailSubject);
        mail.setPlainTextBody(emailBody);
    
        Messaging.EmailFileAttachment csvAttc = new Messaging.EmailFileAttachment();
        blob csvBlob = Blob.valueOf(csvString);
        String stringDate = TODAY_DATE.year() + '-' + TODAY_DATE.month() + '-' + TODAY_DATE.day();
        string csvname = stringDate + ' - ' + emailSubject + '.csv';
        csvAttc.setFileName(csvname);
        csvAttc.setBody(csvBlob);
        mail.setFileAttachments(new Messaging.EmailFileAttachment[]{csvAttc});  
        return mail;
    }
