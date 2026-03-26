/**
 * @description Application constants for chatbot questions, template names, and subscription date.
 */
public with sharing class Constants {
    //Subscription End Date
    public static final String SUBSCRIPTION_END_DATE = '2026-04-16';
    // Comma-separated emails to notify when subscription is within 7 days of expiry (e.g. 'admin@example.com,ops@example.com')
    public static final List<String> SUBSCRIPTION_NOTIFICATION_EMAILS = new List<String>{'sales@winfoim.com','vijay.kumar@winfomi.com','santhosh090405@gmail.com'};
    public static final Integer NOTIFICATION_THRESHOLD_DAYS = 7;

    //Whatsappchatbot.cls
    //Reservation questions
    public static final String CONFIRMATION_QUESTION = 'Would you like us to pick up your items for you? 🚚';
    public static final String SCHEDULE_QUESTION = 'Perfect. What is your preferred date for the pick-up? 🗓️';
    public static final String DELIVER_QUESTION = 'No problem. What is your preferred date for the delivery of your items? 🗓️';
    public static final String PICKUP_NO_MESSAGE = 'get it myself.';

    // //Pickup Service questions
    // public static final String PICKUP_CONFIRMATION_QUESTION = 'Pickup: Do you want us to pick up your items?';
    // public static final String PICKUP_SCHEDULE_QUESTION = 'Pickup: When do you what to us to pick up your items?';
    public static final String OTHER_QUESTION= '💬 Chat with an Expert';
    public static final String  FOLLOWUP_PICKUP = 'Follow Up Pickup';

    public static final String DYNAMIC_TEXT_TEMPLATE_NAME = 'dynamic_text_template';
    public static final String DYNAMIC_QUICK_REPLY_TEMPLATE_NAME = '_dynamic_quick_reply';
    public static final String DYNAMIC_LIST_PICKER_TEMPLATE_NAME = '_dynamic_list_picker';
    public static final String DYNAMIC_LIST_PICKER_WITH_NO_DESCRIPTION = '_list_with_no_description';
}
