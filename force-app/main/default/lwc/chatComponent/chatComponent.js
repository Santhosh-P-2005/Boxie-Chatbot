import { LightningElement, track, api, wire } from 'lwc';
import WhatsAppIcon from '@salesforce/resourceUrl/WhatsAppIcon';
import SmsIcon from '@salesforce/resourceUrl/SmsIcon';
import SentTickIcon from '@salesforce/resourceUrl/SentTickIcon';
import DeliveredTickIcon from '@salesforce/resourceUrl/DeliveredTickIcon';
import SeenTickIcon from '@salesforce/resourceUrl/SeenTickIcon';
import AI_star from '@salesforce/resourceUrl/AI_star';
import Agentforce from '@salesforce/resourceUrl/Agentforce';
import WhatsAppBackground from '@salesforce/resourceUrl/WhatsAppBackground';
import MapImage from '@salesforce/resourceUrl/MapImage';
import Feature_Document from '@salesforce/resourceUrl/Feature_Document';
import hasUserPermission from '@salesforce/apex/ChatComponentController.hasUserPermission';
import listAllMessages from '@salesforce/apex/ChatComponentController.listAllMessages';
import getRecordDetails from '@salesforce/apex/ChatComponentController.getRecordDetails';
import getTemplates from '@salesforce/apex/ChatComponentController.getTemplates';
import updateStarStatus from '@salesforce/apex/ChatComponentController.updateStarStatus';
import updatePinStatus from '@salesforce/apex/ChatComponentController.updatePinStatus';
//import sendSMS from '@salesforce/apex/ChatComponentController.sendSMS';
import scheduleSMS from '@salesforce/apex/ChatComponentController.scheduleSMS';
import createMessageRecord from '@salesforce/apex/ChatComponentController.createMessageRecord';
import generatePublicUrlForContentDocument from '@salesforce/apex/ChatComponentController.generatePublicUrlForContentDocument';
import createScheduleRecord from '@salesforce/apex/ChatComponentController.createScheduleRecord';
import createWhatsAppScheduleRecord from '@salesforce/apex/ChatComponentController.createWhatsAppScheduleRecord';
import listWAMessages from '@salesforce/apex/ChatComponentController.listWAMessages';
import sendTextMessage from '@salesforce/apex/ChatComponentController.sendTextMessage';
import sendTemplateMessage from '@salesforce/apex/ChatComponentController.sendTemplateMessage';
import sendMediaMessage from '@salesforce/apex/WhatsAppServices.sendMediaMessage';
//import sendTypingIndicator from '@salesforce/apex/WhatsAppServices.sendTypingIndicator';
//import sendLocationRequestMessage from '@salesforce/apex/WhatsAppServices.sendLocationRequestMessage';
import getPhoneFields from '@salesforce/apex/ChatComponentController.getPhoneFields';
import getObjectApiNameFromRecordId from '@salesforce/apex/ChatComponentController.getObjectApiNameFromRecordId';
import getActiveChannels from '@salesforce/apex/ChatComponentController.getActiveChannels';
import getActiveWhatsAppChannel from '@salesforce/apex/ChatComponentController.getActiveWhatsAppChannel';
import getTwilioWhatsAppFromNumbers from '@salesforce/apex/ChatComponentController.getTwilioWhatsAppFromNumbers';
import sendTextMessageWithFrom from '@salesforce/apex/ChatComponentController.sendTextMessageWithFrom';
import sendTemplateMessageWithFrom from '@salesforce/apex/ChatComponentController.sendTemplateMessageWithFrom';
import ensureChatbotMessage from '@salesforce/apex/ChatComponentController.ensureChatbotMessage';
import hasChatbotDialogAndOptionDialogRecords from '@salesforce/apex/ChatComponentController.hasChatbotDialogAndOptionDialogRecords';
import { updateRecord } from 'lightning/uiRecordApi';
// import getAISuggestions from '@salesforce/apex/FlexTemplate.suggestNextPrompt';
// import getConversationSummary from '@salesforce/apex/FlexTemplate.getConversationSummary';
// import reframeSentence from '@salesforce/apex/FlexTemplate.reframeSentence';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor'
import getSingleMessage from '@salesforce/apex/ChatComponentController.getSingleMessage';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
//import {getObjectInfo} from 'lightning/uiObjectInfoApi';
import { label } from './constant';
import { NavigationMixin } from 'lightning/navigation';
const MAX_FILE_SIZE = 4194304;
const twilioErrorMessages = {
	'30111': 'Url is on a deny list',
	'57016': "'Topic' is empty",
	'30118': 'Private key is invalid',
	'21725': 'Brand can only be updated when in FAILED state',
	'30006': 'Landline or unreachable carrier',
	'30117': 'Certificate cannot be parsed',
	'30107': 'Domain private certificate has not been uploaded',
	'57013': "'Topic' is absent",
	'57020': 'Authorization failed',
	'30019': 'Content size exceeds carrier limit',
	'30043': 'International SMS via Domestic Gateway',
	'90009': 'The message SID already exists.',
	'92008': 'Unsupported Content Type',
	'90007': 'Invalid validity period value',
	'30124': 'MessagingServiceSID cannot be empty or null',
	'63016': 'Failed to send freeform message because you are outside the allowed window. If you are using WhatsApp please use a Message Template.',
	'21654': 'ContentSid Required',
	'30409': 'This message cannot be canceled',
	'63036': 'The specified phone number cannot be reached by RBM at this time.',
	'30119': 'Certificate and private key pair is invalid',
	'21606': 'The "From" phone number provided is not a valid message-capable Twilio phone number for this destination/account',
	'63031': "Channels message cannot have same 'From' and 'To'",
	'23004': 'Message Redaction Incompatible Configuration: Advanced Opt-Out',
	'11751': 'Media Message - Media exceeds messaging provider size limit',
	'30036': 'Validity Period Expired',
	'30121': 'Fallback URL is missing',
	'21611': 'This "From" number has exceeded the maximum number of queued messages',
	'30027': 'US A2P 10DLC - T-Mobile Daily Message Limit Reached',
	'63008': 'Could not execute the request because the channel module has been misconfigured. Please check the Channel configuration in Twilio',
	'23002': 'Message Redaction Incompatible Configuration: Short code "STOP" filtering',
	'30011': 'MMS not supported by the receiving phone number in this region',
	'30130': 'Messaging Service SID already belongs in another domain configuration.',
	'21627': 'Max Price must be a valid float',
	'23005': 'Phone Number Redaction Incompatible Configuration: Fallback to Long Code',
	'90014': 'Validity Period should be positive integer',
	'92005': 'ContentSid Required',
	'21408': 'Permission to send an SMS or MMS has not been enabled for the region indicated by the "To" number',
	'35125': 'Maximum limit reached in the account for scheduling messages',
	'21712': 'Phone Number or Short Code is associated with another Messaging Service.',
	'57006': "'EventType' is empty",
	'57007': "'EventType' is absent",
	'30108': 'Twilio account does not belong to an organization',
	'57009': "'EventType' is too long",
	'30022': 'US A2P 10DLC - Rate Limits Exceeded',
	'30100': 'Domain SID is invalid',
	'30002': 'Account suspended',
	'92007': 'The Content Variables Parameter is invalid',
	'21723': 'Campaign Verify token import already in progress',
	'30009': 'Missing inbound segment',
	'63028': 'Number of parameters provided does not match the expected number of parameters',
	'30116': 'Certificate or private key or both are missing',
	'63001': 'Channel could not authenticate the request. Please see Channel specific error message for more information',
	'90006': 'Invalid direction',
	'30122': 'Fallback URL is invalid',
	'57018': "'Event' value type must be Map",
	'57003': "'Secret id' is invalid for this Partner",
	'30031': 'Invalid MaxRate',
	'57004': "'Category' is empty",
	'21614': "'To' number is not a valid mobile number",
	'63023': 'Channel generic error',
	'30041': 'Message from an unregistered number sent to a United Kingdom number',
	'21709': 'Alpha Sender ID is Invalid or Not Authorized for this Messaging Service',
	'21658': 'Parameter exceeded character limit',
	'21722': 'Invalid Campaign Verify token',
	'63038': 'Account exceeded the daily messages limit',
	'57002': "'Secret id' is too long",
	'63020': 'Twilio encountered a Business Manager account error',
	'63035': 'This operation is blocked because the RCS agent has not launched the recipient has not accepted the invitation to become a tester or the RCS sender only works in certain regions.',
	'63011': 'Invalid Request: Twilio encountered an error while processing your request',
	'92004': 'Invalid language code',
	'30133': 'The certificate could not be uploaded.',
	'21720': 'A2P Use Case is Invalid',
	'57011': 'Unsupported Partner name',
	'21711': 'Phone Number Shortcode or AlphaSender is not associated to the specified Messaging Service.',
	'30400': 'Parameters are not valid',
	'21605': 'Maximum body length is 160 characters (old API endpoint)',
	'21612': 'Message cannot be sent with the current combination of "To" and/or "From" parameters',
	'57017': "'Topic' is too long",
	'21619': 'A Message Body Media URL or Content SID is required',
	'30007': 'Message filtered',
	'63006': 'Could not format given content for the channel. Please see Channel specific error message for more information',
	'63029': 'The receiver failed to download the template',
	'30040': 'Destination carrier requires Sender ID pre-registration',
	'57021': 'Token invalid',
	'35126': 'The ScheduleType value provided is not supported for this channel',
	'30038': 'OTP Message Body Filtered',
	'35111': 'SendAt timestamp is missing',
	'30103': 'Links not shortened due to application failure.',
	'30105': 'Shortened link not found and no fallback URL found',
	'21710': 'Phone Number Already Exists in Messaging Service',
	'30404': 'Not Found',
	'57005': "'Category' is too long",
	'30129': 'Certificate is self signed',
	'21730': 'System under maintenance. Please try again later.',
	'30127': 'MessagingServiceSID is invalid.',
	'21902': 'InvoiceTag length must be between 0 and 32',
	'30128': 'MessagingServiceSidsAction is invalid',
	'30037': 'Outbound Messaging Disabled',
	'30032': 'Toll-Free Number Has Not Been Verified',
	'21910': "Invalid 'From' and 'To' pair. 'From' and 'To' should be of the same channel",
	'92009': 'The template associated with this SID has already been submitted for approval.',
	'57019': "'Authorization' header is missing or is invalid",
	'30125': 'Your phone number could not be registered with US A2P 10DLC',
	'63025': 'Media already exists',
	'30021': 'Internal Failure with messaging service orchestrator',
	'30485': "Message couldn't be delivered",
	'30123': 'Callback URL is missing',
	'63022': 'Invalid vname certificate',
	'30024': 'Numeric Sender ID Not Provisioned on Carrier',
	'30029': 'Invalid ContentRetention',
	'63009': 'Channel provider returned an internal service error (HTTP 5xx). Please see Channel specific error message for more information',
	'30114': 'Specified date is not available yet',
	'30003': 'Unreachable destination handset',
	'63003': 'Channel could not find To address',
	'30131': "Domain's certificate will expire soon",
	'35117': 'Scheduling does not support this timestamp',
	'21655': 'The ContentSid is Invalid',
	'30034': 'US A2P 10DLC - Message from an Unregistered Number',
	'63007': "Twilio could not find a Channel with the specified 'From' address",
	'30104': 'Shortened link not found. Click redirected to fallback Url',
	'30020': 'Internal Failure with Message Scheduling',
	'30450': 'Message delivery blocked',
	'30010': 'Message price exceeds max price',
	'21610': 'Attempt to send to unsubscribed recipient',
	'90001': 'Message SID is invalid',
	'21717': 'Brand Registration SID for US A2P Campaign Use Case is Not Registered or Not Valid',
	'57001': "'Secret id' is empty",
	'30454': 'Account exceeded the messages limit',
	'92002': 'The "variables" parameter exceeds the allowed limit',
	'90031': 'Broadcast Recipients list is empty [deprecated]',
	'63019': 'Media failed to download',
	'30026': 'US A2P 10DLC - 70% T-Mobile Daily Message Limit Consumed',
	'30115': 'Date format is incorrect',
	'35118': 'MessagingServiceSid is required to schedule a message'
};
export default class ChatComponent extends NavigationMixin(LightningElement) {
	@track contactName;
	@track messages;
	@track allMessages = [];
	@track errordetails;
	@track selectedOption = 'SMS';
	@track smsOption = true;
	@track whatsAppOption;
	@track bothChannelsActive = false;
	@track hasActiveProvider = false;
	@track selectedTemplateId;
	@track selectedTemplateBody = '';
	@track messageText = '';
	@api recordId;
	@api phoneNumber;
	@api objectApiName;
	phoneFieldOptions = [];
	@track searchQuery = '';
	@track lastHighlightedMessageId = null;
	@track selectedPhoneField;
	@track showFieldSelectionModal = false;
	isSpinner = false;
	@track showDropdown = false;
	@track defaultContact;
	@track selectedMediaType = '';
	//@track selectedPhoneField; 
	whatsappIconUrl = WhatsAppIcon;
	smsIconUrl = SmsIcon;
	sentIconURL = SentTickIcon;
	deliveredIconUrl = DeliveredTickIcon;
	seenIconUrl = SeenTickIcon;
	whatsAppBgURL = WhatsAppBackground;
	aiStar = AI_star;
	agentForceIconUrl = Agentforce;
	mapImageUrl = MapImage;
	featureDocUrl = Feature_Document;
	label = label;
	eventName = '/event/SmartMsg__Incoming_Message__e'
	subscription;
	@track showTemplateModal = false;
	@track showSchedulePopup = false;
	@track showMediaUrlModal = false;
	@track showReengagementPopup = false;
	@track HeadermediaUrl = '';
	@track mediaUrl = '';
	@track Templates = [];
	@track filteredTemplates;
	@track selectedDate;
	@track selectedTime;
	@track errorMessage;
	@track inputerrorMessage;
	typingTimeout;
	isTyping = false;
	lastInboundMessageId;
	@track isSearchActive = false;
	@track showContactTiles = false;
	phoneFieldName;
	isDocument = false;
	isEnterKeyPressed = false;
	mediaUrlError = false;
	fileNameError = false;
	phoneFieldError = false;
	@track noMessagesFound = false;
	@track fileName = '';
	@track groupedMessages = [];
	isMobile = false;
	isPermissionError = false;
	@track selectedContact;
	@track selectedContactId;
	shouldScrollToBottom = false;
	@track einsteinActive = false;
	@track pinnedMessageId = null; // For pinning a message to the top 
	@track starredMessageIds = []; // For starring multiple messages 
	@track showStarredOnly = false;
	@track showEinsteinMenu = false;
	@track activeActionMessageId = null;
	@track aiSuggestions = [];
	@track aiSentiment = '';
	@track aiSentence = '';
	@track conversationSummary = '';
	@track showEinsteinResultModal = false;
	@track einsteinResultType = ''; // 'suggestion' or 'summary' 
	@track aiLoading = false;
	@track rawSMSMessages = [];
	@track rawWAMessages = [];
	@track summaryModal = false;
	@track aiBriefReply;
	undoStack = [];
	redoStack = [];
	@track showFooterMenu = false;
	@track showFileUploadSection = true;
	@track showUrlInputSection = false;
	@track uploadBtnVariant = 'brand'; // default selected
	@track urlBtnVariant = 'neutral';
	@track mediaMode = 'upload';
	isLocationRequest = false;
	@track activeWhatsAppChannel = '';
	@track twilioFromNumberOptions = [];
	@track selectedTwilioFromNumber = '';
	@track isAutoReplyEnabled = false;
	@track isAutoReplyEnabledId = null;
	@track hasChatbotDialogsAvailable = false;
	@api hideUtilityBarElements = false;
	@api chatClass;
	limitMessage = false;
	characterLength = 0;
	noStarredMessage = false;
	toggleFooterMenu() {
		event.preventDefault();
		event.stopPropagation();
		this.showFooterMenu = !this.showFooterMenu;

		if (this.showFooterMenu) {
			window.addEventListener('click', this.handleClickOutside.bind(this));
			//this.selectedDate = null; 
			this.setDefaultDate();
			this.selectedTime = null;
			this.errorMessage = '';
		} else {
			window.removeEventListener('click', this.handleClickOutside.bind(this));
		}
	}

