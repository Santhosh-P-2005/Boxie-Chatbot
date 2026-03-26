import { LightningElement, track, wire } from 'lwc';
import { subscribe, unsubscribe } from 'lightning/empApi';
import { EnclosingUtilityId, updateUtility, updatePanel } from 'lightning/platformUtilityBarApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import WhatsAppIcon from '@salesforce/resourceUrl/WhatsAppIcon';
import SmsIcon from '@salesforce/resourceUrl/SmsIcon';
import findContactOrAccount from '@salesforce/apex/IncomingSmsController.findContactOrAccount';
import getIncomingSms from '@salesforce/apex/IncomingSmsController.getIncomingSms';
import getSingleMessage from '@salesforce/apex/IncomingSmsController.getSingleMessage';
import markAsRead from '@salesforce/apex/IncomingSmsController.markAsRead';
import getLastSentUser from '@salesforce/apex/IncomingSmsController.getLastSentUser';
import USER_ID from '@salesforce/user/Id';
import deleteMessage from '@salesforce/apex/IncomingSmsController.deleteMessage';
import Notification_Sound from '@salesforce/resourceUrl/Notification_Sound';
export default class IncomingSmsNotification extends NavigationMixin(LightningElement) {
    @track messages = [];
    @track filteredMessages = [];
    @track groupedMessages = false;
    @track selectedTab = 'ALL';
    @track searchTerm = '';
    @track unreadCount = 0;
    @track currentPage = 1;
    @track pageSize = 10;
    @track totalPages = 0;
    @track showChatModal = false;
    @track chatRecordId;
    @track chatObjectApiName;
    @track chatPhoneNumber;
    @track isChatVisible = false;
    @track chatTitle = 'Chat';
    @track senderName;
    whatsappIconUrl = WhatsAppIcon;
    smsIconUrl = SmsIcon;

    isSpinner = false;
    subscription = {};
    channelName = '/event/SmartMsg__Incoming_Message__e';
    audioContext;
    audioBuffer;

    @wire(EnclosingUtilityId) enclosingUtilityId;


    utilityAttrs = {
        label: 'Incoming Messages',
        icon: 'messaging_conversation',
        iconVariant: 'success',
        highlighted: false
    }

    panelAttrs = {
        label: 'Incoming Messages',
        icon: 'messaging_conversation',
        iconVariant: 'current-color'
    }
    connectedCallback() {

        this.subscribeToEvents();
        this.loadIncomingMessages();
        this.updateUtilityLabel();
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
        this.loadAudio();
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
    }

    subscribeToEvents() {
        subscribe(this.channelName, -1, this.handleIncomingMessage.bind(this))
            .then(response => {
                this.subscription = response;
            })
            .catch(error => {
                console.error('Error subscribing to channel:', error);
            });
    }

    loadAudio() {
        fetch(Notification_Sound)
            .then(response => response.arrayBuffer())
            .then(buffer => this.audioContext.decodeAudioData(buffer))
            .then(decodedData => {
                this.audioBuffer = decodedData;
            })
            .catch(error => console.error('Error loading audio:', error));
    }

    playAudio() {
        if (this.audioBuffer) {
            const source = this.audioContext.createBufferSource();
            source.buffer = this.audioBuffer;
            source.connect(this.audioContext.destination);
            source.start(0);
        }
    }

