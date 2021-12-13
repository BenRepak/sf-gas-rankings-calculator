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

    get rankingOptions() {
        return [
            { label: 'TFE', value: 'tfe' },
            { label: 'AACSB', value: 'aacsb' },
        ];
    }

    get programOptions() {
        return [
            { label: 'MSBA', value: 'msba' },
            { label: 'MSF', value: 'msf' },
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
        processRankings({ programs:this.programValue, academicYear : this.selectedAcademicYear, rankingType : this.rankingValue })  
          .then((result) => { 
            console.log('result ' + JSON.stringify(result));
              this.error = undefined;  
              this.batchSize = null;
              this.disableSpinner();
        })  
          .catch((error) => {  
            console.log('error --> ' + error);
            this.disableSpinner();
        }); 
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