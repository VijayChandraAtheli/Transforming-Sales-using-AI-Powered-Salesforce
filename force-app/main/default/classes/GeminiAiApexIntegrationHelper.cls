public class GeminiAiApexIntegrationHelper {
    
    /**
     * Main method to generate email using Gemini AI
     * Called from LWC component
     * @param contextData - Map containing opportunity details
     * @param tone - Email tone (professional/friendly/direct)
     * @return String - AI-generated email content
     */
    @AuraEnabled
    public static String generateEmail(Map<String, Object> contextData, String tone) {
        try {
            // Build the prompt with opportunity context
            String prompt = buildEmailPrompt(contextData, tone);
            
            // Call Gemini API via ApexCalloutClass
            String generatedEmail = ApexCalloutClass.sendGeminiRequest(prompt);
            
            return generatedEmail;
            
        } catch (Exception e) {
            System.debug('Error generating email: ' + e.getMessage());
            throw new AuraHandledException('Error generating email: ' + e.getMessage());
        }
    }
    
    /**
     * Get comprehensive opportunity context for email generation
     * Gathers all relevant data about the opportunity
     * @param oppId - Opportunity Id
     * @return Map<String, Object> - Context data for prompt building
     */
    @AuraEnabled
    public static Map<String, Object> getOpportunityContext(Id oppId) {
        try {
            // Query Opportunity with related Account data
            Opportunity opp = [
                SELECT Id, Name, StageName, Amount, CloseDate, 
                       Account.Name, Account.Industry, Account.Type,
                       Owner.Name, Description, LeadSource,
                       Probability, Type
                FROM Opportunity 
                WHERE Id = :oppId 
                LIMIT 1
            ];
            
            // Get primary contact
            List<OpportunityContactRole> contactRoles = [
                SELECT Contact.Name, Contact.Email, Contact.Title, Role
                FROM OpportunityContactRole 
                WHERE OpportunityId = :oppId 
                AND IsPrimary = true
                LIMIT 1
            ];
            
            // Get recent activities (tasks and events)
            List<Task> recentTasks = [
                SELECT Subject, ActivityDate, Description, Status
                FROM Task 
                WHERE WhatId = :oppId 
                ORDER BY ActivityDate DESC 
                LIMIT 5
            ];
            
            // Build context map
            Map<String, Object> context = new Map<String, Object>();
            
            // Opportunity details
            context.put('opportunityName', opp.Name);
            context.put('stage', opp.StageName);
            context.put('amount', opp.Amount);
            context.put('closeDate', opp.CloseDate);
            context.put('probability', opp.Probability);
            context.put('type', opp.Type);
            context.put('description', opp.Description);
            context.put('leadSource', opp.LeadSource);
            
            // Account details
            context.put('accountName', opp.Account.Name);
            context.put('industry', opp.Account.Industry);
            context.put('accountType', opp.Account.Type);
            
            // Owner details
            context.put('ownerName', opp.Owner.Name);
            
            // Contact details (if exists)
            if (!contactRoles.isEmpty()) {
                OpportunityContactRole primaryContact = contactRoles[0];
                context.put('contactName', primaryContact.Contact.Name);
                context.put('contactEmail', primaryContact.Contact.Email);
                context.put('contactTitle', primaryContact.Contact.Title);
                context.put('contactRole', primaryContact.Role);
            }
            
            // Recent activities
            List<String> activityList = new List<String>();
            for (Task t : recentTasks) {
                String activity = t.Subject;
                if (t.ActivityDate != null) {
                    activity += ' (Date: ' + t.ActivityDate.format() + ')';
                }
                if (String.isNotBlank(t.Status)) {
                    activity += ' - Status: ' + t.Status;
                }
                activityList.add(activity);
            }
            context.put('recentActivities', activityList);
            
            return context;
            
        } catch (Exception e) {
            System.debug('Error in getOpportunityContext: ' + e.getMessage());
            throw new AuraHandledException('Error fetching opportunity context: ' + e.getMessage());
        }
    }
    
    /**
     * Build a comprehensive, structured prompt for email generation
     * @param context - Opportunity context data
     * @param tone - Desired email tone
     * @return String - Complete prompt for Gemini
     */
        private static String buildEmailPrompt(Map<String, Object> context, String tone) {
        String toneInstruction = getToneInstruction(tone);
        
        // Build comprehensive prompt
        String prompt = 'You are a professional sales email assistant. Generate a follow-up email based on the following information:\n\n';
        
        // Opportunity Information
        prompt += '=== OPPORTUNITY DETAILS ===\n';
        prompt += 'Opportunity Name: ' + context.get('opportunityName') + '\n';
        prompt += 'Current Stage: ' + context.get('stage') + '\n';
        
        if (context.get('amount') != null) {
            prompt += 'Deal Amount: $' + formatAmount(context.get('amount')) + '\n';
        }
        
        prompt += 'Expected Close Date: ' + context.get('closeDate') + '\n';
        
        if (context.get('probability') != null) {
            prompt += 'Win Probability: ' + context.get('probability') + '%\n';
        }
        
        if (context.containsKey('description') && context.get('description') != null) {
            prompt += 'Opportunity Description: ' + context.get('description') + '\n';
        }
        
        // Account Information
        prompt += '\n=== ACCOUNT DETAILS ===\n';
        prompt += 'Company: ' + context.get('accountName') + '\n';
        
        if (context.get('industry') != null) {
            prompt += 'Industry: ' + context.get('industry') + '\n';
        }
        
        if (context.get('accountType') != null) {
            prompt += 'Account Type: ' + context.get('accountType') + '\n';
        }
        
        // Contact Information
        if (context.containsKey('contactName')) {
            prompt += '\n=== PRIMARY CONTACT ===\n';
            prompt += 'Name: ' + context.get('contactName') + '\n';
            
            if (context.get('contactTitle') != null) {
                prompt += 'Title: ' + context.get('contactTitle') + '\n';
            }
            
            if (context.get('contactRole') != null) {
                prompt += 'Role in Deal: ' + context.get('contactRole') + '\n';
            }
        }
        
        // Recent Activities - FIXED TYPE CONVERSION
        if (context.containsKey('recentActivities')) {
            Object activitiesObj = context.get('recentActivities');
            if (activitiesObj != null) {
                // Handle type conversion from List<Object> to strings
                List<Object> activitiesRaw = (List<Object>) activitiesObj;
                if (!activitiesRaw.isEmpty()) {
                    prompt += '\n=== RECENT INTERACTIONS ===\n';
                    for (Integer i = 0; i < activitiesRaw.size(); i++) {
                        prompt += (i + 1) + '. ' + String.valueOf(activitiesRaw[i]) + '\n';
                    }
                }
            }
        }
        
        // Email Generation Instructions
        prompt += '\n=== EMAIL REQUIREMENTS ===\n';
        prompt += toneInstruction + '\n';
        prompt += '- Write a brief, professional follow-up email (3-4 short paragraphs)\n';
        prompt += '- Reference the current deal stage and context naturally\n';
        prompt += '- Include a clear, specific call-to-action\n';
        prompt += '- Keep it concise and action-oriented\n';
        prompt += '- Do NOT include a subject line\n';
        prompt += '- Start directly with the greeting (e.g., "Hi [Name],")\n';
        prompt += '- End with a professional sign-off\n';
        prompt += '- Use the contact name if provided, otherwise use a generic greeting\n\n';
        
        prompt += 'Generate the email now:';
        
        return prompt;
    }
    
    /**
     * Get tone-specific instructions for the AI
     * @param tone - Selected tone (professional/friendly/direct)
     * @return String - Instruction text for that tone
     */
    private static String getToneInstruction(String tone) {
        if (tone == 'professional') {
            return 'Tone: Professional and formal. Use business language and maintain appropriate distance.';
        } else if (tone == 'friendly') {
            return 'Tone: Warm and friendly. Build rapport while remaining professional.';
        } else if (tone == 'direct') {
            return 'Tone: Direct and concise. Get straight to the point with minimal fluff.';
        } else {
            return 'Tone: Professional and balanced.';
        }
    }
    
    /**
     * Format currency amounts nicely
     * @param amountObj - Amount as Object (could be Decimal or null)
     * @return String - Formatted currency string
     */
    private static String formatAmount(Object amountObj) {
        if (amountObj == null) {
            return '0.00';
        }
        
        Decimal amount = (Decimal) amountObj;
        return String.valueOf(amount.setScale(2).format());
    }
    
    /**
     * Test Gemini connection with a simple prompt
     * @return String - Test result
     */
    @AuraEnabled
    public static String testGeminiConnection() {
        try {
            // First test configuration
            String configStatus = ApexCalloutClass.testConfiguration();
            
            // Then test actual API call
            String testPrompt = 'Say "Connection successful!" if you can read this.';
            String response = ApexCalloutClass.sendGeminiRequest(testPrompt);
            
            return 'SUCCESS!\n\n' + configStatus + '\n\nAPI Response: ' + response;
            
        } catch (Exception e) {
            throw new AuraHandledException('Connection failed: ' + e.getMessage());
        }
    }
    
    /**
     * Generate a sample email for testing (without needing real opportunity data)
     * @return String - Sample generated email
     */
    @AuraEnabled
    public static String generateSampleEmail() {
        try {
            // Create mock context for testing
            Map<String, Object> mockContext = new Map<String, Object>();
            mockContext.put('opportunityName', 'Enterprise Software Deal');
            mockContext.put('stage', 'Proposal/Price Quote');
            mockContext.put('amount', 75000);
            mockContext.put('closeDate', Date.today().addDays(30));
            mockContext.put('probability', 70);
            mockContext.put('accountName', 'Acme Corporation');
            mockContext.put('industry', 'Technology');
            mockContext.put('contactName', 'John Smith');
            mockContext.put('contactTitle', 'VP of Sales');
            
            List<String> activities = new List<String>();
            activities.add('Product Demo (Date: ' + Date.today().addDays(-5).format() + ') - Status: Completed');
            activities.add('Follow-up Call (Date: ' + Date.today().addDays(-2).format() + ') - Status: Completed');
            mockContext.put('recentActivities', activities);
            
            // Generate email with mock data
            String email = generateEmail(mockContext, 'professional');
            
            return 'SAMPLE EMAIL GENERATED:\n\n' + email;
            
        } catch (Exception e) {
            throw new AuraHandledException('Sample email generation failed: ' + e.getMessage());
        }
    }
}