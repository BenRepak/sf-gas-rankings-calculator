import { LightningElement } from 'lwc';
import processRankings from '@salesforce/apex/GasRankingsCalculator.processRankings';



export default class GasRankingCalculator extends LightningElement {

    loadSpinner = false;

    selectedAcademicYear = '';

    get academicYear(){
        if(this.selectedAcademicYear === ''){
            this.selectedAcademicYear = new Date().getFullYear();
        }
        return this.selectedAcademicYear;
    } 

    rankingValue = 'tfe';
    programValue = '';

    rankingsDataRaw = [];

    showSummary = false;

    get totalApplicants() {
        return this.rankingsDataRaw.countApplicants;
    }

    get totalOffers() {
        return this.rankingsDataRaw.countOffers;
    }

    get totalNewEntrants() {
        return this.rankingsDataRaw.countNewEntrants;
    }

    get avgGmatNewEntrants() {
        return this.rankingsDataRaw.avgGmatNewEntrants;
    }

    get countNewEntrantsWithGPA() {
        return this.rankingsDataRaw.countNewEntrantsWithGPA;
    }

    get avgGpaNewEntrants() {
        return this.rankingsDataRaw.avgGpaNewEntrants;
    }

    get medianGpaNewEntrants() {
        return this.rankingsDataRaw.medianGpaNewEntrants;
    }

    get countNewEntrantsWithGmat() {
        return this.rankingsDataRaw.countNewEntrantsWithGmat;
    }

    get avgGmatNewEntrants() {
        return this.rankingsDataRaw.avgGmatNewEntrants;
    }

    get medianGmatNewEntrants() {
        return this.rankingsDataRaw.medianGmatNewEntrants;
    }

    get countNewEntrantsWithGre() {
        return this.rankingsDataRaw.countNewEntrantsWithGre;
    }

    get avgGreNewEntrants() {
        return this.rankingsDataRaw.avgGreNewEntrants;
    }

    get medianGreNewEntrants() {
        return this.rankingsDataRaw.medianGreNewEntrants;
    }

    get countNewEntrantsWithEmp() {
        return this.rankingsDataRaw.countNewEntrantsWithEmp;
    }

    get avgMonthsEmpNewEntrants() {
        return this.rankingsDataRaw.avgMonthsEmpNewEntrants;
    }

    get medianMonthsEmpNewEntrants() {
        return this.rankingsDataRaw.medianMonthsEmpNewEntrants;
    }









    get rankingOptions() {
        return [
            { label: 'TFE', value: 'tfe' },
            { label: 'AACSB', value: 'aacsb' },
        ];
    }

    get programOptions() {
        return [
            { label: 'EMBA', value: 'emba' },
            { label: 'FTMBA', value: 'ftmba' },
            { label: 'MBAO', value: 'mbao' },
            { label: 'PMBA', value: 'pmba' },
            { label: 'MACC', value: 'macc' },
            { label: 'MHA', value: 'mha' },
            { label: 'MRED', value: 'mred' },
            { label: 'MSBA', value: 'msba' },
            { label: 'MSCS', value: 'mscs' },
            { label: 'MSF', value: 'msf' },
            { label: 'MSIS', value: 'msis' },
        ];
    }

    handleRankingChange(event) {
        this.rankingValue = event.detail.value;
    }

    handleProgramChange(event) {
        this.programValue = event.detail.value;
    }

    handleYearChange(event) {
        this.selectedAcademicYear = event.detail.value;
    }


    calculate(){
        this.enableSpinner();
        this.showSummary = false;
        let isValid = false;
        isValid = this.validateRequiredFields('lightning-input');
        isValid = this.validateRequiredFields('lightning-combobox');
        if(isValid){
            this.getData();
        } else {
            this.disableSpinner();
        }


    }


    getData(){
        processRankings({ programs:this.programValue, academicYear : this.selectedAcademicYear, rankingType : this.rankingValue })  
            .then((result) => { 
                console.log('result ' + JSON.stringify(result));
                this.rankingsDataRaw = result;
                this.showSummary = true;
                this.error = undefined;  
                this.disableSpinner();
            })  
            .catch((error) => {  
                this.showSummary = false;
                console.log('error --> ' + JSON.stringify(error));
                this.disableSpinner();
            }); 
    }

    validateRequiredFields(fieldType) {
        const isInputsCorrect = [...this.template.querySelectorAll(fieldType)]
            .reduce((validSoFar, inputField) => {
                inputField.reportValidity();
                return validSoFar && inputField.checkValidity();
            }, true);
        if (isInputsCorrect) {
         //perform success logic
            return true;
        } else {
            return false;
        }
        

    }


      // enable spinner when performing work
  enableSpinner(){
    this.loadSpinner = true;
  }

  // disable spinner when work is complete
  disableSpinner(){
    this.loadSpinner = false;
  }
}