	get dropdownClass() {
		return this.showDropdown ? 'dropdown-content show' : 'dropdown-content hide';
	}
	get dropdownIcon() {
		return this.showDropdown ? 'utility:up' : 'utility:down';
	}
	get showSelectChannelOption() {
		return this.smsOption && this.whatsAppOption;
	}
	get showSmsTriggerIcon() {
		if (!this.smsOption) return false;
		if (!this.bothChannelsActive) return true;
		return this.selectedOption === 'SMS' || this.selectedOption === 'Select Channel';
	}
	get showWhatsAppTriggerIcon() {
		if (!this.whatsAppOption) return false;
		if (!this.bothChannelsActive) return true;
		return this.selectedOption === 'WhatsApp' || this.selectedOption === 'Select Channel';
	}
	get smsOptionBorderClass() {
		return this.whatsAppOption ? 'dropdown-option dropdown-option-border' : 'dropdown-option';
	}
	get showScheduleAndAttachment() {
		return !(this.selectedOption === 'WhatsApp' && this.activeWhatsAppChannel === 'Twilio WhatsApp');
	}
	get showTwilioFromNumberDropdown() {
		return this.selectedOption === 'WhatsApp' && this.activeWhatsAppChannel === 'Twilio WhatsApp' && this.twilioFromNumberOptions && this.twilioFromNumberOptions.length > 0;
	}
	get showChatbotToggle() {
		return this.selectedOption === 'WhatsApp' && this.hasChatbotDialogsAvailable;
	}
	get backgroundImageStyle() {
		return `background: linear-gradient(rgba(255, 255, 255, 0.5), rgba(255, 255, 255, 0.5)), url(${this.whatsAppBgURL});`;
	}
	get chatAreaClass() {
		return `slds-chat chat-Area ${this.isUtilityBar ? 'utility-style' : ''}`;
	}
	get isUtilityBar() {
		return this.chatClass === 'utility-bar';
	}
	get hasContacts() {
		return this.contactOptions && this.contactOptions.length > 0;
	}
	get einsteinToggleClass() {
		return this.einsteinActive ? 'einstein-toggle active' : 'einstein-toggle';
	}
	get footereinsteinToggleClass() {
		return this.einsteinActive ? 'footer-menu-btn active' : 'footer-menu-btn';
	}

	toggleEinstein() {
		this.einsteinActive = !this.einsteinActive;
		// Add your logic for enabling/disabling AI suggestions here 
	}
	renderedCallback() {
		if (this.shouldScrollToBottom) {
			this.scrollToBottom();
			this.shouldScrollToBottom = false;
		}
		this.handleShedulePopup();
		this.handleColor();
		this.handleSearchBar();
	}
	toggleDropdown(event) {
		event.preventDefault();
		event.stopPropagation();
		this.showDropdown = !this.showDropdown;
		if (this.showDropdown) {
			this.selectedTime = null;
			this.showSchedulePopup = false;
			this.inputerrorMessage = '';
			this.showFooterMenu = false;
			window.addEventListener('click', this.handleClickOutside.bind(this));
		} else {
			window.removeEventListener('click', this.handleClickOutside.bind(this));
		}
	}
	handleContactTileClick(event) {
		this.isSpinner = true;
		const selectedContactId = event.currentTarget.dataset.id;
		// Clear existing messages 
		this.messages = [];
		this.filteredMessages = [];
		this.validationMessage = '';
		// Get the contact name from the label by removing the "Last Message" part 
		const selectedContact = this.contactOptions.find(contact => contact.value === selectedContactId);
		const selectedContactName = selectedContact ? selectedContact.label.split(' (')[0] : '';
		this.contactOptions = this.contactOptions.map(contact => ({
			...contact,
			tileClass: contact.value === selectedContactId ? 'contact-tile active' : 'contact-tile'
		}));
		this.isLoading = true;
		getRecordDetails({
			objectName: this.objectApiName,
			recordId: this.recordId,
			phoneField: this.selectedPhoneField
		})
			.then(result => {
				if (result && result.Contacts) {
					const newSelectedContact = result.Contacts.find(
						contact => contact.Name === selectedContactName
					);
					this.updatePhoneFieldOptions(newSelectedContact);
					this.isSpinner = false;
					this.loadMessages();
				}
				this.showContactTiles = false;
			})
			.catch(error => {
				console.error(JSON.stringify(error));
				this.validationMessage = 'Error while switching contact';
				this.isLoading = false;
			});
	}
	closeContactDropdown() {
		const contactTiles = this.template.querySelector('.contact-tiles-container');
		if (contactTiles) {
			contactTiles.classList.remove('show');
			contactTiles.classList.add('hide');
			setTimeout(() => {
				this.showContactTiles = false;
			}, 500);
		}
	}
	handleOptionSelection(event) {
		this.selectedOption = (event.target.textContent || '').trim();

		if (this.bothChannelsActive) {
			if (this.selectedOption === 'SMS') {
				this.limitMessage = true;
				this.characterLength = this.messageText.length;
				this.inputerrorMessage = this.messageText.length > 500 ? 'Character Limit exceeded' : '';
			} else if (this.selectedOption === 'WhatsApp') {
				this.limitMessage = false;
				this.checkReengagementMessage();
				if (this.formattedPhoneNumber) {
					this.createOrCheckSmartMsgRecord();
				}
			} else if (this.selectedOption === (this.label.SELECT_CHANNEL_LABEL || 'Select Channel')) {
				this.limitMessage = false;
			}
		} else {
			if (this.selectedOption == 'SMS') {
				this.showReengagementPopup = false;
				this.smsOption = true;
				this.whatsAppOption = false;
				this.limitMessage = true;
				this.characterLength = this.messageText.length;
				this.inputerrorMessage = this.messageText.length > 500 ? 'Character Limit exceeded' : '';
			}
			if (this.selectedOption == 'WhatsApp') {
				this.whatsAppOption = true;
				this.smsOption = false;
				this.limitMessage = false;
				this.checkReengagementMessage();
			}
		}
		this.dispatchEvent(new CustomEvent('optionselected', {
			detail: this.selectedOption
		}));
		this.refreshMessagesForSelectedChannel();
		this.showDropdown = false;
	}
	@wire(hasUserPermission)
	wiredSettings(result) {
		if (result.error) {
			this.error = result.error.body.message;
			if (this.error == 'You do not have the required permissions to access this feature.' || this.error == 'You do not have access to the Apex class named \'ChatComponentController\'.') {
				this.isPermissionError = true;
			}
		}
	}
	@wire(getActiveChannels)
	wiredActiveChannels(result) {
		if (result.data) {
			const smsActive = result.data.SMS === true;
			const whatsAppActive = result.data.WhatsApp === true;
			this.hasActiveProvider = smsActive || whatsAppActive;
			if (smsActive && !whatsAppActive) {
				this.smsOption = true;
				this.whatsAppOption = false;
				this.bothChannelsActive = false;
				this.selectedOption = 'SMS';
				this.limitMessage = true;
			} else if (!smsActive && whatsAppActive) {
				this.smsOption = false;
				this.whatsAppOption = true;
				this.bothChannelsActive = false;
				this.selectedOption = 'WhatsApp';
				this.limitMessage = false;
			} else if (smsActive && whatsAppActive) {
				this.smsOption = true;
				this.whatsAppOption = true;
				this.bothChannelsActive = true;
				this.selectedOption = 'SMS';
				this.limitMessage = true;
			}
			if (!smsActive && !whatsAppActive) {
				this.smsOption = true;
				this.whatsAppOption = false;
				this.bothChannelsActive = false;
				this.selectedOption = 'SMS';
				this.limitMessage = true;
			}
			if (whatsAppActive) {
				getActiveWhatsAppChannel().then((channel) => {
					this.activeWhatsAppChannel = channel || '';
					if (channel === 'Twilio WhatsApp') {
						return getTwilioWhatsAppFromNumbers().then((nums) => {
							this.twilioFromNumberOptions = (nums || []).map((n) => ({ label: n, value: n }));
							if (this.twilioFromNumberOptions.length > 0) {
								const combined = (this.allMessages && this.allMessages.length) ? this.allMessages : [];
								this.setDefaultFromNumberFromInboundMessages(combined);
								if (!this.selectedTwilioFromNumber) {
									this.selectedTwilioFromNumber = this.twilioFromNumberOptions[0].value;
								}
							}
						});
					}
					this.twilioFromNumberOptions = [];
					this.selectedTwilioFromNumber = '';
				}).catch(() => {});
			} else {
				this.activeWhatsAppChannel = '';
				this.twilioFromNumberOptions = [];
				this.selectedTwilioFromNumber = '';
			}
		}
	}
	connectedCallback() {
		// console.log('WhatsAppIcon --->',WhatsAppIcon)
		if (!this.isPermissionError) {
			this.handleSubscribe();
			this.handleErrorRegister();
			this._boundHandleClickOutside = this.handleClickOutside.bind(this);
			this.setDefaultDate();
			this.handleFormFactor();
			this.fetchChatbotDialogAvailability();
			try {
				this.scrollToBottom();
			}
			catch (error) {
				console.error('The error is--->', error);
			}
			if (this.selectedOption == 'SMS') {
				this.limitMessage = true;
			} else {
				this.limitMessage = false;
			}
			// Resolve objectApiName when on record page (may be auto-set or missing for Lead/Contact/Opportunity)
			this.resolveObjectAndFetchRecord();
		}
	}
	resolveObjectAndFetchRecord() {
		const supportedObjects = ['Account', 'Contact', 'Opportunity', 'Lead'];
		if (this.objectApiName && supportedObjects.includes(this.objectApiName)) {
			this.fetchPhoneFields();
			return;
		}
		if (this.recordId) {
			getObjectApiNameFromRecordId({ recordId: this.recordId })
				.then(objectName => {
					if (objectName && supportedObjects.includes(objectName)) {
						this.objectApiName = objectName;
						this.fetchPhoneFields();
					} else {
						this.fetchPhoneFields();
					}
				})
				.catch(() => {
					this.fetchPhoneFields();
				});
		} else {
			this.fetchPhoneFields();
		}
	}
	fetchChatbotDialogAvailability() {
		hasChatbotDialogAndOptionDialogRecords()
			.then(result => {
				this.hasChatbotDialogsAvailable = result === true;
			})
			.catch(() => {
				this.hasChatbotDialogsAvailable = false;
			});
	}
	fetchPhoneFields() {
		getPhoneFields({
			objectName: this.objectApiName
		})
			.then(result => {
				if (result && Object.keys(result).length > 0) {
					// Map all fields directly without filtering out fax
					const allFields = Object.entries(result).map(([apiName, label]) => ({
						label: label,
						value: apiName
					}));

					this.phoneFieldOptions = allFields;
					// console.log('Phone options updated',JSON.stringify(this.phoneFieldOptions));
					this.selectedPhoneField = this.phoneFieldOptions[0]?.value || '';
					this.retrieveRecordDetails();
				} else {
					this.phoneFieldOptions = [];
					this.selectedPhoneField = '';
				}
			})
			.catch(error => {
				console.error('Error fetching phone fields:', error);
			});
		// this.loadMessages();
	}
	handlePhoneFieldChange(event) {
		this.isLoading = true;
		this.isSpinner = true;
		this.inputerrorMessage = '';
		this.selectedPhoneField = event.detail.value;
		this.messages = [];
		this.filteredMessages = [];
		this.phoneNumber = '';
		this.formattedPhoneNumber = '';
		getRecordDetails({
			objectName: this.objectApiName,
			recordId: this.recordId,
			phoneField: this.selectedPhoneField
		})
			.then(result => {
				if (this.objectApiName === 'Opportunity' && result && result.Contacts) {
					const selectedContactName = this.contactName ? this.contactName.split(' (')[0] : '';
					const selectedContactDetails = result.Contacts.find(
						contact => contact.Name === selectedContactName
					);
					if (selectedContactDetails && selectedContactDetails[this.selectedPhoneField]) {
						this.phoneNumber = selectedContactDetails[[this.selectedPhoneField]];
						this.contactName = `${selectedContactDetails.Name} (Last Message on ${selectedContactDetails.LastMessageDate})`;
						this.formattedPhoneNumber = this.phoneNumber.startsWith('+') ? this.phoneNumber : '+' + this.phoneNumber;
						this.validationMessage = '';
						//this.loadMessages();
					} else {
						const phoneFieldList = Object.entries(result.PhoneFields).map(([field, value]) => {
							return { field, value };
						});
						const phoneValue = phoneFieldList.find(item => item.field === this.selectedPhoneField)?.value;
						this.phoneNumber = phoneValue;
						this.isLoading = false;
						//this.loadMessages();
					}
				} else if (result) {
					const selectedPhoneNumber = result.PhoneFields[this.selectedPhoneField];
					if (selectedPhoneNumber) {
						this.contactName = result.Name;
						this.phoneNumber = selectedPhoneNumber;
						this.formattedPhoneNumber = this.phoneNumber.startsWith('+') ?
							this.phoneNumber :
							'+' + this.phoneNumber;
						this.validationMessage = '';
						//this.loadMessages();
					} else {
						this.contactName = result.Name;
						this.validationMessage = `No ${this.selectedPhoneField} available`;
						this.isLoading = false;
						//this.loadMessages();
					}
				}
				this.loadMessages();
				this.isSpinner = false;
			})
			.catch(error => {
				console.error(JSON.stringify(error));
				this.validationMessage = 'Error while changing phone field';
				this.isSpinner = false;
				this.isLoading = false;
			});
	}
	handleFormFactor() {
		if (FORM_FACTOR === "Small") {
			this.isMobile = true;
		}
	}
	// handleSearchInput(event) {
	// 	this.searchQuery = event.target.value.toLowerCase();
	// 	if (this.searchQuery) {
	// 		this.filteredMessages = this.messages.filter(message =>
	// 			message.SmartMsg__Message_Body__c && message.SmartMsg__Message_Body__c.toLowerCase().includes(this.searchQuery)
	// 		);

	// 	} else {
	// 		this.filteredMessages = [...this.messages];
	// 	}
	// 	this.groupByDate(this.filteredMessages);
	// }
	handleSearchInput(event) {
		this.searchQuery = event.target.value.toLowerCase().trim();
		if (!this.searchQuery) {
			this.unhighlightLastMessage();
			return;
		}
		// Find the first matching message
		const foundMessage = this.messages.find(
			m => m.SmartMsg__Message_Body__c && m.SmartMsg__Message_Body__c.toLowerCase().includes(this.searchQuery)
		);
		if (foundMessage) {
			this.scrollToAndHighlightMessage(foundMessage.Id);
		} else {
			this.unhighlightLastMessage();
		}
	}

	scrollToAndHighlightMessage(messageId) {
		this.unhighlightLastMessage();
		const msgElement = this.template.querySelector(`[data-message-id="${messageId}"]`);
		if (msgElement) {
			msgElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
			msgElement.classList.add('search-highlight');
			this.lastHighlightedMessageId = messageId;
			setTimeout(() => msgElement.classList.remove('search-highlight'), 1600);
		}
	}

	unhighlightLastMessage() {
		if (this.lastHighlightedMessageId) {
			const prevElem = this.template.querySelector(`[data-message-id="${this.lastHighlightedMessageId}"]`);
			if (prevElem) prevElem.classList.remove('search-highlight');
			this.lastHighlightedMessageId = null;
		}
	}
	handleContactSwitch(event) {
		event.stopPropagation();
		const contactTiles = this.template.querySelector('.contact-tiles-container');
		if (this.showContactTiles) {
			this.closeContactDropdown();
		} else {
			this.showContactTiles = true;
			setTimeout(() => {
				contactTiles.classList.remove('hide');
				contactTiles.classList.add('show');
			}, 0);
		}
	}
	handleContactSelected(event) {
		const record = event.detail;
		const isAccount = record.Type === 'Account';
		const isLead = record.Type === 'Lead';
		const iconName = record.Type === 'Account' ? 'standard:account' : (record.Type === 'Lead' ? 'standard:lead' : 'standard:contact');
		this.selectedContact = {
			...record,
			iconName: iconName
		};
		this.selectedContactId = record.Id;
		this.contactName = record.Name;
		this.validationMessage = '';
		// Use top-level phone if available 
		this.phoneNumber = record.Phone || '';
		this.formattedPhoneNumber = this.phoneNumber?.startsWith('+') ? this.phoneNumber : '+' + this.phoneNumber;
		// When user selected a different record from lookup, fetch that record's details (object + id)
		const objectNameForFetch = record.Type || this.objectApiName;
		const recordIdForFetch = record.Id;
		getRecordDetails({
			objectName: objectNameForFetch,
			recordId: recordIdForFetch,
			phoneField: this.selectedPhoneField
		}).then(result => {
			if (isAccount && result.PhoneFields) {
				// âœ… Build phoneFieldOptions fresh from Account fields 
				this.phoneFieldOptions = Object.keys(result.PhoneFields).map(apiName => ({
					label: apiName.replace(/([A-Z])/g, ' $1').trim(),
					value: apiName
				}));
				// âœ… Format options to include actual phone values 
				this.phoneFieldOptions = this.phoneFieldOptions.map(field => {
					const value = result.PhoneFields[field.value];
					return {
						...field,
						label: `${field.label.split('(')[0].trim()} ${value ? `(${value})` : '(No number)'}`,
					};
				}).filter(f => !f.label.includes('No number'));
				if (this.phoneFieldOptions.length > 0) {
					this.selectedPhoneField = this.phoneFieldOptions[0].value;
					this.phoneNumber = result.PhoneFields[this.selectedPhoneField];
					this.formattedPhoneNumber = this.phoneNumber?.startsWith('+') ? this.phoneNumber : '+' + this.phoneNumber;
				} else {
					this.phoneNumber = '';
					this.formattedPhoneNumber = '';
					this.validationMessage = 'Account has no valid phone number.';
				}
			}
			// Contact or Lead single-record: build phone options from result.PhoneFields
			if ((record.Type === 'Contact' || isLead) && result.PhoneFields) {
				this.phoneFieldOptions = Object.keys(result.PhoneFields).map(apiName => {
					const value = result.PhoneFields[apiName];
					return {
						label: `${apiName.replace(/([A-Z])/g, ' $1').trim()} ${value ? `(${value})` : '(No number)'}`,
						value: apiName
					};
				}).filter(f => !f.label.includes('No number'));
				if (this.phoneFieldOptions.length > 0) {
					this.selectedPhoneField = this.phoneFieldOptions[0].value;
					this.phoneNumber = result.PhoneFields[this.selectedPhoneField] || '';
					this.formattedPhoneNumber = this.phoneNumber?.startsWith('+') ? this.phoneNumber : '+' + this.phoneNumber;
					this.validationMessage = '';
				} else {
					this.phoneNumber = '';
					this.formattedPhoneNumber = '';
					this.validationMessage = (isLead ? 'Lead' : 'Contact') + ' has no valid phone number.';
				}
			}
			if (!isAccount && result.Contacts?.length > 0) {
				const matched = result.Contacts.find(c => c.Id === record.Id);
				if (matched) {
					this.updatePhoneFieldOptions(matched);
				} else {
					this.validationMessage = `No phone data found for ${record.Name}`;
				}
			}
			this.loadMessages();
			this.scrollToBottom();
		}).catch(error => {
			this.validationMessage = 'Error fetching record details';
			console.error(error);
		});
	}

