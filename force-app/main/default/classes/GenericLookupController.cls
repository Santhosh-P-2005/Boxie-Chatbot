/**
 *  @File Name : GenericLookupController.cls
 * @Description : This class is used to perform search on any object and return the list of records
 * @Author :
 * @Last Modified By :
 * @Last Modified On : April 16, 2025
 * @Modification Log :
 *==============================================================================
 * Ver | Date | Author | Modification
 *==============================================================================
 * 1.0 | April 16, 2025 |   | Initial Version
 **/
/**
 * @description This class provides methods to search and retrieve related contacts for a given parent object (Opportunity or Account).
 */
public with sharing class GenericLookupController {

    /**
     * @description Searches for related Contact records based on the parent record (Opportunity or Account) and a search term.
     *              It first searches Account-related Contacts for the given Opportunity and falls back to OpportunityContactRole if none are found.
     *              For Account, it directly searches related Contacts.
     * 
     * @param parentObjectName The API name of the parent object ('Opportunity' or 'Account').
     * @param parentId The Id of the parent record to search related Contacts for.
     * @param searchTerm The search keyword to match Contact names (uses LIKE filter).
     * @param displayFields Comma-separated Contact fields to display (defaults to 'Name,Phone' if not provided).
     * 
     * @return List<Map<String, String>> A list of maps containing Contact details: Id, Name, Phone, Title, and Type.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchRelatedContacts(String parentObjectName, Id parentId, String searchTerm, String displayFields) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        if (String.isBlank(displayFields)) {
            displayFields = 'Name,Phone';
        }
        String searchFilter = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        if (parentObjectName == 'Opportunity') {
            Opportunity opp = [
                SELECT Id, Account.Id, Account.Name, Account.Phone, Account.Fax 
                FROM Opportunity WHERE Id = :parentId WITH SECURITY_ENFORCED LIMIT 1
            ];
            
            if (opp.AccountId != null) {
                List<Contact> accContacts = [
                    SELECT Id, Name, Phone, Title 
                    FROM Contact 
                    WHERE AccountId = :opp.AccountId AND Name LIKE :searchFilter WITH SECURITY_ENFORCED
                    LIMIT 10
                ];
                
                for (Contact con : accContacts) {
                    results.add(new Map<String, String>{
                        'Id' => con.Id,
                        'Name' => con.Name,
                        'Phone' => con.Phone,
                        'Title' => con.Title,
                        'Type' => 'Contact'
                    });
                }
            }
            
            // If still no results, try OCR fallback
            if (results.isEmpty()) {
                List<OpportunityContactRole> ocrList = [
                    SELECT Contact.Id, Contact.Name, Contact.Phone, Contact.Title 
                    FROM OpportunityContactRole 
                    WHERE OpportunityId = :parentId AND Contact.Name LIKE :searchFilter WITH SECURITY_ENFORCED
                    LIMIT 10
                ];
                for (OpportunityContactRole ocr : ocrList) {
                    if (ocr.Contact != null) {
                        results.add(new Map<String, String>{
                            'Id' => ocr.Contact.Id,
                            'Name' => ocr.Contact.Name,
                            'Phone' => ocr.Contact.Phone,
                            'Title' => ocr.Contact.Title,
                            'Type' => 'Contact'
                        });
                    }
                }
            }
            
        } else if (parentObjectName == 'Account') {
            List<Contact> accContacts = [
                SELECT Id, Name, Phone, Title 
                FROM Contact 
                WHERE AccountId = :parentId AND Name LIKE :searchFilter WITH SECURITY_ENFORCED
                LIMIT 10
            ];
            
            for (Contact con : accContacts) {
                results.add(new Map<String, String>{
                    'Id' => con.Id,
                    'Name' => con.Name,
                    'Phone' => con.Phone,
                    'Title' => con.Title,
                    'Type' => 'Contact'
                });
            }
        }
        
        return results;
    }
    
    /**
     * @description Retrieves initial related records for a given parent object (Opportunity or Account).
     *              Includes the Account record itself and the most recently modified related contacts.
     *              For Opportunity, fallback to OpportunityContactRole if no Account contacts exist.
     * @param parentObjectName The name of the parent object ('Account' or 'Opportunity').
     * @param parentId The ID of the parent record.
     * @return A list of maps containing related record details (Id, Name, Phone, Fax/Title, Type).
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getInitialRelatedContacts(String parentObjectName, Id parentId) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        
        if (parentObjectName == 'Account') {
            // 🔹 Add the Account itself
            Account acc = [SELECT Id, Name, Phone, Fax FROM Account WHERE Id = :parentId WITH SECURITY_ENFORCED LIMIT 1];
            results.add(new Map<String, String>{
                'Id' => acc.Id,
                'Name' => acc.Name,
                'Phone' => acc.Phone,
                'Fax' => acc.Fax,
                'Type' => 'Account'
            });
            
            // 🔹 Add related Contacts
            for (Contact con : [SELECT Id, Name, Phone, Title FROM Contact WHERE AccountId = :parentId WITH SECURITY_ENFORCED ORDER BY LastModifiedDate DESC LIMIT 5]) {
                results.add(new Map<String, String>{
                    'Id' => con.Id,
                    'Name' => con.Name,
                    'Phone' => con.Phone,
                    'Title' => con.Title,
                    'Type' => 'Contact'
                });
            }
            
        } else if (parentObjectName == 'Opportunity') {
            // Step 1: Get Opportunity and its related Account
            Opportunity opp = [
                SELECT Id, Name, Account.Id, Account.Name, Account.Phone, Account.Fax 
                FROM Opportunity WHERE Id = :parentId WITH SECURITY_ENFORCED LIMIT 1
            ];
            
            Boolean contactsAdded = false;
            
            if (opp.AccountId != null) {
                // 🔹 Add the Account itself
                results.add(new Map<String, String>{
                    'Id' => opp.Account.Id,
                    'Name' => opp.Account.Name,
                    'Phone' => opp.Account.Phone,
                    'Fax' => opp.Account.Fax,
                    'Type' => 'Account'
                });
                
                // 🔹 Try to get Contacts from the Account
                List<Contact> accountContacts = [
                    SELECT Id, Name, Phone, Title 
                    FROM Contact 
                    WHERE AccountId = :opp.AccountId WITH SECURITY_ENFORCED
                    ORDER BY LastModifiedDate DESC 
                    LIMIT 5
                ];
                
                if (!accountContacts.isEmpty()) {
                    for (Contact con : accountContacts) {
                        results.add(new Map<String, String>{
                            'Id' => con.Id,
                            'Name' => con.Name,
                            'Phone' => con.Phone,
                            'Title' => con.Title,
                            'Type' => 'Contact'
                        });
                    }
                    contactsAdded = true;
                }
            }
            
            // Step 2: If no Account Contacts found, fallback to OCR
            if (!contactsAdded) {
                // List<OpportunityContactRole> ocrList = [
                //     SELECT Contact.Id, Contact.Name, Contact.Phone, Contact.Title
                //     FROM OpportunityContactRole
                //     WHERE OpportunityId = :parentId
                //     ORDER BY SystemModstamp DESC
                //     LIMIT 5
                // ];
                List<OpportunityContactRole> ocrListRaw = [
                    SELECT Contact.Id, Contact.Name, Contact.Phone, Contact.Title
                    FROM OpportunityContactRole 
                    WHERE OpportunityId = :parentId WITH SECURITY_ENFORCED
                    ORDER BY SystemModstamp DESC 
                    LIMIT 5
                ];
                Set<OpportunityContactRole> ocrList = new Set<OpportunityContactRole>();
                ocrList.addAll(ocrListRaw);
                for (OpportunityContactRole ocr : ocrList) {
                    if (ocr.Contact != null) {
                        results.add(new Map<String, String>{
                            'Id' => ocr.Contact.Id,
                            'Name' => ocr.Contact.Name,
                            'Phone' => ocr.Contact.Phone,
                            'Title' => ocr.Contact.Title,
                            'Type' => 'Contact'
                        });
                    }
                }
            }
        }
        return results;
    }
    
    
    
    
    
}