    async loadIncomingMessages() {
        this.isSpinner = true;
        try {
            const result = await getIncomingSms();
            const phoneNumbers = [...new Set(result.map(msg => msg.SmartMsg__To_Number__c))];
            const contactOrAccountMap = await findContactOrAccount({ phoneNumbers });
            this.messages = result.map(msg => {
                const contactOrAccount = contactOrAccountMap[msg.SmartMsg__To_Number__c];
                 const fileName = msg.SmartMsg__File_Name__c || '';
                const mimeType = msg.SmartMsg__Video_Type__c || '';
                const isImage = /\.(jpg|jpeg|png)$/i.test(fileName);
                const isAudio = mimeType.startsWith('audio/');
                const isVideo = mimeType.startsWith('video/');
                const isFile = !(isImage || isAudio || isVideo);
               return {
                    ...msg,
                    senderName: contactOrAccount ? contactOrAccount.name : msg.SmartMsg__To_Number__c,
                    recordId: contactOrAccount ? contactOrAccount.id : null,
                    recordType: contactOrAccount ? contactOrAccount.type : null,
                    formattedDate: this.formatDateForDisplay(msg.CreatedDate),
                    unreadCount: msg.SmartMsg__Is_Read__c ? 0 : 1,
                    isRead: msg.SmartMsg__Is_Read__c,
                    isWhatsApp: msg.SmartMsg__Channel__c == 'WhatsApp' ? true : false,
                    isSMS: msg.SmartMsg__Channel__c == 'SMS' ? true : false,
                    hasMedia: false,
                    mediaUrl: msg.SmartMsg__Media_Url__c ? `/sfc/servlet.shepherd/document/download/${msg.SmartMsg__Media_Url__c}` : null,
                    isImage: isImage,
                    isAudio: isAudio,
                    isVideo: isVideo,
                    isFile: isFile
                };
            });
            this.processMessagesAndFilters();
            this.updateUnreadCount();
        } catch (error) {
            console.error('Error loading messages:', this.extractErrorMessage(error));
        } finally {
            this.isSpinner = false;
        }
    }
    processMessagesAndFilters() {
        if (this.selectedTab === 'UNREAD') {
            const unreadMessages = this.messages.filter(msg => !msg.SmartMsg__Is_Read__c);
            let grouped = this.groupMessagesBySender(unreadMessages);
            this.filteredMessages = grouped.filter(msg => msg.unreadCount > 0);
        } else if (this.selectedTab === 'ALL') {
            const sortedMessages = [...this.messages].sort((a, b) =>
                new Date(b.CreatedDate) - new Date(a.CreatedDate)
            );
            let grouped = this.groupMessagesBySender(sortedMessages);
            this.filteredMessages = grouped;
        }
        this.filterMessages();
        this.updateUnreadCount();
    }
    updateUtilityLabel() {
        if (this.enclosingUtilityId) {
            this.utilityAttrs.label = `Incoming Messages(${this.unreadCount})`;
            this.panelAttrs.label = `Incoming Messages(${this.unreadCount})`;
            updatePanel(this.enclosingUtilityId, this.panelAttrs);
            updateUtility(this.enclosingUtilityId, this.utilityAttrs);
        }
    }
    handleRecordClick(event) {
        const recordId = event.currentTarget.dataset.recordid;
        const recordType = event.currentTarget.dataset.recordtype;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: recordType,
                    actionName: 'view'
                }
            });
        }
    }

    handleHeaderClick(event) {
        const recordId = event.currentTarget.dataset.recordid;
        const recordType = event.currentTarget.dataset.recordtype;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: recordType,
                    actionName: 'view'
                }
            });
        }
    }

    filterMessages() {
        this.isSpinner = true;
        let filtered = [...this.messages];
        if (this.searchTerm) {
            filtered = filtered.filter(msg =>
                (msg.senderName && msg.senderName.toLowerCase().includes(this.searchTerm)) ||
                (msg.SmartMsg__Message_Body__c && msg.SmartMsg__Message_Body__c.toLowerCase().includes(this.searchTerm))
            );
        }
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        if (this.selectedTab === 'ALL') {
            const sortedMessages = [...this.messages].sort((a, b) =>
                new Date(b.CreatedDate) - new Date(a.CreatedDate)
            );
            let grouped = this.groupMessagesBySender(sortedMessages);
            grouped = grouped.filter(msg =>
                (msg.senderName && msg.senderName.toLowerCase().includes(this.searchTerm.toLowerCase())) ||
                (msg.SmartMsg__Message_Body__c && msg.SmartMsg__Message_Body__c.toLowerCase().includes(this.searchTerm.toLowerCase()))
            );
            this.totalPages = Math.ceil(grouped.length / this.pageSize);
            this.filteredMessages = grouped.slice(startIndex, endIndex);
        }
        else if (this.selectedTab === 'UNREAD') {
            const unreadMessages = filtered.filter(msg => !msg.SmartMsg__Is_Read__c);
            let grouped = this.groupMessagesBySender(unreadMessages);
            grouped = grouped.filter(msg => msg.unreadCount > 0);
            this.totalPages = Math.ceil(grouped.length / this.pageSize);
            this.filteredMessages = grouped.slice(startIndex, endIndex);
        }
        if (this.filteredMessages.length === 0 && this.currentPage > 1) {
            this.currentPage = 1;
            this.filterMessages();
        }
        this.isSpinner = false;
    }
    groupMessagesBySender(messages) {
        const grouped = {};
        messages.forEach(msg => {
            const key = msg.SmartMsg__To_Number__c;
            if (!grouped[key]) {
                grouped[key] = {
                    ...msg,
                    unreadCount: 0,
                    messages: []
                };
            }
            grouped[key].messages.push(msg);
            if (!msg.isRead) {
                grouped[key].unreadCount++;
            }
            if (!grouped[key].lastMessageDate || new Date(msg.CreatedDate) > new Date(grouped[key].lastMessageDate)) {
                grouped[key].SmartMsg__Message_Body__c = msg.SmartMsg__Message_Body__c;
                grouped[key].formattedDate = this.formatDateForDisplay(msg.CreatedDate);
                grouped[key].lastMessageDate = msg.CreatedDate;
                grouped[key].hasMedia = msg.SmartMsg__Media_Url__c ? true : false;
            }
        });
        return Object.values(grouped).sort((a, b) =>
            new Date(b.lastMessageDate) - new Date(a.lastMessageDate)
        );
    }
    updateUnreadCount() {
        const unreadMessages = this.messages.filter(msg => {
            return msg && (msg.SmartMsg__Is_Read__c === false || msg.isRead === false);
        });
        this.unreadCount = unreadMessages.length;
        if (this.enclosingUtilityId) {
            this.utilityAttrs.label = `Incoming Messages(${this.unreadCount})`;
            this.panelAttrs.label = `Incoming Messages(${this.unreadCount})`;
            Promise.all([
                updatePanel(this.enclosingUtilityId, this.panelAttrs),
                updateUtility(this.enclosingUtilityId, this.utilityAttrs)
            ]).catch(error => {
                console.error('Error updating utility bar:', error);
            });
        }
    }
    handleIncomingMessage(event) {
        const eventData = event.data.payload;
        if (eventData.SmartMsg__Event_Type__c === 'Inbound') {
            const phoneNumber = eventData.SmartMsg__From_Number__c;
            this.playAudio();
            getSingleMessage({ recordId: eventData.SmartMsg__Record_Id__c, customerPhone: phoneNumber })
                .then(messageDetails => {
                    findContactOrAccount({ phoneNumbers: [phoneNumber] })
                        .then(contactOrAccountMap => {
                            const contactOrAccount = contactOrAccountMap[phoneNumber];
                            // const hasMedia = messageDetails.SmartMsg__Media_Url__c ? true : false;
                            const contentDocId = messageDetails[0].SmartMsg__Media_Url__c;
                            const fileName = messageDetails[0].SmartMsg__File_Name__c || '';
                            const mimeType = messageDetails[0].SmartMsg__Video_Type__c || '';
                            const isImage = /\.(jpg|jpeg|png)$/i.test(fileName);
                            const isAudio = mimeType.startsWith('audio/');
                            const isVideo = mimeType.startsWith('video/');
                            const isFile = !(isImage || isAudio || isVideo);
                            const newMessage = {
                                id: messageDetails[0].Id,
                                Id: messageDetails[0].Id,
                                senderName: contactOrAccount ? contactOrAccount.name : phoneNumber,
                                senderType: contactOrAccount ? contactOrAccount.type : 'Unknown',
                                recordId: contactOrAccount ? contactOrAccount.id : null,
                                recordType: contactOrAccount ? contactOrAccount.type : null,
                                phoneNumber: phoneNumber,
                                SmartMsg__Message_Body__c: messageDetails[0].SmartMsg__Message_Body__c,
                                CreatedDate: messageDetails[0].CreatedDate,
                                formattedDate: this.formatDateForDisplay(messageDetails[0].CreatedDate),
                                unreadCount: 1,
                                isRead: false,
                                SmartMsg__Is_Read__c: false,
                                Incoming: true,
                                SmartMsg__Type__c: 'Inbound',
                                SmartMsg__Delivery_Status__c: 'Received',
                                isWhatsApp: messageDetails[0].SmartMsg__Channel__c == 'WhatsApp' ? true : false,
                                isSMS: messageDetails[0].SmartMsg__Channel__c == 'SMS' ? true : false,
                                SmartMsg__To_Number__c: phoneNumber,
                                // ✅ Add these for immediate preview:
                                SmartMsg__Media_Url__c: contentDocId,
                                SmartMsg__Video_Type__c: mimeType,
                                isImage : isImage,
                                isAudio : isAudio,
                                isVideo : isVideo,
                                isFile : isFile,                             
                                hasMedia: contentDocId ? true : false,
                                mediaUrl: messageDetails[0].SmartMsg__Media_Url__c ? `/sfc/servlet.shepherd/document/download/${messageDetails[0].SmartMsg__Media_Url__c}` : null
                            };
                            if (this.currentPage === 1) {
                                this.messages = [newMessage, ...this.messages];
                                this.processMessagesAndFilters();
                            }
                            if (this.enclosingUtilityId) {
                                this.utilityAttrs.label = `Incoming Messages(${this.unreadCount})`;
                                this.panelAttrs.label = `Incoming Messages(${this.unreadCount})`;
                                updatePanel(this.enclosingUtilityId, this.panelAttrs);
                                updateUtility(this.enclosingUtilityId, this.utilityAttrs);
                            }
                            this.blinkUtilityBar(phoneNumber, true);
                            getLastSentUser({ phoneNumber: phoneNumber })
                                .then(lastOutboundData => {
                                    const lastOutboundUserId = lastOutboundData?.userId;
                                    const shouldStayBlinking = (lastOutboundUserId === USER_ID);
                                    this.blinkUtilityBar(phoneNumber, shouldStayBlinking);
                                })
                                .catch(error => console.error('Error fetching last sent user:',this.extractErrorMessage(error)));
                        })
                        .catch(error => console.error('Error processing incoming message:', this.extractErrorMessage(error)));
                })
                .catch(error => console.error('Error getting single message:',this.extractErrorMessage(error)));
        }
    }
    blinkUtilityBar(phoneNumber, shouldStayBlinking) {
        let blinkCount = 0;
        const maxBlinks = 5;
        const blinkSpeed = 700;
        const blinkInterval = setInterval(() => {
            this.utilityAttrs.highlighted = !this.utilityAttrs.highlighted;
            updateUtility(this.enclosingUtilityId, this.utilityAttrs);
            blinkCount++;
            if (!shouldStayBlinking && blinkCount >= maxBlinks) {
                clearInterval(blinkInterval);
                this.utilityAttrs.highlighted = true;
                updateUtility(this.enclosingUtilityId, this.utilityAttrs);
            }
            if (shouldStayBlinking && (!this.unreadReplies || !this.unreadReplies.has(phoneNumber))) {
                clearInterval(blinkInterval);
                this.utilityAttrs.highlighted = false;
                updateUtility(this.enclosingUtilityId, this.utilityAttrs);
            }
        }, blinkSpeed);
        if (shouldStayBlinking) {
            if (!this.unreadReplies) {
                this.unreadReplies = new Set();
            }
            this.unreadReplies.add(phoneNumber);
        }
    }
    clearUtilityHighlight() {
        if (this.utilityBar) {
            this.utilityBar.then((utility) => {
                utility.setUtilityHighlighted({
                    highlighted: false
                });
            });
        }
    }



    handleTabChange(event) {
        this.selectedTab = event.currentTarget.dataset.tab;
        this.filterMessages();
        this.clearUtilityHighlight();
    }
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filterMessages();
    }
    formatDateForDisplay(dateString) {
        const messageDate = new Date(dateString);
        const today = new Date();
        if (messageDate.toDateString() === today.toDateString()) {
            return 'Today';
        }
        const diffDays = Math.floor((today - messageDate) / (1000 * 60 * 60 * 24));
        if (diffDays === 0) {
            return 'Today';
        } else if (diffDays === 1) {
            return 'Yesterday';
        } else if (diffDays < 7) {
            return `${diffDays} days ago`;
        } else {
            return messageDate.toLocaleDateString();
        }
    }
    showNotification(message) {
        const evt = new ShowToastEvent({
            title: `New Message from ${message.senderName}`,
            message: message.message,
            variant: 'info',
            mode: 'sticky'
        });
        this.dispatchEvent(evt);
    }
    showToastMessage(title, message, variant, mode = 'dismissable') {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: mode
        });
        this.dispatchEvent(event);
    }

    get allTabClass() {
        return `slds-button ${this.selectedTab === 'ALL' ? 'slds-button_brand' : 'slds-button_neutral'}`;
    }

    get unreadTabClass() {
        return `slds-button ${this.selectedTab === 'UNREAD' ? 'slds-button_brand' : 'slds-button_neutral'}`;
    }

    handleRefresh() {
        this.isSpinner = true;
        const refreshIcon = this.template.querySelector('.refresh-icon');
        if (refreshIcon) {
            refreshIcon.classList.add('rotate');
            setTimeout(() => {
                refreshIcon.classList.remove('rotate');
            }, 500);
        }
        this.loadIncomingMessages();
    }


    handleMarkAsRead(event) {
        const messageId = event.currentTarget.dataset.id;
        const currentMessage = this.messages.find(msg => msg.Id === messageId);
        if (!currentMessage) return;
        const phoneNumber = currentMessage.SmartMsg__To_Number__c;
        this.messages = this.messages.map(msg => {
            if (msg.SmartMsg__To_Number__c === phoneNumber) {
                return {
                    ...msg,
                    isRead: true,
                    unreadCount: 0,
                    SmartMsg__Is_Read__c: true
                };
            }
            return msg;
        });
        if (this.selectedTab === 'UNREAD') {
            this.filteredMessages = this.filteredMessages.filter(msg =>
                msg.SmartMsg__To_Number__c !== phoneNumber
            );
        } else {
            this.filteredMessages = this.filteredMessages.map(msg => {
                if (msg.SmartMsg__To_Number__c === phoneNumber) {
                    return {
                        ...msg,
                        isRead: true,
                        unreadCount: 0,
                        SmartMsg__Is_Read__c: true
                    };
                }
                return msg;
            });
        }
        markAsRead({ phoneNumber: phoneNumber })
            .then(() => {
                this.showToastMessage('Success', 'Messages marked as read', 'success');
                this.processMessagesAndFilters();
                this.stopBlinkingForPhone(phoneNumber);
            })
            .catch(error => {
                console.error('Error marking messages as read:', error);
                this.showToastMessage('Error', 'Failed to mark messages as read', 'error');
                this.loadIncomingMessages();
            });

        this.updateUnreadCount();
    }
    handleCopyMessage(event) {
        const messageId = event.currentTarget.dataset.id;
        const message = this.messages.find(msg => msg.id === messageId);
        if (message) {
            navigator.clipboard.writeText(message.message);
            this.showToast('Success', 'Message copied to clipboard', 'success');
        }
    }

    handleDelete(event) {
        const messageId = event.currentTarget.dataset.id;
        const messageToDelete = this.messages.find(msg => msg.Id === messageId);
        if (!messageToDelete) return;
        const phoneNumber = messageToDelete.SmartMsg__To_Number__c;
        if (!confirm('Are you sure you want to delete this message?')) {
            return;
        }
        if (this.selectedTab === 'UNREAD') {
            this.filteredMessages = this.filteredMessages.filter(msg =>
                msg.Id !== messageId && msg.SmartMsg__To_Number__c !== this.messages.find(m => m.Id === messageId)?.SmartMsg__To_Number__c
            );
        } else {
            this.filteredMessages = this.filteredMessages.filter(msg => msg.Id !== messageId);
        }
        this.messages = this.messages.filter(msg => msg.Id !== messageId);
        this.updateUnreadCount();
        deleteMessage({ messageId: messageId })
            .then(() => {
                this.showToastMessage('Success', 'Message deleted successfully', 'success');
                this.stopBlinkingForPhone(phoneNumber);
                this.updateUtilityLabel();
            })
            .catch(error => {
                console.error('Error deleting message:', error);
                this.showToastMessage('Error', 'Failed to delete message', 'error');
                this.loadIncomingMessages();
            });
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.filterMessages();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.filterMessages();
        }
    }

    get isPreviousDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    handleReply(event) {
        const phoneNumber = event.currentTarget.dataset.number;
        const recordId = event.currentTarget.dataset.recordid;
        const recordType = event.currentTarget.dataset.recordtype;
        const senderName = event.currentTarget.dataset.sendername;
        this.messages = this.messages.map(msg => {
            if (msg.SmartMsg__To_Number__c === phoneNumber) {
                return {
                    ...msg,
                    isRead: true,
                    unreadCount: 0,
                    SmartMsg__Is_Read__c: true
                };
            }
            return msg;
        });
        if (this.selectedTab === 'UNREAD') {
            this.filteredMessages = this.filteredMessages.filter(msg =>
                msg.SmartMsg__To_Number__c !== phoneNumber
            );
        }
        markAsRead({ phoneNumber: phoneNumber })
            .then(() => {
                this.filterMessages();
                this.updateUnreadCount();
                this.stopBlinkingForPhone(phoneNumber);
            })
            .catch(error => {
                console.error('Error marking messages as read:', error);
                this.showToastMessage('Error', 'Failed to mark messages as read', 'error');
                this.loadIncomingMessages();
            });

        this.chatPhoneNumber = phoneNumber;
        this.chatRecordId = recordId;
        this.chatObjectApiName = recordType;

        this.isChatVisible = true;
        this.chatTitle = senderName || phoneNumber || 'Chat';
        this.updateUtilityLabel();
    }

    handleBack() {
        try {
            this.isChatVisible = false;
            this.chatPhoneNumber = null;
            this.chatRecordId = null;
            this.chatObjectApiName = null;
            this.updateUtilityLabel();
            this.chatTitle = 'Chat';
        }
        catch (error) {
            console.error('Error closing chat:', error);
        }
    }
    stopBlinkingForPhone(phoneNumber) {
        if (this.unreadReplies) {
            this.unreadReplies.delete(phoneNumber);
        }
        if (!this.unreadReplies || this.unreadReplies.size === 0) {
            this.utilityAttrs.highlighted = false;
            updateUtility(this.enclosingUtilityId, this.utilityAttrs);
        }
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return JSON.stringify(error);
    }

}