	updatePhoneFieldOptions(contact) {
		// Only include phone fields that have a value on this contact
		this.phoneFieldOptions = Object.keys(contact)
			.filter(key =>
				key !== 'Id' && key !== 'Name' && key !== 'Value' && key !== 'LastMessageDate' &&
				contact[key] && typeof contact[key] === 'string' && contact[key].trim() !== ''
			)
			.map(key => ({
				label: key.replace(/([A-Z])/g, ' $1').trim() + ` (${contact[key]})`,
				value: key
			}));
		if (this.phoneFieldOptions.length > 0) {
			this.selectedPhoneField = this.phoneFieldOptions[0].value;
			this.phoneNumber = contact[this.selectedPhoneField];
			this.formattedPhoneNumber = this.phoneNumber.startsWith('+') ? this.phoneNumber : '+' + this.phoneNumber;
		} else {
			this.validationMessage = 'Selected contact has no valid phone number.';
			this.phoneNumber = '';
			this.formattedPhoneNumber = '';
		}
	}

	handleContactFromLookup(event) {
		const contact = event.detail;
		this.handleContactSelection(contact);
	}
	setDefaultDate() {
		const today = new Date();
		const year = today.getFullYear();
		const month = String(today.getMonth() + 1).padStart(2, '0');
		const day = String(today.getDate()).padStart(2, '0');
		this.selectedDate = `${year}-${month}-${day}`;
	}

	disconnectedCallback() {
		this.handleUnSubscribe();
	}
	handleUnSubscribe() {
		if (this.subscription) {
			unsubscribe(this.subscription);
			this.subscription = null;
		}
	}
	handleSubscribe() {
		subscribe(this.eventName, -1, this.handleSubscribeResponse.bind(this))
			.then((response) => {
				this.subscription = response;

			});
	}
	handleSubscribeResponse(response) {
		//console.log('Handle Subscribe');
		//console.log(JSON.stringify(this.messages));
		let data = response.data.payload;
		let messageId = data.SmartMsg__Record_Id__c;
		//let customerPhone = data.SmartMsg__Channel__c == 'SMS' ? data.SmartMsg__From_Number__c : '+' + data.SmartMsg__From_Number__c;
		let customerPhone = data.SmartMsg__From_Number__c;
		// console.log('customerPhone ---> ', customerPhone);
		// console.log('this.phoneNumber ---> ', this.phoneNumber);
		// console.log(response)
		// console.log('customerPhones ---> ', customerPhones);
		let eventType = data.SmartMsg__Event_Type__c;
		let smsStatus = data.SmartMsg__Delivery_Status__c;
		//console.log('smsStatus ',smsStatus);
		if (this.phoneNumber === customerPhone && eventType == 'Inbound') {
			getSingleMessage({
				recordId: messageId,
				customerPhone: customerPhone
			})
				.then((response) => {
					try {
						if (response) {
							const updatedResponse = Object.assign({}, response, {
								Outgoing: response.SmartMsg__Type__c === 'Outbound',
								Incoming: response.SmartMsg__Type__c === 'Inbound' && response.SmartMsg__Delivery_Status__c === 'Received',
								formattedTime: this.formatTime(response.SmartMsg__Sent_Date_and_Time__c),
								isSMS: response.SmartMsg__Channel__c === 'SMS',
								isWhatsApp: response.SmartMsg__Channel__c === 'WhatsApp',
								sent: response.SmartMsg__Delivery_Status__c === 'Sent',
								delivered: response.SmartMsg__Delivery_Status__c === 'Delivered',
								isImage: response.SmartMsg__File_Name__c &&
									(response.SmartMsg__File_Name__c.toLowerCase().endsWith('.jpeg') ||
										response.SmartMsg__File_Name__c.toLowerCase().endsWith('.jpg') ||
										response.SmartMsg__File_Name__c.toLowerCase().endsWith('.png') ||
										response.SmartMsg__File_Name__c.endsWith('.webp')),
								isPdf: response.SmartMsg__File_Name__c && response.SmartMsg__File_Name__c.endsWith('.pdf'),
								isVideo: response.SmartMsg__File_Name__c && (response.SmartMsg__File_Name__c.endsWith('.mp4') || response.SmartMsg__File_Name__c.endsWith('.mov')),
								isAudio: response.SmartMsg__File_Name__c && (response.SmartMsg__File_Name__c.endsWith('.mp3') || response.SmartMsg__File_Name__c.endsWith('.wav') || response.SmartMsg__File_Name__c.endsWith('.aac')),
								imageUrl: response.SmartMsg__Media_Url__c ? `/sfc/servlet.shepherd/document/download/${response.SmartMsg__Media_Url__c}` : null,
								isLocation: response.SmartMsg__Location_Latitude__c && response.SmartMsg__Location_Longitude__c,
								locationName: response.SmartMsg__Location_Name__c || 'Shared a location',
								locationAddress: response.SmartMsg__Location_Address__c || '',
								latitude: response.SmartMsg__Location_Latitude__c,
								longitude: response.SmartMsg__Location_Longitude__c,
								locationUrl: response.SmartMsg__Location_Latitude__c && response.SmartMsg__Location_Longitude__c
									? `https://www.google.com/maps/search/?api=1&query=${response.SmartMsg__Location_Latitude__c},${response.SmartMsg__Location_Longitude__c}`
									: '',
							});
							// Avoid duplicate: only add if this message Id is not already in the list (e.g. same event delivered twice or loadMessages not yet run)
							const alreadyPresent = (this.messages || []).some(m => m.Id === (response.Id || messageId));
							if (alreadyPresent) {
								return;
							}
							this.messages.push(updatedResponse);
							this.messages = [...this.messages];
							 if (this.messages.length === 0) {
								this.noMessagesFound = true;
							} else {
								this.noMessagesFound = false;
							}
							if (this.selectedOption == 'WhatsApp') {
								this.checkReengagementMessage();
							}
							this.groupMessagesByDate();
							this.scrollToBottom();
						} else {
							//console.log('Empty message received');
						}
					} catch (innerErr) {
						//console.log('Error in .then() block:', innerErr);
					}
				})
				.catch((error) => {
					//console.log(Error)
					// console.log('Error While Receiving the Platform Event Message:', JSON.stringify(error));
				});
		} else if (eventType === 'Outbound') {
			//console.log('Inside of elsee');
			//console.log('Message Record ',JSON.stringify(this.messages));
			const messageIndex = this.messages.findIndex(msg => msg.Id === messageId);
			//console.log('messageIndex ---> ',messageIndex);
			if (messageIndex !== -1) {
				// Update message status (SMS/WhatsApp); include failed reason for tooltip when status is Failed
				const sentTime = data.SmartMsg__Sent_Date_and_Time__c || response.SmartMsg__Sent_Date_and_Time__c;
				this.messages[messageIndex] = {
					...this.messages[messageIndex],
					Scheduled : false,
					sent : smsStatus === 'Sent',
					delivered: smsStatus === 'Delivered',
					isFailed: smsStatus === 'Failed',
					...(smsStatus === 'Failed' && data.SmartMsg__Failed_Reason__c != null && { SmartMsg__Failed_Reason__c: data.SmartMsg__Failed_Reason__c }),
					formattedTime: this.formatTime(sentTime)
				};
				this.messages = [...this.messages];
				//console.log('Message Record 2 : ',JSON.stringify(this.messages));
			}
		}
		//console.log('Method from handleSubscribeResponse');
		this.loadMessages();
	}
	handleErrorRegister() {
		onError((error) => {
			console.error('Received error from server: ', JSON.stringify(error));
		});
	}
	retrieveRecordDetails() {
		//console.log('this.selectedPhoneField ---> ',this.selectedPhoneField);
		getRecordDetails({
			objectName: this.objectApiName,
			recordId: this.recordId,
			phoneField: this.selectedPhoneField
		})
			.then(result => {
				if (!result) return;
				if (this.objectApiName === 'Account' && result.PhoneFields) {
					this.selectedContact = {
						Id: this.recordId,
						Name: result.Name,
						Type: 'Account',
						iconName: 'standard:account',
						...result.PhoneFields
					};
					this.selectedContactId = this.recordId;
					this.contactName = result.Name;
					// Build phone field options from Account fields
					this.phoneFieldOptions = Object.keys(result.PhoneFields).map(apiName => ({
						label: apiName.replace(/([A-Z])/g, ' $1').trim(),
						value: apiName
					})).map(field => {
						const value = result.PhoneFields[field.value];
						return {
							...field,
							label: `${field.label.split('(')[0].trim()} ${value ? `(${value})` : '(No number)'}`
						};
					}).filter(f => !f.label.includes('No number'));
					if (this.phoneFieldOptions.length > 0) {
						this.selectedPhoneField = this.phoneFieldOptions[0].value;
						this.phoneNumber = result.PhoneFields[this.selectedPhoneField];
						this.formattedPhoneNumber = this.phoneNumber?.startsWith('+')
							? this.phoneNumber
							: '+' + this.phoneNumber;
					} else {
						this.validationMessage = 'Account has no valid phone number.';
						this.phoneNumber = '';
						this.formattedPhoneNumber = '';
					}
					this.loadMessages();
					return;
				}
				// 2. If on Opportunity, select the first related Contact (existing behavior)
				if (this.objectApiName === 'Opportunity' && result.Contacts && result.Contacts.length > 0) {
					const defaultContact = result.Contacts[0];
					this.selectedContact = {
						...defaultContact,
						iconName: 'standard:contact'
					};
					this.selectedContactId = defaultContact.Id;
					this.contactName = defaultContact.Name;
					this.phoneNumber = defaultContact[this.selectedPhoneField] || '';
					this.formattedPhoneNumber = this.phoneNumber.startsWith('+')
						? this.phoneNumber
						: '+' + this.phoneNumber;
					this.phoneFieldOptions = this.phoneFieldOptions.map(field => {
						const phoneValue = defaultContact[field.value];
						return {
							...field,
							label: `${field.label.split('(')[0].trim()} ${phoneValue ? `(${phoneValue})` : '(No number)'}`
						};
					}).filter(f => !f.label.includes('No number'));
					if (this.phoneFieldOptions.length > 0) {
						this.selectedPhoneField = this.phoneFieldOptions[0].value;
						this.phoneNumber = defaultContact[this.selectedPhoneField];
						this.formattedPhoneNumber = this.phoneNumber?.startsWith('+')
							? this.phoneNumber
							: '+' + this.phoneNumber;
					} else {
						this.validationMessage = 'Selected contact has no valid phone number.';
						this.phoneNumber = '';
						this.formattedPhoneNumber = '';
					}
					this.loadMessages();
					return;
				}
				if (this.objectApiName === 'Contact' && result.PhoneFields) {
					this.selectedContactId = this.recordId;
					this.selectedContact = {
						Id: this.recordId,
						Name: result.Name,
						Type: 'Contact',
						iconName: 'standard:contact',
						...result.PhoneFields
					};
					this.contactName = result.Name;
					this.phoneFieldOptions = this.phoneFieldOptions.map(field => {
						const phoneValue = result.PhoneFields[field.value];
						return {
							...field,
							label: `${field.label.split('(')[0].trim()} ${phoneValue ? `(${phoneValue})` : '(No number)'}`
						};
					}).filter(f => !f.label.includes('No number'));
					const selectedPhoneNumber = result.PhoneFields[this.selectedPhoneField];
					if (selectedPhoneNumber) {
						this.phoneNumber = selectedPhoneNumber;
						this.formattedPhoneNumber = selectedPhoneNumber.startsWith('+')
							? selectedPhoneNumber
							: '+' + selectedPhoneNumber;
						//console.log('Method called from retrieveRecordDetails ')
						this.loadMessages();
					} else {
						this.phoneNumber = '';
						this.formattedPhoneNumber = '';
						this.validationMessage = `No ${this.selectedPhoneField} available`;
					}
					return;
				}
				if (this.objectApiName === 'Lead' && result.PhoneFields) {
					this.selectedContactId = this.recordId;
					this.selectedContact = {
						Id: this.recordId,
						Name: result.Name,
						Type: 'Lead',
						iconName: 'standard:lead',
						...result.PhoneFields
					};
					this.contactName = result.Name;
					this.phoneFieldOptions = Object.keys(result.PhoneFields).map(apiName => {
						const value = result.PhoneFields[apiName];
						return {
							label: `${apiName.replace(/([A-Z])/g, ' $1').trim()} ${value ? `(${value})` : '(No number)'}`,
							value: apiName
						};
					}).filter(f => !f.label.includes('No number'));

					if (this.phoneFieldOptions.length > 0) {
						this.selectedPhoneField = this.phoneFieldOptions[0].value;
						this.phoneNumber = result.PhoneFields[this.selectedPhoneField];
						this.formattedPhoneNumber = this.phoneNumber?.startsWith('+')
							? this.phoneNumber
							: '+' + this.phoneNumber;
					} else {
						this.phoneNumber = '';
						this.formattedPhoneNumber = '';
						this.validationMessage = 'Lead has no valid phone number.';
					}

					this.loadMessages();
					return;
				}
			})
			.catch(error => {
				console.error('Error fetching record details:', error);
			});
	}
	get defaultSelectedOption() {
		if (this.objectApiName === 'Account') return 'Account';
		if (this.objectApiName === 'Contact') return 'Contact';
		if (this.objectApiName === 'Opportunity') return 'Account'; // Or 'Contact' as per your logic
		if (this.objectApiName === 'Lead') return 'Lead';
		return 'Contact';
	}
	populatePhoneFieldOptions() {
		if (this.objectInfo.data) {
			const fields = this.objectInfo.data.fields;
			this.phoneFieldOptions = Object.keys(fields)
				.filter(fieldName => fields[fieldName].dataType === 'Phone')
				.map(fieldName => ({
					label: fields[fieldName].label,
					value: fieldName
				}));
		} else {
			//console.error('Object info data not available.'); 
		}
	}
	handleFieldSelection(event) {
		this.selectedPhoneField = event.detail.value;
		this.phoneFieldError = false;
	}
	handleTwilioFromNumberChange(event) {
		this.selectedTwilioFromNumber = event.detail.value || '';
		if (this.selectedOption === 'WhatsApp') {
			this.refreshMessagesForSelectedChannel();
		}
	}

	createOrCheckSmartMsgRecord() {
		if (!this.formattedPhoneNumber || this.selectedOption !== 'WhatsApp') return;
		ensureChatbotMessage({ phoneNumber: this.formattedPhoneNumber })
			.then(result => {
				if (result) {
					this.isAutoReplyEnabled = result.chatBotActive === 'true';
					this.isAutoReplyEnabledId = result.recordId;
				}
			})
			.catch(error => {
				console.error('Error in ensureChatbotMessage', error);
			});
	}

