/**
 * @description Application constants for chatbot questions, template names, and subscription date.
 */
public with sharing class Constants {
    //Subscription End Date
    public static final String SUBSCRIPTION_END_DATE = '2026-07-16';
    // Comma-separated emails to notify when subscription is within 7 days of expiry (e.g. 'admin@example.com,ops@example.com')
    public static final List<String> SUBSCRIPTION_NOTIFICATION_EMAILS = new List<String>{'sales@winfoim.com','vijay.kumar@winfomi.com','santhosh090405@gmail.com'};
    public static final Integer NOTIFICATION_THRESHOLD_DAYS = 7;

    //Whatsappchatbot.cls
    //Reservation questions
    public static final List<String> CONFIRMATION_QUESTION = new List<String>{'Would you like us to pick up your items for you? 🚚', 'Zullen we je spullen komen ophalen? 🚚', 'Sollen wir Ihre Gegenstände abholen? 🚚'};
    public static final List<String> SCHEDULE_QUESTION = new List<String>{'Perfect. What is your preferred date for the pick-up? 🗓️', 'Helemaal goed. Wanneer wil je dat we de spullen komen ophalen?', 'Perfekt. Welches Abholdatum wäre Ihnen am liebsten? 🗓️'};
    public static final String DELIVER_QUESTION = 'No problem. What is your preferred date for the delivery of your items? 🗓️';
    public static final List<String> PICKUP_NO_MESSAGE = new List<String>{'ll bring it.', 'ik breng ze.', 'ich bringe sie'};
    public static final List<String> LANGUAGE_LIST = new List<String>{'English', 'Deutsch', 'Nederlands'};
    public static final List<String> EMAIL_LIST = new List<String>{'email address', 'E-Mail-Adresse', 'e-mailadres'};

    // //Pickup Service questions
    // public static final String PICKUP_CONFIRMATION_QUESTION = 'Pickup: Do you want us to pick up your items?';
    // public static final String PICKUP_SCHEDULE_QUESTION = 'Pickup: When do you what to us to pick up your items?';
    public static final List<String> MORE_ITEMS_LIST = new List<String>{'➕ Add More Items','➕ Weitere Abholung','➕ Meer items toevoegen'};
    public static final List<String> OTHER_QUESTION = new List<String>{'💬 Chat with an Expert', '💬 Chat met een expert', '💬Experten fragen'};
    public static final List<String> RESERVATION = new List<String>{'Reservation', 'Reserveer','reservieren'};
    public static final String  FOLLOWUP_PICKUP = 'Follow Up Pickup';

    public static final String DYNAMIC_TEXT_TEMPLATE_NAME = 'dynamic_text_template';
    public static final String DYNAMIC_QUICK_REPLY_TEMPLATE_NAME = '_dynamic_quick_reply';
    public static final String DYNAMIC_LIST_PICKER_TEMPLATE_NAME = '_dynamic_list_picker';
    public static final String DYNAMIC_LIST_PICKER_WITH_NO_DESCRIPTION = '_list_with_no_description';
}