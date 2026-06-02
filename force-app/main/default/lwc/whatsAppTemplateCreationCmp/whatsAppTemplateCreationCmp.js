import { LightningElement, track, wire, api } from 'lwc';
	import getAllObject from '@salesforce/apex/WhatsAppTemplateCreationController.getAllObject';
	import getAllfields from '@salesforce/apex/WhatsAppTemplateCreationController.getAllfields';
	import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
	import WhatsAppIcon from '@salesforce/resourceUrl/WhatsAppIcon';
	import SmsIcon from '@salesforce/resourceUrl/SmsIcon';
	import save from '@salesforce/apex/WhatsAppTemplateCreationController.handleSave';
	import handleEdit from '@salesforce/apex/WhatsAppTemplateCreationController.handleEdit';
	import getActiveSettings from '@salesforce/apex/WhatsAppTemplateCreationController.getActiveSettings';
	// import getMetaAllObject from '@salesforce/apex/WhatsAppChatbotTemplateCreationCtlr.getAllObject';
	// import getMetaAllfields from '@salesforce/apex/WhatsAppChatbotTemplateCreationCtlr.getAllfields';
	// import metaSave from '@salesforce/apex/WhatsAppChatbotTemplateCreationCtlr.handleSave';
	// import metaHandleEdit from '@salesforce/apex/WhatsAppChatbotTemplateCreationCtlr.handleEdit';
	import getTwilioAllObject from '@salesforce/apex/TwilioWhatsAppTemplateController.getAllObject';
	import getTwilioAllFields from '@salesforce/apex/TwilioWhatsAppTemplateController.getAllFields';
	import createAndSaveTwilioContentTemplate from '@salesforce/apex/TwilioWhatsAppTemplateController.createAndSaveTwilioContentTemplate';
	import getActiveWhatsAppChannel from '@salesforce/apex/WhatsappChatComponentController.getActiveWhatsAppChannel';
	import { NavigationMixin } from 'lightning/navigation';
	import FORM_FACTOR from '@salesforce/client/formFactor'
	import { ShowToastEvent } from 'lightning/platformShowToastEvent';
	import { CloseActionScreenEvent } from 'lightning/actions';
	//import generateTemplateJSON from '@salesforce/apex/FlexTemplate.generateTemplateJSON';
	const fields = [
		'SmartMsg__Message_Template__c.SmartMsg__Template_Name__c',
		'SmartMsg__Message_Template__c.SmartMsg__Channel__c',
		'SmartMsg__Message_Template__c.SmartMsg__Body__c',
		'SmartMsg__Message_Template__c.SmartMsg__Header__c',
		'SmartMsg__Message_Template__c.SmartMsg__Footer__c',
		'SmartMsg__Message_Template__c.SmartMsg__Button__c',
		'SmartMsg__Message_Template__c.SmartMsg__WhatsApp_Template_ID__c'
	];

	const FILE_SIZE_LIMITS = {
		audio: 16 * 1024 * 1024,
		document: 5 * 1024 * 1024,
		image: 2 * 1024 * 1024,
		sticker: 100 * 1024,
		video: 2 * 1024 * 1024
	};

	const RESPONSE_TYPES = [
		{ label: 'Text only', value: 'text' },
		{ label: 'Quick Reply (buttons)', value: 'quick_reply' },
		{ label: 'List Picker (no description)', value: 'list_picker' },
		{ label: 'List Picker (with description)', value: 'list_picker_description' }
	];
	const QUICK_REPLY_MAX_OPTIONS = 3;
	const LIST_PICKER_MAX_OPTIONS = 10;

	export default class WhatsAppTemplateCreationCmp extends NavigationMixin(LightningElement) {
		channelOptions = [
			{ label: "SMS", value: "SMS" },
			{ label: "WhatsApp", value: "WhatsApp" }
		];
		headerOptions = [
			{ label: "None", value: "none" },
			{ label: "Text", value: "Text" },
			{ label: "Image", value: "Image" },
			{ label: "Video", value: "Video" },
			{ label: "Document", value: "Document" }
		];
		@api recordId;
		@track fileName;
		@track fileSizeWarning = '';
		@track objectOptions = [];
		@track fieldOptions = [];
		@track templateData = {
			header: 'none',
			channel: null,
			objectName: null,
			bodyText: '',
			footerText: '',
			headerText: '',
			buttons: [],
			headerMedia: {}
		};
		bodyVarCount = 1;
		showFieldPopup = false;
		isLoading = true;
		option = '';
		isManualTick = false;
		isMobile = false;
		isAITick = false;
		isSmsTick = false;
		isWhatsAppTick = false;
		whatsappIconUrl = WhatsAppIcon;
		smsIconUrl = SmsIcon;
		data = false;
		templateCreationMode = '';
		@track twilioTemplateName = '';
		@track twilioObjectName = null;
		@track twilioBodyText = '{{1}}';
		@track twilioResponseType = 'text';
		@track twilioOptions = [];
		twilioOptionId = 0;
		responseTypeOptions = RESPONSE_TYPES;
		get cardTitle() {
			if (this.recordId) {
				this.isManual = true;
			}
			if (this.recordId) return 'Edit Template';
			if (this.templateCreationMode === 'meta') return 'Create Meta WhatsApp Template';
			if (this.templateCreationMode === 'twilio') return 'Create Twilio WhatsApp Content Template';
			return 'Create Template';
		}
		// get showSmsOrMetaForm() {
		// 	return this.isManual && (this.templateCreationMode === 'sms' || this.templateCreationMode === 'meta' || (!this.templateCreationMode && this.recordId));
		// }
		// get showSmsForm() {
		// 	return this.isManual && (this.templateCreationMode === 'sms' || (this.recordId && this.templateData.channel === 'SMS'));
		// }
		getActiveStatus(){
			getActiveSettings()
			.then((data) => {
				this.activeSettingArray = data;
			// console.log('called method');
			if((data.whatsAppActive == true && data.sMSActive == true) || (data.twilioWhatsAppActive == true && data.sMSActive == true)){
				this.initialTemplate = true;
			}else if(data.whatsAppActive){
				this.showMetaForm = true;
				this.templateCreationMode = 'meta';
				this.templateData = { ...this.templateData, channel: 'WhatsApp' };
				this.isManual = true;
				this.fetchAllObjects();
			}else if(data.sMSActive){
				this.showSmsForm = true;
				this.templateCreationMode = 'sms';
				this.templateData = { ...this.templateData, channel: 'SMS' };
				this.isManual = true;
				this.limitMessage = true;
			}else if(data.twilioWhatsAppActive){
				this.showTwilioForm = true;
				this.templateCreationMode = 'twilio';
				this.isManual = false;
				this.initialTemplate = false;
				this.twilioTemplateName = '';
				this.twilioObjectName = null;
				this.twilioBodyText = '{{1}}';
				this.twilioResponseType = 'text';
				this.twilioOptions = [];
				this.fetchAllObjects();
			}
			// console.log('initialTemplate ',this.initialTemplate);
			//console.log('showMetaForm ',this.showMetaForm);
			// console.log('showSmsForm ',this.showSmsForm);
			// console.log('showTwilioForm ',this.showTwilioForm);
			})
			.catch((error) => {
				this.showToast('Error', 'Failed to fetch record', 'error');
			})
		}

		// get showMetaForm() {
		// 	console.log('this.templateCreationMode : '+this.templateCreationMode);
		// 	//return true;
		// 	//return this.isManual && (this.templateCreationMode === 'meta' || (this.recordId && this.templateData.channel === 'WhatsApp'));
		// 	getActiveSettings()
		// 	.then((data) => {
		// 	console.log('calledddddddddd method' + JSON.Stringify(data));
		// 	if((data.whatsAppActive == true && data.sMSActive == true) || (data.twilioWhatsAppActive == true && data.sMSActive == true)){
				
		// 		// this.initialTemplate = true;
		// 		// return this.initialTemplate;
		// 	}else if(data.whatsAppActive){
		// 		//this.showMetaForm = true;
		// 		return true;
		// 	}else if(data.sMSActive){
		// 		// this.showSmsForm = true;
		// 		// return this.showSmsForm;
		// 	}else if(data.twilioWhatsAppActive){
		// 		// this.showTwilioForm = true;
		// 		// return this.showTwilioForm;
		// 	}
		// 	console.log('initialTemplate ',this.initialTemplate);
		// 	//console.log('showMetaForm ',this.showMetaForm);
		// 	console.log('showSmsForm ',this.showSmsForm);
		// 	console.log('showTwilioForm ',this.showTwilioForm);
		// 	})
		// 	.catch((error) => {
		// 		console.log(JSON.stringify(error));
		// 		this.showToast('Error', 'Failed to fetch record', 'error');
		// 	})
		// 	return
		// }
		// get showTwilioForm() {
		// 	return this.templateCreationMode === 'twilio';
		// }
		// Never show; used to hide leftover markup from SMS form redesign.
		get showSmsFormRemoveHeaderBodyFooterButtons() {
			return false;
		}
		get showChannelCombo() {
			return this.templateCreationMode !== 'meta';
		}

		get isShowHeaderText() {
			return this.templateData.header === 'Text';
		}

		get isShowHeaderMedia() {
			return this.templateData.header === 'Image' || this.templateData.header === 'Video' || this.templateData.header === 'Document';
		}

		get headerHelpText() {
			const type = this.templateData.header;
			switch (type) {
				case 'Image':
					return 'Supported formats: JPG and PNG (Max size: 2MB). This file is for preview only. Include the actual image as a link when sending.';
				case 'Video':
					return 'Supported formats: MP4 and 3GPP (Max size: 2MB). This is a preview file. Provide the final video as a URL.';
				case 'Document':
					return 'Supported formats: PDF, DOC, DOCX, XLS, XLSX, TXT (Max size: 2MB). This document is for preview only. Use a URL to send the final version.';
				default:
					return '';
			}
		}


		get isShowButtons() {
			return this.templateData.buttons.length > 0;
		}

		get isWhatsApp() {
			return this.templateData.channel === 'WhatsApp';
		}

		get isShowQuickReply() {
			return this.templateData.buttons.some(button => button.type === "QUICK_REPLY");
		}

		get isShowCalltoAction() {
			const filteredArray = this.templateData.buttons.filter(button => button.isCallToAction == true);
			if (filteredArray.length > 0) {
				return true;
			} else {
				return false;
			}
		}
		// get quickActionLimit() {
		// 	let quickActionCount = 0;
		// 	for(let action of this.templateData.buttons){
		// 		if(action.isQuickReply){
		// 			quickActionCount++;
		// 		}
		// 	}
		// 	console.log(JSON.stringify(this.templateData.buttons))
		// 	if(quickActionCount <= 3){
		// 		return true;
		// 	}else{
		// 		return false;
		// 	}
		// }
		initialTemplate = false
		isManual = false
		isPrompt = false
		isUseAi = true;
		prompt = ''
		showMetaForm = false;
		showTwilioForm = false;
		showSmsForm = false;
		activeSettingArray = {};
		@wire(getRecord, { recordId: '$recordId', fields })
		wiredRecord({ error, data }) {
			if (data) {
				this.initialTemplate = false;
				this.isManual = true;
				this.isUseAi = false;
				this.populateTemplateData(data);
				// console.log('Wire method executed');
			} else if (error) {
				this.showToast('Error', 'Failed to fetch record', 'error');
			}
		}
		connectedCallback() {
			// console.log('Connected call back called')
			this.isLoading = true;
			this.setCSSProperties();
			this.fetchAllObjects();
			this.handleFormFactor();
			this.getActiveStatus();
			if (this.recordId) {
				this.retrieveTemplateDetails();
				this.isManual = true;
			} else {
				// this.initialTemplate = true;
				this.isManual = false;
			}
			// console.log('After initialTemplate --> ' + this.initialTemplate);
			this.isLoading = false;
			this.data = true;
			// console.log('this.data --> ',this.data)
			// console.log('/End of Connected call back')
			// console.log('Final initialTemplate ',this.initialTemplate);
			// console.log('Final showMetaForm ',this.showMetaForm);
			// console.log('Final showSmsForm ',this.showSmsForm);
			// console.log('Final showTwilioForm ',this.showTwilioForm);
		}
		
		
		get options() {
			return [
				{ label: 'Manual', value: 'Manual' },
				{ label: 'Using AI', value: 'Using AI' },
			];
		}
		get manualBoxClass() {
			return `slds-box box ${this.option === 'Manual' ? 'selected-box' : ''}`;
		}

		get aiBoxClass() {
			return `slds-box box ${this.option === 'AI' ? 'selected-box' : ''}`;
		}

		get smsBoxClass() {
			return `slds-box box ${this.option === 'SMS' ? 'selected-box' : ''}`;
		}

		get whatsAppBoxClass() {
			return `slds-box box ${this.option === 'WhatsApp' ? 'selected-box' : ''}`;
		}

		get manualBoxWrapperClass() {
			return `slds-grid slds-gutters icon-wrapper selectedClass ${this.isManualTick ? 'selected-border' : ''}`;
		}


		get aiBoxWrapperClass() {
			return `slds-grid slds-gutters icon-wrapper selectedClass ${this.isAITick ? 'selected-border' : ''}`;
		}

		get smsBoxWrapperClass() {
			return `slds-grid slds-gutters icon-wrapper selectedClass ${this.isSmsTick ? 'selected-border' : ''}`;
		}

		get whatsAppBoxWrapperClass() {
			return `slds-grid slds-gutters icon-wrapper selectedClass ${this.isWhatsAppTick ? 'selected-border' : ''}`;
		}

		handleFormFactor() {
			if (FORM_FACTOR === "Small") {
				this.isMobile = true;
			}
		}

		handleBoxClick(event) {
			this.option = event.currentTarget.dataset.label;
			if (this.option == 'Manual') {
				this.isManualTick = true;
				this.isAITick = false;
			}
			else if (this.option == 'AI') {
				this.isManualTick = false;
				this.isAITick = true;
			}
			else if (this.option == 'SMS') {
				this.templateCreationMode = 'sms';
				this.templateData = {
					header: 'none',
					channel: 'SMS',
					objectName: null,
					bodyText: '',
					footerText: '',
					headerText: '',
					buttons: [],
					headerMedia: {}
				};
				this.isManual = true;
				this.initialTemplate = false;
				this.limitMessage = true;
				this.isSmsTick = true;
				this.isWhatsAppTick = false;
				this.showSmsForm = true;
				this.showMetaForm = false;
				this.showTwilioForm = false;
			}
			else if (this.option == 'WhatsApp') {
				this.isSmsTick = false;
				this.isWhatsAppTick = true;
				this.showSmsForm = false;
				// console.log('activeSettingArray -> ', this.activeSettingArray);
				// console.log('whatsAppActive : ',this.activeSettingArray.whatsAppActive);
				
				if(this.activeSettingArray.twilioWhatsAppActive){
					
					this.templateCreationMode = 'twilio';
					this.showTwilioForm = true;
					this.isManual = false;
					this.initialTemplate = false;
					this.twilioTemplateName = '';
					this.twilioObjectName = null;
					this.twilioBodyText = '{{1}}';
					this.twilioResponseType = 'text';
					this.twilioOptions = [];
					this.fetchAllObjects();
				}else if(this.activeSettingArray.whatsAppActive){
					this.templateCreationMode = 'meta';
					this.showMetaForm = true;
					this.templateData = {
						header: 'none',
						channel: 'WhatsApp',
						objectName: null,
						bodyText: '',
						footerText: '',
						headerText: '',
						buttons: [],
						headerMedia: {}
					};
					this.isManual = true;
					this.initialTemplate = false;
					this.fetchAllObjects();
				}
			}
		}
		handleTemplateOption(event) {
			this.option = event.currentTarget.dataset.label;
			// console.log('Option ---> ' + this.option);
		}
		// handleOK() {
		// 	// console.log('handle OK button');
		// 	// console.log(this.option);
		// 	// console.log(this.option != null);
		// 	if (this.option == 'SMS') {
		// 		this.templateCreationMode = 'sms';
		// 		this.templateData = {
		// 			header: 'none',
		// 			channel: 'SMS',
		// 			objectName: null,
		// 			bodyText: '',
		// 			footerText: '',
		// 			headerText: '',
		// 			buttons: [],
		// 			headerMedia: {}
		// 		};
		// 		this.isManual = true;
		// 		this.initialTemplate = false;
		// 		this.limitMessage = true;
		// 	}
		// 	else if (this.option == 'WhatsApp') {
		// 		getActiveWhatsAppChannel()
		// 			.then((channel) => {
		// 				if (channel === 'Twilio WhatsApp') {
		// 					this.templateCreationMode = 'twilio';
		// 					this.isManual = false;
		// 					this.initialTemplate = false;
		// 					this.twilioTemplateName = '';
		// 					this.twilioObjectName = null;
		// 					this.twilioBodyText = '{{1}}';
		// 					this.twilioResponseType = 'text';
		// 					this.twilioOptions = [];
		// 					this.fetchAllObjects();
		// 				} else {
		// 					this.templateCreationMode = 'meta';
		// 					this.templateData = {
		// 						header: 'none',
		// 						channel: 'WhatsApp',
		// 						objectName: null,
		// 						bodyText: '',
		// 						footerText: '',
		// 						headerText: '',
		// 						buttons: [],
		// 						headerMedia: {}
		// 					};
		// 					this.isManual = true;
		// 					this.initialTemplate = false;
		// 					this.fetchAllObjects();
		// 				}
		// 			})
		// 			.catch((error) => {
		// 				this.showToast('Error', error?.body?.message || 'Unable to determine WhatsApp channel.', 'error');
		// 				this[NavigationMixin.Navigate]({
		// 					type: 'standard__objectPage',
		// 					attributes: {
		// 						objectApiName: 'SmartMsg__Message_Template__c',
		// 						actionName: 'list'
		// 					}
		// 				});
		// 			});
		// 	}
		// 	else if (this.option == 'Manual') {
		// 		this.templateData = {
		// 			header: 'none',
		// 			channel: null,
		// 			objectName: null,
		// 			bodyText: '',
		// 			footerText: '',
		// 			headerText: '',
		// 			buttons: [],
		// 			headerMedia: {}
		// 		};
		// 		this.isManual = true;
		// 		this.initialTemplate = false;
		// 	}
		// 	else if (this.option == 'AI') {
		// 		this.isManual = false;
		// 		this.initialTemplate = false;
		// 		this.isPrompt = true;
		// 	} else {
		// 		this.showToast('Choose one', 'Choose SMS or WhatsApp to create a template.', 'Warning');
		// 	}
		// }


		handleGenerate() {
			this.isPrompt = false;
			this.isLoading = true;
			generateTemplateJSON({ message: this.prompt, channel: this.templateData.channel, objectName: this.templateData.objectName })
				.then(response => {
					// console.log(JSON.stringify(response));
					this.templateData = {

						header: 'none',
						channel: null,
						objectName: null,
						bodyText: '',
						footerText: '',
						headerText: '',
						buttons: [],
						headerMedia: {}
					};
					this.templateData.templateName = response.templateName;
					this.templateData.channel = response.channel;
					this.templateData.bodyText = response.bodyText;
					this.templateData.footerText = response.footerText;
					this.templateData.headerText = response.headerText;
					this.templateData.header = "Text";
					this.templateData.headerMedia = response.channel == 'SMS' ? null : response.headerMedia;
					this.templateData.objectName = response.objectName;
					this.templateData.buttons = response.buttons;
					// console.log(JSON.stringify(this.templateData.headerMedia));

					this.isLoading = false;
					this.isManual = true;
				})
				.catch(error => {
					this.showToast('Time Out', error.body, 'Warning');
					this.isPrompt = true;
					this.isManual = false;
					this.isLoading = false;
				})
		}
		handlePrompt(event) {

			this.prompt = event.currentTarget.value;
			// console.log(this.prompt);
		}

		setCSSProperties() {
			const css = document.body.style;
			css.setProperty('--slds-c-card-spacing-block-start', '20px');
			css.setProperty('--slds-c-card-spacing-block-end', '20px');
			css.setProperty('--slds-c-card-spacing-inline-start', '20px');
			css.setProperty('--slds-c-card-spacing-inline-end', '20px');
			css.setProperty('--lwc-fontSize5', '20px');
		}

		fetchAllObjects() {
			const fetcher = this.templateCreationMode === 'meta' ? getAllObject()
				: this.templateCreationMode === 'twilio' ? getTwilioAllObject()
					: getAllObject();
			fetcher.then(data => {
				this.objectOptions = Object.keys(data).map(key => ({ label: key, value: data[key] }));
			}).catch(() => {
				this.showToast('Error', 'Failed to fetch objects', 'error');
			});
		}

		handleChange(event) {
			const { name } = event.target.dataset;
			// console.log('name --->', name);
			this.templateData[name] = event.detail.value;
			if (name === 'objectName') {
				this.fetchAllFields(event.detail.value);
			}
		}

		fetchAllFields(objectName) {
			const fetcher = this.templateCreationMode === 'meta' ? getAllfields({ objectName })
				: getAllfields({ objectName });
			fetcher.then(data => {
				this.fieldOptions = Object.keys(data).map(key => ({ label: key, value: data[key] }));
			}).catch(() => {
				this.showToast('Error', 'Failed to fetch fields', 'error');
			});
		}
		customButtonCount = 0;
		websiteButtonCount = 0;
		phoneNumberButtonCount = 0;
		websiteErrorMessage = '';
		handleButtonMenuSelect(event) {
			// console.log('Button called')
			if (event.detail.value == 'custom') {

				if (this.customButtonCount < 3) {
					this.customButtonCount++;
					this.templateData.buttons.push({
						id: 'btn-' + Date.now() + '-' + Math.random().toString(36).slice(2),
						type: "QUICK_REPLY",
						text: '',
						isQuickReply: true
					});
				} else {
					this.template.querySelector('.customBtn-error').style.display = 'flex';
				}

			} else if (event.detail.value == 'website') {
				if (this.websiteButtonCount < 1) {
					this.websiteButtonCount++;
					this.templateData.buttons.push({
						id: 'btn-' + Date.now() + '-' + Math.random().toString(36).slice(2),
						type: "URL",
						text: '',
						url: '',
						isCallToAction: true
					});
					if (this.phoneNumberButtonCount >= 1) {
						this.template.querySelector('.phoneBtn-error').style.display = 'none';
					}
				} else if (this.websiteButtonCount >= 1 && this.phoneNumberButtonCount < 1) {
					this.template.querySelector('.websiteBtn-error').style.display = 'flex';
				} else {
					this.template.querySelector('.allBtn-error').style.display = 'flex';
					this.template.querySelector('.websiteBtn-error').style.display = 'none';
					this.template.querySelector('.phoneBtn-error').style.display = 'none';
				}


			} else if (event.detail.value == 'phoneNumber') {
				if (this.phoneNumberButtonCount < 1) {
					this.phoneNumberButtonCount++;
					this.templateData.buttons.push({
						id: 'btn-' + Date.now() + '-' + Math.random().toString(36).slice(2),
						type: "PHONE_NUMBER",
						text: '',
						phone_number: '',
						isCallToAction: true
					});
					if (this.websiteButtonCount >= 1) {
						this.template.querySelector('.websiteBtn-error').style.display = 'none';
					}
				} else if (this.websiteButtonCount < 1 && this.phoneNumberButtonCount >= 1) {
					// console.log('Red')
					this.template.querySelector('.phoneBtn-error').style.display = 'flex';
				} else {
					this.template.querySelector('.allBtn-error').style.display = 'flex';
					this.template.querySelector('.websiteBtn-error').style.display = 'none';
					this.template.querySelector('.phoneBtn-error').style.display = 'none';
				}


				// } else if (event.detail.value == 'offerCode') {
				// 	this.templateData.buttons.push({
				// 		type: "COPY_CODE",
				// 		text: 'Copy offer code',
				// 		example: '',
				// 		isQuickReply: false
				// 	});
			}
			//console.log('Buttons')
			//console.log(JSON.stringify(this.templateData))
		}

		handleMenuSelect(event) {
			let ta = this.template.querySelector('lightning-textarea');
			ta.setRangeText('{!' + event.detail.value + '}');
		}

		handleFilesChange(event) {
			this.fileName = '';
			const file = event.target.files[0];
			if (file) {
				const fileType = this.getFileType(file.type);
				const fileSizeLimit = this.getFileSizeLimit(file.type);
				if (file.size > fileSizeLimit) {
					this.fileSizeWarning = `The file exceeds the maximum size limit for ${fileType}. Max allowed: ${this.formatFileSize(fileSizeLimit)}. Please choose another file.`;
					return;
				} else {
					this.fileSizeWarning = '';
				}

				const reader = new FileReader();
				reader.onload = () => {
					const fileData = reader.result.split(',')[1];
					this.templateData.headerMedia = {
						fileName: file.name,
						fileSize: file.size,
						fileType: file.type,
						fileData: fileData
					};
					this.fileName = file.name;
				};
				reader.readAsDataURL(file);
			}
		}

		getFileSizeLimit(fileType) {
			if (fileType.includes('audio/')) {
				return FILE_SIZE_LIMITS.audio;
			} else if (fileType.includes('document/')) {
				return FILE_SIZE_LIMITS.document;
			} else if (fileType.includes('image/')) {
				return FILE_SIZE_LIMITS.image;
			} else if (fileType.includes('sticker/')) {
				return FILE_SIZE_LIMITS.sticker;
			} else if (fileType.includes('video/')) {
				return FILE_SIZE_LIMITS.video;
			} else {
				return FILE_SIZE_LIMITS.document;
			}
		}

		getFileType(fileMimeType) {
			if (fileMimeType.startsWith('audio/')) {
				return 'audio';
			} else if (fileMimeType.startsWith('application/')) {
				return 'document';
			} else if (fileMimeType.startsWith('image/')) {
				return 'image';
			} else if (fileMimeType.startsWith('video/')) {
				return 'video';
			} else {
				return 'file';
			}
		}

		formatFileSize(size) {
			if (size >= 1024 * 1024) {
				return `${(size / (1024 * 1024)).toFixed(2)} MB`;
			} else if (size >= 1024) {
				return `${(size / 1024).toFixed(2)} KB`;
			}
			return `${size} bytes`;
		}
		replacePlaceholders(text) {

			const pattern = /{![^{}]+}/g;
			let index = 1;
			//console.log('Before result --- >' + text)
			const result = text.replace(pattern, function () {
				return `{{${index++}}}`;
			});
			//console.log('After result --- >' + result)
			this.bodyVarCount = index;
			return result;
		}


		populateTemplateData(record) {
			// console.log('Start of Populate template data Called')
			this.templateData.templateName = getFieldValue(record, 'SmartMsg__Message_Template__c.SmartMsg__Template_Name__c');
			this.templateData.channel = getFieldValue(record, 'SmartMsg__Message_Template__c.SmartMsg__Channel__c');
			this.templateData.bodyText = getFieldValue(record, 'SmartMsg__Message_Template__c.SmartMsg__Body__c');
			this.templateData.headerText = getFieldValue(record, 'SmartMsg__Message_Template__c.SmartMsg__Header__c');
			this.templateData.footerText = getFieldValue(record, 'SmartMsg__Message_Template__c.SmartMsg__Footer__c');
			this.templateData.TemplateId = getFieldValue(record, 'SmartMsg__Message_Template__c.SmartMsg__WhatsApp_Template_ID__c');
			const buttonData = getFieldValue(record, 'SmartMsg__Message_Template__c.SmartMsg__Button__c');
			// console.log('Button Data : '+ buttonData);
			this.templateData.buttons = buttonData ? JSON.parse(buttonData) : [];
			this.templateData.buttons.forEach((btn, i) => {
				btn.isQuickReply = (btn.type === 'QUICK_REPLY');
				btn.isCallToAction = (btn.type === 'URL' || btn.type === 'PHONE_NUMBER');
				if (!btn.id) btn.id = 'btn-loaded-' + i + '-' + (btn.type || '');
			});
			if (this.templateData.channel === 'WhatsApp') {
				this.templateCreationMode = 'meta';
			} else {
				this.templateCreationMode = 'sms';
			}
			if (this.templateData.buttons.length > 0) {
				this.data = true;
			} else {
				this.data = false;
			}
			// console.log('Template Buttons : '+JSON.stringify(this.templateData.buttons));
			// console.log('End  of Populate template data ')

		}

		handleSave() {
			if (this.templateCreationMode === 'twilio') {
				this.handleTwilioSave();
				// console.log('Inside of templateCreationMode');
				return;
			}
			this.isLoading = true;
			const ta = this.template.querySelector('lightning-textarea');
			if (ta) this.templateData.formattedBodyText = this.replacePlaceholders(ta.value);
			if (this.bodyVarCount > 1) {
				const exampleVar = {
					body_text: []
				};
				const bodyTextVar = [];
				for (let i = 1; i < this.bodyVarCount; i++) {
					bodyTextVar.push('Test ' + i);
				}
				exampleVar.body_text.push(bodyTextVar);
				this.templateData['example'] = exampleVar;

			}

			const templateDataStr = JSON.parse(JSON.stringify(this.templateData));
			const buttons = templateDataStr.buttons;
			if (buttons) {
				buttons.forEach(button => delete button.isQuickReply);
				buttons.forEach(button => delete button.isCallToAction);
			}
			// const doSave = this.templateCreationMode === 'meta' ? metaSave : save;
			// const doEdit = this.templateCreationMode === 'meta' ? metaHandleEdit : handleEdit;
			if (this.recordId) {
				handleEdit({ templateDataStr: JSON.stringify(this.templateData), waTemplateId: this.templateData.TemplateId, templateId: this.recordId })
					.then((data) => {
						// console.log('Edit response ',JSON.stringify(data));
						if (data == 'success') {
							this.showToast('Success', 'Template Updated Successfully', 'success');
						} else if (data == 'error_24_hour_limit') {
							this.showToast('Error', 'Template can only be edited once in 24 hours', 'error');
						} else {
							this.showToast('Error', 'Failed to Edit template', 'error');
						}

						this.dispatchEvent(new CloseActionScreenEvent());

					}).catch(() => {
						this.showToast('Error', 'Failed to Edit template', 'error');
					});
				this.isLoading = false;
			}
			else {

				// console.log(JSON.stringify(templateDataStr))
				save({ templateDataStr: JSON.stringify(templateDataStr) })
					.then(() => {
						this.showToast('Success', 'Template Saved Successfully', 'success');
						this.isLoading = false;
						this.resetToCreateTemplateChoice();
						this.navigateToList();
					})
					.catch((error) => {
						// console.log(JSON.stringify(error));
						if (error && error.body && error.body.message) {
							console.error('Apex error message:', error.body.message);
						} else if (error && error.message) {
							// Handles JS errors
							console.error('JS error message:', error.message);
						} else {
							// Fallback for unknown formats
							console.error('Unknown error in fallback getSingleMessage for Outbound:', error);
						}
						this.showToast('Error', error.body.message, 'error');
						this.isLoading = false;

					});

			}
		}
		get twilioHasOptions() {
			return this.twilioResponseType !== 'text';
		}
		get twilioIsListPickerWithDesc() {
			return this.twilioResponseType === 'list_picker_description';
		}
		get twilioMaxOptions() {
			return this.twilioResponseType === 'quick_reply' ? QUICK_REPLY_MAX_OPTIONS : LIST_PICKER_MAX_OPTIONS;
		}
		get twilioCanAddOption() {
			if (!this.twilioHasOptions) return false;
			return this.twilioOptions.length < this.twilioMaxOptions;
		}
		get twilioOptionsLimitMessage() {
			if (!this.twilioHasOptions) return '';
			const max = this.twilioMaxOptions;
			return this.twilioResponseType === 'quick_reply'
				? `Maximum ${max} buttons allowed.`
				: `Maximum ${max} options allowed.`;
		}
		get twilioAddOptionDisabled() {
			return !this.twilioCanAddOption;
		}
		get twilioOptionRowLabelPrefix() {
			return this.twilioResponseType === 'quick_reply' ? 'Button' : 'Option';
		}
		get twilioOptionFirstLabel() {
			return 'Title';
		}
		get twilioOptionTextPlaceholder() {
			return this.twilioResponseType === 'quick_reply' ? 'Button Title' : 'Option title';
		}
		get twilioOptionCardClass() {
			const base = 'option-row option-card slds-m-bottom_small';
			return this.twilioIsListPickerWithDesc ? base + ' option-card-with-desc' : base;
		}
		get twilioBodyPlaceholder() {
			return 'Hello! {{1}}';
		}
		get twilioBodySectionDescription() {
			return 'Message body. Use for the main message when sending. Add options below for Quick Reply or List Picker. Use "Insert merge field" to add placeholders like {!Name}; when the template is sent from a record page, these are replaced with that record\'s field values.';
		}
		get twilioOptionsMapDesc() {
			return 'Add button titles or list items. These map to {{2}}, {{3}}, etc. in the template.';
		}
		get twilioAddOptionDisabledTitle() {
			if (this.twilioCanAddOption) return '';
			return this.twilioResponseType === 'quick_reply'
				? 'Quick Reply allows at most 3 buttons.'
				: 'List Picker allows at most 10 options.';
		}
		handleTwilioObjectChange(event) {
			this.twilioObjectName = event.detail.value;
			if (this.twilioObjectName) {
				getTwilioAllFields({ objectName: this.twilioObjectName })
					.then((fieldMap) => {
						this.fieldOptions = Object.keys(fieldMap).map((label) => ({ label, value: fieldMap[label] }));
					})
					.catch(() => {
						this.fieldOptions = [];
					});
			} else {
				this.fieldOptions = [];
			}
		}
		handleTwilioTemplateNameChange(event) {
			this.twilioTemplateName = event.detail.value;
		}
		handleTwilioBodyChange(event) {
			this.twilioBodyText = event.detail.value || '{{1}}';
		}
		handleTwilioResponseTypeChange(event) {
			this.twilioResponseType = event.detail.value;
			if (this.twilioResponseType === 'text') {
				this.twilioOptions = [];
			} else {
				const max = this.twilioResponseType === 'quick_reply' ? QUICK_REPLY_MAX_OPTIONS : LIST_PICKER_MAX_OPTIONS;
				if (this.twilioOptions.length > max) {
					this.twilioOptions = this.twilioOptions.slice(0, max).map((o, i) => ({ ...o, idx: i, indexLabel: String(i + 1) + '.', optionNumber: i + 1 }));
				} else if (this.twilioOptions.length === 0) {
					this.handleTwilioAddOption();
				}
			}
		}
		handleTwilioMergeFieldSelect(event) {
			const value = (event.detail && event.detail.value) || (event.target && event.target.value);
			if (!value || typeof value !== 'string') return;
			const current = this.twilioBodyText || '';
			this.twilioBodyText = current + (current.length > 0 && !current.endsWith(' ') ? ' ' : '') + '{!' + value + '}';
		}
		handleTwilioAddOption() {
			if (!this.twilioCanAddOption) return;
			const idx = this.twilioOptions.length;
			this.twilioOptions = [
				...this.twilioOptions,
				{
					id: 'opt' + this.twilioOptionId++,
					idx,
					indexLabel: String(idx + 1) + '.',
					optionNumber: idx + 1,
					text: '',
					description: ''
				}
			];
		}
		handleTwilioOptionChange(event) {
			const idx = parseInt(event.target.dataset.idx, 10);
			const text = event.detail.value;
			this.twilioOptions = this.twilioOptions.map((o) => (o.idx === idx ? { ...o, text } : o));
		}
		handleTwilioOptionDescChange(event) {
			const idx = parseInt(event.target.dataset.idx, 10);
			const description = event.detail.value;
			this.twilioOptions = this.twilioOptions.map((o) => (o.idx === idx ? { ...o, description } : o));
		}
		handleTwilioRemoveOption(event) {
			const idx = parseInt(event.currentTarget.dataset.idx, 10);
			this.twilioOptions = this.twilioOptions.filter((o) => o.idx !== idx).map((o, i) => ({ ...o, idx: i, indexLabel: String(i + 1) + '.', optionNumber: i + 1 }));
		}
		handleTwilioSave() {
			if (!this.twilioTemplateName || !this.twilioTemplateName.trim()) {
				this.showToast('Validation', 'Template Name is required.', 'error');
				return;
			}
			const needsOptions = this.twilioResponseType !== 'text';
			if (needsOptions && this.twilioOptions.length === 0) {
				this.showToast('Validation', 'Add at least one option for this response type.', 'error');
				return;
			}
			const maxAllowed = this.twilioResponseType === 'quick_reply' ? QUICK_REPLY_MAX_OPTIONS : LIST_PICKER_MAX_OPTIONS;
			if (needsOptions && this.twilioOptions.length > maxAllowed) {
				this.showToast('Validation', this.twilioResponseType === 'quick_reply' ? 'Quick Reply allows at most 3 buttons.' : 'List Picker allows at most 10 options.', 'error');
				return;
			}
			const optionsPayload = this.twilioOptions.map((o) => {
				if (this.twilioResponseType === 'list_picker_description' && (o.text || o.description)) {
					return { text: o.text || '', description: o.description || '' };
				}
				return { text: o.text || '' };
			});
			const responseTypeForApex = this.twilioResponseType === 'quick_reply' ? 'Button' : (this.twilioResponseType === 'text' ? 'text' : 'List Picker');
			const templateData = {
				templateName: this.twilioTemplateName.trim(),
				objectName: this.twilioObjectName,
				bodyText: this.twilioBodyText || '{{1}}',
				responseType: responseTypeForApex,
				options: optionsPayload
			};
			this.isLoading = true;
			createAndSaveTwilioContentTemplate({ templateDataStr: JSON.stringify(templateData) })
				.then((result) => {
					this.isLoading = false;
					if (result.success) {
						this.showToast('Success', 'Twilio Content template created and saved to Salesforce.', 'success');
						this.resetToCreateTemplateChoice();
						this.navigateToList();
					} else {
						this.showToast('Error', result.error || 'Failed to create template.', 'error');
					}
				})
				.catch((error) => {
					this.isLoading = false;
					const msg = (error.body && error.body.message) || error.message || 'Unknown error';
					this.showToast('Error', msg, 'error');
				});
		}
		navigateToList() {
			this[NavigationMixin.Navigate]({
				type: 'standard__objectPage',
				attributes: {
					objectApiName: 'SmartMsg__Message_Template__c',
					actionName: 'list'
				}
			});
		}

		/**
		 * Resets component to the initial "Create Template" state so the user is always
		 * prompted to choose SMS or WhatsApp (based on active provider settings) when
		 * they click Create Template again after saving, avoiding empty channel on save.
		 */
		resetToCreateTemplateChoice() {
			this.templateData = {
				header: 'none',
				channel: null,
				objectName: null,
				bodyText: '',
				footerText: '',
				headerText: '',
				buttons: [],
				headerMedia: {}
			};
			this.customButtonCount = 0;
			this.showSmsForm = false;
			this.showMetaForm = false;
			this.showTwilioForm = false;
			this.option = '';
			this.isSmsTick = false;
			this.isWhatsAppTick = false;
			this.templateCreationMode = '';
			this.isManual = false;
			this.isPrompt = false;
			this.twilioTemplateName = '';
			this.twilioObjectName = null;
			this.twilioBodyText = '{{1}}';
			this.twilioResponseType = 'text';
			this.twilioOptions = [];
			this.getActiveStatus();
		}

		handleTwilioCancel() {
			this.navigateToList();
		}
		showToast(title, message, variant) {
			const event = new ShowToastEvent({ title, message, variant });
			this.dispatchEvent(event);
		}
		handleChangeButtonText(event) {

			const removeBtn = this.templateData.buttons[event.detail.indx];

			// console.log('Button called')
			//console.log('this.templateData.buttons --> ', JSON.stringify(this.templateData.buttons))
			this.templateData.buttons.splice(event.detail.indx, 1)
			if (removeBtn.type == "QUICK_REPLY") {
				if (this.customButtonCount > 0) {
					this.customButtonCount--;
					// console.log('Custom Button Count ---->',this.customButtonCountButtonCount)
				}
				if (this.customButtonCount < 3) {
					this.template.querySelector('.customBtn-error').style.display = 'none';
				}
			}

			if (removeBtn.type == "URL") {
				if (this.websiteButtonCount > 0) {
					this.websiteButtonCount--;
					// console.log('Website Button Count ---->', this.websiteButtonCount)
				}
				if (this.websiteButtonCount < 1) {
					this.template.querySelector('.websiteBtn-error').style.display = 'none';
					this.template.querySelector('.allBtn-error').style.display = 'none';

				}
			}

			if (removeBtn.type == "PHONE_NUMBER") {
				if (this.phoneNumberButtonCount > 0) {
					this.phoneNumberButtonCount--;
					// console.log('Website Button Count ---->', this.phoneNumberButtonCount)
				}
				if (this.phoneNumberButtonCount < 1) {
					this.template.querySelector('.phoneBtn-error').style.display = 'none';
					this.template.querySelector('.allBtn-error').style.display = 'none';
				}
			}

			// console.log('Custom Button Count ---->',this.customButtonCountButtonCount)
			// console.log('Array length ----> ', this.templateData.buttons.length)




		}
		handleButtonData(event) {
			this.templateData.buttons[event.detail.indx] = event.detail.buttonData;
		}
		handleBack() {
			this.initialTemplate = true
			this.isPrompt = false
			this.isManual = false
		}
		handleAI() {
			this.initialTemplate = false
			this.isPrompt = true
			this.isManual = false
		}
		// handleClose() {
		// 	const baseUrl = window.location.origin; 
		// 	const listViewUrl = `/lightning/o/SmartMsg__Message_Template__c/list`; // Construct the list view URL
		// 	window.location.href = baseUrl + listViewUrl;
		// }

		handleClose() {
			if (this.isMobile) {
				this[NavigationMixin.Navigate]({
					type: 'standard__objectPage',
					attributes: {
						objectApiName: 'SmartMsg__Message_Template__c',
						actionName: 'list'
					},
					state: {
						filterName: 'Recent' // Optional, or use a specific list view API name
					}
				});
			}
			else {
				const baseUrl = window.location.origin;
				const listViewUrl = `/lightning/o/SmartMsg__Message_Template__c/list`; // Construct the list view URL
				window.location.href = baseUrl + listViewUrl;
			}
		}

		handleButtonClose(event) {
			const indexOfButton = event.detail.index;
			// console.log('Parent called');
			// console.log(indexOfButton);
		}

		@track isSelected = false;
		get selectedClass() {
			return this.isSelected ? 'icon-wrapper selected' : 'icon-wrapper';
		}
		handleClick() {
			this.isSelected = !this.isSelected;
		}
		handleKeyDown(event) {
			if (event.key === 'Enter' || event.key === ' ') {
				event.preventDefault();
				const label = event.currentTarget.dataset?.label;
				if (label === 'SMS' || label === 'WhatsApp') {
					this.option = label;
					this.isSmsTick = label === 'SMS';
					this.isWhatsAppTick = label === 'WhatsApp';
				} else {
					this.handleClick();
				}
			}
		}

		handlePhonebuttonCount(event) {
			// console.log('phone called')
			// console.log('event.detail.indx --- > ',event.detail.indx)
			// console.log(event.detail.phoneNumberCount);
			this.phoneNumberButtonCount = event.detail.phoneNumberCount;
			this.websiteButtonCount = event.detail.websiteCount;
			// console.log(this.phoneNumberButtonCount)
			// console.log(this.websiteButtonCount)
			//console.log(JSON.stringify(this.templateData))
			if (this.phoneNumberButtonCount > 1) {
				// console.log('this.templateData', this.templateData);
				const phone = this.templateData.buttons.pop()
				// console.log('phone -->', phone);
				this.template.querySelector('.phoneBtn-error').style.display = 'flex';
				this.phoneNumberButtonCount--;
			} else {
				this.template.querySelector('.phoneBtn-error').style.display = 'none';
			}
		}


		handleWebsitebuttonCount(event) {
			// console.log(' parent js website called')
			this.phoneNumberButtonCount = event.detail.phoneNumberCount;
			this.websiteButtonCount = event.detail.websiteCount;
			// console.log('Phone number : ', this.phoneNumberButtonCount);
			// console.log('Website :', this.websiteButtonCount);
			if (this.websiteButtonCount > 1) {
				// console.log(JSON.stringify(this.templateData.buttons))
				const web = this.templateData.buttons.filter(button => button.type != 'PHONE_NUMBER');
				this.templateData.buttons = web;
				// console.log('web --> ', web);
				// console.log(JSON.stringify(this.templateData.buttons))
				// console.log(JSON.stringify(web))
				this.template.querySelector('.websiteBtn-error').style.display = 'flex';
				this.websiteButtonCount--;
			} else {
				this.template.querySelector('.websiteBtn-error').style.display = 'none';
			}
		}

	}