	handleAutoReplyChange(event) {
		const newValue = event.target.checked;
		this.isAutoReplyEnabled = newValue;
		if (!this.isAutoReplyEnabledId) return;
		const fields = {
			Id: this.isAutoReplyEnabledId,
			SmartMsg__Chatbot_on_off__c: newValue
		};
		updateRecord({ fields })
			.then(() => {
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Success',
						message: 'ChatBot ' + (newValue === true ? 'Activated.' : newValue === false ? 'Deactivated.' : 'setting updated.'),
						variant: 'success'
					})
				);
			})
			.catch(error => {
				this.isAutoReplyEnabled = !newValue;
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Error updating Auto Reply',
						message: error.body?.message || error.message,
						variant: 'error'
					})
				);
			});
	}

	loadMessages() {
		this.messages = [];
		// console.log('Message size : ',this.messages.length);
		this.isLoading = true;
		const smsPromise = listAllMessages({
			phoneNumber: this.formattedPhoneNumber
		});
		const whatsappPromise = listWAMessages({
			customerPhone: this.phoneNumber
		});
		Promise.all([smsPromise, whatsappPromise])
			.then(([smsResult, whatsappResult]) => {
				const formattedSMSMessages = this.formatMessages(smsResult);
				const formattedWhatsAppMessages = this.formatWhatsAppMessages(whatsappResult);
				let combinedMessages = [...formattedSMSMessages, ...formattedWhatsAppMessages].sort((a, b) => {
					return new Date(a.CreatedDate) - new Date(b.CreatedDate);
				});
				// Deduplicate by Id so the same message never appears multiple times (e.g. if API returns duplicates)
				const seenIds = new Set();
				combinedMessages = combinedMessages.filter(m => {
					const id = m.Id;
					if (!id || seenIds.has(id)) return false;
					seenIds.add(id);
					return true;
				});
				this.allMessages = combinedMessages.map(msg => ({
					...msg,
					starLabel: msg.SmartMsg__Starred__c ? 'Unstar Message' : 'Star Message',
					pinLabel: msg.SmartMsg__Pinned__c ? 'Unpin Message' : 'Pin Message'

				}));
				this.refreshMessagesForSelectedChannel();
				this.setDefaultFromNumberFromInboundMessages(combinedMessages);
				this.refreshMessagesForSelectedChannel();
				this.shouldScrollToBottom = true;
				if (this.searchScroll) {
					this.scrollToBottom();
				}
				this.searchScroll = true;
				this.isLoading = false;
				this.isSpinner = false;
				if (this.selectedOption === 'WhatsApp' && this.formattedPhoneNumber) {
					this.createOrCheckSmartMsgRecord();
				}
			})
			.catch(error => {
				if (error && error.body && error.body.message) {
					console.error('Apex error message:', error.body.message);
				} else if (error && error.message) {
					console.error('JS error message:', error.message);
				} else {
					console.error('Unknown error in fallback loadMessages Method:', error);
				}
				this.errordetails = error;
				this.isLoading = false;
				const errMsg = (error && error.body && error.body.message) ? error.body.message : (error && error.message) ? error.message : 'An error occurred while loading messages.';
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Error',
						message: errMsg,
						variant: 'error'
					})
				);
			});
			// console.log('End of Load messages method Message size : ',this.messages.length);
	}

	normalizePhoneForCompare(phone) {
		if (phone == null || phone === '') return '';
		const s = String(phone).trim();
		return s.replace(/^\+/, '').replace(/\D/g, '') || s;
	}

	/**
	 * Sets the default Twilio "from" number in the UI from existing inbound message records.
	 * Uses SmartMsg__From_Number__c from the most recent inbound (WhatsApp) message when it appears in twilioFromNumberOptions.
	 */
	setDefaultFromNumberFromInboundMessages(combinedMessages) {
		if (!combinedMessages || combinedMessages.length === 0) return;
		if (this.activeWhatsAppChannel !== 'Twilio WhatsApp' || !this.twilioFromNumberOptions || this.twilioFromNumberOptions.length === 0) return;

		const inboundWhatsApp = combinedMessages
			.filter(m => (m.SmartMsg__Type__c === 'Inbound') && (m.isWhatsApp || (m.SmartMsg__Channel__c && (m.SmartMsg__Channel__c === 'WhatsApp' || m.SmartMsg__Channel__c === 'Twilio WhatsApp'))))
			.filter(m => m.SmartMsg__From_Number__c != null && m.SmartMsg__From_Number__c !== '')
			.sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate));

		const fromNumberFromInbound = inboundWhatsApp.length > 0 ? inboundWhatsApp[0].SmartMsg__From_Number__c : null;
		if (!fromNumberFromInbound) return;

		const inboundNorm = this.normalizePhoneForCompare(fromNumberFromInbound);
		const matchingOption = this.twilioFromNumberOptions.find(opt => this.normalizePhoneForCompare(opt.value) === inboundNorm);
		if (matchingOption) {
			this.selectedTwilioFromNumber = matchingOption.value;
		}
	}

	refreshMessagesForSelectedChannel() {
		const source = (this.allMessages && this.allMessages.length) ? this.allMessages : (this.messages || []);
		const selected = (this.selectedOption || '').toLowerCase();
		let filtered = source;

		if (selected === 'sms') {
			filtered = source.filter(m => (m.SmartMsg__Channel__c || '').toLowerCase() === 'sms');
		} else if (selected === 'whatsapp') {
			filtered = source.filter(m => {
				const c = (m.SmartMsg__Channel__c || '').toLowerCase();
				return c === 'whatsapp' || c === 'twilio whatsapp';
			});
			// When Twilio WhatsApp is active and a from number is selected, show only messages for that from number
			if (this.activeWhatsAppChannel === 'Twilio WhatsApp' && this.selectedTwilioFromNumber) {
				const selectedNorm = this.normalizePhoneForCompare(this.selectedTwilioFromNumber);
				if (selectedNorm) {
					filtered = filtered.filter(m => {
						const msgFrom = this.normalizePhoneForCompare(m.SmartMsg__From_Number__c);
						return msgFrom === selectedNorm;
					});
				}
			}
		}
		// Deduplicate by Id so each message appears only once in the UI
		const messageIdsSeen = new Set();
		filtered = filtered.filter(m => {
			const id = m.Id;
			if (!id || messageIdsSeen.has(id)) return false;
			messageIdsSeen.add(id);
			return true;
		});

		this.messages = filtered;

		// Check if no messages for the selected channel
		this.noMessagesFound = this.messages.length === 0;

		// Resolve pinned message only within selected channel
		this.pinnedMessageId = null;
		for (const msg of this.messages) {
			if (msg.SmartMsg__Pinned__c === true) {
				this.pinnedMessageId = msg.Id;
				break; // stop after first match
			}
		}

		const visibleMessages = this.showStarredOnly ? this.messages.filter(msg => msg.SmartMsg__Starred__c) : this.messages;
		this.noStarredMessage = this.showStarredOnly && visibleMessages.length === 0;
		this.groupByDate(visibleMessages);
		this.checkReengagementMessage();
	}
	groupByDate(messages) {
		let grouped = [];
		const seen = new Set(); // âœ… Track message.Id to avoid duplicate render
		messages.forEach(message => {
			if (!message.CreatedDate || seen.has(message.Id)) {
				return; // Skip if already processed
			}
			seen.add(message.Id);
			const date = new Date(message.CreatedDate);
			const options = {
				day: 'numeric',
				month: 'short',
				year: 'numeric',
				timeZone: this.userTimeZone
			};
			const messageDate = new Intl.DateTimeFormat('en-US', options).format(date);
			let dateGroup = grouped.find(group => group.date === messageDate);
			if (!dateGroup) {
				dateGroup = {
					date: messageDate,
					messages: [],
					key: grouped.length
				};
				grouped.push(dateGroup);
			}
			dateGroup.messages.push(message);
		});
		this.groupedMessages = [...grouped];
	}
	searchScroll = true;
	toggleSearch() {
		this.searchScroll = false;
		this.loadMessages();
		const searchBar = this.template.querySelector('.search-bar');
		const chatArea = this.template.querySelector('.chat-Area');
		if (!this.isSearchActive) {
			this.isSearchActive = true;
			if (searchBar == null) {
				try {
					searchBar.classList.remove('slide-out'); // Remove the slide-out animation class 
					searchBar.style.display = 'flex'; // Ensure the search bar is visible 
					setTimeout(() => {
						searchBar.classList.add('slide-in'); // Add slide-in animation class 
					}, 10); // Slight delay for the animation to register 
				} catch (error) {
					console.error(error);
				}
				chatArea.style.paddingTop = '50px';
				if (/ipad|iphone/i.test(navigator.userAgent)) {
					chatArea.style.paddingTop = '65px';
				}
			}
		} else {
			if (searchBar) {
				searchBar.classList.remove('slide-in'); // Remove the slide-in animation class 
				searchBar.classList.add('slide-out'); // Add the slide-out animation class 
				setTimeout(() => {
					this.isSearchActive = false;
					this.searchQuery = ''; // Clear the search query 
					this.filteredMessages = [...this.messages]; // Reset the filtered messages 
					searchBar.style.display = 'none'; // Hide the search bar 
				}, 300); // Match this to the animation duration (0.3s) 

				chatArea.style.paddingTop = '10px';
				if (/ipad|iphone/i.test(navigator.userAgent)) {
					chatArea.style.paddingTop = '10px';
				}
			}
		}
	}
	handleRefresh() {
		this.isSpinner = true;
		const refreshIcon = this.template.querySelector('.refresh-icon');
		if (refreshIcon) {
			refreshIcon.classList.add('rotate');
			setTimeout(() => {
				refreshIcon.classList.remove('rotate'); // Remove the class after animation 
			}, 500); // Match the duration of the rotation animation 
		}
		//console.log('Method called from handle refresh')
		this.loadMessages();
	}

	handleMenuSelect(event) {
		// console.log('Handle menu select');
		const value = event.detail.value;
		// console.log('value : ',value)
		if (value === 'starred') {
			this.showStarredOnly = !this.showStarredOnly;
			//console.log('Method called from handle Menu select')
			this.loadMessages();
		} else if (value === 'pinned') {
			this.showPinnedBanner = !this.showPinnedBanner;
		} else if (value === 'download') {
			this.downloadTranscript();
		} else if (value === 'search') {
			this.toggleSearch();
		}
		else if (value === 'refresh') {
			//console.log('handleRefresh method called')
			this.handleRefresh();
		}
		// add this
		else if (value === 'about') {
			// Replace with your actual PDF URL
			// console.log('About button clicked');
			//console.log('featureDocUrl -->',this.featureDocUrl);
			window.open(Feature_Document, '_blank');
		}

	}

	downloadTranscript() {
		let content = '';
		this.messages.forEach(msg => {
			const time = msg.formattedTime || '';
			const sender = msg.Outgoing ? 'You' : (this.contactName || msg.senderName || 'Contact');
			const body = msg.SmartMsg__Message_Body__c || '';
			content += `[${time}] ${sender}: ${body}\n`;
		});
		// Create a Blob and trigger download 
		const blob = new Blob([content], {
			type: 'text/plain'
		});
		const url = URL.createObjectURL(blob);
		// Create an anchor and click it 
		const a = document.createElement('a');
		a.href = url;
		a.download = `${this.contactName || 'chat'}-transcript.txt`;
		document.body.appendChild(a);
		a.click();
		document.body.removeChild(a);
		URL.revokeObjectURL(url);
	}
	checkReengagementMessage() {
		try {
			this.messages = this.messages || [];

			// Only applicable for WhatsApp channel
			if (this.selectedOption !== 'WhatsApp') {
				this.showReengagementPopup = false;
				return;
			}

			const now = new Date();

			// Last INBOUND WhatsApp message (by type only - any delivery status).
			// For Twilio WhatsApp, this.messages is already filtered by selected from number in refreshMessagesForSelectedChannel.
			const isWhatsAppChannel = (msg) => {
				const ch = (msg.SmartMsg__Channel__c || '').toLowerCase();
				return ch === 'whatsapp' || ch === 'twilio whatsapp';
			};
			const isInbound = (msg) => (msg.SmartMsg__Type__c || '') === 'Inbound';

			const lastWhatsAppMessage = this.messages
				.filter(msg => isInbound(msg) && isWhatsAppChannel(msg))
				.sort((a, b) => new Date(a.CreatedDate) - new Date(b.CreatedDate))
				.pop();

			// No inbound message for this conversation (for Twilio: for this from number + to number) means no
			// conversation within 24h window → show 24h limit popup so user must use template to message.
			if (!lastWhatsAppMessage || !lastWhatsAppMessage.CreatedDate) {
				this.showReengagementPopup = true;
				return;
			}

			const lastMessageDate = new Date(lastWhatsAppMessage.CreatedDate);
			const diffInHours = (now.getTime() - lastMessageDate.getTime()) / (1000 * 60 * 60);

			// Show popup when last inbound WhatsApp message is more than 24 hours ago
			this.showReengagementPopup = diffInHours > 24;
		} catch (e) {
			this.showReengagementPopup = false;
		}
	}
	toggleShowStarred() {
		this.showStarredOnly = !this.showStarredOnly;
		this.refreshMessagesForSelectedChannel();
	}
	groupMessagesByDate() {
		let source = this.showStarredOnly ? this.messages.filter(m => m.isStarred) : this.messages;
		const grouped = source.reduce((acc, message) => {
			const messageDate = new Date(message.CreatedDate);
			let dateKey;
			const today = new Date();
			const yesterday = new Date(today);
			yesterday.setDate(today.getDate() - 1);
			if (messageDate.toDateString() === today.toDateString()) {
				dateKey = 'Today';
			} else if (messageDate.toDateString() === yesterday.toDateString()) {
				dateKey = 'Yesterday';
			} else {
				dateKey = messageDate.toLocaleDateString('en-GB', {
					weekday: 'short',
					day: '2-digit',
					month: 'short',
					year: 'numeric'
				});
			}
			if (!acc[dateKey]) {
				acc[dateKey] = [];
			}
			acc[dateKey].push(message);
			return acc;
		}, {});
		this.groupedMessages = Object.keys(grouped).map(date => {
			return {
				date: date,
				messages: grouped[date]
			};
		});
	}

	formatMessages(messages) {
		return messages.map(message => {
			const formattedScheduledTime = message.SmartMsg__Scheduled_Date_Time__c != null ? this.formatScheduledTime(message.SmartMsg__Scheduled_Date_Time__c) : null;
			const messageScheduledTime = this.formatTime(message.CreatedDate);
			return {
				...message,
				Outgoing: message.SmartMsg__Type__c == 'Outbound' ? true : false,
				Incoming: message.SmartMsg__Type__c === 'Inbound' && message.SmartMsg__Delivery_Status__c === 'Received' ? true : false,
				sent: message.SmartMsg__Delivery_Status__c == 'Sent' ? true : false,
				delivered: message.SmartMsg__Delivery_Status__c == 'Delivered' ? true : false,
				Scheduled: message.SmartMsg__Delivery_Status__c == 'Scheduled' ? true : false,
				isSMS: message.SmartMsg__Channel__c == 'SMS' ? true : false,
				isWhatsApp: message.SmartMsg__Channel__c == 'WhatsApp' ? true : false,
				isFailed: message.SmartMsg__Delivery_Status__c == 'Failed' ? true : false,
				formattedTime: this.formatTime(message.SmartMsg__Sent_Date_and_Time__c ? message.SmartMsg__Sent_Date_and_Time__c : message.CreatedDate),
				senderName: message.CreatedBy ? message.CreatedBy.Name : 'Unknown User',
				// Setting the isImage flag and image URL based on the Media_Url__c and File_Content__c fields 
				isImage: message.SmartMsg__File_Name__c &&
					(message.SmartMsg__File_Name__c.toLowerCase().endsWith('.jpeg') ||
						message.SmartMsg__File_Name__c.toLowerCase().endsWith('.jpg') ||
						message.SmartMsg__File_Name__c.toLowerCase().endsWith('.png') ||
						message.SmartMsg__File_Name__c.endsWith('.webp')),
				isMedia: message.SmartMsg__Media_Url__c ? true : false,
				isPdf: message.SmartMsg__File_Name__c && message.SmartMsg__File_Name__c.endsWith('.pdf'),
				isVideo: message.SmartMsg__File_Name__c && (message.SmartMsg__File_Name__c.endsWith('.mp4') || message.SmartMsg__File_Name__c.endsWith('.mov')),
				isAudio: message.SmartMsg__File_Name__c && (message.SmartMsg__File_Name__c.endsWith('.mp3') || message.SmartMsg__File_Name__c.endsWith('.wav') || message.SmartMsg__File_Name__c.endsWith('.aac')),
				imageUrl: message.SmartMsg__Media_Url__c ? `/sfc/servlet.shepherd/document/download/${message.SmartMsg__Media_Url__c}` : null,
				pinIconVariant: this.pinnedMessageId === message.Id ? 'brand' : 'border-filled',
				starIconName: this.starredMessageIds.includes(message.Id) ? 'utility:favorite' : 'utility:favorite',
				starIconVariant: this.starredMessageIds.includes(message.Id) ? 'brand' : 'border-filled',
				showMenu: false,
				isPinned: message.SmartMsg__Pinned__c ? true : false,
				pinLabel: this.pinnedMessageId === message.Id ? 'Unpin Message' : 'Pin Message',
				isStarred: message.SmartMsg__Starred__c == true ? true : false,
				starLabel: this.starredMessageIds.includes(message.Id) ? 'Unstar Message' : 'Star Message',
				base64ImageUrl: message.SmartMsg__File_Content__c ? `data:image/png;base64,${message.SmartMsg__File_Content__c}` : '',
				showRetryIcon: message.SmartMsg__Retry_Count__c >= 3 && message.SmartMsg__Delivery_Status__c === 'Failed' ? true : false,
				formattedScheduledTime: formattedScheduledTime,
				messageScheduledTime: messageScheduledTime

			};

		});
	}
	get formattedScheduledTime() {
		return this.messages.map(message => this.formatScheduledTime(message.SmartMsg__Scheduled_Date_Time__c));
	}
	get formattedTime() {
		return this.messages.map(message => this.formatTime(message.dateTime));
	}
	formatScheduledTime(scheduledTime) {
		if (!scheduledTime) return '';
		const scheduledDateandTime = new Date(scheduledTime);
		const options = {
			weekday: 'long',
			month: 'short',
			day: '2-digit',
			hour: '2-digit',
			minute: '2-digit',
			hour12: true
		};
		const formattedScheduledDateTime = new Intl.DateTimeFormat('en-US', options).format(scheduledDateandTime);
		return `${formattedScheduledDateTime}`;
	}
	formatTime(dateTimeString) {
		if (!dateTimeString) return ''; // Handle null or empty values 
		// Parse the UTC datetime string into a Date object 
		const utcDate = new Date(dateTimeString);
		// Use Intl.DateTimeFormat with the user's Salesforce time zone 
		const options = {
			hour: '2-digit',
			minute: '2-digit',
			hour12: true, // AM/PM format 
			timeZone: this.userTimeZone // Use the Salesforce user's time zone 
		};
		// Format and return the time 
		return new Intl.DateTimeFormat('en-US', options).format(utcDate);
	}
	formatWhatsAppMessages(messages) {
		const messageIdMap = {};
		messages.forEach(msg => {
			if (msg.SmartMsg__Message_ID__c) {
				messageIdMap[msg.SmartMsg__Message_ID__c.trim()] = msg;
			}

		});
		return messages.map(message => {
			const WAScheduledTime = message.SmartMsg__Delivery_Status__c === 'Scheduled' ? this.formatScheduledTime(message.SmartMsg__Scheduled_Date_Time__c) : '';
			//console.log('WAScheduledTime ---> ', WAScheduledTime);
			const isSalesforceFile = message.SmartMsg__Media_Url__c && !message.SmartMsg__Media_Url__c.startsWith('http');
			const parentMessageId = message.SmartMsg__Parent_Message_Id__c?.trim();
			const parentMessage = parentMessageId ? messageIdMap[parentMessageId] : null;
			const formattedMessage = {
				...message,
				Outgoing: message.SmartMsg__Type__c === 'Outbound' ? true : false,
				Incoming: message.SmartMsg__Type__c === 'Inbound' && message.SmartMsg__Delivery_Status__c === 'Received' ? true : false,
				Scheduled: message.SmartMsg__Type__c === 'Outbound' && message.SmartMsg__Delivery_Status__c === 'Scheduled' ? true : false,
				sent: message.SmartMsg__Delivery_Status__c == 'Sent' ? true : false,
				delivered: message.SmartMsg__Delivery_Status__c == 'Delivered' ? true : false,
				read: message.SmartMsg__Delivery_Status__c == 'Read' ? true : false,
				isSMS: message.SmartMsg__Channel__c === 'SMS' ? true : false,
				isWhatsApp: message.SmartMsg__Channel__c === 'WhatsApp' || message.SmartMsg__Channel__c === 'Twilio WhatsApp' ? true : false,
				formattedTime: this.formatTime(message.CreatedDate),
				WAScheduledTime: WAScheduledTime,
				isImage: message.SmartMsg__File_Name__c &&
					(message.SmartMsg__File_Name__c.toLowerCase().endsWith('.jpeg') ||
						message.SmartMsg__File_Name__c.toLowerCase().endsWith('.jpg') ||
						message.SmartMsg__File_Name__c.toLowerCase().endsWith('.png') ||
						message.SmartMsg__File_Name__c.endsWith('.webp')),
				isPdf: message.SmartMsg__File_Name__c && message.SmartMsg__File_Name__c.endsWith('.pdf'),
				isVideo: message.SmartMsg__File_Name__c && (message.SmartMsg__File_Name__c.endsWith('.mp4') || message.SmartMsg__File_Name__c.endsWith('.mov')),
				isAudio: message.SmartMsg__File_Name__c && (message.SmartMsg__File_Name__c.endsWith('.mp3') || message.SmartMsg__File_Name__c.endsWith('.wav') || message.SmartMsg__File_Name__c.endsWith('.aac')),
				isMedia: message.SmartMsg__Media_Url__c ? true : false,
				imageUrlIsSalesforce: isSalesforceFile,
				imageUrl: isSalesforceFile ? `/sfc/servlet.shepherd/document/download/${message.SmartMsg__Media_Url__c}` : null,
				//imageUrl: message.SmartMsg__Media_Url__c?.startsWith('http') ? message.SmartMsg__Media_Url__c : `/sfc/servlet.shepherd/document/download/${message.SmartMsg__Media_Url__c}`,
				isLocation: message.SmartMsg__Location_Latitude__c && message.SmartMsg__Location_Longitude__c ? true : false,
				locationName: message.SmartMsg__Location_Name__c || 'Shared a location',
				locationAddress: message.SmartMsg__Location_Address__c || '',
				latitude: message.SmartMsg__Location_Latitude__c,
				longitude: message.SmartMsg__Location_Longitude__c,
				locationUrl: message.SmartMsg__Location_Latitude__c && message.SmartMsg__Location_Longitude__c ? `https://www.google.com/maps/search/?api=1&query=${message.SmartMsg__Location_Latitude__c},${message.SmartMsg__Location_Longitude__c}` : '',
				isLocationRequest: message.SmartMsg__Message_Type__c === 'location-request',
				pinIconVariant: this.pinnedMessageId === message.Id ? 'brand' : 'border-filled',
				starIconName: this.starredMessageIds.includes(message.Id) ? 'utility:favorite' : 'utility:favorite',
				starIconVariant: this.starredMessageIds.includes(message.Id) ? 'brand' : 'border-filled',
				isPinned: this.pinnedMessageId === message.Id,
				pinLabel: this.pinnedMessageId === message.Id ? 'Unpin Message' : 'Pin Message',
				isStarred: message.SmartMsg__Starred__c ? true : false,
				starLabel: message.SmartMsg__Starred__c ? 'Unstar Message' : 'Star Message',
				showMenu: false,
				isFailed: message.SmartMsg__Delivery_Status__c == 'Failed' ? true : false,
				formattedScheduledTime: WAScheduledTime,
				parentMessage: parentMessage ? { body: parentMessage.SmartMsg__Message_Body__c, type: parentMessage.SmartMsg__Message_Type__c, isMedia: !!parentMessage.SmartMsg__Media_Url__c } : null
			};
			if (message.SmartMsg__Delivery_Status__c == 'Failed') {
				const data = message.SmartMsg__Response__c
			}
			// console.log('formattedMessage : '+JSON.stringify(formattedMessage));
			return formattedMessage;
		});
	}
	handleMessageInputChange(event) {
		this.undoStack.push(this.messageText);
		this.messageText = event.target.value || '';
		if (this.selectedOption == 'WhatsApp') {
			if (this.isAutoReplyEnabled) {
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Warning',
						message: 'You can not send direct Message, as Chatbot is active.',
						variant: 'warning',
						mode: 'dismissible'
					})
				);
			}
			this.limitMessage = false;
			this.isLocationRequest = /location/i.test(this.messageText.trim());
			this.scrollToBottom();
		} else {
			this.limitMessage = true;
			if (this.messageText.length >= 500) {
				this.characterLength = this.messageText.length;
				this.inputerrorMessage = 'Character Limit exceeded';
			}
			else {
				this.characterLength = this.messageText.length;
				this.inputerrorMessage = '';
			}
		}
		this.scrollToBottom();
		if (this.messageText == '') {
			this.selectedTemplateId = null;
		}
		this.isEnterKeyPressed = false;
		this.redoStack = [];
		//this.inputerrorMessage = '';
		this.lastInboundMessageId = this.getLastInboundMessageIdForCurrentContact();

		if (!this.isTyping && this.phoneNumber && this.lastInboundMessageId) {
			this.isTyping = true;
			//this.sendWhatsAppTypingIndicator();
		}
		if (this.typingTimeout) {
			clearTimeout(this.typingTimeout);
		}

		this.typingTimeout = setTimeout(() => {
			this.isTyping = false;
		}, 30000);
	}

	getLastInboundMessageIdForCurrentContact() {
		if (!this.messages || !this.phoneNumber) return null;

		const inboundMessages = this.messages
			.filter(m =>
				m.isWhatsApp &&
				m.Incoming &&
				m.SmartMsg__Message_Id__c &&
				m.SmartMsg__Channel__c === 'WhatsApp' &&
				m.SmartMsg__To_Number__c === this.phoneNumber
			)
			.sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate));

		return inboundMessages.length > 0 ? inboundMessages[0].SmartMsg__Message_Id__c : null;
	}


	sendWhatsAppTypingIndicator() {
		if (!this.phoneNumber || !this.lastInboundMessageId) {
			console.error('❌ Missing phoneNumber or lastInboundMessageId');
			return;
		}

		// sendTypingIndicator({
		// 	toPhone: this.phoneNumber,
		// 	messageId: this.lastInboundMessageId
		// })
		// 	.then(() => {
		// 		//console.log('✅ Typing indicator sent to WhatsApp');
		// 	})
		// 	.catch(error => {
		// 		console.error('❌ Error sending typing indicator', error);
		// 	});
	}

	handleRequestLocationClick() {
		this.isRequestLocationMode = true;
	}



	handleFileNameChange(event) {
		event.preventDefault();
		this.fileName = event.target.value;
		this.fileNameError = false;
	}

	@wire(getTemplates, {
		objectApiName: '$objectApiName',
		templateType: '$selectedOption'
	})
	wiredTemplates({
		error,
		data
	}) {
		if (data) {
			this.Templates = data;
			this.filteredTemplates = data;
		} else if (error) {
			this.error = error;
		}
	}

	showTemplates() {
		this.showTemplateModal = true;
		this.filteredTemplates = this.Templates;
		this.showFooterMenu = false;
	}

	closeModal() {
		this.showTemplateModal = false;
	}

	handleSearch(event) {
		const searchKeyword = event.target.value.toLowerCase();
		this.filteredTemplates = this.Templates.filter(template =>
			template.SmartMsg__Template_Name__c.toLowerCase().includes(searchKeyword)
		);
	}

	handleRowClick(event) {
		this.isDocument = false;
		const templateId = event.currentTarget.dataset.id;
		const template = this.Templates.find(t => t.Id === templateId);
		const templateBody = template ? template.SmartMsg__Body__c : '';
		const selectedTemplate = this.Templates.find(template => template.Id === templateId);
		this.selectedTemplateId = templateId;
		if (selectedTemplate.SmartMsg__Header__c === 'Document' || selectedTemplate.SmartMsg__Header__c === 'Image' || selectedTemplate.SmartMsg__Header__c === 'Video') {
			this.showMediaUrlModal = true;
			if (selectedTemplate.SmartMsg__Header__c === 'Document') {
				this.isDocument = true;
			}
		}
		this.messageText = templateBody;
		if (selectedTemplate.SmartMsg__Header__c === 'Document' || selectedTemplate.SmartMsg__Header__c === 'Image' || selectedTemplate.SmartMsg__Header__c === 'Video') {
			this.showTemplateModal = false;
		} else {
			this.showTemplateModal = false;
		}
	}
	handleMediaUrlChange(event) {
		this.HeadermediaUrl = event.target.value;
		this.mediaUrlError = false;
	}
	handleSaveMediaUrl() {
		this.mediaUrlError = false;
		this.fileNameError = false;
		let valid = true;
		if (!this.HeadermediaUrl) {
			this.mediaUrlError = true;
			valid = false;
		}
		if (this.isDocument && !this.fileName) {
			this.fileNameError = true;
			valid = false;
		}
		if (!valid) {
			return;
		}
		this.showMediaUrlModal = false;
		this.showTemplateModal = false;
	}
	closeMediaUrlModal() {
		this.showMediaUrlModal = false;
		this.mediaUrlError = false;
		this.fileNameError = false
	}
	handleMediaMessageUrlChange(event) {
		this.mediaUrl = event.target.value;
		this.mediaUrlError = false;
	}
	handleSendTemplate() {
		this.showTemplateModal = true;
	}
	showSchedule(event) {
		event.preventDefault();
		event.stopPropagation();
		this.showSchedulePopup = !this.showSchedulePopup;
		if (this.showSchedulePopup) {
			window.addEventListener('click', this.handleClickOutside.bind(this));
			this.setDefaultDate();
			this.selectedTime = null;
			this.errorMessage = '';
			this.showFooterMenu = false;
		} else {
			window.removeEventListener('click', this.handleClickOutside.bind(this));
		}
	}
	incomingMessageDropDown = false;
	outgoingMessageDropDown = false;
	calledFromOutsideClick = true;
	handleMenuToggle(event) {
		event.stopPropagation();
		let clickedId = null;
		if (this.calledFromOutsideClick) {
			clickedId = event.currentTarget.dataset.id;
		}
		this.calledFromOutsideClick = true;
		this.messages = this.messages.map(msg => ({
			...msg,
			showMenu: msg.Id === clickedId ? !msg.showMenu : false
		}));
		if (this.showStarredOnly) {
			let starredMessageRecord = this.messages.filter(msg => msg.isStarred == true)
			this.groupByDate(starredMessageRecord)
		} else {
			this.groupByDate(this.messages);
		}
		this.messages.map(msg => {
			if (msg.showMenu) {
				window.addEventListener('click', this._boundHandleClickOutside);
				if (msg.SmartMsg__Type__c == 'Inbound') {
					this.incomingMessageDropDown = true;
					this.outgoingMessageDropDown = false;
				} else {
					this.outgoingMessageDropDown = true;
					this.incomingMessageDropDown = false;
				}
			}
		})
	}

	handleClickOutside(event) {
		if (this.incomingMessageDropDown) {
			const incoming = this.template.querySelector('.incoming-message');
			if (incoming != null) {
				window.removeEventListener('click', this._boundHandleClickOutside);
				this.calledFromOutsideClick = false;
				incoming.click();
			}
		}
		if (this.outgoingMessageDropDown) {
			const outgoing = this.template.querySelector('.outgoing-Message');
			if (outgoing != null) {
				window.removeEventListener('click', this._boundHandleClickOutside);
				this.calledFromOutsideClick = false;
				outgoing.click();
			}
		}
		const einsteinPopup = this.template.querySelector('.einstein-dropup-menu');
		if (einsteinPopup && !einsteinPopup.contains(event.target)) {
			this.showEinsteinMenu = false;
			this.errorMessage = '';
			this.inputerrorMessage = '';
			this.selectedDate = null;
			this.selectedTime = null;
			window.removeEventListener('click', this.handleClickOutside.bind(this));
		}

		const schedulePopup = this.template.querySelector('.scheduling-popup');
		if (schedulePopup && !schedulePopup.contains(event.target)) {
			this.showSchedulePopup = false;
			this.showFooterMenu = false;
			this.errorMessage = '';
			this.inputerrorMessage = '';
			this.selectedDate = null;
			this.selectedTime = null;
			window.removeEventListener('click', this.handleClickOutside.bind(this));
		}

		const dropdown = this.template.querySelector('.dropdown');
		if (dropdown && !dropdown.contains(event.target)) {
			this.showDropdown = false;
			window.removeEventListener('click', this.handleClickOutside.bind(this));
		}

		const footermenu = this.template.querySelector('.footer-action-menu');
		if (footermenu && !footermenu.contains(event.target)) {
			this.showFooterMenu = false;
			window.removeEventListener('click', this.handleClickOutside.bind(this));
		}
	}
	stopPropagation(event) {
		event.stopPropagation();
	}
	get todaysDate() {
		const today = new Date();
		const year = today.getFullYear();
		const month = String(today.getMonth() + 1).padStart(2, '0');
		const day = String(today.getDate()).padStart(2, '0');
		return `${year}-${month}-${day}`;
	}
	minDate = this.getTodayDate();
	minTime = this.getCurrentTime();
	isTimeDisabled = false;
	handleDateChange(event) {
		this.selectedDate = event.target.value;
		this.errorMessage = '';
		const todayStr = this.getTodayDate();
		if (!this.selectedDate || this.selectedDate < todayStr) {
			// If date is empty or in the past 
			this.isTimeDisabled = true;
			this.minTime = '';
			this.selectedTime = '';
			this.errorMessage = 'Please select a valid date (today or future).';
			return;
		}
		// Valid date selected (today or future) 
		this.isTimeDisabled = false;
		this.updateTimeRestrictions();
	}
	updateTimeRestrictions() {
		if (this.selectedDate === this.getTodayDate()) {
			this.minTime = this.getCurrentTime();
		} else {
			this.minTime = '';
		}
	}
	getTodayDate() {
		const today = new Date();
		return today.toISOString().split('T')[0];
	}
	getCurrentTime() {
		const now = new Date();
		const hours = now.getHours().toString().padStart(2, '0');
		const minutes = now.getMinutes().toString().padStart(2, '0');
		return `${hours}:${minutes}`;
	}
	handleTime() {
		this.updateTimeRestrictions();
	}
	handleTimeChange(event) {
		const selectedTime = event.target.value;
		try {
			if (this.selectedDate === this.getTodayDate() && selectedTime > this.getCurrentTime()) {
				if (!this.isTimeValid(this.selectedDate, selectedTime) && this.selectedOption === 'SMS') {
					this.errorMessage = 'Selected time must be at least 15 minutes from now.';
					this.selectedTime = '';
				} else {
					this.selectedTime = selectedTime;
					this.errorMessage = '';
				}
			} else {
				this.errorMessage = 'Selected time is in the past!';
				this.selectedTime = '';
			}
		} catch (error) {
			//console.log(error);
		}
	}
	isTimeValid(selectedDate, selectedTime) {
		const currentTime = new Date();
		const selectedDateTime = new Date(selectedDate);
		const [hours, minutes] = selectedTime.split(':').map(Number);
		selectedDateTime.setHours(hours, minutes, 0, 0);
		const isSameDay = selectedDateTime.toDateString() === currentTime.toDateString();
		const timeDifference = (selectedDateTime - currentTime) / (1000 * 60);
		return isSameDay ? timeDifference >= 15 : true;
	}
	handleContinue() {
		if (!this.selectedDate || !this.selectedTime) {
			this.errorMessage = 'Please select both date and time.';
			return;
		}
		if ((this.selectedDate && this.selectedTime) && !this.messageText) {
			this.errorMessage = 'Please Enter a Message to schedule';
		}
		//this.errorMessage = '';
		if (this.selectedOption == 'SMS') {
			this.limitMessage = true;
			if (this.messageText.length >= 500) {
				this.characterLength = this.messageText.length;
				this.inputerrorMessage = 'Character Limit exceeded';
				this.showSchedulePopup = true;
			}
			else {
				this.characterLength = this.messageText.length;
				this.inputerrorMessage = '';
				this.scheduleMessage();
				this.characterLength = 0;
			}

		} else if (this.selectedOption == 'WhatsApp') {
			this.scheduleWhatsAppMessage();
		} else if (this.selectedOption === 'Select Channel') {
			this.showToast('Select a channel', 'Please select SMS or WhatsApp before scheduling.', 'warning');
		}
	}
	scheduleMessage() {
		if (!this.phoneNumber || !this.messageText && this.selectedOption == 'SMS') {
			return;
		}
		const scheduledDateTime = new Date(`${this.selectedDate}T${this.selectedTime}Z`);
		scheduledDateTime.setHours(scheduledDateTime.getHours() - 5);
		scheduledDateTime.setMinutes(scheduledDateTime.getMinutes() - 30);
		const adjustedUtcDateTime = scheduledDateTime.toISOString();
		const params = {
			phoneNumber: this.phoneNumber,
			smsBody: this.messageText,
			status: 'Scheduled',
			scheduledTime: adjustedUtcDateTime,
			templateId: this.selectedTemplateId,
			relatedRecordId: this.recordId,
		};
		createScheduleRecord({
			smsparams: params
		})
			.then(() => {
				scheduleSMS({
					recordId: this.recordId,
					phoneNumber: this.phoneNumber,
					smsBody: this.messageText,
					scheduledTime: adjustedUtcDateTime
				})
					.then(result => {
						const updatedResult = Object.assign({
							Outgoing: result.SmartMsg__Type__c == 'Outbound' ? true : false,
							Incoming: result.SmartMsg__Type__c === 'Inbound' && result.SmartMsg__Delivery_Status__c == 'Received' ? true : false,
							Scheduled: result.SmartMsg__Type__c == 'Outbound' && result.SmartMsg__Delivery_Status__c == 'Scheduled' ? true : false,
							Failed : result.SmartMsg__Type__c == 'Outbound' && result.SmartMsg__Delivery_Status__c == 'Failed' ? true : false,
							isSMS: result.SmartMsg__Channel__c == 'SMS' ? true : false,
							isFailed: result.SmartMsg__Delivery_Status__c == 'Failed' ? true : false,
							isWhatsApp: (result.SmartMsg__Channel__c == 'WhatsApp' || result.SmartMsg__Channel__c == 'Twilio WhatsApp') ? true : false
						}, result);
						// console.log(updatedResult);
						
						const newMessage = {
							...updatedResult
						};
						// console.log(JSON.stringify(newMessage))
						try {
							newMessage.formattedScheduledTime = this.formatScheduledTime(newMessage.SmartMsg__Scheduled_Date_Time__c);
							newMessage.formattedTime = this.formatTime(newMessage.CreatedDate);
							this.messages = [...this.messages, newMessage];
							this.allMessages = [...(this.allMessages || []), newMessage];
							this.groupMessagesByDate();
							refreshApex(this.messages);
						} catch (error) {
							//console.log('error in create sched' + JSON.stringify(error));
						}
					})
					.catch(error => {
						console.error('Error scheduling message:', error);
						const errMsg = (error && error.body && error.body.message) ? error.body.message : (error && error.message) ? error.message : 'Subscription Expired';
						this.dispatchEvent(
							new ShowToastEvent({
								title: 'Error',
								message: errMsg,
								variant: 'error'
							})
						);
					})
					.finally(() => {
						this.isSpinner = false;
						this.scrollToBottom();
						this.allFiles = [];
						this.filesData = [];
						this.messageText = '';
						this.showSchedulePopup = false;
						this.selectedDate = null;
						this.selectedTime = null;
					});
			})
			.catch(error => {
				console.error('Error creating message record:', error);
				const errMsg = (error && error.body && error.body.message) ? error.body.message : (error && error.message) ? error.message : 'Subscription Expired';
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Error',
						message: errMsg,
						variant: 'error'
					})
				);
			});
	}
	scheduleWhatsAppMessage() {
		if (!this.phoneNumber || !this.messageText) {
			return;
		}
		const scheduledDateTime = new Date(`${this.selectedDate}T${this.selectedTime}`);
		const formattedScheduledDateTime = scheduledDateTime.toISOString();
		const params = {
			phoneNumber: this.phoneNumber,
			messageBody: this.messageText,
			status: 'Scheduled',
			scheduledTime: formattedScheduledDateTime,
			templateId: this.selectedTemplateId,
			relatedRecordId: this.recordId,
		};
		createWhatsAppScheduleRecord({
			whatsappparams: params
		})
			.then(result => {
				const updatedResult = Object.assign({
					Outgoing: result.SmartMsg__Type__c == 'Outbound' ? true : false,
					Incoming: result.SmartMsg__Type__c === 'Inbound' && result.SmartMsg__Delivery_Status__c == 'Received' ? true : false,
					Scheduled: result.SmartMsg__Type__c == 'Outbound' && result.SmartMsg__Delivery_Status__c == 'Scheduled' ? true : false,
					isSMS: result.SmartMsg__Channel__c == 'SMS' ? true : false,
					isWhatsApp: (result.SmartMsg__Channel__c == 'WhatsApp' || result.SmartMsg__Channel__c == 'Twilio WhatsApp') ? true : false
				}, result);
				const newMessage = {
					...updatedResult
				};
				newMessage.WAScheduledTime = this.formatScheduledTime(newMessage.SmartMsg__Scheduled_Date_Time__c);
				newMessage.formattedTime = this.formatTime(newMessage.CreatedDate);
				this.messages = [...this.messages, newMessage];
				this.allMessages = [...(this.allMessages || []), newMessage];
				this.groupMessagesByDate();
				this.loadMessages();
			})
			.catch(error => {
				console.error('Error scheduling message:', error);
			})
			.finally(() => {
				this.isSpinner = false;
				this.scrollToBottom();
				this.messageText = '';
				this.showSchedulePopup = false;
				this.selectedDate = null;
				this.selectedTime = null;
			});
	}


	handleKeyPress(event) {
		// Enter without Shift: send message. Shift+Enter: new line.
		if (event.key === 'Enter' && !event.shiftKey) {
			event.preventDefault();
			if (!this.isSendButtonDisabled) {
				this.handleSendMessage();
			}
			return;
		}
		// Only support undo/redo with Ctrl+Z / Ctrl+Y
		if ((event.ctrlKey || event.metaKey) && event.key === 'z') {
			event.preventDefault();
			if (this.undoStack.length > 0) {
				this.redoStack.push(this.messageText);
				this.messageText = this.undoStack.pop();
			}
		}
		if ((event.ctrlKey || event.metaKey) && event.key === 'y') {
			event.preventDefault();
			if (this.redoStack.length > 0) {
				this.undoStack.push(this.messageText);
				this.messageText = this.redoStack.pop();
			}
		}
		if (event.keyCode != 8 && event.keyCode != 46 && this.messageText.length >= 500 && this.selectedOption == 'SMS') {
			event.preventDefault();
		}

	}

	get sendButtonClass() {
		if (this.showSchedulePopup || !(this.messageText && this.messageText.trim()) || this.isAutoReplyEnabled === true) {
			return 'send-icon disabled-icon';
		}
		return 'send-icon';
	}
	handleSendButtonClick(event) {
		event.preventDefault();
		if (!this.isSendButtonDisabled) {
			this.handleSendMessage();
		}

	}
	get isSendButtonDisabled() {
		const text = (this.messageText || '').trim();
		return this.isAutoReplyEnabled === true || text === '';
	}
	handleSendMessage() {
		if (!this.isEnterKeyPressed) {
			this.isEnterKeyPressed = true;
			if (this.selectedOption === 'Select Channel') {
				this.showToast('Select a channel', 'Please select SMS or WhatsApp before sending.', 'warning');
				this.isEnterKeyPressed = false;
				return;
			}
			if (this.selectedOption === 'WhatsApp' && this.isAutoReplyEnabled) {
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Warning',
						message: 'You can not send direct Message, as Chatbot is active.',
						variant: 'warning',
						mode: 'dismissible'
					})
				);
				this.isEnterKeyPressed = false;
				return;
			}
			if (this.selectedOption === 'SMS') {
				if (this.messageText.length > 500) {
					this.inputerrorMessage = 'Message Limit reached';
				} else {
					this.sendSMSMessage();
					this.characterLength = 0
				}

			} else if (this.selectedOption === 'WhatsApp') {
				this.sendWhatsAppMessage();
				this.checkReengagementMessage();

			} else {
				//console.error('Invalid messaging option.'); 
			}
		}


	}
	sendSMSMessage() {
		let msgText = this.messageText.replaceAll(' ', '');
		msgText = msgText.replace(/\\\\/g, '\\');
		if (msgText) {
			if (!this.phoneNumber) {
				const errorMsg = 'Phone number not found for the record.';
				this.showToast('Attention!', errorMsg, 'info', 'sticky');
				console.error(errorMsg);
				return;
			}
			createMessageRecord({
				phoneNumber: this.formattedPhoneNumber,
				smsBody: this.messageText,
				status: 'Sent',
				channel: this.selectedOption,
				fileData: JSON.stringify(this.filesData),
				templateId: this.selectedTemplateId,
				relatedRecordId: this.recordId,
				relatedObjectId: this.recordId
			})
				.then((result) => {
					this.isSpinner = true;
					const updatedResult = Object.assign({
						Outgoing: result.SmartMsg__Type__c == 'Outbound' ? true : false,
						Incoming: result.SmartMsg__Type__c == 'Inbound' && result.SmartMsg__Delivery_Status__c == 'Received' ? true : false,
						Scheduled: result.SmartMsg__Type__c == 'Outbound' && result.SmartMsg__Delivery_Status__c == 'Scheduled' ? true : false,
						isSMS: result.SmartMsg__Channel__c == 'SMS' ? true : false,
						isWhatsApp: (result.SmartMsg__Channel__c == 'WhatsApp' || result.SmartMsg__Channel__c == 'Twilio WhatsApp') ? true : false,
						sent: result.SmartMsg__Delivery_Status__c == 'Sent' ? true : false,
						delivered: result.SmartMsg__Delivery_Status__c == 'Delivered' ? true : false,
						SmartMsg__Message_Body__c: result.SmartMsg__Message_Body__c,
						isImage: result.SmartMsg__File_Name__c &&
							(result.SmartMsg__File_Name__c.toLowerCase().endsWith('.jpeg') ||
								result.SmartMsg__File_Name__c.toLowerCase().endsWith('.jpg') ||
								result.SmartMsg__File_Name__c.toLowerCase().endsWith('.png') ||
								result.SmartMsg__File_Name__c.endsWith('.webp')),
						isMedia: result.SmartMsg__Media_Url__c ? true : false,
						isPdf: result.SmartMsg__File_Name__c && result.SmartMsg__File_Name__c.endsWith('.pdf'),
						isVideo: result.SmartMsg__File_Name__c && (result.SmartMsg__File_Name__c.endsWith('.mp4') || result.SmartMsg__File_Name__c.endsWith('.mov')),
						isAudio: result.SmartMsg__File_Name__c && (result.SmartMsg__File_Name__c.endsWith('.mp3') || result.SmartMsg__File_Name__c.endsWith('.wav') || result.SmartMsg__File_Name__c.endsWith('.aac')),
						imageUrl: result.SmartMsg__Media_Url__c ? `/sfc/servlet.shepherd/document/download/${result.SmartMsg__Media_Url__c}` : null,
						senderName: result.CreatedBy ? result.CreatedBy.Name : 'Unknown User',
						isFailed: result.SmartMsg__Delivery_Status__c == 'Failed' ? true : false
					},
						result
					);
					try {
						const newMessage = {
							...updatedResult
						};
						newMessage.formattedTime = this.formatTime(newMessage.CreatedDate);
						this.messages = [...this.messages, newMessage];
						this.allMessages = [...(this.allMessages || []), newMessage];
						this.groupMessagesByDate();
						this.isSpinner = false;
					} catch (error) {
						//console.log('Error creating message record:', error)
					}
				})
				.catch((error) => {
					console.error('Error creating SMS record:', error);
					// Log deeper error details 
					if (error.body) {
						console.error('Error Body:', JSON.stringify(error.body));
					}
					if (error.message) {
						console.error('Error Message:', error.message);
					}
					if (error.stack) {
						console.error('Error Stack:', error.stack);
					}
					const errMsg = (error && error.body && error.body.message) ? error.body.message : (error && error.message) ? error.message : 'Subscription Expired';
					this.dispatchEvent(
						new ShowToastEvent({
							title: 'Error',
							message: errMsg,
							variant: 'error',
							mode: 'sticky'
						})
					);
				})
				.finally(() => {
					this.isSpinner = false;
					this.scrollToBottom();
					this.messageText = '';
					this.allFiles = [];
					this.filesData = [];
					this.setUpChatMessage();
					this.isEnterKeyPressed = false;
					this.messageLength = 0;
				});
		} else {
			this.isEnterKeyPressed = false;
		}
	}
	getTwilioErrorMessage(errorCode) {
		return twilioErrorMessages[errorCode] || 'Unknown error occurred';
	}
	showErrorNotification(title, message) {
		const event = new ShowToastEvent({
			title: title,
			message: message,
			variant: 'error',
		});
		this.dispatchEvent(event);
	}
	setUpChatMessage() {
		let chatInput = this.template.querySelector(".chat-input");
		if (chatInput) {
			chatInput.addEventListener("keydown", (event) => {
				if (event.key === "Enter") {
					this.handleSendMessage();
				}
			});
		}
	}
	sendWhatsAppMessage() {
		let allValid = this.handleValidate();
		if (allValid && this.selectedOption == 'WhatsApp') {
			if (!this.isSpinner && this.selectedTemplateId) {
				this.isEnterKeyPressed = false;
				const templateParams = {
					recordId: this.recordId,
					templateId: this.selectedTemplateId,
					phoneNumber: this.phoneNumber,
					headerMediaURL: this.HeadermediaUrl,
					fileName: this.fileName
				};
				const templatePromise = this.activeWhatsAppChannel === 'Twilio WhatsApp'
					? sendTemplateMessageWithFrom({ ...templateParams, fromNumber: this.selectedTwilioFromNumber || null })
					: sendTemplateMessage(templateParams);
				templatePromise
					.then(result => {
						const updatedResult = Object.assign({
							Outgoing: result.SmartMsg__Type__c == 'Outbound' ? true : false,
							Incoming: result.SmartMsg__Type__c === 'Inbound' && result.SmartMsg__Delivery_Status__c == 'Received' ? true : false,
							Scheduled: result.SmartMsg__Type__c == 'Outbound' && result.SmartMsg__Delivery_Status__c == 'Scheduled' ? true : false,
							sent: result.SmartMsg__Delivery_Status__c == 'Sent' ? true : false,
							delivered: result.SmartMsg__Delivery_Status__c == 'Delivered' ? true : false,
							read: result.SmartMsg__Delivery_Status__c == 'Read' ? true : false,
							isSMS: result.SmartMsg__Channel__c == 'SMS' ? true : false,
							isWhatsApp: (result.SmartMsg__Channel__c == 'WhatsApp' || result.SmartMsg__Channel__c == 'Twilio WhatsApp') ? true : false
						}, result);
						const newMessage = {
							...updatedResult
						};
						newMessage.formattedTime = this.formatTime(newMessage.CreatedDate);
						this.messages = [...this.messages, newMessage];
						this.allMessages = [...(this.allMessages || []), newMessage];
						this.groupMessagesByDate();
						this.scrollToBottom();
					})
					.catch(error => {
						console.error('Error sending template message:', error);
						const errMsg = (error && error.body && error.body.message) ? error.body.message : (error && error.message) ? error.message : 'Subscription Expired';
						this.dispatchEvent(
							new ShowToastEvent({
								title: 'Error',
								message: errMsg,
								variant: 'error'
							})
						);
					})
					.finally(() => {
						this.isSpinner = false;
						this.messageText = '';
						this.selectedTemplateId = null;
						this.isTyping = false;
						this.isEnterKeyPressed = false;
					});

			}
			else if (
				!this.isSpinner &&
				!this.selectedTemplateId &&
				this.filesData &&
				this.filesData.length > 0
			) {
				this.isSpinner = true;
				let messageResult = null;

				createMessageRecord({
					phoneNumber: this.phoneNumber,
					smsBody: this.messageText,
					status: 'Sent',
					fileData: JSON.stringify(this.filesData),
					templateId: null,
					relatedRecordId: this.recordId,
					relatedObjectId: this.recordId,
					channel: 'WhatsApp',
					publicMediaUrl: null,
					publicFileName: null
				})
					.then(result => {
						messageResult = result;
						return generatePublicUrlForContentDocument({
							contentDocumentId: messageResult.SmartMsg__Media_Url__c
						});
					})
					.then(publicUrl => {
						// Step 3: Send WhatsApp media message and update the same record
						return sendMediaMessage({
							messageRecordId: messageResult.Id,
							mediaType: this.selectedMediaType,
							mediaUrl: publicUrl,
							toPhone: this.phoneNumber,
							caption: this.messageText,
							fileName: messageResult.SmartMsg__File_Name__c
						}).then(updatedResult => {
							// Step 4: Update UI with the updated message
							const isSalesforceFile = updatedResult.SmartMsg__Media_Url__c && !updatedResult.SmartMsg__Media_Url__c.startsWith('http');
							const newMessage = {
								...updatedResult,
								Outgoing: true,
								Incoming: false,
								Scheduled: false,
								sent: updatedResult.SmartMsg__Delivery_Status__c === 'Sent',
								delivered: updatedResult.SmartMsg__Delivery_Status__c === 'Delivered',
								read: updatedResult.SmartMsg__Delivery_Status__c === 'Read',
								isSMS: false,
								isWhatsApp: true,
								isImage: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.jpeg') || updatedResult.SmartMsg__File_Name__c.endsWith('.jpg') || updatedResult.SmartMsg__File_Name__c.endsWith('.png')),
								isPdf: updatedResult.SmartMsg__File_Name__c && updatedResult.SmartMsg__File_Name__c.endsWith('.pdf'),
								isVideo: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.mp4') || updatedResult.SmartMsg__File_Name__c.endsWith('.mov')),
								isAudio: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.mp3') || updatedResult.SmartMsg__File_Name__c.endsWith('.wav') || updatedResult.SmartMsg__File_Name__c.endsWith('.aac')),
								//imageUrl: updatedResult.SmartMsg__Media_Url__c ? `/sfc/servlet.shepherd/document/download/${updatedResult.SmartMsg__Media_Url__c}` : null,
								imageUrlIsSalesforce: isSalesforceFile,
								imageUrl: isSalesforceFile ? `/sfc/servlet.shepherd/document/download/${updatedResult.SmartMsg__Media_Url__c}` : null,
								formattedTime: this.formatTime(updatedResult.CreatedDate)
							};
							this.messages = [...this.messages, newMessage];
							this.allMessages = [...(this.allMessages || []), newMessage];
							this.groupMessagesByDate();
							this.scrollToBottom();

							// Reset UI state
							this.messageText = '';
							this.filesData = [];
							this.fileName = '';
							this.selectedMediaType = '';
							this.mediaUrl = '';
						});
					})
					.catch(error => {
						console.error('❌ Error in WhatsApp media message flow:', + (error.body?.message || error.message || ''));
						this.showToast('Error', 'Failed to send WhatsApp media message. ' + (error.body?.message || error.message || ''), 'error');
					})
					.finally(() => {
						this.isSpinner = false;
						this.isTyping = false;
						this.isEnterKeyPressed = false;
					});
			}
			else if (
				!this.isSpinner &&
				!this.selectedTemplateId &&
				this.mediaMode === 'url' &&
				this.mediaUrl
			) {
				this.isSpinner = true;
				createMessageRecord({
					phoneNumber: this.phoneNumber,
					smsBody: this.messageText,
					status: 'Sent',
					fileData: null, // No ContentVersion
					templateId: null,
					relatedRecordId: this.recordId,
					relatedObjectId: this.recordId,
					channel: 'WhatsApp',
					publicMediaUrl: this.mediaUrl,
					publicFileName: this.extractFileNameFromUrl(this.mediaUrl)
				})
					.then(result => {
						return sendMediaMessage({
							messageRecordId: result.Id,
							mediaType: this.selectedMediaType,
							mediaUrl: this.mediaUrl,
							toPhone: this.phoneNumber,
							caption: this.messageText,
							fileName: this.extractFileNameFromUrl(this.mediaUrl)
						}).then(updatedResult => {
							// Step 4: Update UI with the updated message
							const isSalesforceFile = updatedResult.SmartMsg__Media_Url__c && !updatedResult.SmartMsg__Media_Url__c.startsWith('http');
							const newMessage = {
								...updatedResult,
								Outgoing: true,
								Incoming: false,
								Scheduled: false,
								sent: updatedResult.SmartMsg__Delivery_Status__c === 'Sent',
								delivered: updatedResult.SmartMsg__Delivery_Status__c === 'Delivered',
								read: updatedResult.SmartMsg__Delivery_Status__c === 'Read',
								isSMS: false,
								isWhatsApp: true,
								isImage: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.jpeg') || updatedResult.SmartMsg__File_Name__c.endsWith('.jpg') || updatedResult.SmartMsg__File_Name__c.endsWith('.png')),
								isPdf: updatedResult.SmartMsg__File_Name__c && updatedResult.SmartMsg__File_Name__c.endsWith('.pdf'),
								isVideo: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.mp4') || updatedResult.SmartMsg__File_Name__c.endsWith('.mov')),
								isAudio: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.mp3') || updatedResult.SmartMsg__File_Name__c.endsWith('.wav') || updatedResult.SmartMsg__File_Name__c.endsWith('.aac')),
								//imageUrl: updatedResult.SmartMsg__Media_Url__c ? `/sfc/servlet.shepherd/document/download/${updatedResult.SmartMsg__Media_Url__c}` : null,
								imageUrlIsSalesforce: isSalesforceFile,
								imageUrl: isSalesforceFile ? `/sfc/servlet.shepherd/document/download/${updatedResult.SmartMsg__Media_Url__c}` : null,
								formattedTime: this.formatTime(updatedResult.CreatedDate)
							};
							this.messages = [...this.messages, newMessage];
							this.allMessages = [...(this.allMessages || []), newMessage];
							this.groupMessagesByDate();
							this.scrollToBottom();
							this.messageText = '';
							this.filesData = [];
							this.fileName = '';
							this.selectedMediaType = '';
							this.mediaUrl = '';
						});
					})
					.catch(error => {
						this.showToast('Error', 'Failed to send WhatsApp media message via URL. ' + (error.body?.message || error.message || ''), 'error');
					})
					.finally(() => {
						this.isSpinner = false;
						this.isTyping = false;
						this.isEnterKeyPressed = false;
					});
			}
			else if (allValid && this.selectedOption == 'WhatsApp' && this.isRequestLocationMode) {
				this.isSpinner = true;
				let messageRecordId = null;

				createMessageRecord({
					phoneNumber: this.phoneNumber,
					smsBody: this.messageText,
					status: 'Sent',
					fileData: null,
					templateId: null,
					relatedRecordId: this.recordId,
					relatedObjectId: this.recordId,
					channel: 'WhatsApp',
					publicMediaUrl: null,
					publicFileName: null
				})
					.then(result => {
						messageRecordId = result.Id;
						return sendLocationRequestMessage({ toPhone: this.phoneNumber, messageId: result.Id, messageBody: this.messageText });
					})
					.then(updatedResult => {
						// Step 4: Update UI with the updated message
						const isSalesforceFile = updatedResult.SmartMsg__Media_Url__c && !updatedResult.SmartMsg__Media_Url__c.startsWith('http');
						const newMessage = {
							...updatedResult,
							Outgoing: true,
							Incoming: false,
							Scheduled: false,
							sent: updatedResult.SmartMsg__Delivery_Status__c === 'Sent',
							delivered: updatedResult.SmartMsg__Delivery_Status__c === 'Delivered',
							read: updatedResult.SmartMsg__Delivery_Status__c === 'Read',
							isSMS: false,
							isWhatsApp: true,
							isImage: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.jpeg') || updatedResult.SmartMsg__File_Name__c.endsWith('.jpg') || updatedResult.SmartMsg__File_Name__c.endsWith('.png')),
							isPdf: updatedResult.SmartMsg__File_Name__c && updatedResult.SmartMsg__File_Name__c.endsWith('.pdf'),
							isVideo: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.mp4') || updatedResult.SmartMsg__File_Name__c.endsWith('.mov')),
							isAudio: updatedResult.SmartMsg__File_Name__c && (updatedResult.SmartMsg__File_Name__c.endsWith('.mp3') || updatedResult.SmartMsg__File_Name__c.endsWith('.wav') || updatedResult.SmartMsg__File_Name__c.endsWith('.aac')),
							//imageUrl: updatedResult.SmartMsg__Media_Url__c ? `/sfc/servlet.shepherd/document/download/${updatedResult.SmartMsg__Media_Url__c}` : null,
							imageUrlIsSalesforce: isSalesforceFile,
							imageUrl: isSalesforceFile ? `/sfc/servlet.shepherd/document/download/${updatedResult.SmartMsg__Media_Url__c}` : null,
							isLocationRequest: updatedResult.SmartMsg__Message_Type__c === 'location-request',
							formattedTime: this.formatTime(updatedResult.CreatedDate)
						};
						this.messages = [...this.messages, newMessage];
						this.groupMessagesByDate();
						this.scrollToBottom();
						this.messageText = '';
						this.isRequestLocationMode = false;
						this.isLocationRequest = false;
						this.filesData = [];
						this.fileName = '';
						this.selectedMediaType = '';
						this.mediaUrl = '';
					})
					.catch(error => {
						console.error('Error sending location request:', error);
						this.showToast('Error', 'Failed to send location request', 'error');
					})
					.finally(() => {
						this.messageText = '';
						this.isRequestLocationMode = false;
						this.isSpinner = false;
						this.isEnterKeyPressed = false;
					});
				return;
			}

			else if (!this.isSpinner && !this.selectedTemplateId) {
				let phone = this.phoneNumber;
				phone = phone.slice(1);
				const textParams = { messageContent: this.messageText, toPhone: phone };
				const textPromise = this.activeWhatsAppChannel === 'Twilio WhatsApp'
					? sendTextMessageWithFrom({ ...textParams, fromNumber: this.selectedTwilioFromNumber || null })
					: sendTextMessage(textParams);
				textPromise
					.then(result => {
						// console.log('result : '+JSON.stringify(result));
						const updatedResult = Object.assign({
							Outgoing: result.SmartMsg__Type__c == 'Outbound' ? true : false,
							Incoming: result.SmartMsg__Type__c === 'Inbound' && result.SmartMsg__Delivery_Status__c == 'Received' ? true : false,
							Scheduled: result.SmartMsg__Type__c == 'Outbound' && result.SmartMsg__Delivery_Status__c == 'Scheduled' ? true : false,
							sent: result.SmartMsg__Delivery_Status__c == 'Sent' ? true : false,
							delivered: result.SmartMsg__Delivery_Status__c == 'Delivered' ? true : false,
							read: result.SmartMsg__Delivery_Status__c == 'Read' ? true : false,
							isSMS: result.SmartMsg__Channel__c == 'SMS' ? true : false,
							isWhatsApp: (result.SmartMsg__Channel__c == 'WhatsApp' || result.SmartMsg__Channel__c == 'Twilio WhatsApp') ? true : false
						}, result);
						const newMessage = {
							...updatedResult
						};
						newMessage.formattedTime = this.formatTime(newMessage.CreatedDate);
						this.messages = [...this.messages, newMessage];
						this.allMessages = [...(this.allMessages || []), newMessage];
						this.groupMessagesByDate();
						this.scrollToBottom();
					})
					.catch((errors) => {
						this.errorDetails = errors;
						this.showMessages = false;
						const errMsg = (errors && errors.body && errors.body.message) ? errors.body.message : (errors && errors.message) ? errors.message : 'Subscription Expired';
						this.dispatchEvent(
							new ShowToastEvent({
								title: 'Error',
								message: errMsg,
								variant: 'error'
							})
						);
					})
					.finally(() => {
						this.scrollToBottom();
						this.handleSubscribe();
						this.messageText = '';
						this.isTyping = false;
						this.isEnterKeyPressed = false;
					});
			}
		}
	}
	scrollToBottom() {
		let scroll = this.template.querySelector('.chat-Area');
		if (scroll) {
			scroll.scrollTop = scroll.scrollHeight;
		}
	}
	handleValidate() {
		const allValid = [
			...this.template.querySelectorAll('lightning-input'),
		].reduce((validSoFar, inputCmp) => {
			inputCmp.reportValidity();
			return validSoFar && inputCmp.checkValidity();
		}, true);
		return allValid;
	}
	openFileModal = false;

	@track allFiles = [];
	@track filesData = [];
	selectFileModal() {
		this.openFileModal = true;
		this.showFooterMenu = false;
		this.fileName = '';
		this.filesData = [];
		this.allFiles = [];
		this.mediaUrl = '';
	}
	closeFileModal() {
		this.openFileModal = false;
		this.filesData = [];
		this.allFiles = [];
		this.fileError = '';
		this.fileName = '';

	}
	acceptedContentType = ['image/jpeg', 'image/jpg', 'image/gif', 'image/png', 'image/heic', 'application/pdf', 'video/mp4', 'audio/mp3', 'audio/mp4', 'audio/mpeg', 'video/mpeg4', 'video/mpeg'];
	tempFiles = [];
	maxSize = 3 * 1024 * 1024;
	fileError = null;
	handleFileUploaded(event) {
		try {
			var allFiles = event.target.files;
			if (allFiles.length > 5) {
				this.fileError = 'Add a maximum of up to 5 files!';
				this.allFiles = [];
				this.fileName = '';
				return;
			}
			let totalSize = 0;
			this.fileError = null;
			this.allFiles = [];
			this.fileName = '';
			for (let i = 0; i < allFiles.length; i++) {
				let file = allFiles[i];
				totalSize += file.size;
				// ⛔️ Check unsupported file type
				if (!this.acceptedContentType.includes(file.type)) {
					this.fileError = `File "${file.name}" is of unsupported type (${file.type}). Only PDF files are allowed for document uploads. Please upload a valid PDF.`;
					this.allFiles = [];
					this.fileName = '';
					return;
				}
				// âœ… Check if the file is a video and exceeds 600KB 
				if (file.type.startsWith('video/') && file.size > 600 * 1024) {
					this.fileError = `Error: The video file "${file.name}" exceeds the 600KB size limit.`;
					this.allFiles = [];
					this.fileName = '';
					return;
				}
				this.fileName += file.name + (i < allFiles.length - 1 ? ', ' : '');
				this.allFiles.push(file);
				// Set media type for WhatsApp API
				if (file.type.startsWith('image/')) {
					this.selectedMediaType = 'image';
				} else if (file.type.startsWith('video/')) {
					this.selectedMediaType = 'video';
				} else if (file.type === 'application/pdf') {
					this.selectedMediaType = 'document';
				} else if (file.type.startsWith('audio/')) {
					this.selectedMediaType = 'audio';
				}
			}
			// âœ… Check total file size limit (2MB max) 
			if (totalSize > this.maxSize) {
				this.allFiles = [];
				this.fileError = 'Total file size exceeds 2 MB. Please select smaller files.';
				this.fileName = '';
				//this.mediaUrl = '';
			} else {
				this.fileError = null;
			}
		} catch (error) {
			this.fileError = "An unexpected error occurred while uploading the file.";
		}
	}
	get isWhatsAppSelected() {
		return this.selectedOption === 'WhatsApp';
	}


	handleUploadMediaButtonClick() {
		// Force read the latest value from the input
		if (this.showUrlInputSection) {
			const input = this.template.querySelector('lightning-input');
			if (input) {
				this.mediaUrl = input.value;
			}
		}

		this.clearMediaErrors();

		// SMS only allows file upload
		if (this.selectedOption === 'SMS') {
			// Proceed with SMS file upload
			// console.log('this.filesData : '+this.filesData);
			// console.log('this.filesData.length : '+this.filesData.length);
			// console.log('!this.fileName ',!this.fileName);
			this.uploadFileData();
			return;
		}

		// WhatsApp → Upload Mode
		if (this.selectedOption === 'WhatsApp' && this.showFileUploadSection) {
			// console.log('this.filesData : '+this.filesData);
			// console.log('this.filesData.length : '+this.filesData.length);
			// console.log('!this.fileName ',!this.fileName);

			// if (!this.fileName || !this.filesData?.length) {
			// 	this.fileNameError = !this.fileName;
			// 	this.fileError = !this.filesData?.length ? 'Please upload a valid file.' : '';
			// 	return;
			// }

			// Proceed with WhatsApp upload
			this.mediaMode = 'upload';
			this.uploadFileData(); // This will call sendWhatsAppMessage
			return;
		}

		// WhatsApp → URL Mode
		this.selectedMediaType = this.detectMediaTypeFromUrl(this.mediaUrl);
		if (this.selectedOption === 'WhatsApp' && this.showUrlInputSection) {

			// ✅ Ensure you read the *latest* user input!
			const mediaUrlInput = this.template.querySelector('[data-id="mediaUrlInput"]');
			if (mediaUrlInput) {
				this.mediaUrl = mediaUrlInput.value;
			}
			if (!this.mediaUrl || !this.mediaUrl.startsWith('http')) {
				this.mediaUrlError = true;
				return;
			}

			this.mediaMode = 'url'; // store URL for use in sendWhatsAppMessage
			this.closeFileModal(); // close the modal
			return;
		}
	}

	detectMediaTypeFromUrl(url) {
		if (!url) return 'document';

		try {
			const cleanUrl = url.split('?')[0].split('#')[0];
			const filename = cleanUrl.substring(cleanUrl.lastIndexOf('/') + 1);
			const dotIndex = filename.lastIndexOf('.');
			if (dotIndex === -1) { return 'document'; }
			const extension = filename.substring(dotIndex + 1).toLowerCase();
			if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].includes(extension)) return 'image';
			if (['mp4', 'mov', 'avi', 'mkv', 'webm'].includes(extension)) return 'video';
			if (['mp3', 'wav', 'aac', 'ogg'].includes(extension)) return 'audio';
			if (['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt'].includes(extension)) return 'document';
			return 'document'; // fallback
		} catch (e) {
			return 'document';
		}
	}
	uploadFileData() {
		let totalSize = 0;
		// console.log('Upload file method');
		// console.log('this.filesData : '+this.filesData);
		// console.log('this.filesData.length : '+this.filesData.length);
		// console.log('!this.fileName ',this.fileName);
		// console.log('this.allFiles :',this.allFiles);
		// console.log('this.allFiles.length : '+this.allFiles.length);
		for (let i = 0; i < this.allFiles.length; i++) {
			totalSize += this.allFiles[i].size;
		}
		if (totalSize > this.maxSize) {
			this.allFiles = [];
			this.fileError = 'Total file size exceeds 2 MB. Please select smaller files.';
		}
		if (this.allFiles.length > 5) {
			this.allFiles = [];
			this.fileError = 'Add Maximum of upto 5 files';
		} else if (this.allFiles.length == 0) {
			this.allFiles = [];
			this.fileError = 'Please Select at least one file.';
		} else if (this.allFiles.length <= 5 && totalSize < this.maxSize) {
			this.openFileModal = false;
			for (let i = 0; i < this.allFiles.length; i++) {
				if (this.allFiles[i].size > MAX_FILE_SIZE) {
					return;
				}
				let file = this.allFiles[i];
				this.fileName = file.name;
				if (!this.acceptedContentType.includes(file.type)) {
					this.allFiles = [];
					this.fileError = `File "${file.name}" is of unsupported type (${file.type}). Please upload a valid file.`;
					return;
				}
				if (this.acceptedContentType.includes(file.type)) {
					let reader = new FileReader();
					reader.onloadend = () => {
						this.filesData.push({
							filename: file.name,
							base64: reader.result.split(',')[1], // Extract base64 data 
							type: file.type,
							contentSize: file.size
						});
					};
					reader.readAsDataURL(file);
				}
			}
		}
	}
	get stagedAttachments() {
		if (this.filesData && this.filesData.length > 0) {
			return this.filesData.map((f, i) => ({
				filename: f.filename,
				key: `file-${i}-${f.filename}`,
				dataId: String(i)
			}));
		}
		if (this.mediaMode === 'url' && this.mediaUrl) {
			const name = this.extractFileNameFromUrl(this.mediaUrl) || 'media (URL)';
			return [{ filename: name + ' (URL)', key: 'url', dataId: 'url' }];
		}
		return [];
	}

	removeFilesPill(event) {
		const dataId = event.currentTarget.dataset.id;
		if (dataId === 'url') {
			this.mediaUrl = '';
			this.mediaMode = 'upload';
			return;
		}
		const index = parseInt(dataId, 10);
		if (!isNaN(index) && index >= 0 && this.filesData && this.filesData.length > index) {
			this.filesData.splice(index, 1);
			if (this.allFiles && this.allFiles.length > index) {
				this.allFiles.splice(index, 1);
			}
			if (this.filesData.length === 0) {
				this.fileName = '';
			} else {
				this.fileName = this.filesData.map(f => f.filename).join(', ');
			}
		}
	}
	showFileUpload() {
		this.showFileUploadSection = true;
		this.showUrlInputSection = false;
		this.uploadBtnVariant = 'brand';
		this.urlBtnVariant = 'neutral';
		this.clearMediaErrors();
	}

	showUrlInput() {
		this.showFileUploadSection = false;
		this.showUrlInputSection = true;
		this.uploadBtnVariant = 'neutral';
		this.urlBtnVariant = 'brand';
		this.clearMediaErrors();
	}

	clearMediaErrors() {
		this.mediaUrlError = false;
		this.fileNameError = false;
		this.fileError = '';
		this.mediaUrl = '';
	}

	handleTemplateName(event) {
		const recordId = event.currentTarget.dataset.recordid;
		if (recordId) {
			this[NavigationMixin.Navigate]({
				type: 'standard__recordPage',
				attributes: {
					recordId: recordId,
					actionName: 'view'
				}
			});
		}
	}
	handlePinMessage(event) {
		const messageId = event.currentTarget.dataset.id;
		const idx = this.messages.findIndex(msg => msg.Id === messageId);
		if (idx !== -1) {
			const currentState = this.messages[idx].SmartMsg__Pinned__c === true;
			const newPinState = !currentState;
			updatePinStatus({ messageId, isPinned: newPinState })
				.then(() => {
					this.messages = this.messages.map(msg => {
						if (msg.Id === messageId && newPinState) {
							return {
								...msg,
								SmartMsg__Pinned__c: true,
								pinLabel: 'Unpin Message',
								showMenu: false
							};
						} else {
							return {
								...msg,
								SmartMsg__Pinned__c: false,
								pinLabel: 'Pin Message',
								showMenu: false
							};
						}
					});
					this.pinnedMessageId = newPinState ? messageId : null;
					this.groupByDate(this.messages);
				})
				.catch(error => {
					console.error('Error in updatePinStatus:', error.body?.message || error);
				});
		}
	}

	handleStarMessage(event) {
		const messageId = event.currentTarget.dataset.id;
		const idx = this.messages.findIndex(msg => msg.Id === messageId);
		if (idx !== -1) {
			const isCurrentlyStarred = this.messages[idx].SmartMsg__Starred__c === true;
			const newStarState = !isCurrentlyStarred;
			updateStarStatus({ messageId, isStarred: newStarState })
				.then(() => {
					this.messages[idx].SmartMsg__Starred__c = newStarState;
					this.messages[idx].starLabel = newStarState ? 'Unstar Message' : 'Star Message';
					this.messages[idx].showMenu = false;
					this.messages[idx].isStarred = newStarState;
					if (this.showStarredOnly) {
						this.messages = this.messages.filter(msg => msg.isStarred == true)
					}
					// console.log('this.messages.length --> ', this.messages.length)

					if (this.messages.length == 0) {
						this.noStarredMessage = true;
					}
					this.groupByDate(this.messages);
				})
				.catch(error => {
					if (error && error.body && error.body.message) {
						console.error('Apex error message:', error.body.message);
					} else if (error && error.message) {
						// Handles JS errors
						console.error('JS error message:', error.message);
					} else {
						// Fallback for unknown formats
						console.error('Unknown error in fallback getSingleMessage for Outbound:', error);
					}

				});
		}
	}
	get pinnedMessage() {

		return this.messages?.find(m => m.Id === this.pinnedMessageId);
	}
	handleUnpinMessage() {
		for (let msg of this.messages) {
			if (msg.SmartMsg__Pinned__c == true) {
				msg.SmartMsg__Pinned__c = false;
				msg.pinLabel = 'Pin Message'
				msg.showMenu = false
			}
		}
		const messageId = this.pinnedMessageId;
		updatePinStatus({ messageId, isPinned: false })
			.then(() => {
				this.messages = this.messages.map(msg => {
					if (msg.Id === messageId && msg.SmartMsg__Pinned__c) {
						return {
							...msg,
							SmartMsg__Pinned__c: true,
							pinLabel: 'Unpin Message',
							showMenu: false
						};
					} else {
						return {
							...msg,
							SmartMsg__Pinned__c: false,
							pinLabel: 'Pin Message',
							showMenu: false
						};
					}
				});
				this.groupByDate(this.messages);
			})
			.catch(error => {
				console.error('Error in updatePinStatus:', error.body?.message || error);
			});
		this.pinnedMessageId = null;
		this.groupMessagesByDate();
	}
	toggleEinsteinMenu() {
		event.preventDefault();
		event.stopPropagation();
		this.showEinsteinMenu = !this.showEinsteinMenu;
		this.einsteinActive = this.showEinsteinMenu;
		this.showFooterMenu = false;
		if (this.showEinsteinMenu) {
			window.addEventListener('click', this.handleClickOutside.bind(this));
			this.setDefaultDate();
			this.selectedTime = null;
			this.errorMessage = '';
			this.inputerrorMessage = '';
		} else {
			window.removeEventListener('click', this.handleClickOutside.bind(this));
		}
	}
	async handleEinsteinSuggestion() {
		this.showEinsteinMenu = false;
		this.aiLoading = true;
		const lastUserMessage = (this.messages || [])
			.filter(msg => msg.Incoming)
			.slice(-1)[0]?.SmartMsg__Message_Body__c || '';
		if (!lastUserMessage) {
			this.showToast('No user message found for suggestion.', '', 'info');
			return;
		}
		try {
			const result = await getAISuggestions({
				message: lastUserMessage
			});
			this.aiSuggestions = result && result.suggestions ? result.suggestions : [];
			this.aiSentiment = result && result.sentiment ? result.sentiment : '';
			this.aiBriefReply = result && result.brief_reply ? result.brief_reply : '';
			this.messageText = this.aiBriefReply;
			this.einsteinResultType = 'suggestion';
			this.aiLoading = false;
		} catch (e) {
			this.showToast('AI Suggestion Error', e.body?.message || e.message, 'error');
		}
		this.aiLoading = false;
	}
	handleSuggestionClick(event) {
		this.messageText = event.target.textContent;
	}
	async handleEinsteinSummary() {
		this.showEinsteinMenu = false;
		this.aiLoading = true;
		try {
			const summary = await getConversationSummary({
				phoneNumber: this.formattedPhoneNumber
			});
			this.conversationSummary = summary;
			this.einsteinResultType = 'summary';
			this.summaryModal = true;
		} catch (e) {
			this.showToast('AI Summary Error', e.body?.message || e.message, 'error');
		}
		this.aiLoading = false;
	}
	async handleEinsteinReframe() {
		this.showEinsteinMenu = false;
		this.aiLoading = true;
		const message = this.messageText;
		if (!message) {
			this.showToast('No message found for reframing.', '', 'info');
			return;
		}
		try {
			const result = await reframeSentence({
				message: message
			});
			this.aiSentence = result;
			this.messageText = this.aiSentence;
			this.einsteinResultType = 'reframe';
			this.aiLoading = false;
		} catch (e) {
			this.showToast('AI Reframing Error', e.body?.message || e.message, 'error');
		}
		this.aiLoading = false;
	}
	get starMenuLabel() {
		return this.showStarredOnly ? 'Show All Messages' : 'Show Starred Messages';
	}
	closeSummaryModal() {
		this.summaryModal = false;
	}
	copyToClipboard() {
		const el = document.createElement('textarea');
		el.value = this.conversationSummary;
		document.body.appendChild(el);
		el.select();
		document.execCommand('copy');
		document.body.removeChild(el);
		this.showToast('Copied', 'Summary copied to clipboard!', 'success');
		this.summaryModal = false;
	}

	showToast(title, message, variant) {
		const evt = new ShowToastEvent({
			title: title,
			message: message,
			variant: variant,
		});
		this.dispatchEvent(evt);
	}
	handleBriefReplyClick() {
		this.messageText = this.aiBriefReply;
		this.aiBriefReply = '';
	}
	handleColor() {
		if (/ipad|iphone/i.test(navigator.userAgent)) {
			try {
				const menuWrapper = this.template.querySelectorAll('.menu-wrapper')
				menuWrapper.forEach(wrapper => {
					wrapper.classList.add('ios-menu-wrapper');
				});
			} catch (error) {
				console.error(error)
			}

			try {
				const inboundMenuWrapper = this.template.querySelectorAll('.inbound-menu-wrapper');
				inboundMenuWrapper.forEach(inboundWrapper => {
					inboundWrapper.classList.add('ios-inbound-menu-wrapper');
				});
			} catch (error) {
				console.error(error)
			}

			try {
				const textInbound = this.template.querySelectorAll('.text-bound');
				textInbound.forEach(inbound => {
					inbound.classList.add('ios-text-outbound');
				});
			} catch (error) {
				console.error(error);
			}
		}
	}
	handleShedulePopup() {
		if (/ipad|iphone/i.test(navigator.userAgent)) {
			try {
				const schedulePopup = this.template.querySelector('.scheduling-popup');
				schedulePopup.classList.add('ios-scheduled-popup');
			}
			catch (error) {
				console.error(error)
			}

			try {
				const continueButton = this.template.querySelector('.continue-button');
				continueButton.classList.add('ios-continue-button');
			} catch (error) {
				console.error(error);
			}

			try {
				const chatInput = this.template.querySelector('.chat-input');
				chatInput.classList.add('ios-chat-input');
			} catch (error) {
				console.error(error);
			}

			try {
				let msgChatInput = this.template.querySelector('.msg-chat-input');
				msgChatInput.classList.add('ios-msg-chat-input');
			} catch (error) {
				console.error(error);
			}

			try {
				const pickerInput = this.template.querySelector('.date-picker');
				pickerInput.classList.add('ios-date-picker');
			} catch (error) {
				console.error(error);
			}
		}

	}

	handleSearchBar() {
		if (/ipad|iphone/i.test(navigator.userAgent)) {
			try {
				const searchBarContanier = this.template.querySelector('.search-bar-container');
				searchBarContanier.classList.add('ios-searchbar-container');
			} catch (error) {
				console.error(error);
			}
			try {
				let msgChatInput = this.template.querySelector('.msg-chat-input');
				msgChatInput.classList.add('ios-msg-chat-input');
			} catch (error) {
				console.error(error);
			}

			try {
				let footerArea = this.template.querySelector('.footer-area');
				footerArea.style.bottom = '-40px';
			} catch (error) {
				console.error(error);
			}

			try {
				let customCard = this.template.querySelector('.custom-card');
				customCard.style.marginBottom = '30px';
			} catch (error) {
				console.error(error);
			}

			try {
				let footer = this.template.querySelector('.margin-zero');
				footer.style.bottom = '20px';
			} catch (error) {
				console.error(error);
			}

			try {
				let searchBarContainer = this.template.querySelector('.search-bar-container');
				searchBarContainer.style.top = '49px';
			} catch (error) {
				console.error(error);
			}
		}
		if (navigator.userAgent.match(/iPhone/i)) {
			let einsteinMenu = this.template.querySelector('.einstein-dropup-menu');
			let phoneInput = this.template.querySelector('.phone-input');
			let reengagementPopup = this.template.querySelector('.reengagement-popup');
			let inputWrapper = this.template.querySelector('.input-wrapper');
			let footerArea = this.template.querySelector('.footer-area');
			try {
				einsteinMenu.style.width = '145px';
			} catch (error) {
				console.error(error);
			}
			try {
				phoneInput.style.marginBottom = '10px';
			} catch (error) {
				console.error(error);
			}
			try {
				reengagementPopup.style.bottom = '25px';
			} catch (error) {
				console.error(error);
			}
			try {
				inputWrapper.style.width = '300px';
				// console.log(inputWrapper,'InputWrapper');
			} catch (error) {
				// console.log(error)
			}
			try {
				footerArea.style.justifyContent = 'space-between';
			} catch (error) {
				console.error(error);
			}

		}
	}
	openMedia(event) {
		const fullUrl = event.target.dataset.url;  // e.g., "/sfc/servlet.shepherd/document/download/069gK000002UXDVQA4"
		const match = fullUrl.match(/\/([0-9A-Za-z]{15,18})$/);
		if (match && match[1]) {
			const contentDocumentId = match[1];
			this[NavigationMixin.Navigate]({
				type: 'standard__namedPage',
				attributes: {
					pageName: 'filePreview'
				},
				state: {
					selectedRecordId: contentDocumentId
				}
			});
		} else {
			console.error('Could not extract ContentDocumentId from URL:', fullUrl);
		}
	}
	handleExternalMediaClick(event) {
		const url = event.currentTarget.dataset.url;
		if (url && url.startsWith('http')) {
			window.open(url, '_blank');
		}
	}

	extractFileNameFromUrl(url) {
		if (!url) return '';

		try {
			const cleanUrl = url.split('?')[0].split('#')[0];
			const fileName = cleanUrl.substring(cleanUrl.lastIndexOf('/') + 1);
			return decodeURIComponent(fileName); // handle %20 or URL-encoded chars
		} catch (error) {
			console.error(error);
			return '';
		}
	}

	get isLocationRequest() {
		return this.message.SmartMsg__Message_Type__c === 'location-request';
	}

	// In your LWC JS:
	scrollToPinnedMessage() {
		if (!this.pinnedMessageId) return;
		const msgElement = this.template.querySelector(`[data-message-id="${this.pinnedMessageId}"]`);
		if (msgElement) {
			msgElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
			msgElement.classList.add('highlight');
			setTimeout(() => msgElement.classList.remove('highlight'), 1200);
		}
	}

	scrollToMessage(messageId) {
		const messageElement = this.template.querySelector(`[data-message-id="${messageId}"]`);
		if (messageElement) {
			messageElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
			// Optional: apply highlight effect
			messageElement.classList.add('highlight');
			setTimeout(() => messageElement.classList.remove('highlight'), 1200);
		}
	}


}