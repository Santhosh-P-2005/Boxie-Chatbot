import { LightningElement,api } from 'lwc';
export default class WhatsAppTemplateButtonCmp extends LightningElement {
	@api buttonData;
	@api indx;
	@api websitebutton; 
	@api phonebutton;
	actionTypes = [
		{
				label:'Call Phone Number',
				value:'Call Phone Number'
		},
		{
				label:'Visit website',
				value:'Visit website'
		}
		
	];
	get isCustomButtonType(){
		return this.buttonData.type == 'QUICK_REPLY';
	}
	get isPhoneButtonType(){
		return this.buttonData.type == 'PHONE_NUMBER';
	}
	
	get isUrlButtonType(){
		return this.buttonData.type == 'URL';
	}
	
	get isCopyCodeButtonType(){
		return this.buttonData.type == 'COPY_CODE';
	}

	renderedCallback() {
		this.handleHelpText();
	}

	handleButtonType(event) {
		const selectedLabel = event.detail.value;
		let selectedType;
		if (selectedLabel === 'Call Phone Number') {
			selectedType = 'PHONE_NUMBER';
			this.phonebutton ++;
			this.websitebutton --;
			this.dispatchEvent(new CustomEvent('phonebutton', {
			detail: {
				phoneNumberCount : this.phonebutton,
				websiteCount : this.websitebutton,
				indx: this.indx
			}
		}));
		} else if (selectedLabel === 'Visit website') {
			selectedType = 'URL';
			this.websitebutton ++;
			this.phonebutton --;
			this.dispatchEvent(new CustomEvent('websitebutton', {
			detail: {
				phoneNumberCount : this.phonebutton,
				websiteCount : this.websitebutton,
				indx: this.indx
			}
		}));
		} else {
			selectedType = 'QUICK_REPLY'; // fallback or default
		}

		// Clone current buttonData
		const data = JSON.parse(JSON.stringify(this.buttonData));
		data.type = selectedType;

		// Clean up unrelated fields
		if (selectedType === 'PHONE_NUMBER') {
			delete data.url;
		} else if (selectedType === 'URL') {
			delete data.phone_number;
		}

		// this.buttonData = data;

		// Fire update to parent
		this.dispatchEvent(new CustomEvent('buttondata', {
			detail: {
				buttonData: data,
				indx: this.indx
			}
		}));

	}
handleTextChange(event) {
		let data = JSON.parse(JSON.stringify(this.buttonData));
		data[event.target.dataset.name] = event.detail.value;
		this.buttonData = data;
    }
		
	handleOnBlur(){
		this.dispatchEvent(new CustomEvent('buttondata', {
			detail: {
				buttonData: this.buttonData,
				indx: this.indx
			}
		}));
	}

	handleCustomCloseButton(event){
		this.dispatchEvent(new CustomEvent('buttonclose', {
			detail: {
				indx: this.indx
			}
		}));
		
		
	}

	handleHelpText(){
		if (/ipad|iphone/i.test(navigator.userAgent)) {
			try{
				this.template.querySelector('.help-text-2').style.top = '-77px'
				// this.template.querySelector('.help-text').style.left = '85%'
			}catch(error){
			}
		}
	}

	
}