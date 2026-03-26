import { LightningElement, api, track } from 'lwc';
import searchRelatedContacts from '@salesforce/apex/GenericLookupController.searchRelatedContacts';
import getInitialRelatedContacts from '@salesforce/apex/GenericLookupController.getInitialRelatedContacts';


export default class GenericLookup extends LightningElement {
    @api objectApiName;
    @api parentObjectName;
    @api parentId;
    @api placeholder = 'Search...';
    @api displayFields = 'Name,Phone'; 
    @api searchField = 'Name';
    @track searchTerm = '';
    @track initialSuggestions = [];
    @track searchResults = [];
    @track showDropdown = false;
    @track showInitialSuggestions = false;
    @track showSearchResults = false;
    @api selectedRecord;
    ignoreNextClick = false;

    renderedCallback(){
        this.handleSearch();
        
    }

    connectedCallback() {
        
        if (this.selectedRecord) {
            this.searchTerm = this.selectedRecord.Name;

            const type = this.selectedRecord.Type
                || (this.objectApiName === 'Account' ? 'Account' : 'Contact');

            const cloned = {
                ...this.selectedRecord,
                iconName: type === 'Account' ? 'standard:account' : 'standard:contact'
            };
                
            this.selectedRecord = cloned;
            this.initialSuggestions = [cloned];
        }

        this._boundHandleClickOutside = this.handleClickOutside.bind(this);
        document.addEventListener('click', this._boundHandleClickOutside);
    }


    disconnectedCallback() {
        document.removeEventListener('click', this._boundHandleClickOutside);
    }

        handleClickOutside(event) {
        if (!this.template.contains(event.target)) {
            this.showDropdown = false;
            this.showInitialSuggestions = false;
            this.showSearchResults = false;
        }
    }


    // Get initial contacts on focus
    handleFocus() {
        this.ignoreNextClick = true;

        setTimeout(async () => {
            if (this.parentObjectName && this.parentId) {
                const results = await getInitialRelatedContacts({
                    parentObjectName: this.parentObjectName,
                    parentId: this.parentId
                });
                  // 🔧 Add icon dynamically
                this.initialSuggestions = results.map(rec => ({
                    ...rec,
                    iconName: rec.Type === 'Account' ? 'standard:account' : 'standard:contact'
                }));
                //this.initialSuggestions = results;
                this.showDropdown = true;
                this.showInitialSuggestions = true;
                this.showSearchResults = false;

                // Allow outside clicks *after* this cycle
                setTimeout(() => {
                    this.ignoreNextClick = false;
                }, 0);
            }
        }, 0);

        
        
    }





    // Existing search logic (modified)
    async handleSearchInput(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length > 1) {
            try {
                const results = await searchRelatedContacts({
                    parentObjectName: this.parentObjectName,
                    parentId: this.parentId,
                    searchTerm: this.searchTerm
                });

                // Map results to include iconName
                this.searchResults = results.map(rec => ({
                    ...rec,
                    iconName: rec.Type === 'Account' ? 'standard:account' : 'standard:contact'
                }));
                // this.searchResults = results;
                this.showInitialSuggestions = false;
                this.showSearchResults = true;
                this.showDropdown = true;
            } catch (e) {
                this.searchResults = [];
                console.error('Error fetching search results:', e);
            }
        } else {
            this.handleFocus(); // Show initial suggestions again
        }
    }


//    handleSearchInput(event) {
//     this.searchTerm = event.target.value;
//     if (this.searchTerm.length > 1) {
//         if (this.parentObjectName === 'Account' || this.parentObjectName === 'Opportunity') {
//             searchRelatedContacts({
//                 parentObjectName: this.parentObjectName,
//                 parentId: this.parentId,
//                 searchTerm: this.searchTerm,
//                 displayFields: this.displayFields
//             }).then(results => {
//                 this.searchResults = results.map(r => ({
//                     ...r,
//                     displayLabel: this.displayFields.split(',').map(f => r[f.trim()]).join(' - ')
//                 }));
//                 this.noResults = this.searchResults.length === 0;
//                 this.showDropdown = true;
//             });
//         } else {
//         }
//     } else {
//         this.showDropdown = false;
//     }
//    }



    handleSelect(event) {
        const recordId = event.currentTarget.dataset.id;

        let allRecords = this.showInitialSuggestions ? this.initialSuggestions : this.searchResults;
        this.selectedRecord = allRecords.find(r => r.Id === recordId);
        this.searchTerm = this.selectedRecord.Name;

        this.showDropdown = false;

        this.dispatchEvent(new CustomEvent('select', {
            detail: this.selectedRecord
        }));
    }


    get comboboxClass() {
        return this.showDropdown
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    clearSelection() {
    this.selectedRecord = null;
    this.searchTerm = '';
    this.handleFocus();
    this.showDropdown = true;
    this.showInitialSuggestions = true;
    this.showSearchResults = false;
    }


    handleSearch(){

        if (/ipad|iphone/i.test(navigator.userAgent)) {
            try{
                let searchIcon = this.template.querySelector('.search-icon');
                searchIcon.style.top = '12px';
            }catch(error){
			}
        }

        if (/iPhone/i.test(navigator.userAgent)) { 
            try{
                let headerSearch = this.template.querySelector('.header-search');
                if (headerSearch) {
                    headerSearch.style.setProperty('height', '40px', 'important');
                }

            }catch(error){
            }
        }

    }



}